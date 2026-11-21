# Spec: meeting-alerts

Module 3 of 3 in the NextUp capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on `menubar-app`. Status: built; the manual QA list is open; the panel (R25–R35) is specified and not built.

## Objective

One minute before a meeting starts, macOS shows a notification with a Join button. A meeting is an event with a Google Meet link. Join, or a click on the notification, opens the link in the browser. At the same moment NextUp opens its own panel at the top right, copied from Notion Calendar's: the title, a red `in 1 m · 5:30 – 6:30 PM`, and `Join Google Meet`. It stays until Join, Dismiss or the meeting's end. What to announce is decided by a pure function; the shell only keeps macOS's pending notifications and the panel timers equal to that plan.

### Requirements

**Plan** (pure, in `NextUpCore`)
- R1. `AlertPlan.alerts(for:now:calendar:locale:)` returns one `Alert` for each event that has a `meetURL` and `start > now`. Events without a link get none.
- R2. An `Alert` has:
  - `id`: the start as whole seconds since 1970, a `|`, and the link, as `1795183200|https://meet.google.com/abc-defg-hij` for a start of 2026-11-20 17:30 in `Asia/Tehran`;
  - `fireDate`: 60 s before `start`;
  - `title`: the shown title at limit 50 (core-rules R15–R16);
  - `body`: `Starts at ` and the start time (core-rules R25), as `Starts at 5:30 PM`;
  - `url`: the event's `meetURL`.
- R3. Events that give the same `id` (one meeting in two calendars) give one alert, from the first of them in core-rules R10 order. The same link at two start times gives two alerts.
- R4. The result is sorted by `fireDate`, then `id`.
- R5. An alert stays in the plan until its meeting starts, not until it fires. The plan therefore doesn't change in the second the notification is due. An open panel keeps its own copy of the alert until the meeting ends (R27).
- R6. `AlertPlan.changes(from:to:now:)` compares the last scheduled plan with a new one:
  - `remove`: the ids that left the plan;
  - `add`: the alerts that are new, or differ from the last plan's, and whose `fireDate > now`.
- R7. Cases for R1–R6, on the events of core-rules R26 with now = Friday 2026-11-20 12:05:13:

  | Case | Result |
  |---|---|
  | the plan | `Design sync` (fires Friday 17:29:00, body `Starts at 5:30 PM`), `Planning`, `Retro`, in that order |
  | now = Friday 17:29:30 | `Design sync` is still first in the plan |
  | now = Friday 17:30:00 | the plan starts with `Planning` |
  | `Design sync` given twice | still three alerts |
  | changes from a plan to itself | nothing to remove, nothing to add |
  | changes from an empty plan | every alert in `add` |
  | changes from an empty plan at Friday 17:29:30 | `Planning` and `Retro` in `add`, `Design sync` not |
  | an alert left the plan | its id in `remove` |
  | the same id with a new title | the alert in `add`, nothing in `remove` |

**Scheduling**
- R8. After every `refresh()` in normal mode: compute the plan, apply `changes` against the last scheduled plan, and keep the new plan.
  - `remove` goes to `removePendingNotificationRequests(withIdentifiers:)`;
  - each alert in `add` becomes one request (R10). Adding replaces a pending request with the same identifier.
- R9. A request that didn't change is never touched. Removing and re-adding everything could drop a notification that is due that second.
- R10. A request has:
  - the identifier `id`;
  - content: `title`, `body`, the default sound, the category `MEETING`, and `userInfo["url"]` holding the link as a string;
  - a `UNCalendarNotificationTrigger`, not repeating, from the fire date's year, month, day, hour, minute and second in `Calendar.autoupdatingCurrent`.
- R11. The first run after launch has no last plan: `removeAllPendingNotificationRequests()`, then add every alert whose `fireDate` is ahead.
- R12. `.NSSystemClockDidChange` and `.NSSystemTimeZoneDidChange` forget the last plan, so the next refresh schedules from scratch (R11): the triggers hold wall-clock components.
- R13. A meeting first seen less than a minute before it starts gets no notification.
- R14. Quitting removes every pending request before the process ends: `applicationShouldTerminate` answers `.terminateLater`, calls `removeAllPendingNotificationRequests()`, awaits `pendingNotificationRequests()` so the removal has gone through, then replies `true`. A quit app can't keep its alerts true.

**Permission**
- R15. In normal mode at launch, once the calendar request has resolved: `requestAuthorization(options: [.alert, .sound])`. macOS asks once.
- R16. After each refresh, read `notificationSettings().authorizationStatus` and keep it for the menu. When it differs from the kept one, forget the last plan and schedule again (R11): a request added without permission may have been dropped.
- R17. While the kept status is known and isn't `.authorized`, the menu shows one more item directly above `Launch at login`: `Turn on meeting alerts…`, which opens `x-apple.systempreferences:com.apple.Notifications-Settings.extension`.

