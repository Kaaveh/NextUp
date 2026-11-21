# Spec: menubar-app

Module 2 of 3 in the NextUp capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on `core-rules`. Status: built; the manual QA list is open; R36's new output (core-rules R37–R40) is specified and not built.

## Objective

NextUp runs in the menu bar with no Dock icon. The bar shows a thin colour bar and `Design sync · in 5 h 24 m`. A click lists what is running and what is coming today and the next 2 days; a meeting's row offers Join; the menu ends with Launch at login and Quit. Events come from the macOS calendar store. This module also makes the app buildable, checkable and installable from the command line, and takes the first memory number.

The shell is thin: it reads events, hands them to `NextUpCore`, and draws what comes back. It adds no rule of its own.

### Requirements

**App**
- R1. An executable target `NextUp` in the package, depending on `NextUpCore`. AppKit lifecycle in `main.swift`: `NSApplication.shared`, a delegate, `setActivationPolicy(.accessory)`, `run()`. No storyboard, no nib, no SwiftUI.
- R2. The target sets `.defaultIsolation(MainActor.self)`: the whole shell is main-thread code.
- R3. It uses AppKit, EventKit and ServiceManagement, and has no network code.
- R4. NextUp stores nothing: no preferences of its own, no files, no cache.
- R5. Normal mode needs the app bundle. When `Bundle.main.bundleIdentifier` is `nil` (as under `swift run`) and `--self-check` is absent, the process prints one line to stderr and exits with status 64. Outside the bundle macOS has no usage text to show for a permission.

**Bundle**
- R6. `Support/Info.plist`:

  | Key | Value |
  |---|---|
  | `CFBundleIdentifier` | `ir.kaavehdev.nextup` |
  | `CFBundleName`, `CFBundleExecutable` | `NextUp` |
  | `CFBundlePackageType` | `APPL` |
  | `CFBundleShortVersionString`, `CFBundleVersion` | `1.0.0`, `1` |
  | `CFBundleInfoDictionaryVersion` | `6.0` |
  | `LSMinimumSystemVersion` | `14.0` |
  | `LSUIElement` | `true` |
  | `NSCalendarsFullAccessUsageDescription` | `NextUp shows your upcoming events in the menu bar. Your calendar stays on this Mac.` |

- R7. `scripts/build-app.sh`:
  1. `swift build -c release`;
  2. the product folder is what `swift build -c release --show-bin-path` prints, and no path under `.build` is written into the script;
  3. a fresh `build/NextUp.app` with `Contents/MacOS/NextUp` (the product) and `Contents/Info.plist` (a copy of `Support/Info.plist`);
  4. `codesign --force --sign "${NEXTUP_SIGN_IDENTITY:--}" build/NextUp.app`, where `-` signs ad-hoc, then `codesign --verify --strict build/NextUp.app`;
  5. it prints nothing about the identity.
- R8. No sandbox, no hardened runtime, no entitlements file: each exists for distribution and would add entitlements to maintain.

**Calendar**
- R9. One `EKEventStore` for the life of the app.
- R10. Access is `EKEventStore.authorizationStatus(for: .event)`, read on every refresh:
  - `.fullAccess`: read the events;
  - `.notDetermined`, at launch only: call `requestFullAccessToEvents()` once, which shows macOS's prompt, and refresh when it returns;
  - anything else: the no-access state (R22, R28).
- R11. Reading: `predicateForEvents(withStart:end:calendars:)` over `Agenda.window`, with `calendars: nil` for every calendar, then `events(matching:)`. It runs on the main thread, because a 3-day window is small.
- R12. Each `EKEvent` becomes an `Event` and the EventKit object is dropped: `title` (`nil` becomes the empty string), `startDate`, `endDate`, the calendar's `color` converted to sRGB (grey when the calendar has none), and `MeetLink.find(in: notes)`.
- R13. Skipped while mapping: `isAllDay`; `status == .canceled`; an event whose attendee with `isCurrentUser` has `participantStatus == .declined`.
- R14. When access turns to full after the store was created (granted later in System Settings), call the store's `reset()` once before reading.

**Refresh**
- R15. One `refresh()`: read (R10–R14), keep the `[Event]`, draw the bar (R19–R22). The same call serves every trigger, so nothing can go stale between them.
- R16. Triggers:
  - launch;
  - `.EKEventStoreChanged`, which macOS also posts when calendar access changes;
  - a timer at every minute boundary, at most 1 s late;
  - `NSWorkspace.didWakeNotification`;
  - `.NSCalendarDayChanged`;
  - `.NSSystemClockDidChange` and `.NSSystemTimeZoneDidChange`.
- R17. Wake and the clock and time-zone changes also re-align the timer to the next minute boundary.
- R18. The clock is `Date()`, the calendar `Calendar.autoupdatingCurrent`, the locale `Locale.autoupdatingCurrent`.

