# Spec: meeting-alerts

Module 3 of 3 in the NextUp capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on `menubar-app` being merged. Status: specified, not built.

## Objective

One minute before a meeting starts, macOS shows a notification with a Join button. A meeting is an event with a Google Meet link. Join, or a click on the notification, opens the link in the browser. What to announce is decided by a pure function; the shell only keeps macOS's pending notifications equal to that plan.

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
- R5. An alert stays in the plan until its meeting starts, not until it fires. The plan therefore doesn't change in the second the notification is due.
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
}

public enum AlertPlan {
    public static func alerts(for events: [Event], now: Date, calendar: Calendar, locale: Locale) -> [Alert]
    public static func changes(from last: [Alert], to plan: [Alert], now: Date) -> (remove: [String], add: [Alert])
}
```

## Project Structure

```
Sources/NextUpCore/AlertPlan.swift              Alert, the plan, the changes
Tests/NextUpCoreTests/AlertPlanTests.swift
Sources/NextUp/MeetingAlerts.swift              the delegate, the category, permission, scheduling, quit
Sources/NextUp/AppDelegate.swift                calls it after refresh; the alerts-off item
Support/Info.plist, scripts/check.sh            the alert style key and its check
```

## Tech Stack, Commands, Code Style

Same as [SPEC-menubar-app.md](SPEC-menubar-app.md), plus UserNotifications. Its calls use their `async` forms, and the delegate's two methods are the `async` ones.

Checks (the gate, unattended): `scripts/check.sh`

## Testing Strategy

- `AlertPlanTests`: every row of R7, with the fixed calendar and locale of core-rules.
- The scheduling itself has no automated test: it needs the notification permission. It is the manual QA list below.
- The self-check must keep passing unchanged, which shows the notification code stays out of its path.

## Boundaries

- Always: decide what to schedule in `AlertPlan`; keep the shell to applying `changes`; run `scripts/check.sh` before each commit.
- Ask first (in an unattended run, stop and report it): an entitlement (time-sensitive alerts need one); a second kind of notification; a lead time other than one minute.
- Never:
  - call any UserNotifications API in `--self-check`, in a test or in a script;
  - start NextUp without `--self-check` in an automated session;
  - post a notification to try it out;
  - open a URL from a notification without the check of R20;
  - log event titles or links.

## Success Criteria

Done when: the alert plan and its changes are tested; scheduling, the Join action, quit and the alerts-off item are built; `scripts/check.sh` passes; the manual QA list stays open.

Automated (the Checks cover them):

- [ ] `scripts/check.sh` exits with 0, with the self-check's output unchanged.
- [ ] Every row of R7 is a test.
- [ ] The bundle's `Info.plist` holds `NSUserNotificationAlertStyle`.

Manual QA (the user, on the installed app; stays open after the build):

- [ ] After the first install with this module, macOS asks once to allow NextUp's notifications.
- [ ] A test event with a Meet link that starts in 3 minutes: the notification arrives one minute before, with a sound, the event's title and `Starts at <time>`.
- [ ] `Join` opens the meeting and the browser comes to the front. A click on the notification's body does the same.
- [ ] The notification stays on screen until dismissed. If it leaves by itself, note it and set NextUp's alert style to Persistent in System Settings → Notifications.
- [ ] Moving the test event 10 minutes later gives one notification, at the new time. Deleting it gives none. An event without a link gives none.
- [ ] After `Quit NextUp`, no notification arrives for a meeting that was already planned.
- [ ] With NextUp's notifications switched off in System Settings, the menu shows `Turn on meeting alerts…` within a minute, and it opens the Notifications pane. Switched back on, the next test meeting gets its notification.
- [ ] A working day with Notion Calendar quit: nothing was missed.

## Open Questions

None of its own. A Focus mode silences the alert unless NextUp is on its allowed list; breaking through needs an entitlement and is out of scope (see the map).

## Tasks (build order)

- [ ] T1. `Alert`, `AlertPlan.alerts`, `AlertPlan.changes` and their tests (R1–R7). Verify: `swift test`.
- [ ] T2. `MeetingAlerts` in the shell: the delegate, the category and its action, permission, scheduling after each refresh, the first-run and clock rules, quit; the plist key and its check (R8–R15, R18–R24). Verify: `scripts/check.sh`, with the self-check's output unchanged.
- [ ] T3. The kept permission status, rescheduling when it changes, and the alerts-off item (R16–R17). Verify: `scripts/check.sh`.
- [ ] T4. Docs and spec workflow: add the notification permission to `CLAUDE.md` and `README.md`; delete this section and the automated Success Criteria; set the status line and the row in `docs/specs/README.md` to built with manual QA open. Verify: `scripts/check.sh`.
