# Capability Map: NextUp v1

NextUp is a macOS menu bar app for one person on their own Mac. The bar shows the next calendar event and a countdown, a click lists today and the next 2 days, and a meeting with a Google Meet link is one Join away, with NextUp's own panel a minute before it starts. It replaces Notion Calendar's menu bar item, which holds about 369 MB of memory for this one job. This file is the index of what exists: each module's spec is named by its id and sits beside it.

| Module id | Spec | Responsibility | Depends on |
|---|---|---|---|
| `core-rules` | [SPEC-core-rules.md](SPEC-core-rules.md) | The Swift package and `NextUpCore`, the pure rules: the Meet link in an event's notes, which event is next, the countdown, the bar's text, the menu's sections and rows. Also the repo's `CLAUDE.md`, `README.md` and `.gitignore` | — |
| `menubar-app` | [SPEC-menubar-app.md](SPEC-menubar-app.md) | The AppKit agent app: reading the macOS calendar store, the bar, the menu, Join from the menu, the no-access state, refresh, Launch at login, Quit. Also the bundle, check and install scripts, the self-check and the first memory number | `core-rules` |
| `meeting-alerts` | [SPEC-meeting-alerts.md](SPEC-meeting-alerts.md) | NextUp's own Notion-style panel one minute before a meeting, with Join: the pure alert plan and the panel timers kept equal to it | `menubar-app` |
| `release` | [SPEC-release.md](SPEC-release.md) | Install without Xcode: the universal build, the DMG, zip and checksums, the `v*` tag workflow that publishes a GitHub Release, the README's Install section | `menubar-app` |

Build order: core-rules → menubar-app → meeting-alerts → release.

## Success

- The user quits Notion Calendar and misses nothing.
- NextUp's physical memory footprint stays under 30 MB at idle (how it's measured: menubar-app R40).

## Out of scope

- Google sign-in, any Google API, any network code.
- Transcription.
- A settings window, or preferences of any kind.
- Creating or editing events.
- Zoom, Teams and any link other than Google Meet; a Meet link anywhere but the event's notes.
- Notarization, a Developer ID, the hardened runtime, the sandbox, an updater, an app icon. CI beyond the `v*` tag workflow (release).
- Localization (the UI is English) and special handling of right-to-left titles.
- Choosing calendars; merging one event that sits in two calendars.
- Alerts for events without a Meet link; snooze; a lead time other than one minute; a macOS notification (removed on 2026-11-22: it sat under the panel and showed again after Join). NextUp's own panel is a window, so it shows whatever the Focus.
- SwiftUI, storyboards, third-party packages.

## Verified on the target Mac (2026-11-20)

- macOS 27.2.1 on Apple silicon, Xcode 27.2, Swift and SwiftPM 6.4.2. `swift build` and `swift test` (Swift Testing) run from the command line.
- SwiftPM puts products in `.build/out/Products/<Configuration>/`; `swift build -c release --show-bin-path` prints the folder.
- The Google account is a CalDAV source in macOS. Other calendars sit beside the main one (holidays, birthdays, a subscribed one).
- A scan of 157 events (30 days back, 30 ahead) found 136 with a Meet link, all 136 in `EKEvent.notes`. `location`, `url` and `structuredLocation.title` never held one.
- One sampled `notes` value was a single line of HTML: an `<a>` whose `href` and text are the link, with a 3-4-3 lowercase code and no query string. Other shapes weren't sampled.
- 112 of 114 events with attendees had a link. Events without attendees can carry one too.
- A hand-assembled, ad-hoc signed `.app` (`LSUIElement`, `NSCalendarsFullAccessUsageDescription`, `requestFullAccessToEvents`, launched with `open`) got the system prompt and full access.
- With ad-hoc signing macOS asks for the permissions again after every rebuild, because the identity changes.
- `tccutil reset Calendar <bundle id>` works only while an app with that id sits where LaunchServices indexes it: it worked under the home folder and failed under `/private/tmp`.
- The keychain holds 2 valid Apple Development code-signing identities.
- `/Applications` is writable without `sudo`. `/usr/bin/timeout` exists here, but not on GitHub's macOS 27.0.1 image; `/usr/bin/perl` exists on both.
- `swift build -c release --arch arm64 --arch x86_64` builds a universal binary, `minos 14.0` in both slices, into the same folder as a native build. It warns that x86_64 is deprecated.
- A process started from a shell can build an `NSStatusItem` and its `NSMenu`, print them and exit, with no prompt. The self-check relies on this.
- An AppKit agent with one status item and a small menu, built for release, bundled and ad-hoc signed, idles at 17 to 18 MB of physical footprint with no calendar code running. That leaves about 12 MB for everything else.
- In `en_US` the short time has U+202F before `AM` and `PM`.
- System Settings on this macOS has the panes `com.apple.settings.PrivacySecurity.extension` (with the anchor `Privacy_Calendars`) and `com.apple.Notifications-Settings.extension`.

## Not verified

