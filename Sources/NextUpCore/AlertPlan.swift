import Foundation

/// One meeting notification: shown a minute before the meeting, with its Meet link (meeting-alerts R2).
public struct Alert: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var title: String
    public var body: String
    public var url: URL
    public var start: Date
    public var end: Date
    /// "5:30 – 6:30 PM": the start and end as one range (meeting-alerts R26).
    public var timeRange: String

    public init(id: String, fireDate: Date, title: String, body: String, url: URL, start: Date, end: Date, timeRange: String) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
        self.url = url
        self.start = start
        self.end = end
        self.timeRange = timeRange
    }
}

public enum AlertPlan {
    /// One alert per meeting that hasn't started, deduplicated by id, sorted by fire date then id (meeting-alerts R1–R5).
    public static func alerts(for events: [Event], now: Date, calendar: Calendar, locale: Locale) -> [Alert] {
        let time = Agenda.shortTime(calendar: calendar, locale: locale)
        let range = DateIntervalFormatter()
        range.locale = locale
        range.calendar = calendar
        range.timeZone = calendar.timeZone
        range.dateTemplate = "jm"
        var seen = Set<String>()
        var alerts: [Alert] = []
        for event in Agenda.ordered(events) where event.start > now {
            guard let url = event.meetURL else { continue }
            let id = "\(Int(event.start.timeIntervalSince1970.rounded(.down)))|\(url.absoluteString)"
            guard seen.insert(id).inserted else { continue }
            alerts.append(Alert(id: id, fireDate: event.start - 60, title: Agenda.shownTitle(event.title, limit: 50),
                                body: "Starts at " + time.string(from: event.start), url: url,
                                start: event.start, end: event.end, timeRange: range.string(from: event.start, to: event.end)))
        }
        return alerts.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
    }

    /// What to remove from and add to the last scheduled plan; an alert already due isn't added (meeting-alerts R6, R13).
    public static func changes(from last: [Alert], to plan: [Alert], now: Date) -> (remove: [String], add: [Alert]) {
        let ids = Set(plan.map(\.id))
        let kept = Dictionary(last.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return (last.map(\.id).filter { !ids.contains($0) },
                plan.filter { kept[$0.id] != $0 && $0.fireDate > now })
    }

    /// The panel's status: the countdown to the start, `now` until the end, `nil` from the end on (meeting-alerts R27).
    public static func panelStatus(for alert: Alert, now: Date) -> String? {
        now < alert.end ? Agenda.countdown(from: now, to: alert.start) : nil
    }
}
