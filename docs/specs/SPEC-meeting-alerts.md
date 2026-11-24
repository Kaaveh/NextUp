# Spec: meeting-alerts

Module 3 of 4 in the NextUp capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on `menubar-app`. Status: built; the manual QA list is open.

## Objective

One minute before a meeting starts, NextUp opens its own panel at the top right, copied from Notion Calendar's: the title, a red `in 1 m · 5:30 – 6:30 PM`, and `Join Google Meet`. A meeting is an event with a Google Meet link. The panel stays until Join, Dismiss or the meeting's end. It is the only alert: NextUp posts no macOS notification (removed on 2026-11-22, because the notification sat under the panel and showed again after Join). What to announce is decided by a pure function; the shell only keeps the panel timers equal to that plan.

### Requirements

**Plan** (pure, in `NextUpCore`)
- R1. `AlertPlan.alerts(for:now:calendar:locale:)` returns one `Alert` for each event that has a `meetURL` and `start > now`. Events without a link get none.
- R2. An `Alert` has:
  - `id`: the start as whole seconds since 1970, a `|`, and the link, as `1795183200|https://meet.google.com/abc-defg-hij` for a start of 2026-11-20 17:30 in `Asia/Tehran`;
  - `fireDate`: 60 s before `start`;
  - `title`: the shown title at limit 50 (core-rules R15–R16);
  - `url`: the event's `meetURL`.
- R3. Events that give the same `id` (one meeting in two calendars) give one alert, from the first of them in core-rules R10 order. The same link at two start times gives two alerts.
- R4. The result is sorted by `fireDate`, then `id`.
- R5. An alert stays in the plan until its meeting starts, not until it fires. The plan therefore doesn't change in the second the panel is due. An open panel keeps its own copy of the alert until the meeting ends (R27).
- R6. `AlertPlan.changes(from:to:now:)` compares the last scheduled plan with a new one:
  - `remove`: the ids that left the plan;
  - `add`: the alerts that are new, or differ from the last plan's, and whose `fireDate > now`.
- R7. Cases for R1–R6, on the events of core-rules R26 with now = Friday 2026-11-20 12:05:13:

  | Case | Result |
  |---|---|
  | the plan | `Design sync` (fires Friday 17:29:00), `Planning`, `Retro`, in that order |
  | now = Friday 17:29:30 | `Design sync` is still first in the plan |
  | now = Friday 17:30:00 | the plan starts with `Planning` |
  | `Design sync` given twice | still three alerts |
  | changes from a plan to itself | nothing to remove, nothing to add |
  | changes from an empty plan | every alert in `add` |
  | changes from an empty plan at Friday 17:29:30 | `Planning` and `Retro` in `add`, `Design sync` not |
  | an alert left the plan | its id in `remove` |
  | the same id with a new title | the alert in `add`, nothing in `remove` |

**Scheduling** (the panel timers; no macOS notification)
- R8. After every `refresh()` in normal mode: compute the plan, apply `changes` against the last plan to the panel timers (R29), and keep the new plan.
- R9–R10. Removed on 2026-11-22 with the macOS notification.
- R11. The first run after launch has no last plan: it starts from scratch (R29).
- R12. `.NSSystemClockDidChange` and `.NSSystemTimeZoneDidChange` forget the last plan, so the next refresh starts from scratch: a `Timer` may not follow a clock change.
- R13. A meeting first seen less than a minute before it starts gets no panel.
- R14–R19. Removed on 2026-11-22 with the macOS notification: no pending requests to clear at quit, no permission request, no `Turn on meeting alerts…` item, no delegate, no category.
- R20. A Meet link opens with `NSWorkspace.shared.open` only when it parses to an `https` URL whose host is `meet.google.com` (`MeetingAlerts.open`).
- R21–R22. Removed on 2026-11-22 with the macOS notification, and `NSUserNotificationAlertStyle` with it.
- R23. `--self-check` creates no `MeetingAlerts`: no timer, no panel. Its expected output doesn't change.
- R24. Removed with the key of R22.