| Item | Answered by |
|---|---|
| `SMAppService.mainApp` for a hand-assembled, locally signed bundle in `/Applications` | menubar-app manual QA |
| A keychain dialog when `codesign` uses an Apple Development identity from a script | menubar-app manual QA |
| The calendar grant surviving a rebuild signed with the same Apple Development identity | menubar-app manual QA |
| The System Settings links landing on the right pane | manual QA of both app modules |
| Guests' statuses (a declined guest) reaching `EKEvent.attendees` from the Google CalDAV source | menubar-app manual QA |
| Idle memory with real calendars against the 30 MB target | menubar-app manual QA and R40–R42 |
| What Notion Calendar does where the screenshots don't show it | Open Questions below |
| The release workflow on GitHub's `xcode-27` image, the self-check included | release manual QA |
| Gatekeeper's Open Anyway for a downloaded ad-hoc build, and the grants after an update | release manual QA |

## Shared decisions (bind every module)

- Swift 6 with the AppKit lifecycle (`NSApplication`, `NSStatusItem`, `NSMenu`): an agent app with no Dock icon. No SwiftUI, no storyboard.
- One SwiftPM package: `NextUpCore` (the rules), `NextUp` (the shell) and `NextUpCoreTests`, with scripts that assemble and sign `NextUp.app`. An agent can build all of it from the command line.
- Every rule worth a test is a pure function in `NextUpCore`. The shell reads, draws and schedules.
- Events come from EventKit only: every calendar in macOS, timed events only. All-day, cancelled and declined events are skipped.
- The Meet link is read from the event's notes only.
- The window is today plus the next 2 days.
- No network code, no third-party packages, nothing stored.
- The bundle id is `ir.kaavehdev.nextup`. It never changes after the first install, because the permissions and the login item hang on it.
- Signing: automated checks sign ad-hoc, which never prompts. The user's install signs with a local Apple Development identity picked at run time, so that macOS can keep the grants across rebuilds. A GitHub Release is always ad-hoc, because an identity's name would ship inside its signature. No identity name, team id or hash is ever committed.
- No sandbox, no hardened runtime, no notarization: the app is built locally, or downloaded from a GitHub Release and let past Gatekeeper once by hand (release).
- Unattended checks never raise a prompt. They run `NextUp --self-check`, which uses sample events and touches no calendar, notification or login-item API. Everything else is manual QA.
- Memory: under 30 MB of physical footprint at idle. A higher measured number is recorded as an open item; the code isn't contorted to reach the target.
- The minimum is macOS 14, the lowest version that has every API used. Only macOS 27 is tested.
- The look is copied from Notion Calendar's menu bar item, from two reference screenshots that stay out of the repo: a thin colour bar and `<title> · in 5 h 24 m` in the bar, and a native menu with grey section headers and rows of `<bar> 5:30 PM · <title>`. An event a guest declined gets a striped bar and a `⚠ ` before the text. Join items show the Google Meet logo, public releases included: the user chose to keep it.
- UI text is English. The clock format follows the system.
- Privacy: no real event titles, people, calendar names, email addresses, home-folder paths, identity names, team ids or hashes anywhere in the repo. NextUp logs no event data.

## Assumptions (chosen for the user; overrule any before the build)

1. The bundle id is `ir.kaavehdev.nextup`. Confirm it before the first install.
2. The app is installed at `/Applications/NextUp.app` (menubar-app R39).
3. The install signs with the first Apple Development identity in the keychain, unless `NEXTUP_SIGN_IDENTITY` names another (menubar-app R39).
4. The bar shows the running event, as `<title> · now`, until the next event is 15 minutes away; otherwise the next event today (core-rules R37). Picked by the user from Notion Calendar's behaviour.
5. Join sits in the meeting row's submenu, and the menu's first row also has it right under the row, with the Google Meet logo, as in the reference. A click on a row itself does nothing (menubar-app R25–R26).
6. The menu's sections are `Ending in …` for what is running, `Upcoming in …` for later today, `Tomorrow`, and the day after by date. Ended events aren't listed (core-rules R22–R23).
7. All-day, cancelled and declined events are skipped (menubar-app R13).
8. Only an event with a Meet link gets an alert: NextUp's own Notion-style panel with Join, which stays until Join, Dismiss or the meeting's end. It plays no sound, and NextUp posts no macOS notification (meeting-alerts R1, R25–R35).
9. A meeting first seen less than a minute before it starts gets no panel (meeting-alerts R13).
10. With nothing coming, the bar is a calendar icon. Without calendar access it is the icon with an exclamation badge, and the menu offers System Settings (menubar-app R22, R28).
11. Titles are cut at 30 characters in the bar and at 50 in a menu row (core-rules R16).
12. The countdown is whole minutes rounded up, in one format in the bar and the header, with `in 1 d 3 h` beyond a day (core-rules R12–R13).
13. The calendar is read again on every trigger, the minute tick included, on the main thread (menubar-app R11, R15–R16).
14. An event that sits in two calendars shows twice in the menu, and alerts once (meeting-alerts R3).
15. A release tag is `v` plus `CFBundleShortVersionString`, optionally with a `-suffix` that makes it a pre-release; any other tag fails the workflow (release R13–R14).
16. The DMG window shows the app and an Applications link in Finder's default layout, with no background or icon positions (release R5).

## Open Questions

| Owner | Item |
|---|---|
| User | Two Apple Development identities are in the keychain. Is the first one listed the right one, or will `NEXTUP_SIGN_IDENTITY` be set? |
| User | With several events on one day, is `Ending in …` / `Upcoming in …` the grouping wanted? Notion's wasn't seen |
| User | If idle memory measures 30 MB or more: accept the number, or spec an optimisation pass? |
| User | A right-to-left title may put the countdown before the title in the bar (not tested). Is a fix wanted? |
