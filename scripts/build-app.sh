#!/bin/bash
# Universal release build → build/NextUp.app, signed with $NEXTUP_SIGN_IDENTITY or ad-hoc (`-`).
set -euo pipefail
cd "$(dirname "$0")/.."

archs=(--arch arm64 --arch x86_64)
swift build -c release "${archs[@]}"
bin=$(swift build -c release "${archs[@]}" --show-bin-path)

rm -rf build/NextUp.app
mkdir -p build/NextUp.app/Contents/MacOS build/NextUp.app/Contents/Resources
cp "$bin/NextUp" build/NextUp.app/Contents/MacOS/NextUp
cp Support/Info.plist build/NextUp.app/Contents/Info.plist
cp Support/meet.png build/NextUp.app/Contents/Resources/meet.png
cp Support/AppIcon.icns build/NextUp.app/Contents/Resources/AppIcon.icns

codesign --force --sign "${NEXTUP_SIGN_IDENTITY:--}" build/NextUp.app
codesign --verify --strict build/NextUp.app