**Panel** (NextUp's own window, as in Notion Calendar)
- R25. Every alert opens a panel at its `fireDate`, from the plan and its `changes` (R6). The panel is the only alert: NextUp posts no macOS notification.
- R26. `Alert` gains `start`, `end` and `timeRange`. `timeRange` is the start and end as one range from `DateIntervalFormatter` with the template `jm`, in `locale` and the calendar's time zone: `5:30 – 6:30 PM` in `en_US` (U+2009 on both sides of the en dash, U+202F before `PM`), `17:30 – 18:30` in `en_GB`.
- R27. `AlertPlan.panelStatus(for:now:) -> String?` is the countdown to `start` (core-rules R12–R13) before the start, `now` from `start` until `end`, and `nil` from `end` on, when the panel closes.
- R28. Cases on `Design sync` (Friday 17:30 to 18:30) of R7, locale `en_US`:

  | Now | `panelStatus` |
  |---|---|
  | Friday 17:29:00 (the fire date) | `in 1 m` |
  | Friday 17:29:59 | `in 1 m` |
  | Friday 17:30:00 | `now` |
  | Friday 18:29:59 | `now` |
  | Friday 18:30:00 | `nil` |

  Its `timeRange` is `5:30 – 6:30 PM`; in `en_GB`, `17:30 – 18:30`.
- R29. Timers: each alert in `add` gets a one-shot `Timer` at its `fireDate`, on the main run loop in `.common` mode, kept by `id` and replacing an older timer of that id. Each id in `remove` invalidates its timer. A start from scratch (R11, R12) invalidates every timer first. Open panels are never closed by this. A meeting first seen less than a minute before it starts gets no panel (R13). Each update first fires every timer past its `fireDate`, since a `Timer` runs late by a sleep and a start from scratch would drop it.
- R30. A firing timer opens the alert's panel, unless a panel with that `id` is open or `panelStatus` is already `nil` (a sleep past the meeting's end).
- R31. Look, from the reference screenshot, the same in light and dark mode:
  - a borderless `NSPanel`, about 460 × 72 pt, with `NSAppearance(named: .darkAqua)`, a corner radius of 12 pt, the fill `#2C2C2C` and a 1 pt border `#3B3B3B`;
  - on the left, 16 pt in, two lines: the title (13 pt medium, label colour, one line, cut at the tail); below it the status (R27) in `systemRed`, then ` · ` and the `timeRange` in the secondary label colour, both 12 pt;
  - on the right, 12 pt in and centred vertically: a 28 pt tall button with the fill `#373737` and a 6 pt corner radius holding the Google Meet logo (16 pt, the image of menubar-app R26) and `Join Google Meet` (13 pt), joined to a 28 × 28 pt `chevron.down` part by a 1 pt divider in the panel's fill `#2C2C2C`. The chevron opens a menu with `Dismiss` and `Copy link`;
  - a close button as on macOS notifications: `xmark.circle.fill`, 14 pt, borderless, in the secondary label colour, 4 pt in from the panel's top and left edges, clear of the title. It is hidden until the pointer enters the panel and hidden again when it leaves (an `NSTrackingArea` with `.activeAlways`, since NextUp is never the active app); a panel that opens or moves under a still pointer sets it from the pointer's place.
- R32. Place: the top right of the screen with the menu bar (`NSScreen.screens.first`), 8 pt below the top of its `visibleFrame` and 8 pt in from its right edge. Another open panel goes 8 pt below the lowest one; when one closes, the ones below move up. The panel sits at the `.statusBar` level, shows on every Space and over full-screen apps (`.canJoinAllSpaces`, `.fullScreenAuxiliary`), stays when NextUp isn't active (`hidesOnDeactivate = false`), and never takes focus from the app being typed in (`.nonactivatingPanel`): a click on its buttons works without activating NextUp.
- R33. Each refresh passes `now` on: an open panel redraws its status, and closes when `panelStatus` is `nil`. The status is at most a minute stale, which the minute tick (menubar-app R16) keeps true at whole-minute starts.
- R34. Actions:
  - `Join Google Meet` opens the link with R20's check (`MeetingAlerts.open`) and closes the panel;
  - `Dismiss`, and the close button of R31, close it;
  - `Copy link` puts the link on the general pasteboard as a string, and the panel stays.
