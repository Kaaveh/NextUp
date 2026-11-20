import Foundation

public enum MeetLink {
    /// The first Meet link anywhere in `text`, as `https://meet.google.com/<code>` (core-rules R7–R8).
    public static func find(in text: String?) -> URL? {
        guard let text,
              let match = text.firstMatch(of: /(?:https?:\/\/)?meet\.google\.com\/([A-Za-z0-9_-]+)/.ignoresCase())
        else { return nil }
        return URL(string: "https://meet.google.com/\(match.1)")
    }
}
