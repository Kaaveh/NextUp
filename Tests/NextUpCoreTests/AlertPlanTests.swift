import Foundation
import Testing
@testable import NextUpCore

@Suite struct AlertPlanTests {
    static let events = SectionsTests.events
    static let now = at(2026, 11, 20, 12, 5, 13)
    static let dueSecond = at(2026, 11, 20, 17, 29, 30)

    func plan(_ events: [Event] = events, now: Date = now) -> [Alert] {
        AlertPlan.alerts(for: events, now: now, calendar: tehran, locale: enUS)
    }

    // meeting-alerts R1, R2, R4, R7: the plan
    @Test func thePlan() {
        let plan = plan()
        #expect(plan.map(\.title) == ["Design sync", "Planning", "Retro"])
        #expect(plan.first == Alert(id: "1795183200|https://meet.google.com/abc-defg-hij",
                                    fireDate: at(2026, 11, 20, 17, 29), title: "Design sync",
                                    body: "Starts at 5:30\u{202F}PM", url: meet))
    }

    // meeting-alerts R5, R7
    @Test func anAlertStaysUntilItsMeetingStarts() {
        #expect(plan(now: Self.dueSecond).first?.title == "Design sync")
        #expect(plan(now: at(2026, 11, 20, 17, 30)).first?.title == "Planning")
    }

    // meeting-alerts R3, R7
    @Test func oneMeetingInTwoCalendarsAlertsOnce() {
        let twice = Self.events + Self.events.filter { $0.title == "Design sync" }
        #expect(plan(twice).count == 3)
    }

    // meeting-alerts R6, R7
    @Test func changesFromAPlanToItself() {
        let changes = AlertPlan.changes(from: plan(), to: plan(), now: Self.now)
        #expect(changes.remove.isEmpty)
        #expect(changes.add.isEmpty)
    }

    @Test func changesFromAnEmptyPlan() {
        let changes = AlertPlan.changes(from: [], to: plan(), now: Self.now)
        #expect(changes.remove.isEmpty)
        #expect(changes.add == plan())
    }

    // meeting-alerts R6, R7, R13: an alert already due isn't added
    @Test func changesFromAnEmptyPlanInTheDueSecond() {
        let changes = AlertPlan.changes(from: [], to: plan(now: Self.dueSecond), now: Self.dueSecond)
        #expect(changes.add.map(\.title) == ["Planning", "Retro"])
    }

    @Test func anAlertLeftThePlan() {
        let last = plan()
        let changes = AlertPlan.changes(from: last, to: plan(Self.events.filter { $0.title != "Retro" }), now: Self.now)
        #expect(changes.remove == [last[2].id])
        #expect(changes.add.isEmpty)
    }

    @Test func theSameIdWithANewTitle() {
        let renamed = Self.events.map { event in
            var event = event
            if event.title == "Design sync" { event.title = "Design review" }
            return event
        }
        let new = plan(renamed)
        let changes = AlertPlan.changes(from: plan(), to: new, now: Self.now)
        #expect(changes.remove.isEmpty)
        #expect(changes.add == [new[0]])
        #expect(new[0].id == plan()[0].id)
    }
}
