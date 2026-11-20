import Foundation

/// A calendar's colour as sRGB, each channel in 0...1 (core-rules R6).
public struct RGB: Equatable, Sendable {
    public var red, green, blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// One timed calendar event, as the rules see it (core-rules R5, R31).
public struct Event: Equatable, Sendable {
    public var title: String
    public var start: Date
    public var end: Date
    public var color: RGB
    public var meetURL: URL?
    /// A guest other than the user declined it (core-rules R31).
    public var declinedByGuest: Bool

    public init(title: String, start: Date, end: Date, color: RGB, meetURL: URL?, declinedByGuest: Bool = false) {
        self.title = title
        self.start = start
        self.end = end
        self.color = color
        self.meetURL = meetURL
        self.declinedByGuest = declinedByGuest
    }
}
