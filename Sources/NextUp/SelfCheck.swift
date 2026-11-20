import AppKit
import NextUpCore

/// `NextUp --self-check`: sample events at a fixed time, the bar and menu printed, the footprint (menubar-app R32–R37).
enum SelfCheck {
    nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "GMT")!
        return calendar
    }()
    static let locale = Locale(identifier: "en_US")
    static let now = date(day: 20, hour: 12, minute: 5, second: 13)

    static let events: [Event] = {
        let blue = RGB(red: 0.10, green: 0.45, blue: 0.90)
        let orange = RGB(red: 0.95, green: 0.55, blue: 0.15)
        func event(_ title: String, day: Int, _ hour: Int, _ minute: Int, minutes: Int, _ color: RGB, _ meet: String?) -> Event {
            let start = date(day: day, hour: hour, minute: minute)
            return Event(title: title, start: start, end: start.addingTimeInterval(Double(minutes) * 60),
                         color: color, meetURL: meet.flatMap { URL(string: "https://meet.google.com/\($0)") })
        }
        return [
            event("Standup", day: 20, 12, 0, minutes: 30, blue, "aaa-bbbb-ccc"),
            event("Design sync", day: 20, 17, 30, minutes: 60, blue, "abc-defg-hij"),
            event("Lunch", day: 21, 12, 0, minutes: 60, orange, nil),
            event("Planning", day: 22, 9, 30, minutes: 60, blue, "ddd-eeee-fff"),
        ]
    }()

    nonisolated private static func date(day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
    }

    static func run(_ statusItem: NSStatusItem) {
        let menu = statusItem.menu!
        menu.delegate?.menuNeedsUpdate?(menu)
        print(plain("bar: " + (statusItem.button?.title ?? "").trimmingCharacters(in: .whitespaces)))
        for item in menu.items { print(plain("menu: " + line(item))) }
        Task {
            try? await Task.sleep(for: .seconds(5))
            guard let bytes = footprint() else {
                FileHandle.standardError.write(Data("NextUp: proc_pid_rusage failed\n".utf8))
                exit(1)
            }
            print(String(format: "footprint: %.1f MB", Double(bytes) / 1_048_576))
            exit(0)
        }
    }

    private static func line(_ item: NSMenuItem) -> String {
        if item.isSeparatorItem { return "---" }
        if item.isSectionHeader { return "# " + item.title }
        guard let submenu = item.submenu else { return item.title }
        return item.title + " > " + submenu.items.map(\.title).joined(separator: ", ")
    }

    /// U+202F (before AM and PM) as a plain space, so the expected text can be typed.
    private static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// This process's physical footprint in bytes, as `footprint` reports it; `nil` when the call fails.
    private static func footprint() -> UInt64? {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V2, $0) }
        }
        return result == 0 ? info.ri_phys_footprint : nil
    }
}
