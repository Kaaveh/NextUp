#!/bin/bash
# Release build → build/NextUp.app, signed with $NEXTUP_SIGN_IDENTITY or ad-hoc (`-`).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
bin=$(swift build -c release --show-bin-path)

rm -rf build/NextUp.app
mkdir -p build/NextUp.app/Contents/MacOS build/NextUp.app/Contents/Resources
cp "$bin/NextUp" build/NextUp.app/Contents/MacOS/NextUp
cp Support/Info.plist build/NextUp.app/Contents/Info.plist
cp Support/meet.png build/NextUp.app/Contents/Resources/meet.png

codesign --force --sign "${NEXTUP_SIGN_IDENTITY:--}" build/NextUp.app
codesign --verify --strict build/NextUp.app
