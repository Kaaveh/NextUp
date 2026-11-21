import Foundation
import Testing
@testable import NextUpCore

@Suite struct BarTests {
    // core-rules R18
    @Test func showsTheNextEventWithItsColor() {
        let blue = RGB(red: 0.2, green: 0.4, blue: 0.9)
        let events = [event("Design sync", at(2026, 11, 20, 17, 30), at(2026, 11, 20, 18, 30), color: blue)]
        #expect(Agenda.bar(for: events, now: at(2026, 11, 20, 12, 5, 13), calendar: tehran)
            == BarContent(text: "Design sync · in 5 h 25 m", color: blue))
    }

    // core-rules R19: nothing running and nothing more today
    @Test func nothingComingIsNil() {
        let events = [event("Design sync", at(2026, 11, 20, 17, 30), at(2026, 11, 20, 18, 30))]
        #expect(Agenda.bar(for: events, now: at(2026, 11, 20, 18, 30), calendar: tehran) == nil)
        #expect(Agenda.bar(for: [], now: at(2026, 11, 20, 12), calendar: tehran) == nil)
    }

    // core-rules R35–R36
    @Test func onlyTodayShows() {
        let now = at(2026, 11, 20, 12, 5, 13)
        let lateTonight = [event("Design sync", at(2026, 11, 20, 23, 59), at(2026, 11, 21, 0, 30))]
        let midnight = [event("Design sync", at(2026, 11, 21), at(2026, 11, 21, 0, 30))]
        #expect(Agenda.bar(for: lateTonight, now: now, calendar: tehran)?.text == "Design sync · in 11 h 54 m")
        #expect(Agenda.bar(for: midnight, now: now, calendar: tehran) == nil)
    }

    // core-rules R38: a running event shows with its colour and flag, even when the next one is tomorrow
    @Test func runningShowsNow() {
        let blue = RGB(red: 0.2, green: 0.4, blue: 0.9)
        var running = event("Design sync", at(2026, 11, 20, 23), at(2026, 11, 21, 0, 30), color: blue)
        running.declinedByGuest = true
        let events = [running, event("Lunch", at(2026, 11, 21, 0, 10), at(2026, 11, 21, 1))]
        #expect(Agenda.bar(for: events, now: at(2026, 11, 20, 23, 55), calendar: tehran)
            == BarContent(text: "⚠ Design sync · now", color: blue, declinedByGuest: true))
    }
}
