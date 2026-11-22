# Specs

NextUp is built spec-first. A spec keeps the decisions: what the app does, where it departs from the look it copies and why, and what is still open. The code keeps signatures and wiring. Read the [capability map](CAPABILITY-MAP.md) once (modules, shared decisions, assumptions), then the module you're touching.

| Module | Code | Status | Spec |
|---|---|---|---|
| `core-rules` | `Package.swift`, `Sources/NextUpCore/`, `Tests/NextUpCoreTests/` | Built | [SPEC-core-rules.md](SPEC-core-rules.md) |
| `menubar-app` | `Sources/NextUp/`, `Support/Info.plist`, `scripts/` | Built, manual QA open | [SPEC-menubar-app.md](SPEC-menubar-app.md) |
| `meeting-alerts` | `Sources/NextUpCore/AlertPlan.swift`, `Sources/NextUp/MeetingAlerts.swift`, `Sources/NextUp/MeetingPanel.swift` | Built, manual QA open | [SPEC-meeting-alerts.md](SPEC-meeting-alerts.md) |
| `release` | `scripts/make-dmg.sh`, `.github/workflows/release.yml`, README's Install | Built, manual QA open | [SPEC-release.md](SPEC-release.md) |

## Workflow

One session writes or updates a spec and stops. A fresh session, which starts with none of that conversation, implements it.

- **Writing.** Change the module's spec: set the status line to what is specified and not built, add the decisions as requirements, and give the implementing session a `## Tasks (build order)` section. A new capability gets a row in the map and its own `SPEC-<module-id>.md`.
- **Implementing.** The spec is the contract.
  1. Read the spec, then the map, then `CLAUDE.md`.
  2. Build the Tasks top to bottom, one commit per task, and run each task's `Verify` before committing.
  3. Run the spec's Checks. They run with nobody at the keyboard, so no step may raise a permission prompt.
  4. In the same pull request: delete the Tasks section and the automated Success Criteria, set the status line and this index row, and leave the manual QA list unticked.
  5. Write any departure from the spec into its sections in that pull request. If the code or the platform contradicts the spec, stop and say so instead of quietly deviating.
- **Done** means the status line says built and the manual QA list holds only what is still open. Git keeps the history; the spec keeps none.

## Writing a spec

Every session that touches a module reads its spec, so specs stay lean: the decisions that still bind.

- **Files.** One `CAPABILITY-MAP.md` (the index of modules, the decisions they share, the assumptions made for the user) and one `SPEC-<module-id>.md` per module. Module ids are kebab-case and never renamed.
- **Status line** (line 3): the module's place in the map, what it depends on, and `Status:` in one sentence. No dates, counts or history.
- **Sections**, in this order: Objective (with `### Requirements`), Interface, Project Structure, Tech Stack, Commands, Code Style, Testing Strategy, Boundaries, Success Criteria, Open Questions, Tasks (build order). A module that shares a section with an earlier one points at it.
- **Requirements** are numbered `R1`, `R2`, … under bold group names. A number is never reused or shifted once code or another spec cites it (`core-rules R12`); a removed requirement leaves a gap.
- **A decision is one bullet:** the decision and at most one clause of why. Give numbers and example values, not adjectives.
- **Interface** names what the next module reads. Once the module is built, the code is the source for signatures.
- **Checks** are full commands that pass or fail unattended. Whatever needs a real calendar, a visible notification, the login item, a signing key or a human eye is manual QA under Success Criteria.
- **Tasks** are numbered `T1`, `T2`, …, one commit each, each ending in a `Verify:` line. They exist only for unbuilt work.
- **Open Questions** are a table: Owner and Item. Open rows only.
- **Privacy.** This repo may become public. Samples are invented (`Design sync`). No real event titles, people, calendar names, email addresses, home-folder paths, signing identity names, team ids or certificate hashes: not in specs, code, tests, logs, commits or pull requests.
- **Say it once.** A decision shared by modules lives in the map. How the repo is built and laid out lives in `CLAUDE.md`. Specs point there and don't repeat it.
