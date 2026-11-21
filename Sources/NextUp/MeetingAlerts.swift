import AppKit
import NextUpCore
import UserNotifications

/// Keeps macOS's pending notifications and the panel timers equal to the alert plan; normal mode only, never in the self-check
/// (meeting-alerts R8–R23, R25, R29–R35).
final class MeetingAlerts: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    /// The last plan given to `update`.
    private var plan: [Alert] = []
    /// `false` until the first update and after `forget()`: the next update starts from scratch (R11).
    private var scheduled = false
    private var quitting = false
    /// The authorization status read after the last refresh; `nil` until the first read (R16).
    private var status: UNAuthorizationStatus?
    /// The scheduling of each update runs after the one before, so a removal can't overtake an older add.
    private var work: Task<Void, Never>?
    /// One one-shot timer per alert, at its fire date, by id (R29).
    private var timers: [String: Timer] = [:]
    /// The open panels, top to bottom (R32).
    private var panels: [MeetingPanel] = []

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
    /// The panel timers follow the same changes, and open panels redraw or close (R29, R33).
    func update(_ new: [Alert], now: Date) {
        for panel in panels { panel.update(now: now) }
        guard !quitting else { return }
        let fromScratch = !scheduled
        let changes = AlertPlan.changes(from: fromScratch ? [] : plan, to: new, now: now)
        plan = new
        scheduled = true
        let stale = fromScratch ? Array(timers.keys) : changes.remove
        for id in stale { timers.removeValue(forKey: id)?.invalidate() }
        for alert in changes.add { schedulePanel(alert) }
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
            // A request added without permission may have been dropped: a new status schedules from scratch (R16).
            let status = await center.notificationSettings().authorizationStatus
            // The first read only records the status: this update's adds already ran under it.
            let changed = self.status.map { $0 != status } ?? false
            self.status = status
            if changed {
                forget()
                update(plan, now: Date())
            }
        }
    }

    /// The status is known and isn't `.authorized`: the menu offers `Turn on meeting alerts…` (R17).
    var isOff: Bool {
        status.map { $0 != .authorized } ?? false
    }

    /// Removes every pending request and waits until the removal has gone through (R14).
    func removeAll() async {
        quitting = true
        await work?.value
        center.removeAllPendingNotificationRequests()
        _ = await center.pendingNotificationRequests()
    }

    // MARK: Panel (R25, R29–R35)

    /// A one-shot timer at the fire date that opens the panel, replacing an older timer of that id (R29).
    private func schedulePanel(_ alert: Alert) {
        timers[alert.id]?.invalidate()
        let timer = Timer(fire: alert.fireDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.openPanel(alert) }
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[alert.id] = timer
    }

    /// Opens the alert's panel below the open ones, unless one with its id is open (R30, R32); after a sleep past
    /// the meeting's end, none.
    private func openPanel(_ alert: Alert) {
        timers[alert.id] = nil
        let now = Date()
        guard !panels.contains(where: { $0.alert.id == alert.id }), AlertPlan.panelStatus(for: alert, now: now) != nil else { return }
        let panel = MeetingPanel(alert, now: now) { [weak self] closed in
            self?.panels.removeAll { $0 === closed }
            self?.stackPanels()
        }
        panels.append(panel)
        stackPanels()
        panel.orderFrontRegardless()
    }

    /// Top right of the menu bar's screen, 8 pt in from the top and right of its visible frame, 8 pt apart (R32).
    private func stackPanels() {
        guard let visible = NSScreen.screens.first?.visibleFrame else { return }
        var top = visible.maxY - 8
        for panel in panels {
            panel.setFrameTopLeftPoint(NSPoint(x: visible.maxX - 8 - panel.frame.width, y: top))
            top -= panel.frame.height + 8
        }
    }

    /// Opens an https link on meet.google.com and nothing else (R20, R34).
    static func open(_ url: URL) {
        guard url.scheme == "https", url.host() == "meet.google.com" else { return }
        NSWorkspace.shared.open(url)
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

    /// `Join` or a click opens the link, only an https link on meet.google.com, and closes the panel with the same id;
    /// dismissing does nothing (R20, R34).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard [UNNotificationDefaultActionIdentifier, "JOIN"].contains(response.actionIdentifier) else { return }
        let id = response.notification.request.identifier
        let url = (response.notification.request.content.userInfo["url"] as? String).flatMap(URL.init(string:))
        await MainActor.run {
            if let url { Self.open(url) }
            panels.first { $0.alert.id == id }?.dismiss()
        }
    }
}
