import Foundation
import Testing
@testable import NextUpCore

@Suite struct MeetLinkTests {
    // core-rules R9
    @Test(arguments: [
        (#"<a href="https://meet.google.com/abc-defg-hij">https://meet.google.com/abc-defg-hij</a>"#, "https://meet.google.com/abc-defg-hij"),
        ("Agenda first.\nJoin: meet.google.com/abc-defg-hij.", "https://meet.google.com/abc-defg-hij"),
        ("http://Meet.Google.com/abc-defg-hij?authuser=1", "https://meet.google.com/abc-defg-hij"),
        ("https://meet.google.com/aaa-bbbb-ccc and https://meet.google.com/ddd-eeee-fff", "https://meet.google.com/aaa-bbbb-ccc"),
    ])
    func finds(text: String, expected: String) {
        #expect(MeetLink.find(in: text) == URL(string: expected))
    }

    @Test(arguments: [nil, "", "https://zoom.us/j/123456", "https://meet.google.com/"] as [String?])
    func findsNothing(text: String?) {
        #expect(MeetLink.find(in: text) == nil)
    }
}
