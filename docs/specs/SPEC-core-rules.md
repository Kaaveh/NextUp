# Spec: core-rules

Module 1 of 3 in the NextUp capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on nothing. Status: specified, not built.

## Objective

Every rule NextUp shows or acts on in the bar and the menu is a pure function in one small library, tested with no permissions and no screen: the Meet link in an event's notes, which event is next, the countdown, the bar's text, and the menu's sections and rows. This module also creates the Swift package and the repo's `CLAUDE.md`, `README.md` and `.gitignore`. The app (`menubar-app`) draws what these functions return and adds no rule of its own.

### Requirements

**Package**
- R1. A SwiftPM package named `NextUp`: `swift-tools-version: 6.2`, Swift 6 language mode, `platforms: [.macOS(.v14)]`, no dependencies.
- R2. Two targets: the library `NextUpCore` and its tests `NextUpCoreTests`. The executable target arrives with `menubar-app`.
- R3. `NextUpCore` imports Foundation only.
- R4. The library never reads the clock, the calendar or the locale itself (`Date()`, `Calendar.current`, `Locale.current`). Callers pass `now`, `calendar` and `locale`, so every rule runs on fixed values in a test.

**Event**
- R5. `Event` is a value with `title`, `start`, `end`, `color` and `meetURL`. It has no identifier, no notes and no calendar name.
- R6. `RGB` holds a calendar's colour as sRGB `red`, `green` and `blue`, each in 0…1.

**Meet link**
- R7. `MeetLink.find(in:)` returns the first match of `(https?://)?meet\.google\.com/([A-Za-z0-9_-]+)` anywhere in the text, matched case-insensitively. It searches the whole string and doesn't assume HTML.
- R8. The result is always `https://meet.google.com/<code>`: the scheme forced to https, the code as written, everything after it dropped.
- R9. Cases:

  | Text | Result |
  |---|---|
  | `<a href="https://meet.google.com/abc-defg-hij">https://meet.google.com/abc-defg-hij</a>` | `https://meet.google.com/abc-defg-hij` |
  | `Agenda first.`, a newline, `Join: meet.google.com/abc-defg-hij.` | `https://meet.google.com/abc-defg-hij` |
  | `http://Meet.Google.com/abc-defg-hij?authuser=1` | `https://meet.google.com/abc-defg-hij` |
  | `https://meet.google.com/aaa-bbbb-ccc and https://meet.google.com/ddd-eeee-fff` | `https://meet.google.com/aaa-bbbb-ccc` |
  | `nil`, the empty string, `https://zoom.us/j/123456`, `https://meet.google.com/` | `nil` |

**Order and next**
- R10. One order everywhere: `start` ascending; on equal starts an event with a Meet link comes first; then `title` ascending. Example: three events at the same time, `Focus`, `Alpha` and `Sync` (the only one with a link), order as `Sync`, `Alpha`, `Focus`.
- R11. The next event is the first in that order with `start > now`. An event that has started is never next.

**Countdown**
- R12. Minutes = the seconds from `now` to `start`, divided by 60 and rounded up. At 12:05:13 an event at 17:30:00 is 5 h 25 m away, which is what the menu bar's clock suggests.
- R13. Text, with single spaces:

  | Minutes | Text | Examples |
  |---|---|---|
  | 0 or less | `now` (the bar never asks: the next event has `start > now`) | |
  | 1 to 59 | `in <m> m` | `in 25 m` |
  | 60 to 1439 | `in <h> h <m> m`; `in <h> h` when the minutes are 0 | `in 5 h 25 m`, `in 5 h` |
  | 1440 and more | `in <d> d <h> h`, minutes dropped; `in <d> d` when the hours are 0 | `in 1 d 3 h`, `in 2 d` |

- R14. Cases, for a start on Friday 2026-11-20 at 17:30:00:

  | Now | Text |
  |---|---|
  | Friday 12:05:13 | `in 5 h 25 m` |
  | Friday 12:06:00 | `in 5 h 24 m` |
  | Friday 12:30:00 | `in 5 h` |
  | Friday 17:05:00 | `in 25 m` |
  | Friday 17:29:01 and 17:29:59 | `in 1 m` |
  | Thursday 14:00:00 | `in 1 d 3 h` |
  | Wednesday 17:30:00 | `in 2 d` |

**Titles**
- R15. The shown title: every run of whitespace and newlines becomes one space, the ends are trimmed, and an empty result becomes `(No title)`.
- R16. A shown title longer than its limit is cut to its first `limit - 1` characters plus `…`. Limits: 30 in the bar, 50 in a menu row. A character is a Swift `Character`.
- R17. Cases:

  | Title | Limit | Shown |
  |---|---|---|
  | `"  Design\n sync "` | 30 | `Design sync` |
  | `""`, `" \n "` | 30 | `(No title)` |
  | `Quarterly roadmap review with the whole team` (44 characters) | 30 | `Quarterly roadmap review with…` (30 characters) |
  | the same | 50 | unchanged |
  | `Quarterly roadmap review, pt 2` (30 characters) | 30 | unchanged |

