# NextUp

NextUp is a small macOS menu bar app that shows your next calendar event and a countdown, lists today and the next 2 days, and puts a Google Meet link one click away, with a notification one minute before each meeting. It exists to replace a much heavier calendar app's menu bar item for this one job, with a footprint of a few tens of megabytes.

## Requirements

- macOS 14 or later to run.
- Xcode with Swift 6.2 or later to build.

## Build and test

```
swift build
swift test
scripts/check.sh      # tests, the app bundle and a self-check with sample events
```

`scripts/check.sh` signs ad-hoc and never asks for a permission. Its self-check puts a sample item in the menu bar for about 5 seconds, so it needs a logged-in desktop session.

## Install

```
scripts/install.sh
```

It builds `NextUp.app`, signs it with the first Apple Development identity in your keychain (or the one `NEXTUP_SIGN_IDENTITY` names), replaces `/Applications/NextUp.app` and opens it. It prints only whether it signed with a keychain identity or ad-hoc. Without an Apple Development identity it signs ad-hoc, and macOS then asks for calendar access again after every install. `codesign` may ask once for access to the keychain.

## Permissions

- **Calendar.** On first launch macOS asks for full access to your calendars. NextUp reads today and the next 2 days from every calendar on your Mac; the events stay on this Mac. Without access the menu bar shows a calendar icon with an exclamation badge, and the menu offers `Open Privacy Settings…` (Privacy & Security → Calendars).
- **Notifications.** On first launch macOS also asks to allow NextUp's notifications. One minute before an event with a Google Meet link starts, a notification shows its title and start time; `Join`, or a click on it, opens the meeting. NextUp asks for the style that stays on screen; if it leaves by itself, set NextUp's alert style to Persistent in System Settings → Notifications. With notifications off, the menu offers `Turn on meeting alerts…`. Quitting NextUp cancels the pending ones.
- **Launch at login.** Ticking `Launch at login` in the menu adds NextUp to System Settings → General → Login Items.

To see the first-run prompt again: `tccutil reset Calendar ir.kaavehdev.nextup`, while NextUp is in `/Applications`.

## Memory

The target is a physical footprint under 30 MB at idle. After NextUp has idled for 10 minutes:

```
footprint -p "$(pgrep -x NextUp)"
```

The header line holds `Footprint: <n> MB`. The self-check prints its own number as the last line of `scripts/check.sh`, with no calendar code running.

NextUp reads the calendars on your Mac, stores nothing and has no network code.
