import AppKit
import NextUpCore
import UserNotifications

/// Keeps macOS's pending notifications equal to the alert plan; normal mode only, never in the self-check (meeting-alerts R8–R23).
final class MeetingAlerts: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    /// The last plan given to `update`.
    private var plan: [Alert] = []
    /// `false` until the first update and after `forget()`: the next update starts from scratch (R11).
    private var scheduled = false
    private var quitting = false
    /// The scheduling of each update runs after the one before, so a removal can't overtake an older add.
    private var work: Task<Void, Never>?

    /// Sets the delegate and the `MEETING` category; called before any `await` at launch (R18–R19).
    override init() {
        super.init()
        center.delegate = self
        let join = UNNotificationAction(identifier: "JOIN", title: "Join", options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: "MEETING", actions: [join], intentIdentifiers: [])])
    }

    /// macOS asks once (R15).
    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// The next update schedules from scratch: the triggers hold wall-clock components (R12).
    func forget() {
        scheduled = false
    }

    /// Applies the plan's changes against the last one; the first time, removes everything first (R8–R11, R13).
    func update(_ new: [Alert], now: Date) {
        guard !quitting else { return }
        let fromScratch = !scheduled
        let changes = AlertPlan.changes(from: fromScratch ? [] : plan, to: new, now: now)
        plan = new
        scheduled = true
        let previous = work
        work = Task {
            await previous?.value
            if fromScratch {
                center.removeAllPendingNotificationRequests()
            } else if !changes.remove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: changes.remove)
            }
            for alert in changes.add {
                do {
                    try await center.add(Self.request(alert))
                } catch {
                    NSLog("NextUp: a meeting alert wasn't scheduled: %@", String(describing: error))
                }
            }
        }
    }

    /// Removes every pending request and waits until the removal has gone through (R14).
    func removeAll() async {
        quitting = true
        await work?.value
        center.removeAllPendingNotificationRequests()
        _ = await center.pendingNotificationRequests()
    }

    /// The identifier, the content and a one-time wall-clock trigger (R10).
    private static func request(_ alert: Alert) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        content.categoryIdentifier = "MEETING"
        content.userInfo = ["url": alert.url.absoluteString]
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alert.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Shown while NextUp is frontmost too (R21).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// `Join` or a click opens the link, only an https link on meet.google.com; dismissing does nothing (R20).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard [UNNotificationDefaultActionIdentifier, "JOIN"].contains(response.actionIdentifier),
              let link = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: link), url.scheme == "https", url.host() == "meet.google.com"
        else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