**Bar**
- R18. `Agenda.bar(for:now:)` returns, for the next event (R11), the text `<shown title, limit 30> · <countdown>` and the event's colour. The separator is a space, U+00B7 and a space. Example: `Design sync · in 5 h 25 m`.
- R19. With no next event it returns `nil`.

**Window**
- R20. `Agenda.window(now:calendar:)` runs from `now` to 00:00 of the third day after today in `calendar`: today plus the next 2 days. Example: Friday 2026-11-20 12:05:13 gives an end of Monday 2026-11-23 00:00:00.
- R21. Day arithmetic goes through `Calendar`, never through 86 400 s. In `America/New_York`, a `now` of 2026-03-07 10:00 gives an end of 2026-03-10 00:00, which is 71 hours after that day's midnight (daylight saving starts on 2026-03-08).

**Menu sections**
- R22. `Agenda.sections(for:now:calendar:locale:)` returns these sections in this order, leaving out the empty ones:

  | Header | Events |
  |---|---|
  | `Now` | running: `start <= now` and `now < end` |
  | `Upcoming ` and the countdown to the section's first event, as `Upcoming in 5 h 25 m` | starting later today |
  | `Tomorrow` | starting tomorrow |
  | the day after tomorrow as `EEE MMM d`, as `Sun Nov 22` | starting that day |

- R23. An event that has ended (`end <= now`), or that starts after the day after tomorrow, is in no section.
- R24. Rows follow R10. A row's text is `<start time> · <shown title, limit 50>`, with the separator of R18. A row carries its event's colour and `meetURL`.
- R25. The start time is the locale's short time in the calendar's time zone: `5:30 PM` in `en_US`, `17:30` in `en_GB`.
- R26. Example. Now is Friday 2026-11-20 12:05:13, locale `en_US`, and the events arrive in any order:

  | Title | Start | End | Meet link |
  |---|---|---|---|
  | `Breakfast` | Friday 08:00 | 08:30 | no |
  | `Standup` | Friday 12:00 | 12:30 | yes |
  | `Design sync` | Friday 17:30 | 18:30 | yes |
  | `Lunch` | Saturday 12:00 | 13:00 | no |
  | `Planning` | Sunday 09:30 | 10:30 | yes |
  | `Retro` | Monday 10:00 | 11:00 | yes |

  Sections:

  | Header | Rows |
  |---|---|
  | `Now` | `12:00 PM · Standup` |
  | `Upcoming in 5 h 25 m` | `5:30 PM · Design sync` |
  | `Tomorrow` | `12:00 PM · Lunch` |
  | `Sun Nov 22` | `9:30 AM · Planning` |

  `Breakfast` has ended and `Retro` is past the window. The bar for the same input is `Design sync · in 5 h 25 m`.
- R27. More cases on the same events:

  | Now | Section headers | Bar |
  |---|---|---|
  | Friday 17:30:00 | `Now` (with `Design sync`), `Tomorrow`, `Sun Nov 22` | `Lunch · in 18 h 30 m` |
  | Friday 19:00:00 | `Tomorrow`, `Sun Nov 22` | `Lunch · in 17 h` |
  | Sunday 23:00:00, without `Retro` | none | `nil` |

**Repo files**
- R28. `.gitignore`: `.build/`, `build/`, `.swiftpm/`, `.DS_Store`, `*.xcodeproj`, `xcuserdata/`, `DerivedData/`.
- R29. `CLAUDE.md`, short, in this order:
  1. what NextUp is, in two sentences, and its limits: Swift and AppKit, no SwiftUI, no network code, no third-party packages, EventKit as the only source of events;
  2. the workflow: spec first, then a fresh session; `docs/specs/README.md` is the contract;
  3. commands: `swift build`, `swift test`;
  4. layout: the targets and what belongs in each;
  5. conventions: a rule worth a test is a pure function in `NextUpCore` with its test in `NextUpCoreTests`; `now`, `calendar` and `locale` are passed in; an API is checked against the installed SDK, or with `ctx7`, before it's used from memory;
  6. privacy: the rule from `docs/specs/README.md` «Writing a spec»;
  7. never, in an automated session: run anything that asks for calendar, notification, keychain or login-item permission.
- R30. `README.md`, short: what NextUp is and why, in one paragraph; what it needs (macOS 14 or later to run, Xcode with Swift 6.2 or later to build); `swift build` and `swift test`; one line saying it reads calendars on the Mac and has no network code.

## Interface (provided)

What `menubar-app` reads. Each struct also has a public memberwise initializer. Order, next, countdown and shown title stay internal and are tested through `@testable import`.

