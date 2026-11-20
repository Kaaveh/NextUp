import Foundation
import Testing
@testable import NextUpCore

@Suite struct OrderTests {
    // core-rules R10
    @Test func equalStartsPutTheMeetingFirstThenTitles() {
        let t = at(2026, 11, 20, 17, 30)
        let events = [
            event("Focus", t, t + 3600),
            event("Alpha", t, t + 3600),
            event("Sync", t, t + 3600, link: true),
            event("Early", t - 3600, t),
        ]
        #expect(Agenda.ordered(events).map(\.title) == ["Early", "Sync", "Alpha", "Focus"])
    }

    // core-rules R11
    @Test func nextIsTheFirstThatHasNotStarted() {
        let now = at(2026, 11, 20, 12)
        let events = [
            event("Later", now + 7200, now + 9000),
            event("Running", now - 60, now + 600),
            event("Starting now", now, now + 600),
            event("Soon", now + 60, now + 600),
        ]
        #expect(Agenda.next(in: events, now: now)?.title == "Soon")
        #expect(Agenda.next(in: events, now: now + 7200) == nil)
    }
}
