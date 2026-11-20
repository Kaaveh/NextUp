# NextUp

NextUp is a macOS menu bar app that shows the next calendar event with a countdown and lists today and the next 2 days. A meeting with a Google Meet link is one Join away. Limits: Swift and AppKit, no SwiftUI, no network code, no third-party packages, EventKit as the only source of events.

## Workflow

Spec first, then a fresh session implements it. `docs/specs/README.md` is the contract: read the module's spec, then `docs/specs/CAPABILITY-MAP.md`, then this file.

## Commands

```
swift build
swift test
```

## Layout

- `NextUpCore` (`Sources/NextUpCore/`): the pure rules (Meet link, order, countdown, bar text, menu sections). Foundation only.
- `NextUpCoreTests` (`Tests/NextUpCoreTests/`): Swift Testing table tests for those rules.
- `NextUp` (`Sources/NextUp/`, arrives with `menubar-app`): the AppKit shell that reads events and draws what `NextUpCore` returns.

## Conventions

- A rule worth a test is a pure function in `NextUpCore`, with its test in `NextUpCoreTests`.
- `now`, `calendar` and `locale` are passed in; the library never reads the clock, calendar or locale itself.
- Check an API against the installed SDK (`xcrun --show-sdk-path`), or with `ctx7`, before using it from memory.

## Privacy

This repo may become public. Samples are invented (`Design sync`). No real event titles, people, calendar names, email addresses, home-folder paths, signing identity names, team ids or certificate hashes: not in specs, code, tests, logs, commits or pull requests.

## Never, in an automated session

Run anything that asks for calendar, notification, keychain or login-item permission.
