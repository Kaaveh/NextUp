# Spec: release

Module 4 of 4 in the NextUp capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on `menubar-app`. Status: specified, not built.

## Objective

Someone without Xcode or an Apple Developer account installs NextUp from a GitHub Release: download a DMG, drag NextUp to Applications, let it past Gatekeeper once. A pushed `v*` tag builds, checks and publishes that release. The app stays ad-hoc signed and not notarized, so the README walks through Gatekeeper's Open Anyway.

### Requirements

**Build**
- R1. `scripts/build-app.sh` builds universal: `swift build -c release --arch arm64 --arch x86_64`, and asks for the product folder with the same flags. Every caller gets the same bundle, so the self-check runs on what ships. This amends menubar-app R7.
- R2. `scripts/check.sh` fails unless `lipo -archs` on the bundle's binary lists `arm64` and `x86_64`.

**Package** (`scripts/make-dmg.sh [version]`)
- R3. The version is the first argument, else `CFBundleShortVersionString` of `Support/Info.plist`. It must match `^[0-9A-Za-z.-]+$`, because it goes into file names.
- R4. It runs `NEXTUP_SIGN_IDENTITY=- scripts/build-app.sh`: a release is always ad-hoc, whatever the environment holds, because a keychain identity's name would ship inside the signature.
- R5. `build/NextUp-<version>.dmg`: `hdiutil create -volname NextUp -srcfolder <staging> -format UDZO -ov`, where the staging folder holds `NextUp.app` (copied with `ditto`) and `Applications`, a symlink to `/Applications`. No background image or icon positions: they need Finder scripting, which raises an Automation prompt and can't run unattended.
- R6. `build/NextUp-<version>.zip`: `ditto -c -k --keepParent build/NextUp.app`.
- R7. `build/NextUp-<version>.sha256`: `shasum -a 256` of the DMG and the zip, run inside `build/`, so the file holds bare names and `shasum -a 256 -c` checks it in a download folder.
- R8. Only tools that ship with macOS and Xcode.

**Workflow** (`.github/workflows/release.yml`)
- R9. Trigger: a pushed tag matching `v*`, nothing else.
- R10. `permissions: contents: write` and the default `GITHUB_TOKEN`, nothing more. No secrets, certificates or signing identities.
- R11. Runner `xcode-27`: GitHub's public-preview image with Xcode 27.1 on macOS 27, the closest to the development Mac (Swift 6.4, `/usr/bin/timeout`, which `check.sh` needs).
- R12. Steps: `actions/checkout` with `persist-credentials: false`, pinned to a full commit SHA with its tag in a comment; the tag check (R13); `swift test`; `scripts/check.sh`; `scripts/make-dmg.sh <version>`; the release (R14). No other action: the release uses the `gh` CLI that the image ships.
- R13. The tag minus its leading `v` and any `-suffix` must equal `CFBundleShortVersionString`, or the job fails before building: `v1.2.0` and `v1.2.0-rc1` both need `1.2.0`.
- R14. `gh release create <tag> --verify-tag --generate-notes --title "NextUp <version>"` with the DMG, the zip and the `.sha256` attached, where `<version>` is the tag minus its `v`. A tag holding `-` adds `--prerelease`.
- R15. The tag reaches shell code only through `GITHUB_REF_NAME`, never as `${{ }}` inside `run:`, so a tag name can't inject a command.

**README**
- R16. `Install` starts with the download: the DMG from Releases, open it, drag NextUp to Applications.
- R17. First launch: macOS blocks it because it isn't notarized. Open it once, then System Settings → Privacy & Security → Open Anyway, and confirm once. Terminal alternative: `xattr -dr com.apple.quarantine /Applications/NextUp.app`.
- R18. After an update macOS may ask for calendar access again, because each ad-hoc build is a new identity. Notifications aren't mentioned: NextUp asks for none (meeting-alerts).
- R19. Two screenshot placeholders as HTML comments: the DMG window, and the Open Anyway button. No image file until the user takes them.
- R20. Building from source with `scripts/install.sh` stays, under its own heading.
- R21. `How to cut a release`, for the maintainer: set `CFBundleShortVersionString` (and raise `CFBundleVersion`) in `Support/Info.plist` on `main`, tag `vX.Y.Z`, push the tag.

