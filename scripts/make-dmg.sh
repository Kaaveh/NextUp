#!/bin/bash
# build/NextUp-<version>.dmg, .zip and .sha256 from a universal, ad-hoc signed NextUp.app.
# The version is $1, else CFBundleShortVersionString of Support/Info.plist.
set -euo pipefail
cd "$(dirname "$0")/.."

version=${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)}
if ! [[ $version =~ ^[0-9A-Za-z.-]+$ ]]; then
    echo "make-dmg: the version may hold only letters, digits, '.' and '-': $version" >&2
    exit 64
fi
name=NextUp-$version

# 1. Always ad-hoc: a keychain identity's name would ship inside the signature.
NEXTUP_SIGN_IDENTITY=- scripts/build-app.sh

# 2. The DMG window: NextUp.app beside a link to /Applications.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto build/NextUp.app "$stage/NextUp.app"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname NextUp -srcfolder "$stage" -format UDZO -ov "build/$name.dmg"

# 3. The zip and the checksums, with bare names so `shasum -a 256 -c` works in a download folder.
rm -f "build/$name.zip"
ditto -c -k --keepParent build/NextUp.app "build/$name.zip"
(cd build && shasum -a 256 "$name.dmg" "$name.zip" > "$name.sha256")
cat "build/$name.sha256"
