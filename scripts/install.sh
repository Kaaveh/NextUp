#!/bin/bash
# For a person, never for automation: it may make codesign ask for the keychain,
# and NextUp asks for calendar access on first launch.
# Builds NextUp.app signed with a keychain identity, puts it in /Applications and opens it.
set -euo pipefail
cd "$(dirname "$0")/.."

# 1. The identity: $NEXTUP_SIGN_IDENTITY, else the first Apple Development one, else ad-hoc.
identity=${NEXTUP_SIGN_IDENTITY:-}
if [ -z "$identity" ]; then
    identity=$(security find-identity -v -p codesigning | grep -m 1 'Apple Development' | awk '{print $2}' || true)
fi
if [ -z "$identity" ]; then
    identity=-
    echo "warning: no Apple Development identity found; signing ad-hoc, so macOS will ask for the permissions again after every install" >&2
fi

# 2.
NEXTUP_SIGN_IDENTITY=$identity scripts/build-app.sh

# 3. Replace the installed app and open it.
pkill -x NextUp || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x NextUp >/dev/null || break
    sleep 0.5
done
rm -rf /Applications/NextUp.app
ditto build/NextUp.app /Applications/NextUp.app
open /Applications/NextUp.app

# 4. Never the identity's name or hash.
if [ "$identity" = - ]; then
    echo "signed with: ad-hoc"
else
    echo "signed with: a keychain identity"
fi