**Bar**
- R19. One `NSStatusItem` of variable length.
- R20. With a result from `Agenda.bar`: the button's image is the colour bar, leading, and its title is the text.
- R21. The colour bar is an image of 4 × 16 pt with a corner radius of 2 pt, filled with the event's colour, not a template. A menu row uses the same image.
- R22. Without a bar text the button shows a template image, with an accessibility description and no title:
  - when nothing more starts today (core-rules R35): today's day of the month (in the calendar of R18) in a drawn 16 × 16 pt calendar, matched pixel for pixel to Notion Calendar's icon: a 1.5 pt frame with a 3.5 pt corner radius, a solid 4.5 pt header, the day in bold New York (10 pt) centred 0.5 pt right with its baseline 3 pt up. Described as `NextUp: nothing more today`. The SF Symbol `21.calendar` was tried and looked small (17 × 15 with thin digits) and needs macOS 26;
  - the SF Symbol `calendar.badge.exclamationmark` when NextUp has no calendar access, described as `NextUp: no calendar access`.

**Menu**
- R23. The menu is rebuilt in `menuNeedsUpdate` from the kept events and the current time. Opening it reads nothing from the calendar.
- R24. `Agenda.sections`, in order: a header is `NSMenuItem.sectionHeader(title:)`; a row is an item with the row's text and its colour bar.
- R25. Rows look enabled (the menu's `autoenablesItems` is `false`). A click on a row does nothing.
- R26. A row with a `meetURL` has a submenu with one item, `Join Google Meet`, which opens the URL with `NSWorkspace.shared.open`. When the menu's first row (the first row of the first section) has a `meetURL`, the same item also sits right under that row, as in the reference. Every `Join Google Meet` item shows the Google Meet logo at 16 × 16 pt, from `Contents/Resources/meet.png` (`Support/meet.png`, Google's 96 px product logo); a bundle without the file shows the item without an icon.
- R27. With access and no sections: one disabled row, `No upcoming events`.
- R28. Without access: the header `No calendar access` and the item `Open Privacy Settings…`, which opens `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars`. No event rows.
- R29. The menu always ends with: a separator, `Launch at login`, a separator, `Quit NextUp` (key equivalent `q`).

**Launch at login**
- R30. `Launch at login` carries a checkmark when `SMAppService.mainApp.status == .enabled`, read each time the menu opens.
- R31. A click calls `unregister()` when enabled and `register()` otherwise. If the status is `.requiresApproval` afterwards, it calls `SMAppService.openSystemSettingsLoginItems()`. An error is logged with `NSLog` and changes nothing else.

**Self-check**
- R32. `NextUp --self-check` runs the same status item and menu code as normal mode. Only four things differ: the events are the sample of R34, the clock is fixed at 2026-11-20 12:05:13, the calendar is Gregorian in GMT, and the locale is `en_US`.
- R33. It calls no EventKit, no ServiceManagement and no `NSWorkspace.open`, so it can't raise a prompt or change anything on the Mac. This outranks R32: `Launch at login` is drawn unchecked, and no refresh trigger (R16) is installed, since it exits after 5 s.
- R34. Sample events (GMT):

  | Title | Start | End | Colour (red, green, blue) | Meet link | Declined by a guest |
  |---|---|---|---|---|---|
  | `Standup` | 2026-11-20 12:00 | 12:30 | 0.10, 0.45, 0.90 | `https://meet.google.com/aaa-bbbb-ccc` | no |
  | `Design sync` | 2026-11-20 17:30 | 18:30 | 0.10, 0.45, 0.90 | `https://meet.google.com/abc-defg-hij` | no |
  | `Lunch` | 2026-11-21 12:00 | 13:00 | 0.95, 0.55, 0.15 | none | no |
  | `Planning` | 2026-11-22 09:30 | 10:30 | 0.10, 0.45, 0.90 | `https://meet.google.com/ddd-eeee-fff` | yes |

- R35. It prints to stdout:
  - `bar: ` and the button's title, trimmed;
  - one `menu: ` line per menu item, top to bottom: `# <title>` for a section header, `---` for a separator, otherwise the title, followed by ` > ` and the submenu's titles (comma-separated) when the item has a submenu;
  - U+202F as a plain space, so the expected text can be typed.
- R36. Expected output:

  ```
  bar: Standup · now
  menu: # Ending in 25 m
  menu: 12:00 PM · Standup > Join Google Meet
  menu: Join Google Meet
  menu: # Upcoming in 5 h 25 m
  menu: 5:30 PM · Design sync > Join Google Meet
  menu: # Tomorrow
  menu: 12:00 PM · Lunch
  menu: # Sun Nov 22
  menu: ⚠ 9:30 AM · Planning > Join Google Meet
  menu: ---
  menu: Launch at login
  menu: ---
  menu: Quit NextUp
  ```

