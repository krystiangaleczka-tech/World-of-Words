---
id: T-0027
title: Execute S1 Android SDK spike
epic: E02
type: spike
area: platform.ads
risk: high
executor: human
think: xhigh
ui: none
status: done
depends_on: [T-0026]
touch:
  - spikes/s1-android/**
  - docs/spikes/S1-android.md
  - tasks/T-0027-*.md
revision: 2
---

## Goal
Execute the T-0026 Android S1 matrix on the Galaxy A15 using a disposable project and
record reproducible evidence for the engine gate. Never promote a smoke test to a matrix PASS.

## Context
- `docs/spikes/S1-plan.md` owns candidates, bounded fallbacks, prerequisites and P1-P11.
- `docs/decisions/0001-engine.md` owns engine pin and F1-F4 classification.
- `docs/decisions/0007-app-identifiers.md` fixes `com.mazen.worldofwordgame.spike`.
- Roadmap T-0027; FR-PLAT-01, FR-ADS-04, FR-IAP-03.

## Current state
- T-0026 revision 3 merged through PR #8 at commit 9749479; its status still says review.
- Android SDK 36 and Java 17 are locally available; Godot 4.7.2 is available upstream.
- Galaxy A15 SM-A156B is connected over ADB Wi-Fi, Android 16 / API 36.
- No throwaway S1 project or Android report exists.
- Chris confirmed provider/store resources are not prepared.

## Specification
### Behavior
1. Create an isolated typed-GDScript Godot 4.7.2 diagnostic project; leave game/ untouched.
2. Pin Poing AdMob 5.1.0 and Google Play Billing 3.3.0, including native dependencies.
3. Export/install a debug APK and record native singleton availability and Billing connection.
4. Keep ads uninitialized and do not request ads without configured/resolved UMP.
5. Execute P1-P8/P10-P11 only with the plan's real prerequisites; P9 is iOS-only.
6. Record unexecuted matrix items and prerequisites as deferred. Chris accepted this diagnostic
   round as completion of T-0027; task completion does not mean the full S1 matrix passed.

### Edge cases
- Missing provider resources: DEFERRED / NOT EXECUTED, never PASS or an engine failure.
- Missing native singleton/export failure: record exact error before the bounded fallback.
- Sideloaded Billing connection: smoke evidence only, never P4/P5/P10 evidence.

## Out of scope
Production game code, iOS execution, native ads/IAP rewrites, paid purchases and production resources.

## Tests
- `make check` on the production project.
- `tools/tasks.py lint` and scope check against origin/main.
- Headless import and Android debug export of the disposable project.
- Device launch: actual Godot version, native singleton presence and Billing connection in logcat.
- Deferred: full device matrix P1-P11 exactly as S1-plan when resources are ready, before release.

## Acceptance
Diagnostic export/install/startup and Billing connection have genuine device evidence.
Chris explicitly accepts this task as done with the full matrix deferred; no S1 gate PASS is claimed.

## Rollback
Revert this task's files and uninstall the disposable app. No production save or store ID changes.

## Escalation log
- Chris requested execution from T-0026 despite missing T-0027 file; this records its scope.
- T-0026 is merged, accepted as the dependency despite stale review status; no unrelated task edited.
- S1: T-0012 has no task file; its roadmap/account prerequisites remain unmet for the deferred store tests.
- Chris confirmed missing account/provider resources; runtime smoke work can proceed, full S1 cannot.

## Decision log
- 2026-10-03 — Chris explicitly declared T-0027 complete and requested this decision be logged.
  Revision 2 supersedes the earlier requirement to keep this task blocked until all rows pass.
- Chris will create the Play developer account closer to release, not during the current prototype
  stage. Real Play purchases/restore and AAB internal-track acceptance (P4/P5/P10) are deferred
  until that account, products and testers are configured, with time reserved before publication.
- Remaining unexecuted ads/UMP, analytics/crash, haptics and integrated stability matrix rows
  remain deferred evidence, not passed tests. Continue gameplay, input, save, performance and
  haptics testing on device during development; those checks need not wait for a Play account.
- Accepted tradeoff: Godot/SDK purchase and store compatibility will be confirmed later, so later
  findings may require integration changes in a more developed application. T-0028/T-0033 must
  distinguish this accepted task closure from full S1 validation and preserve the outstanding tests.