**Actions**
- R18. The `UNUserNotificationCenter` delegate is set in `applicationDidFinishLaunching` before any `await`, so a click that launches NextUp still reaches it.
- R19. The category `MEETING` has one action: identifier `JOIN`, title `Join`, options `[.foreground]`, so NextUp is the active app when it hands over to the browser.
- R20. `JOIN`, and a click on the notification itself (`UNNotificationDefaultActionIdentifier`), open `userInfo["url"]` with `NSWorkspace.shared.open`, and only when it parses to an `https` URL whose host is `meet.google.com`. Dismissing does nothing.
- R21. `willPresent` returns `[.banner, .list, .sound]`, so the notification also shows while NextUp is frontmost.

**Bundle and checks**
- R22. `Support/Info.plist` gains `NSUserNotificationAlertStyle` = `alert`: it asks macOS for the style that stays on screen until dismissed.
- R23. `--self-check` calls no UserNotifications API: `UNUserNotificationCenter.current()` needs the app bundle and could raise a prompt. Its expected output doesn't change.
- R24. `scripts/check.sh` also checks the key of R22.

**Panel** (NextUp's own window beside the notification, as in Notion Calendar)
- R25. Every alert also opens a panel at its `fireDate`, from the same plan and the same `changes` (R6) as the notification. The notification stays as it is (R8–R22).
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
- R29. Timers: each alert in `add` gets a one-shot `Timer` at its `fireDate`, on the main run loop in `.common` mode, kept by `id` and replacing an older timer of that id. Each id in `remove` invalidates its timer. A start from scratch (R11, R12, R16) invalidates every timer first. Open panels are never closed by this. A meeting first seen less than a minute before it starts gets no panel (R13).
- R30. A firing timer opens the alert's panel, unless a panel with that `id` is open.
- R31. Look, from the reference screenshot, the same in light and dark mode:
  - a borderless `NSPanel`, about 460 × 72 pt, with `NSAppearance(named: .darkAqua)`, a corner radius of 12 pt, the fill `#2C2C2C` and a 1 pt border `#3B3B3B`;
  - on the left, 16 pt in, two lines: the title (13 pt medium, label colour, one line, cut at the tail); below it the status (R27) in `systemRed`, then ` · ` and the `timeRange` in the secondary label colour, both 12 pt;
  - on the right, 12 pt in and centred vertically: a 28 pt tall button with the fill `#373737` and a 6 pt corner radius holding the Google Meet logo (16 pt, the image of menubar-app R26) and `Join Google Meet` (13 pt), joined to a 28 × 28 pt `chevron.down` part by a 1 pt divider. The chevron opens a menu with `Dismiss` and `Copy link`.
- R32. Place: the top right of the screen with the menu bar (`NSScreen.screens.first`), 8 pt below the top of its `visibleFrame` and 8 pt in from its right edge. Another open panel goes 8 pt below the lowest one; when one closes, the ones below move up. The panel sits at the `.statusBar` level, shows on every Space and over full-screen apps (`.canJoinAllSpaces`, `.fullScreenAuxiliary`), stays when NextUp isn't active (`hidesOnDeactivate = false`), and never takes focus from the app being typed in (`.nonactivatingPanel`): a click on its buttons works without activating NextUp.
- R33. Each refresh passes `now` on: an open panel redraws its status, and closes when `panelStatus` is `nil`. The status is at most a minute stale, which the minute tick (menubar-app R16) keeps true at whole-minute starts.
- R34. Actions:
  - `Join Google Meet` opens the link with R20's check and closes the panel;
  - `Dismiss` closes it;
  - `Copy link` puts the link on the general pasteboard as a string, and the panel stays;
  - `Join` or a click on the notification (R20) also closes the open panel with the same `id`.
- R35. The panel plays no sound (the notification does, R10), needs no permission, and shows with notifications off or a Focus on. It exists only in normal mode: `MeetingAlerts` owns the timers and panels, the self-check never creates it (R23), and its output doesn't change.

## Interface

Consumed: `Event`, the order, the shown title and the start time of `core-rules` (R10, R15–R16, R25); `refresh()`, the kept events and the menu's last block of `menubar-app` (R15, R29).

Provided (nothing reads it yet):

```swift
public struct Alert: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var title: String
    public var body: String
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
Sources/NextUp/MeetingAlerts.swift              the delegate, the category, permission, scheduling, quit, the panel timers
Sources/NextUp/MeetingPanel.swift               the panel window, its layout, its actions and the stacking
Sources/NextUp/AppDelegate.swift                calls it after refresh; the alerts-off item
Support/Info.plist, scripts/check.sh            the alert style key and its check
```

## Tech Stack, Commands, Code Style

Same as [SPEC-menubar-app.md](SPEC-menubar-app.md), plus UserNotifications. Its calls use their `async` forms, and the delegate's two methods are the `async` ones, `nonisolated`, since macOS calls them off the main thread.

- Each update's removals and adds run in one task chained after the previous update's, so a removal can't overtake an older add. Quitting (R14) waits for that chain first, and ignores any update after it.
- R16's first status read only records the status, since that update's adds ran under it; a refresh follows the authorization request (R15), so a new status counts at once rather than at the next tick.

Checks (the gate, unattended): `scripts/check.sh`

## Testing Strategy

- `AlertPlanTests`: every row of R7 and R28, with the fixed calendar and locale of core-rules.
- The scheduling and the panel have no automated test: one needs the notification permission, the other a person looking at the screen. They are the manual QA list below.
- The self-check must keep passing unchanged, which shows the notification code stays out of its path.

## Boundaries

- Always: decide what to schedule in `AlertPlan`; keep the shell to applying `changes`; run `scripts/check.sh` before each commit.
- Ask first (in an unattended run, stop and report it): an entitlement (time-sensitive alerts need one); a third kind of alert beside the notification and the panel; a lead time other than one minute.
- Never:
  - call any UserNotifications API in `--self-check`, in a test or in a script;
  - start NextUp without `--self-check` in an automated session;
  - post a notification to try it out;
  - open a URL from a notification or the panel without the check of R20;
  - open a panel to try it out, from a test, a script or the self-check;
  - log event titles or links.

## Success Criteria

Done when: the alert plan and its changes are tested; scheduling, the Join action, quit and the alerts-off item are built; `scripts/check.sh` passes; the manual QA list stays open.

Manual QA (the user, on the installed app; stays open after the build):

- [ ] After the first install with this module, macOS asks once to allow NextUp's notifications.
- [ ] A test event with a Meet link that starts in 3 minutes: the notification arrives one minute before, with a sound, the event's title and `Starts at <time>`.
- [ ] `Join` opens the meeting and the browser comes to the front. A click on the notification's body does the same.
- [ ] The notification stays on screen until dismissed. If it leaves by itself, note it and set NextUp's alert style to Persistent in System Settings → Notifications.
- [ ] Moving the test event 10 minutes later gives one notification, at the new time. Deleting it gives none. An event without a link gives none.
- [ ] After `Quit NextUp`, no notification arrives for a meeting that was already planned.
- [ ] With NextUp's notifications switched off in System Settings, the menu shows `Turn on meeting alerts…` within a minute, and it opens the Notifications pane. Switched back on, the next test meeting gets its notification.
- [ ] One minute before a test meeting, the panel opens at the top right beside the notification: the title, a red `in 1 m · <range>`, `Join Google Meet`. It stays on screen.
- [ ] At the start time it reads `now`; at the meeting's end it closes by itself.
- [ ] `Join Google Meet` opens the meeting and closes the panel. `˅` → `Dismiss` closes it. `˅` → `Copy link` copies the link and leaves it open. Join on the notification closes the panel too.
- [ ] Two meetings at the same time give two stacked panels; closing the top one moves the other up.
- [ ] The panel shows over a full-screen app and on another Space, and typing in another app isn't interrupted.
- [ ] Beside Notion Calendar's panel, the size, colours and text match; note any gap to tune.
- [ ] A working day with Notion Calendar quit: nothing was missed.

## Open Questions

None of its own. A Focus mode silences the notification unless NextUp is on its allowed list; breaking through needs an entitlement and is out of scope (see the map). The panel shows whatever the Focus (R35).

## Tasks (build order)

- T1. `Alert`'s `start`, `end` and `timeRange`, and `AlertPlan.panelStatus` (R26–R28), with every row of R28 as a test; update the tests that build an `Alert` by hand. Verify: `scripts/check.sh`.
- T2. `MeetingPanel.swift` and the panel timers in `MeetingAlerts` (R25, R29–R35): open at the fire date, stack, redraw and close on refresh, the three actions, closing from the notification's Join. Read the self-check's path from `main.swift` to exit and confirm it reaches none of this code. Verify: `scripts/check.sh`, with the self-check's output unchanged.
- T3. Implementing workflow (`docs/specs/README.md` «Workflow»): delete this Tasks section; set the status line and the README row back to built with manual QA open; keep the manual QA list unticked. Verify: `scripts/check.sh`.
