import Foundation
import Testing
@testable import NextUpCore

@Suite struct SectionsTests {
    // core-rules R26, in an order other than the sorted one
    static let events = [
        event("Retro", at(2026, 11, 23, 10), at(2026, 11, 23, 11), link: true),
        event("Lunch", at(2026, 11, 21, 12), at(2026, 11, 21, 13)),
        event("Design sync", at(2026, 11, 20, 17, 30), at(2026, 11, 20, 18, 30), link: true),
        event("Planning", at(2026, 11, 22, 9, 30), at(2026, 11, 22, 10, 30), link: true),
        event("Breakfast", at(2026, 11, 20, 8), at(2026, 11, 20, 8, 30)),
        event("Standup", at(2026, 11, 20, 12), at(2026, 11, 20, 12, 30), link: true),
    ]

    /// Each section as its header followed by its rows' text.
    func lines(_ events: [Event], _ now: Date, locale: Locale = enUS) -> [[String]] {
        Agenda.sections(for: events, now: now, calendar: tehran, locale: locale).map { [$0.header] + $0.rows.map(\.text) }
    }

    // core-rules R26
    @Test func example() {
        let now = at(2026, 11, 20, 12, 5, 13)
        #expect(lines(Self.events, now) == [
            ["Ending in 25 m", "12:00\u{202F}PM · Standup"],
            ["Upcoming in 5 h 25 m", "5:30\u{202F}PM · Design sync"],
            ["Tomorrow", "12:00\u{202F}PM · Lunch"],
            ["Sun Nov 22", "9:30\u{202F}AM · Planning"],
        ])
        #expect(Agenda.bar(for: Self.events, now: now, calendar: tehran)?.text == "Standup · now")
    }

    // core-rules R24: a row carries its event's colour and Meet link
    @Test func rowsCarryColorAndLink() {
        let blue = RGB(red: 0.2, green: 0.4, blue: 0.9)
        let start = at(2026, 11, 20, 17, 30)
        let sections = Agenda.sections(for: [event("Design sync", start, start + 3600, link: true, color: blue)],
                                       now: at(2026, 11, 20, 12), calendar: tehran, locale: enUS)
        #expect(sections.first?.rows == [MenuRow(text: "5:30\u{202F}PM · Design sync", color: blue, meetURL: meet)])
    }

    // core-rules R25
    @Test func timeFollowsTheLocale() {
        let start = at(2026, 11, 20, 17, 30)
        let rows = lines([event("Design sync", start, start + 3600)], at(2026, 11, 20, 12),
                         locale: Locale(identifier: "en_GB"))
        #expect(rows.first?.last == "17:30 · Design sync")
    }

    // core-rules R27
    @Test(arguments: [
        (at(2026, 11, 20, 17, 30), true, [["Ending in 1 h", "5:30\u{202F}PM · Design sync"], ["Tomorrow", "12:00\u{202F}PM · Lunch"], ["Sun Nov 22", "9:30\u{202F}AM · Planning"]], "Design sync · now" as String?),
        (at(2026, 11, 20, 19), true, [["Tomorrow", "12:00\u{202F}PM · Lunch"], ["Sun Nov 22", "9:30\u{202F}AM · Planning"]], nil),
        (at(2026, 11, 22, 23), false, [], nil),
    ])
    func moreCases(now: Date, withRetro: Bool, expected: [[String]], bar: String?) {
        let events = withRetro ? Self.events : Self.events.filter { $0.title != "Retro" }
        #expect(lines(events, now) == expected)
        #expect(Agenda.bar(for: events, now: now, calendar: tehran)?.text == bar)
    }

    // core-rules R37–R40: R26's events plus two running from 16:00
    @Test(arguments: [
        (at(2026, 11, 20, 16, 30), "Focus · now" as String?, "Ending in 30 m"),
        (at(2026, 11, 20, 17, 14, 59), "Workshop · now", "Ending in 46 m"),
        (at(2026, 11, 20, 17, 15), "Design sync · in 15 m", "Ending in 45 m"),
        (at(2026, 11, 20, 17, 30), "Design sync · now", "Ending in 30 m"),
        (at(2026, 11, 20, 18), "Design sync · now", "Ending in 30 m"),
        (at(2026, 11, 20, 18, 30), nil, "Tomorrow"),
    ])
    func runningEvent(now: Date, bar: String?, firstHeader: String) {
        let events = Self.events + [
            event("Workshop", at(2026, 11, 20, 16), at(2026, 11, 20, 18)),
            event("Focus", at(2026, 11, 20, 16), at(2026, 11, 20, 17)),
        ]
        #expect(Agenda.bar(for: events, now: now, calendar: tehran)?.text == bar)
        #expect(lines(events, now).first?.first == firstHeader)
    }
}
