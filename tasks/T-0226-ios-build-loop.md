---
id: T-0226
title: Create unsigned iOS export and macOS build loop
epic: E12
type: infra
area: infra
risk: high
executor: sol
think: high
ui: none
status: in_progress
depends_on: [T-0208]
touch:
  - game/export_presets.cfg
  - .github/workflows/build-ios.yml
  - tools/ios_build.py
  - tools/tests/test_ios_build.py
  - docs/qa/T-0226-ios-build.md
  - tasks/T-0226-ios-build-loop.md
revision: 1
---

## Goal
Prepare iOS export and a repeatable nightly/manual macOS compile without storing
Apple credentials or implying a signed device build.

## Context
- ROADMAP T-0226, FR-PLAT-02, FR-AUDIO-02, decision 0009.
- Godot 4.7 iOS exporter requires a real Apple Team ID and bundle identifier.
- AGENTS.md S7/S11: only the explicitly authorized iOS export and workflow
  changes are in scope. Owner credentials/device proof remain gated.

## Current state
- game/export_presets.cfg contains Android Debug and Release presets only.
- game/project.godot pins 4.7.2 and iOS Ambient category.
- .github/workflows/ci.yml runs Linux checks, not iOS.
- game/platform/haptics has Android and Fake, but no iOS implementation.

## Specification
1. Append iOS Debug preset with minimum iOS 17; do not change Android IDs.
2. Add manual and nightly pinned macOS/Xcode CI job for unsigned export and compile.
3. Use GitHub variables IOS_APPLE_TEAM_ID and IOS_BUNDLE_IDENTIFIER, never
   store them or signing certificates in Git. Invalid input must fail closed.
4. Missing variables result in an explicit NOT RUN status, never a false pass.
5. Capture engine and Xcode logs; preserve artifact on failure.
6. Keep native haptics, signing, TestFlight and iPhone tests in separate gates.

## Tests
- Reject invalid team, bundle or missing preset without mutating files.
- Preserve Android IDs, check iOS 17 floor, run all local checks.
- Verify actual macOS compile and native-device behavior before done.

## Acceptance
CI produces a real Xcode build artifact and diagnostics with owner variables.
After independent review and iPhone verification, close T-0226.
Until then leave PR draft and status in_progress.

## Out of scope
Distribution signing, secret insertion, plugins, native haptics, store build,
project.godot and Android changes.

## Escalation
S11: no owner Apple Team ID, bundle or signed iPhone environment was supplied.
Prepared only a safe unsigned path. Human validation remains required.
