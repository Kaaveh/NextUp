# NextUp

<p align="center"><img src="docs/screenshot.png" width="475" alt="NextUp in the menu bar: the next meeting with its countdown, and the open menu with a Join Google Meet row and the events of today, tomorrow and the day after"></p>

NextUp is a small macOS menu bar app that shows your next calendar event and a countdown, lists today and the next 2 days, and puts a Google Meet link one click away, with its own Join panel one minute before each meeting. It exists to replace a much heavier calendar app's menu bar item for this one job, with a footprint of a few tens of megabytes.

## Requirements

- macOS 14 or later, on Apple silicon or Intel, to run.
- Xcode with Swift 6.2 or later to build.

## Build and test

```
swift build
swift test
scripts/check.sh      # tests, the app bundle and a self-check with sample events
```

`scripts/check.sh` signs ad-hoc and never asks for a permission. Its self-check puts a sample item in the menu bar for about 5 seconds, so it needs a logged-in desktop session.

## Install

### Download

1. Download `NextUp-<version>.dmg` from [Releases](https://github.com/Kaaveh/NextUp/releases/latest).
2. Open it and drag **NextUp** onto **Applications**.

<!-- Screenshot: the DMG window, NextUp beside the Applications link. -->

**First launch.** NextUp is not notarized by Apple (it is signed ad-hoc, without a developer account), so macOS blocks it the first time:

1. Open NextUp from Applications. macOS says Apple could not verify it is free of malware; click **Done**.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, and click **Open Anyway** beside the line about NextUp.
3. Confirm with your password or Touch ID. NextUp opens, and later launches open normally.

<!-- Screenshot: Privacy & Security with the Open Anyway button for NextUp. -->

Or, instead of those 3 steps, in Terminal:

```
xattr -dr com.apple.quarantine /Applications/NextUp.app
```

NextUp then asks for calendar access (see Permissions).

**Updating.** Quit NextUp (`Quit NextUp` in its menu), install the new DMG the same way and choose **Replace**. Every release has a new ad-hoc signature, so macOS treats it as a new app: it may ask for calendar access again, and the first-launch steps may be needed again.

### Build from source

```
scripts/install.sh
```

It builds `NextUp.app`, signs it with the first Apple Development identity in your keychain (or the one `NEXTUP_SIGN_IDENTITY` names), replaces `/Applications/NextUp.app` and opens it. It prints only whether it signed with a keychain identity or ad-hoc. Without an Apple Development identity it signs ad-hoc, and macOS then asks for calendar access again after every install. `codesign` may ask once for access to the keychain.

## Permissions

- **Calendar.** On first launch macOS asks for full access to your calendars. NextUp reads today and the next 2 days from every calendar on your Mac; the events stay on this Mac. Without access the menu bar shows a calendar icon with an exclamation badge, and the menu offers `Open Privacy Settings…` (Privacy & Security → Calendars).
- **Meeting panel.** Needs no permission. One minute before an event with a Google Meet link starts, NextUp opens a panel at the top right with the title, a countdown and `Join Google Meet`. It stays until you join, dismiss it, or the meeting ends. NextUp posts no macOS notification.
- **Launch at login.** Ticking `Launch at login` in the menu adds NextUp to System Settings → General → Login Items.

To see the first-run prompt again: `tccutil reset Calendar ir.kaavehdev.nextup`, while NextUp is in `/Applications`.

## Memory

The target is a physical footprint under 30 MB at idle. After NextUp has idled for 10 minutes:

```
footprint -p "$(pgrep -x NextUp)"
```

The header line holds `Footprint: <n> MB`. The self-check prints its own number as the last line of `scripts/check.sh`, with no calendar code running.

NextUp reads the calendars on your Mac, stores nothing and has no network code.

## How to cut a release

For the maintainer:

1. In `Support/Info.plist`, set `CFBundleShortVersionString` to the new version and raise `CFBundleVersion`; commit on `main`.
2. Tag and push: `git tag v1.2.0 && git push origin v1.2.0`.

The Release workflow checks that the tag matches `CFBundleShortVersionString`, runs `swift test` and `scripts/check.sh`, builds the DMG, zip and checksums with `scripts/make-dmg.sh`, and publishes the release with generated notes. A tag with a suffix, such as `v1.2.0-rc1`, becomes a pre-release. `scripts/make-dmg.sh` runs locally too and writes to `build/`.
