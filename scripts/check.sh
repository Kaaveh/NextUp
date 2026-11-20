#!/bin/bash
# The gate: rules, bundle, self-check. Unattended: it signs ad-hoc and raises no prompt.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "check: FAIL: $*" >&2; exit 1; }

# 1. NextUpCore imports Foundation only.
if grep -rhE '^[[:space:]]*(@[[:alnum:]_]+[[:space:]]+)*import[[:space:]]' Sources/NextUpCore \
    | grep -vE '^[[:space:]]*import[[:space:]]+Foundation[[:space:]]*$'; then
    fail "Sources/NextUpCore imports something other than Foundation"
fi

# 2. No SwiftUI, no network code.
if grep -rnE 'import[[:space:]]+(SwiftUI|Network)([^[:alnum:]_]|$)|URLSession' Sources; then
    fail "Sources has SwiftUI or network code"
fi

# 3. The rules.
swift test

# 4. The bundle, always ad-hoc: no keychain is touched.
NEXTUP_SIGN_IDENTITY=- scripts/build-app.sh

# 5. The bundle's plist and signature.
app=build/NextUp.app
plist=$app/Contents/Info.plist
key() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist" 2>/dev/null; }
plutil -lint "$plist" >/dev/null || fail "Info.plist doesn't lint"
codesign --verify --strict "$app" || fail "codesign --verify --strict failed"
[ "$(key LSUIElement)" = true ] || fail "LSUIElement isn't true"
[ "$(key CFBundleIdentifier)" = ir.kaavehdev.nextup ] || fail "CFBundleIdentifier isn't ir.kaavehdev.nextup"
key NSCalendarsFullAccessUsageDescription >/dev/null || fail "NSCalendarsFullAccessUsageDescription is missing"
[ "$(key NSUserNotificationAlertStyle)" = alert ] || fail "NSUserNotificationAlertStyle isn't alert"
[ -f "$app/Contents/Resources/meet.png" ] || fail "Contents/Resources/meet.png is missing"

# 6. The self-check: sample events, no prompts.
expected=$(cat <<'LINES'
bar: Design sync · in 5 h 25 m
menu: # Now
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
LINES
)
out=$(timeout 30 "$app/Contents/MacOS/NextUp" --self-check) || fail "self-check exited with $?"
body=$(printf '%s\n' "$out" | sed '$d')
last=$(printf '%s\n' "$out" | tail -n 1)
if [ "$body" != "$expected" ]; then
    diff <(printf '%s\n' "$expected") <(printf '%s\n' "$body") >&2 || true
    fail "self-check output differs from menubar-app R36"
fi
printf '%s\n' "$last" | grep -qE '^footprint: [0-9]+\.[0-9] MB$' || fail "self-check's last line isn't a footprint: $last"

# 7.
echo "$last"
echo "check: OK"
