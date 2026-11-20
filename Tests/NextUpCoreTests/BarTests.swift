import Foundation
import Testing
@testable import NextUpCore

@Suite struct BarTests {
    // core-rules R18
    @Test func showsTheNextEventWithItsColor() {
        let blue = RGB(red: 0.2, green: 0.4, blue: 0.9)
        let events = [event("Design sync", at(2026, 11, 20, 17, 30), at(2026, 11, 20, 18, 30), color: blue)]
        #expect(Agenda.bar(for: events, now: at(2026, 11, 20, 12, 5, 13))
            == BarContent(text: "Design sync · in 5 h 25 m", color: blue))
    }

    // core-rules R19
    @Test func nothingComingIsNil() {
        let events = [event("Design sync", at(2026, 11, 20, 17, 30), at(2026, 11, 20, 18, 30))]
        #expect(Agenda.bar(for: events, now: at(2026, 11, 20, 17, 30)) == nil)
        #expect(Agenda.bar(for: [], now: at(2026, 11, 20, 12)) == nil)
    }
}
