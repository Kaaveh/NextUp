import Foundation
import Testing
@testable import NextUpCore

@Suite struct DeclinedTests {
    // core-rules R31–R32, R34
    @Test(arguments: [
        ("Design sync", false, "Design sync · in 5 h 25 m", "5:30\u{202F}PM · Design sync"),
        ("Design sync", true, "⚠ Design sync · in 5 h 25 m", "⚠ 5:30\u{202F}PM · Design sync"),
        ("Quarterly roadmap review with the whole team", true,
         "⚠ Quarterly roadmap review with… · in 5 h 25 m", "⚠ 5:30\u{202F}PM · Quarterly roadmap review with the whole team"),
    ])
    func prefix(title: String, declined: Bool, bar: String, row: String) {
        let events = [Event(title: title, start: at(2026, 11, 20, 17, 30), end: at(2026, 11, 20, 18, 30),
                            color: gray, meetURL: meet, declinedByGuest: declined)]
        let now = at(2026, 11, 20, 12, 5, 13)
        #expect(Agenda.bar(for: events, now: now, calendar: tehran) == BarContent(text: bar, color: gray, declinedByGuest: declined))
        #expect(Agenda.sections(for: events, now: now, calendar: tehran, locale: enUS).first?.rows
            == [MenuRow(text: row, color: gray, meetURL: meet, declinedByGuest: declined)])
    }

    // core-rules R33: the order and the alert plan ignore the flag
    @Test func changesNothingElse() {
        let start = at(2026, 11, 20, 17, 30), end = at(2026, 11, 20, 18, 30), now = at(2026, 11, 20, 12, 5, 13)
        let plain = [event("Alpha", start, end, link: true), event("Beta", start, end, link: true)]
        var flagged = plain
        flagged[0].declinedByGuest = true
        #expect(Agenda.ordered(flagged).map(\.title) == ["Alpha", "Beta"])
        #expect(Agenda.next(in: flagged, now: now)?.title == "Alpha")
        #expect(AlertPlan.alerts(for: flagged, now: now, calendar: tehran, locale: enUS)
            == AlertPlan.alerts(for: plain, now: now, calendar: tehran, locale: enUS))
    }
}
