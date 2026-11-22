# NextUp

NextUp is a macOS menu bar app that shows the next calendar event with a countdown and lists today and the next 2 days. A meeting with a Google Meet link is one Join away, and NextUp's own panel with Join opens one minute before it starts. Limits: Swift and AppKit, no SwiftUI, no network code, no third-party packages, EventKit as the only source of events.

## Workflow

Spec first, then a fresh session implements it. `docs/specs/README.md` is the contract: read the module's spec, then `docs/specs/CAPABILITY-MAP.md`, then this file.

## Commands

```
swift build
swift test
scripts/check.sh                                        # the gate: rules, bundle, self-check (ad-hoc, no prompts)
scripts/build-app.sh                                    # build/NextUp.app (universal), signed with $NEXTUP_SIGN_IDENTITY or ad-hoc
scripts/make-dmg.sh [version]                           # build/NextUp-<version>.dmg, .zip, .sha256, always ad-hoc
build/NextUp.app/Contents/MacOS/NextUp --self-check     # sample data, no prompts; needs the logged-in desktop session
scripts/install.sh                                      # a person only: keychain identity, /Applications/NextUp.app, open
footprint -p "$(pgrep -x NextUp)"                       # idle memory of the installed app
```

Run `scripts/check.sh` before each commit.

## Layout

- `NextUpCore` (`Sources/NextUpCore/`): the pure rules (Meet link, order, countdown, bar text, menu sections, the alert plan). Foundation only.
- `NextUpCoreTests` (`Tests/NextUpCoreTests/`): Swift Testing table tests for those rules.
- `NextUp` (`Sources/NextUp/`): the AppKit shell that reads events and draws what `NextUpCore` returns. `Support/Info.plist` is its bundle's plist; `scripts/` builds, checks and installs it.

## Conventions

- A rule worth a test is a pure function in `NextUpCore`, with its test in `NextUpCoreTests`.
- `now`, `calendar` and `locale` are passed in; the library never reads the clock, calendar or locale itself.
- Check an API against the installed SDK (`xcrun --show-sdk-path`), or with `ctx7`, before using it from memory.

## Privacy

This repo may become public. Samples are invented (`Design sync`). No real event titles, people, calendar names, email addresses, home-folder paths, signing identity names, team ids or certificate hashes: not in specs, code, tests, logs, commits or pull requests.

## Never, in an automated session

- Run anything that asks for calendar, notification, keychain or login-item permission.
- Post a macOS notification or import UserNotifications (the meeting panel is the only alert), or open a panel to try it out.
- Start NextUp without `--self-check`: not with `open`, not by running the binary, not with `swift run`.
- Run `scripts/install.sh`, `tccutil` or `security`, or sign with anything but `-` (ad-hoc).
- Call `SMAppService` `register()` anywhere but the `Launch at login` menu action.
- Import SwiftUI or add network code.
- Log event titles or links, or commit identity names, team ids or hashes.
- Read the user's calendar from a test or a script.