## Interface

Consumed from `menubar-app`: `scripts/build-app.sh`, `scripts/check.sh`, `Support/Info.plist` (R6–R7, R38).

Provided: the release assets `NextUp-<version>.dmg`, `NextUp-<version>.zip` and `NextUp-<version>.sha256`.

## Project Structure

```
scripts/build-app.sh             + the two --arch flags (R1)
scripts/check.sh                 + the lipo check (R2)
scripts/make-dmg.sh              build/NextUp-<version>.dmg, .zip, .sha256
.github/workflows/release.yml    tag → check → package → GitHub Release
README.md                        Install, How to cut a release
```

## Tech Stack

Bash 3.2 with `hdiutil`, `ditto`, `shasum`, `lipo` and `PlistBuddy` from macOS. GitHub Actions with the `gh` CLI of the runner image.

## Commands

```
scripts/make-dmg.sh              # build/NextUp-<plist version>.dmg, .zip, .sha256
scripts/make-dmg.sh 1.2.0        # the same, named 1.2.0
```

Checks (unattended): `scripts/check.sh`, then `scripts/make-dmg.sh`, `hdiutil verify build/NextUp-<version>.dmg` and `(cd build && shasum -a 256 -c NextUp-<version>.sha256)`. Where installed: `shellcheck scripts/*.sh` and `actionlint`.

## Code Style

Scripts as in [SPEC-menubar-app.md](SPEC-menubar-app.md). The workflow is one job, its steps named after what they check.

## Testing Strategy

- The scripts are tested by running them: the checks above.
- The workflow runs only on GitHub, so its first run, the Release page and Gatekeeper are the manual QA list below.

## Boundaries

- Always: sign releases ad-hoc; pin each action to a full commit SHA.
- Ask first (in an unattended run, stop and report it): a secret, a certificate, a Developer ID or notarization; another action or packaging tool; a trigger other than a `v*` tag.
- Never:
  - sign a release with a keychain identity;
  - script Finder or call `osascript` from a script;
  - put `${{ github.ref_name }}` or another tag-derived `${{ }}` inside `run:`;
  - commit an image file the user hasn't supplied.

## Success Criteria

Done when: `scripts/check.sh` passes on a universal bundle; `scripts/make-dmg.sh` writes a DMG that `hdiutil verify` accepts, a zip, and a `.sha256` that `shasum -c` accepts; `shellcheck` and `actionlint` report nothing; the README holds R16–R21; the manual QA list stays open.

Manual QA (the user; stays open after the build):

- [ ] Push the tag `v1.0.0-test`. The workflow passes on `xcode-27`, the self-check included, and a pre-release `NextUp 1.0.0-test` holds the DMG, the zip and the `.sha256`, with generated notes.
- [ ] `shasum -a 256 -c NextUp-1.0.0-test.sha256` in the download folder passes.
- [ ] The DMG window shows NextUp beside Applications, and dragging one onto the other installs it.
- [ ] First launch is blocked; Open Anyway in Privacy & Security opens it after one confirmation, and the calendar prompt follows.
- [ ] On a second copy, `xattr -dr com.apple.quarantine` opens it without the Settings step.
- [ ] Installing a newer release over it: note whether macOS asks for calendar access again, and whether `Launch at login` is still ticked.
- [ ] On an Intel Mac, if one is at hand: the app runs.
- [ ] The test release and its tag are deleted.

## Open Questions

| Owner | Item |
|---|---|
| User | The two README screenshots (R19) |
| Later | `xcode-27` is a preview label: switch to the GA label once GitHub ships Xcode 27 on one |

## Tasks (build order)

- T1. Universal build, the lipo check and `scripts/make-dmg.sh` (R1–R8); the command in `CLAUDE.md`; menubar-app R7 and R38 amended. Verify: `scripts/check.sh && scripts/make-dmg.sh && hdiutil verify build/NextUp-1.0.0.dmg && (cd build && shasum -a 256 -c NextUp-1.0.0.sha256) && shellcheck scripts/*.sh`
- T2. The workflow (R9–R15). Verify: `actionlint .github/workflows/release.yml`
- T3. The README (R16–R21); close the spec out. Verify: `grep -q 'Open Anyway' README.md && grep -q 'xattr -dr com.apple.quarantine' README.md`