- R37. Then it keeps the status item on screen for 5 s, prints `footprint: <n> MB` (its own physical footprint in MB with one decimal, from `proc_pid_rusage`'s `ri_phys_footprint`), and exits with status 0.

**Scripts**
- R38. `scripts/check.sh` is the gate, written for the system's bash 3.2. In order:
  1. fail if `Sources/NextUpCore` imports anything but Foundation;
  2. fail if `Sources` contains `import SwiftUI`, `import Network` or `URLSession`;
  3. `swift test`;
  4. `NEXTUP_SIGN_IDENTITY=- scripts/build-app.sh`: always ad-hoc, whatever the environment holds, so no keychain is touched;
  5. on `build/NextUp.app`: `plutil -lint` on its `Info.plist`; `codesign --verify --strict`; `LSUIElement` is `true`; `CFBundleIdentifier` is `ir.kaavehdev.nextup`; `NSCalendarsFullAccessUsageDescription` exists;
  6. `timeout 30 build/NextUp.app/Contents/MacOS/NextUp --self-check` exits with 0, its output without the last line equals R36, and the last line matches `^footprint: [0-9]+\.[0-9] MB$`;
  7. print the footprint line and `check: OK`.
- R39. `scripts/install.sh` is for a person, never for automation:
  1. the identity is `$NEXTUP_SIGN_IDENTITY` when set; otherwise the SHA-1 on the first line containing `Apple Development` in the output of `security find-identity -v -p codesigning`; otherwise `-`, with a warning that macOS will ask for the permissions again after every install;
  2. `scripts/build-app.sh` with that identity;
  3. quit a running NextUp (`pkill -x NextUp`, where no match is fine), replace `/Applications/NextUp.app` with the new bundle (`ditto`), and `open` it;
  4. print `signed with: ad-hoc` or `signed with: a keychain identity`, never a name or a hash.

**Memory**
- R40. Target: a physical footprint under 30 MB at idle. It is measured on the installed app, after 10 idle minutes, with `footprint -p "$(pgrep -x NextUp)"`; the header line of its output holds `Footprint: <n> MB`.
- R41. The self-check's number (R37) is the floor with no calendar code running. It goes into the pull request's text.
- R42. A number of 30 MB or more, from either measurement, is recorded as an open item in the pull request and in this spec's Open Questions. The code isn't restructured to chase the target.

**Declined by a guest**
- R43. Mapping (R12) sets `declinedByGuest` when `attendees` holds a participant with `isCurrentUser == false` and `participantStatus == .declined`. R13's skip of an event the user declined still comes first.
- R44. A bar or row with `declinedByGuest` gets a striped colour bar instead of the solid one: the size and corner radius of R21, filled with 45° diagonal stripes, 2 pt of the event's colour then 2 pt transparent (measured along the bar), not a template. The `⚠ ` comes with the text (core-rules R32).
- R45. Nothing else changes for such an event: it gets its alert (meeting-alerts), its Join items (R26) and its place in the order.

## Interface

Consumed from `core-rules`: `Event`, `RGB`, `MeetLink.find(in:)`, `Agenda.window`, `Agenda.bar`, `Agenda.sections`, with `BarContent`, `MenuSection` and `MenuRow`. Read the signatures from the code.

Provided to `meeting-alerts`:

- `refresh()` and the `[Event]` it keeps;
- the menu's last block (R29), where that module adds one item;
- `--self-check`, which must stay free of any permission-gated API;
- `Support/Info.plist` and `scripts/check.sh`, which that module extends.

## Project Structure

```
Package.swift                          + the executable target NextUp
Sources/NextUp/main.swift              the bundle guard, NSApplication, the delegate
Sources/NextUp/AppDelegate.swift       status item, menu, refresh, timer and observers, Launch at login
Sources/NextUp/CalendarSource.swift    EventKit: access, read, map to Event
Sources/NextUp/SelfCheck.swift         sample events, fixed clock, the printed lines, the footprint
Support/Info.plist
Support/meet.png                       the Google Meet logo of R26, copied to Contents/Resources
scripts/build-app.sh                   release build → build/NextUp.app, signed
scripts/check.sh                       the gate
scripts/install.sh                     for a person: a keychain identity, /Applications, open
build/                                 output, ignored by git
```

## Tech Stack

Swift 6, AppKit, EventKit, ServiceManagement, on top of `NextUpCore`. Shell scripts for bash 3.2, with `codesign`, `plutil`, `PlistBuddy`, `ditto` and `timeout` from macOS. No dependencies.

## Commands

```
scripts/check.sh                                        # the gate: rules, bundle, self-check
scripts/build-app.sh                                    # build/NextUp.app, ad-hoc signed
build/NextUp.app/Contents/MacOS/NextUp --self-check     # sample data, no prompts
scripts/install.sh                                      # a person only: /Applications/NextUp.app
footprint -p "$(pgrep -x NextUp)"                       # idle memory of the installed app
```

Checks (the gate, unattended): `scripts/check.sh`

## Code Style

The shell is main-actor code. EventKit calls use their `async` forms (`try await store.requestFullAccessToEvents()`). A callback that AppKit or Foundation delivers on the main thread (a timer, an observer with `queue: .main`) enters the main actor explicitly:

```swift
let timer = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
    MainActor.assumeIsolated { self?.refresh() }
}
timer.tolerance = 1
RunLoop.main.add(timer, forMode: .common)
```

The two modes differ only in where the clock, the calendar, the locale and the events come from. Everything after that is the same code.

Every script is executable, starts with `#!/bin/bash` and `set -euo pipefail`, and changes to the repo root first, so it runs from any folder.

## Testing Strategy

- The rules are tested in `NextUpCoreTests`. The shell adds none, so it has no unit tests.
- The self-check is the shell's automated test: a real `NSStatusItem` and `NSMenu`, sample data, exact expected text. It needs the logged-in desktop session, because it builds a real status item.
- Whatever needs the real calendar, the login item, a signing key or a pair of eyes is the manual QA list below.

## Boundaries

- Always: keep rules in `NextUpCore` (a new rule is a new pure function with a test, or it is out of scope); run `scripts/check.sh` before each commit from T2 on; check an API against the installed SDK, or with `ctx7`, before using it from memory.
- Ask first (in an unattended run, stop and report it): a dependency; an entitlement, the sandbox or the hardened runtime; a change to the bundle id; a new public name in `NextUpCore`; anything that stores data; a self-check that can't reach the window server.
- Never:
  - start NextUp without `--self-check` in an automated session: not with `open`, not by running the binary, not with `swift run`;
  - run `scripts/install.sh`, `tccutil`, or anything else that raises a calendar, keychain or login-item prompt;
  - call `register()` anywhere but the menu action;
  - import SwiftUI or add network code;
  - log event titles or links, or commit identity names, team ids or hashes;
  - read the user's calendar from a test or a script.

## Success Criteria

Done when: `scripts/check.sh` passes and the self-check's footprint is in the pull request's text; calendar reading, refresh, Launch at login and the install script are built; the manual QA list stays open.

Manual QA (the user, on the installed app; stays open after the build). Run `scripts/install.sh` yourself. To see a first-run prompt again: `tccutil reset Calendar ir.kaavehdev.nextup`, while NextUp is in `/Applications`.

- [ ] `scripts/install.sh` signs with an Apple Development identity. Note whether `codesign` raised a keychain dialog, and whether Always Allow silenced it for the next install.
- [ ] First launch: macOS asks for calendar access once. After Allow, the bar shows the next event with its calendar's colour, and the countdown steps down every minute.
- [ ] The bar and the menu look like the reference: colour bar, gap, text; grey headers; rows with their bars; a chevron on meetings.
- [ ] The menu lists what is running under `Ending in …`, later today under `Upcoming in …`, then `Tomorrow` and the day after. Ended, all-day, cancelled and declined events don't appear.
- [ ] `Join Google Meet` opens the right meeting in the browser.
- [ ] An event a guest declined shows the striped bar and `⚠` in the bar and in its menu row. (Whether the Google CalDAV feed gives EventKit the guests' statuses is checked here.)
- [ ] An event added, moved or deleted in Calendar shows in the bar within a minute.
- [ ] After sleep, and after midnight, the bar and the headers are right.
- [ ] While a meeting runs, the bar shows `<title> · now` and the menu's first header is `Ending in …`; 15 minutes before the next event the bar switches to its countdown; a running meeting that is the day's last stays in the bar until it ends.
- [ ] With nothing more today, the bar shows only today's date icon and the menu still lists `Tomorrow`; after midnight the bar shows the day's first event again.
- [ ] With calendar access switched off in System Settings, the bar shows the badge icon and the menu offers `Open Privacy Settings…`, which lands on Privacy & Security → Calendars. Switched back on, the events return within a minute, without a relaunch.
- [ ] `Launch at login`: ticking it adds NextUp to System Settings → General → Login Items, and NextUp is running after the next login. Unticking removes it.
- [ ] A second `scripts/install.sh`, after a code change, doesn't make macOS ask for calendar access again.
- [ ] `footprint -p "$(pgrep -x NextUp)"` after 10 idle minutes: note the number. The target is under 30 MB.

## Open Questions

| Owner | Item |
|---|---|
| User | If `Launch at login` fails in manual QA for a locally signed build: accept it, or spec a LaunchAgent instead |
| Later | Reading off the main thread, if the 3-day read ever makes the menu bar stutter |

