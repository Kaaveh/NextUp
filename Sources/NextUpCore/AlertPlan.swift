import Foundation

/// One meeting notification: shown a minute before the meeting, with its Meet link (meeting-alerts R2).
public struct Alert: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var title: String
    public var body: String
    public var url: URL

    public init(id: String, fireDate: Date, title: String, body: String, url: URL) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
        self.url = url
    }
}

public enum AlertPlan {
    /// One alert per meeting that hasn't started, deduplicated by id, sorted by fire date then id (meeting-alerts R1–R5).
    public static func alerts(for events: [Event], now: Date, calendar: Calendar, locale: Locale) -> [Alert] {
        let time = Agenda.shortTime(calendar: calendar, locale: locale)
        var seen = Set<String>()
        var alerts: [Alert] = []
        for event in Agenda.ordered(events) where event.start > now {
            guard let url = event.meetURL else { continue }
            let id = "\(Int(event.start.timeIntervalSince1970.rounded(.down)))|\(url.absoluteString)"
            guard seen.insert(id).inserted else { continue }
            alerts.append(Alert(id: id, fireDate: event.start - 60, title: Agenda.shownTitle(event.title, limit: 50),
                                body: "Starts at " + time.string(from: event.start), url: url))
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
}
