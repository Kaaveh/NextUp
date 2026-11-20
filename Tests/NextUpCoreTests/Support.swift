import Foundation
@testable import NextUpCore

/// The fixed calendar of every test: Gregorian in Asia/Tehran, whose half-hour offset catches UTC assumptions.
let tehran: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tehran")!
    return calendar
}()

let enUS = Locale(identifier: "en_US")

/// A date from components in `calendar` (Tehran unless given).
func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
        in calendar: Calendar = tehran) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

let gray = RGB(red: 0.5, green: 0.5, blue: 0.5)
let meet = URL(string: "https://meet.google.com/abc-defg-hij")!

func event(_ title: String, _ start: Date, _ end: Date, link: Bool = false, color: RGB = gray) -> Event {
    Event(title: title, start: start, end: end, color: color, meetURL: link ? meet : nil)
}
