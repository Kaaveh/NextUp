import Foundation
import Testing
@testable import NextUpCore

@Suite struct WindowTests {
    // core-rules R20
    @Test func todayAndTheNextTwoDays() {
        let now = at(2026, 11, 20, 12, 5, 13)
        #expect(Agenda.window(now: now, calendar: tehran) == DateInterval(start: now, end: at(2026, 11, 23)))
    }

    // core-rules R21: daylight saving starts in New York on 2026-03-08
    @Test func daysAreCalendarDays() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let window = Agenda.window(now: at(2026, 3, 7, 10, in: newYork), calendar: newYork)
        #expect(window.end == at(2026, 3, 10, in: newYork))
        #expect(window.end.timeIntervalSince(at(2026, 3, 7, in: newYork)) == 71 * 3600)
    }

    // core-rules R20–R21: in Santiago, 2026-09-06 has no 00:00 (daylight saving starts at midnight), so today starts at 01:00
    @Test func todayWithoutMidnightStillEndsAtMidnight() {
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = TimeZone(identifier: "America/Santiago")!
        let window = Agenda.window(now: at(2026, 9, 6, 12, in: santiago), calendar: santiago)
        #expect(window.end == at(2026, 9, 9, in: santiago))
    }
}
