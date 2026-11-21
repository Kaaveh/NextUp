import Foundation

/// What the menu bar shows: the next event's text and its calendar's colour.
public struct BarContent: Equatable, Sendable {
    public var text: String
    public var color: RGB
    public var declinedByGuest: Bool

    public init(text: String, color: RGB, declinedByGuest: Bool = false) {
        self.text = text
        self.color = color
        self.declinedByGuest = declinedByGuest
    }
}

/// One menu row: "5:30 PM · Design sync", its calendar's colour and its Meet link.
public struct MenuRow: Equatable, Sendable {
    public var text: String
    public var color: RGB
    public var meetURL: URL?
    public var declinedByGuest: Bool

    public init(text: String, color: RGB, meetURL: URL?, declinedByGuest: Bool = false) {
        self.text = text
        self.color = color
        self.meetURL = meetURL
        self.declinedByGuest = declinedByGuest
    }
}

/// A menu section: "Ending in 25 m", "Upcoming in 5 h 25 m", "Tomorrow" or "Sun Nov 22", with its rows.
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

    /// Ending in, Upcoming, Tomorrow and the day after tomorrow, empty ones left out (core-rules R22–R25, R39).
    public static func sections(for events: [Event], now: Date, calendar: Calendar, locale: Locale) -> [MenuSection] {
        let tomorrow = day(after: 1, from: now, calendar: calendar)
        let dayAfter = day(after: 2, from: now, calendar: calendar)
        let end = day(after: 3, from: now, calendar: calendar)
        let events = ordered(events)
        let starting = { (from: Date, to: Date) in events.filter { $0.start > now && from <= $0.start && $0.start < to } }

        let time = shortTime(calendar: calendar, locale: locale)
        let date = DateFormatter()
        date.locale = locale
        date.calendar = calendar
        date.timeZone = calendar.timeZone
        date.dateFormat = "EEE MMM d"

        let running = events.filter { $0.start <= now && now < $0.end }
        let later = starting(now, tomorrow)
        let groups = [
            ("Ending " + (running.map(\.end).min().map { countdown(from: now, to: $0) } ?? ""), running),
            ("Upcoming " + (later.first.map { countdown(from: now, to: $0.start) } ?? ""), later),
            ("Tomorrow", starting(tomorrow, dayAfter)),
            (date.string(from: dayAfter), starting(dayAfter, end)),
        ]
        return groups.filter { !$0.1.isEmpty }.map { header, events in
            MenuSection(header: header, rows: events.map {
                MenuRow(text: flag($0) + "\(time.string(from: $0.start)) · \(shownTitle($0.title, limit: 50))",
                        color: $0.color, meetURL: $0.meetURL, declinedByGuest: $0.declinedByGuest)
            })
        }
    }

    /// The locale's short time in the calendar's time zone: `5:30 PM` in `en_US` (core-rules R25).
    static func shortTime(calendar: Calendar, locale: Locale) -> DateFormatter {
        let time = DateFormatter()
        time.locale = locale
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time.dateStyle = .none
        time.timeStyle = .short
        return time
    }

    /// 00:00 of the `n`th day after today, through `Calendar` rather than 86 400 s steps (core-rules R21).
    static func day(after n: Int, from now: Date, calendar: Calendar) -> Date {
        // Add first, then take the start of day: a day whose midnight is skipped by DST starts at 01:00,
        // and adding days to that start would keep the 01:00.
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: n, to: now)!)
    }

    /// "Design sync · in 5 h 25 m" or "Standup · now" for the bar's event, `nil` when there is none (core-rules R18–R19, R35, R37–R38).
    public static func bar(for events: [Event], now: Date, calendar: Calendar) -> BarContent? {
        let today = day(after: 1, from: now, calendar: calendar)
        let next = next(in: events, now: now).flatMap { $0.start < today ? $0 : nil }
        let soon = next.flatMap { minutes(from: now, to: $0.start) <= 15 ? $0 : nil }
        let running = ordered(events).filter { $0.start <= now && now < $0.end }
        let latest = running.first { $0.start == running.map(\.start).max() }
        guard let event = soon ?? latest ?? next else { return nil }
        return BarContent(
            text: flag(event) + "\(shownTitle(event.title, limit: 30)) · \(countdown(from: now, to: event.start))",
            color: event.color,
            declinedByGuest: event.declinedByGuest
        )
    }

    /// `⚠ ` in front of the text of an event a guest declined, outside the title cut (core-rules R32).
    static func flag(_ event: Event) -> String {
        event.declinedByGuest ? "\u{26A0} " : ""
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
        let minutes = minutes(from: now, to: start)
        guard minutes > 0 else { return "now" }
        let (d, h, m) = (minutes / 1440, minutes % 1440 / 60, minutes % 60)
        var parts: [String] = []
        if d > 0 { parts.append("\(d) d") }
        if h > 0 { parts.append("\(h) h") }
        if m > 0 && d == 0 { parts.append("\(m) m") }
        return "in " + parts.joined(separator: " ")
    }

    /// Whole minutes from `now` to `start`, rounded up (core-rules R12).
    static func minutes(from now: Date, to start: Date) -> Int {
        Int((start.timeIntervalSince(now) / 60).rounded(.up))
    }

    /// Whitespace collapsed, ends trimmed, `(No title)` when empty, cut to `limit` characters with `…` (core-rules R15–R16).
    static func shownTitle(_ title: String, limit: Int) -> String {
        let shown = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if shown.isEmpty { return "(No title)" }
        return shown.count > limit ? shown.prefix(limit - 1) + "…" : shown
    }
}
