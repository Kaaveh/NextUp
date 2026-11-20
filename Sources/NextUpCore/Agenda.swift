import Foundation

/// What the menu bar shows: the next event's text and its calendar's colour.
public struct BarContent: Equatable, Sendable {
    public var text: String
    public var color: RGB

    public init(text: String, color: RGB) {
        self.text = text
        self.color = color
    }
}

public enum Agenda {
    /// "Design sync · in 5 h 25 m" for the next event, `nil` when none is coming (core-rules R18–R19).
    public static func bar(for events: [Event], now: Date) -> BarContent? {
        guard let event = next(in: events, now: now) else { return nil }
        return BarContent(
            text: "\(shownTitle(event.title, limit: 30)) · \(countdown(from: now, to: event.start))",
            color: event.color
        )
    }

    /// Start ascending, then events with a Meet link, then title ascending (core-rules R10).
    static func ordered(_ events: [Event]) -> [Event] {
        events.sorted { a, b in
            if a.start != b.start { return a.start < b.start }
            if (a.meetURL != nil) != (b.meetURL != nil) { return a.meetURL != nil }
            return a.title < b.title
        }
    }

    /// The first event in order that hasn't started (core-rules R11).
    static func next(in events: [Event], now: Date) -> Event? {
        ordered(events).first { $0.start > now }
    }

    /// "in 5 h 25 m": whole minutes until `start`, rounded up (core-rules R12–R13).
    static func countdown(from now: Date, to start: Date) -> String {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        guard minutes > 0 else { return "now" }
        let (d, h, m) = (minutes / 1440, minutes % 1440 / 60, minutes % 60)
        var parts: [String] = []
        if d > 0 { parts.append("\(d) d") }
        if h > 0 { parts.append("\(h) h") }
        if m > 0 && d == 0 { parts.append("\(m) m") }
        return "in " + parts.joined(separator: " ")
    }

    /// Whitespace collapsed, ends trimmed, `(No title)` when empty, cut to `limit` characters with `…` (core-rules R15–R16).
    static func shownTitle(_ title: String, limit: Int) -> String {
        let shown = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if shown.isEmpty { return "(No title)" }
        return shown.count > limit ? shown.prefix(limit - 1) + "…" : shown
    }
}
