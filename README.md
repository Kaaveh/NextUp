# NextUp

NextUp is a small macOS menu bar app that shows your next calendar event and a countdown, lists today and the next 2 days, and puts a Google Meet link one click away. It exists to replace a much heavier calendar app's menu bar item for this one job, with a footprint of a few tens of megabytes.

## Requirements

- macOS 14 or later to run.
- Xcode with Swift 6.2 or later to build.

## Build and test

```
swift build
swift test
```

NextUp reads the calendars on your Mac and has no network code.
