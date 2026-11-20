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

/// One menu row: "5:30 PM · Design sync", its calendar's colour and its Meet link.
public struct MenuRow: Equatable, Sendable {
    public var text: String
    public var color: RGB
    public var meetURL: URL?

    public init(text: String, color: RGB, meetURL: URL?) {
        self.text = text
        self.color = color
        self.meetURL = meetURL
    }
}

/// A menu section: "Now", "Upcoming in 5 h 25 m", "Tomorrow" or "Sun Nov 22", with its rows.
public struct MenuSection: Equatable, Sendable {
    public var header: String
    public var rows: [MenuRow]

    public init(header: String, rows: [MenuRow]) {
        self.header = header
        self.rows = rows
    }
}

public enum Agenda {
    /// From `now` to 00:00 of the third day after today in `calendar`, by calendar days (core-rules R20–R21).
    public static func window(now: Date, calendar: Calendar) -> DateInterval {
        DateInterval(start: now, end: day(after: 3, from: now, calendar: calendar))
    }

    /// Now, Upcoming, Tomorrow and the day after tomorrow, empty ones left out (core-rules R22–R25).
    public static func sections(for events: [Event], now: Date, calendar: Calendar, locale: Locale) -> [MenuSection] {
        let tomorrow = day(after: 1, from: now, calendar: calendar)
        let dayAfter = day(after: 2, from: now, calendar: calendar)
        let end = day(after: 3, from: now, calendar: calendar)
        let events = ordered(events)
        let starting = { (from: Date, to: Date) in events.filter { $0.start > now && from <= $0.start && $0.start < to } }

        let time = DateFormatter()
        time.locale = locale
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time.dateStyle = .none
        time.timeStyle = .short
        let date = DateFormatter()
        date.locale = locale
        date.calendar = calendar
        date.timeZone = calendar.timeZone
        date.dateFormat = "EEE MMM d"

        let running = events.filter { $0.start <= now && now < $0.end }
        let later = starting(now, tomorrow)
        let groups = [
            ("Now", running),
            ("Upcoming " + (later.first.map { countdown(from: now, to: $0.start) } ?? ""), later),
            ("Tomorrow", starting(tomorrow, dayAfter)),
            (date.string(from: dayAfter), starting(dayAfter, end)),
        ]
        return groups.filter { !$0.1.isEmpty }.map { header, events in
            MenuSection(header: header, rows: events.map {
                MenuRow(text: "\(time.string(from: $0.start)) · \(shownTitle($0.title, limit: 50))",
                        color: $0.color, meetURL: $0.meetURL)
            })
        }
    }

    /// 00:00 of the `n`th day after today, through `Calendar` rather than 86 400 s steps (core-rules R21).
    static func day(after n: Int, from now: Date, calendar: Calendar) -> Date {
        // Add first, then take the start of day: a day whose midnight is skipped by DST starts at 01:00,
        // and adding days to that start would keep the 01:00.
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: n, to: now)!)
    }

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