- R35. A panel that opens plays `Contents/Resources/Knock.wav` once, loaded from the bundle's URL (not `NSSound(named:)`, which falls back to the system's sound folders); a bundle without the file opens it silently. Panels that open while the knock still plays (two meetings at once, timers fired after a sleep) add no second knock. The knock is NextUp's own sound in the style of Slack's Knock Brush (a soft high brush, then three short 1210 Hz knocks, 0.5 s in all), synthesized by `scripts/make-sound.swift` into `Support/Knock.wav`, which is committed, so builds don't run the script; Slack's own file is never used. The panel needs no permission and shows, with its sound, with a Focus on: NextUp can't read the Focus without a permission. It exists only in normal mode: `MeetingAlerts` owns the timers and panels, the self-check never creates it (R23), and its output doesn't change.

## Interface

Consumed: `Event`, the order, the shown title and the start time of `core-rules` (R10, R15–R16, R25); `refresh()`, the kept events and the menu's last block of `menubar-app` (R15, R29).

Provided (nothing reads it yet):

```swift
public struct Alert: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var title: String
    public var url: URL
    public var start: Date
    public var end: Date
    public var timeRange: String          // "5:30 – 6:30 PM" (R26)
}

public enum AlertPlan {
    public static func alerts(for events: [Event], now: Date, calendar: Calendar, locale: Locale) -> [Alert]
    public static func changes(from last: [Alert], to plan: [Alert], now: Date) -> (remove: [String], add: [Alert])
    public static func panelStatus(for alert: Alert, now: Date) -> String?      // "in 1 m", "now", nil (R27)
}
```

## Project Structure

```
Sources/NextUpCore/AlertPlan.swift              Alert, the plan, the changes
Tests/NextUpCoreTests/AlertPlanTests.swift
Sources/NextUp/MeetingAlerts.swift              the panel timers, the open panels, the link check
Sources/NextUp/MeetingPanel.swift               the panel window, its layout, its actions and the stacking
Sources/NextUp/AppDelegate.swift                calls it after refresh
scripts/make-sound.swift                        synthesizes Support/Knock.wav (R35)
Support/Knock.wav                               the panel's sound, copied to Contents/Resources
```

## Tech Stack, Commands, Code Style

Same as [SPEC-menubar-app.md](SPEC-menubar-app.md). No UserNotifications.

Checks (the gate, unattended): `scripts/check.sh`

## Testing Strategy

- `AlertPlanTests`: every row of R7 and R28, with the fixed calendar and locale of core-rules.
- The panel timers and the panel have no automated test: they need a person looking at the screen. They are the manual QA list below.
- The self-check must keep passing unchanged, which shows the alert code stays out of its path.

## Boundaries

- Always: decide what to schedule in `AlertPlan`; keep the shell to applying `changes`; run `scripts/check.sh` before each commit.
- Ask first (in an unattended run, stop and report it): a second kind of alert beside the panel; a lead time other than one minute.
- Never:
  - post a macOS notification or import UserNotifications: the panel is the only alert (the notification was removed on 2026-11-22);
  - start NextUp without `--self-check` in an automated session;
  - open a URL from the panel without the check of R20;
  - open a panel to try it out, from a test, a script or the self-check;
  - log event titles or links.

## Success Criteria

Done when: the alert plan, its changes and the panel's status are tested; the panel timers and the panel are built, and no UserNotifications code is left; `scripts/check.sh` passes; the manual QA list stays open.

Manual QA (the user, on the installed app; stays open after the build):

- [ ] One minute before a test meeting, the panel opens at the top right: the title, a red `in 1 m · <range>`, `Join Google Meet`. It stays on screen, and no macOS notification arrives with it or after Join.
- [ ] Moving the test event 10 minutes later gives one panel, at the new time. Deleting it gives none. An event without a link gives none.
- [ ] At the start time it reads `now`; at the meeting's end it closes by itself.
- [ ] `Join Google Meet` opens the meeting and closes the panel. `˅` → `Dismiss` closes it. `˅` → `Copy link` copies the link and leaves it open; the browser comes to the front on Join.
- [ ] The panel opens with the knock. Hovering it shows the × at the top left; the × closes it; moving the pointer away hides the ×.
- [ ] Two meetings at the same time give two stacked panels; closing the top one moves the other up.
- [ ] The panel shows over a full-screen app and on another Space, and typing in another app isn't interrupted.
- [ ] Beside Notion Calendar's panel, the size, colours and text match; note any gap to tune.
- [ ] A working day with Notion Calendar quit: nothing was missed.

## Open Questions

None of its own. The panel is a window, so it shows whatever the Focus (R35).

