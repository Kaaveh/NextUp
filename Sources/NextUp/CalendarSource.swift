import AppKit
import EventKit
import NextUpCore

/// EventKit, the only source of events: access, reading, mapping to `Event` (menubar-app R9–R14).
final class CalendarSource {
    private let store = EKEventStore()
    /// Whether the store has had full access since it was created or last reset.
    private var hadAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess

    static var accessNotDetermined: Bool { EKEventStore.authorizationStatus(for: .event) == .notDetermined }

    /// Shows macOS's prompt; called once, at launch, while access is not determined.
    func requestAccess() async {
        do { _ = try await store.requestFullAccessToEvents() } catch { NSLog("NextUp: calendar access request failed: %@", String(describing: error)) }
    }

    /// The events in `window`, or `nil` without full access.
    func events(in window: DateInterval) -> [Event]? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            hadAccess = false
            return nil
        }
        if !hadAccess {
            // Access granted after the store was created: it reads nothing until reset.
            store.reset()
            hadAccess = true
        }
        let predicate = store.predicateForEvents(withStart: window.start, end: window.end, calendars: nil)
        return store.events(matching: predicate).compactMap(Self.event)
    }

    /// The `Event` for `event`, `nil` when it is all-day, cancelled or declined.
    private static func event(_ event: EKEvent) -> Event? {
        if event.isAllDay || event.status == .canceled { return nil }
        if event.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }) == true { return nil }
        let color = event.calendar?.color?.usingColorSpace(.sRGB)
        return Event(
            title: event.title ?? "",
            start: event.startDate,
            end: event.endDate,
            color: color.map { RGB(red: $0.redComponent, green: $0.greenComponent, blue: $0.blueComponent) }
                ?? RGB(red: 0.5, green: 0.5, blue: 0.5),
            meetURL: MeetLink.find(in: event.notes)
        )
    }
}
