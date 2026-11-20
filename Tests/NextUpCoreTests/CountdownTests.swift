import Foundation
import Testing
@testable import NextUpCore

@Suite struct CountdownTests {
    // core-rules R14: a start on Friday 2026-11-20 at 17:30:00
    @Test(arguments: [
        (20, 12, 5, 13, "in 5 h 25 m"),
        (20, 12, 6, 0, "in 5 h 24 m"),
        (20, 12, 30, 0, "in 5 h"),
        (20, 17, 5, 0, "in 25 m"),
        (20, 17, 29, 1, "in 1 m"),
        (20, 17, 29, 59, "in 1 m"),
        (19, 14, 0, 0, "in 1 d 3 h"),
        (18, 17, 30, 0, "in 2 d"),
    ])
    func countdown(day: Int, h: Int, m: Int, s: Int, expected: String) {
        #expect(Agenda.countdown(from: at(2026, 11, day, h, m, s), to: at(2026, 11, 20, 17, 30)) == expected)
    }

    // core-rules R13: 0 minutes or less
    @Test func startedIsNow() {
        let start = at(2026, 11, 20, 17, 30)
        #expect(Agenda.countdown(from: start, to: start) == "now")
        #expect(Agenda.countdown(from: start + 90, to: start) == "now")
    }
}