```swift
public struct RGB: Equatable, Sendable {
    public var red, green, blue: Double                 // sRGB, 0...1
}

public struct Event: Equatable, Sendable {
    public var title: String
    public var start: Date
    public var end: Date
    public var color: RGB                               // the calendar's colour
    public var meetURL: URL?
}

public struct BarContent: Equatable, Sendable {
    public var text: String                             // "Design sync · in 5 h 25 m"
    public var color: RGB
}

public struct MenuRow: Equatable, Sendable {
    public var text: String                             // "5:30 PM · Design sync"
    public var color: RGB
    public var meetURL: URL?
}

public struct MenuSection: Equatable, Sendable {
    public var header: String                           // "Now", "Upcoming in 5 h 25 m", "Tomorrow", "Sun Nov 22"
    public var rows: [MenuRow]
}

public enum MeetLink {
    public static func find(in text: String?) -> URL?
}

public enum Agenda {
    public static func window(now: Date, calendar: Calendar) -> DateInterval
    public static func bar(for events: [Event], now: Date) -> BarContent?
    public static func sections(for events: [Event], now: Date, calendar: Calendar, locale: Locale) -> [MenuSection]
}
```

## Project Structure

```
Package.swift
Sources/NextUpCore/Event.swift          Event, RGB
Sources/NextUpCore/MeetLink.swift       the link in the notes
Sources/NextUpCore/Agenda.swift         order, next, countdown, titles, bar, window, sections
Tests/NextUpCoreTests/                  one file per rule family
CLAUDE.md, README.md, .gitignore
```

## Tech Stack

Swift 6 (the Mac has Swift 6.4 with Xcode 27.2), SwiftPM, Foundation, Swift Testing. No dependencies.

## Commands

```
swift build
swift test
swift test --filter MeetLink        # one suite
```

Checks (the gate, unattended): `swift build && swift test`

## Code Style

A rule is a small static function with a one-line doc that cites its requirement, and a table test beside it:

```swift
/// "in 5 h 25 m": whole minutes until `start`, rounded up (core-rules R12–R13).
static func countdown(from now: Date, to start: Date) -> String {
    let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
    guard minutes > 0 else { return "now" }
    let (d, h, m) = (minutes / 1440, minutes % 1440 / 60, minutes % 60)
    var parts: [String] = []
    if d > 0 { parts.append("\(d) d") }
    if h > 0 { parts.append("\(h) h") }
    if m > 0 && d == 0 { parts.append("\(m) m") }
    return "in " + parts.joined(separator: " ")
}
```

```swift
@Test(arguments: [
    (12, 5, 13, "in 5 h 25 m"),
    (17, 29, 59, "in 1 m"),
])
func countdown(h: Int, m: Int, s: Int, expected: String) {
    #expect(Agenda.countdown(from: at(2026, 11, 20, h, m, s), to: at(2026, 11, 20, 17, 30)) == expected)
}
```

`at(…)` is the tests' helper that builds a date from components in the fixed calendar. Names in code use American spelling (`color`). UI text is English and is written once, in the function that returns it.

## Testing Strategy

- Swift Testing in `Tests/NextUpCoreTests`, with table tests (`@Test(arguments:)`).
- Every table and example in the Requirements is a test, row for row.
- Fixed inputs only: a Gregorian calendar in `Asia/Tehran` (a half-hour offset catches UTC assumptions), the locale `en_US`, dates built from components. R21 adds the one `America/New_York` case.
- In `en_US` the short time has U+202F, a narrow no-break space, before `AM` and `PM`. Tests write `"5:30\u{202F}PM"`, never a typed space.

## Boundaries

- Always: pass `now`, `calendar` and `locale` in; add the test in the same commit as the rule; run `swift build && swift test` before each commit.
- Ask first (in an unattended run, stop and report it): a dependency; a public name other than those in Interface; a rule this spec doesn't state.
- Never: import AppKit, EventKit, UserNotifications or SwiftUI in `NextUpCore`; read the real clock, calendar or locale in the library or its tests; use real event titles, people or calendar names in tests.

## Success Criteria

Done when: `NextUpCore` holds the Meet-link, bar and menu rules with every case of this spec as a passing test, and `swift build && swift test` pass.

Automated (the Checks cover them):

- [ ] `swift build && swift test` pass.
- [ ] Every row of R9, R10, R14, R17, R21, R26 and R27 is a test.
- [ ] `grep -rhE '^import ' Sources/NextUpCore | sort -u` prints only `import Foundation`.

Manual QA: none.

## Open Questions

None of its own. The product assumptions behind these rules are in the map.

## Tasks (build order)

- [ ] T1. Scaffold and first rule: `.gitignore`, `Package.swift`, `CLAUDE.md`, `README.md`, `Event`, `RGB`, `MeetLink` and its tests (R1–R9, R28–R30). Verify: `swift build && swift test`.
- [ ] T2. Order, next, countdown, titles and `Agenda.bar`, with their tests (R10–R19). Verify: `swift test`.
- [ ] T3. `Agenda.window` and `Agenda.sections`, with their tests (R20–R27). Verify: `swift test`.
- [ ] T4. Spec workflow: delete this section and the automated Success Criteria, set the status line and the row in `docs/specs/README.md` to built. Verify: `swift build && swift test`.
