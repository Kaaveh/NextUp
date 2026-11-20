import Testing
@testable import NextUpCore

@Suite struct TitleTests {
    // core-rules R17
    @Test(arguments: [
        ("  Design\n sync ", 30, "Design sync"),
        ("", 30, "(No title)"),
        (" \n ", 30, "(No title)"),
        ("Quarterly roadmap review with the whole team", 30, "Quarterly roadmap review with…"),
        ("Quarterly roadmap review with the whole team", 50, "Quarterly roadmap review with the whole team"),
        ("Quarterly roadmap review, pt 2", 30, "Quarterly roadmap review, pt 2"),
    ])
    func shown(title: String, limit: Int, expected: String) {
        let shown = Agenda.shownTitle(title, limit: limit)
        #expect(shown == expected)
        #expect(shown.count <= limit)
    }
}
