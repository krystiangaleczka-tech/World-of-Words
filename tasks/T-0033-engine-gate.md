---
id: T-0033
title: Resolve engine gate and platform providers
epic: E02
type: docs
area: docs
risk: high
executor: sol
think: high
ui: none
status: blocked
depends_on: [T-0028, T-0029]
touch:
  - docs/decisions/0001-engine.md
  - docs/decisions/0009-platform-providers.md
  - docs/PRODUCT.md
  - tasks/T-0033-*.md
revision: 1
---

## Goal
Close the Phase 0 engine gate: either accept decision 0001 with Godot 4.7.2 pinned, or supersede it
with Unity 6 LTS and re-plan the Godot-specific foundation work. On the Godot path, freeze platform
provider choices, minimum Android/iOS versions, haptics and silent-switch approach, and the mobile
screen-reader outcome.

## Context
- ROADMAP T-0033 is the Phase 0 engine gate and depends on T-0028 and T-0029.
- `docs/decisions/0001-engine.md#s1-pass-criteria` fixes P1-P11 and failure criteria F1-F4.
- `docs/PRODUCT.md#open-questions` Q8 asks for analytics/crash providers; Q9 asks for minimum OS versions.
- NFR-09 requires supported Android/iOS versions to be stated and tested on the lowest supported versions.
- FR-A11Y-04 requires the gate to record whether the pinned engine exposes mobile screen-reader support.

## Current state
- `main` has decision 0001 in `proposed` state and pins Godot 4.7.2 conditionally.
- T-0028 exists only on open PR #10. Its task is marked `done` by Chris's explicit scope decision,
  but iOS P1-P11 remain DEFERRED / NOT EXECUTED and the PR is not merged to `main`.
- T-0029 exists only on open PR #12. Its task is `status: review`; the Galaxy A15 build/run,
  swipe feel, haptics and Chris's latency rating are NOT EXECUTED / NOT RATED.
- Therefore F4 (engine-caused perceivable swipe lag) has no evidence and T-0033's declared dependencies
  are not done on `main`.
- Repository evidence does not currently show an F1-F3 engine failure. Android S1 preparation proved
  Godot 4.7.2 export/install and native plugin loading, but the deliberately deferred store/provider
  matrix must not be upgraded to PASS.
- Current integration floors from the selected S1 candidates are Android API 24+ and iOS 17+; iOS 17
  is driven by the current OpenIAP prebuilt framework. These are provisional until the gate can close.
- Godot 4.7 documents screen-reader integration for desktop platforms; mobile TalkBack/VoiceOver
  exposure is not supported by the pinned version. FR-A11Y-04 therefore remains a Later item on the
  Godot path.
- Godot's iOS audio session can respect the hardware silent switch by using the Ambient/default-style
  session rather than Playback; verify this on device before release.
- The S1 plan's provisional provider choices remain: Poing AdMob for ads/UMP/ATT, Google Play Billing
  integration for Android IAP, OpenIAP for StoreKit 2, `godot-x/firebase` Analytics, Sentry for crash
  reporting, and `toniqat/godot-haptics` with a tiny native iOS bridge as the bounded fallback.

## Specification

### Behavior
1. Do not accept or supersede decision 0001 until both T-0028 and T-0029 are done on `main`.
2. Evaluate P1-P11 and F1-F4 strictly from recorded evidence. DEFERRED / NOT EXECUTED is not PASS.
3. If no F1-F4 failure is present and Chris accepts the residual deferred device/store validation risk,
   update decision 0001 to `accepted` with Godot 4.7.2 pinned.
4. If a failure criterion is met and no bounded fix is credible, supersede decision 0001 with Unity 6
   LTS and create a separate re-plan task/PR for affected E01, E03 and E04 rows; do not edit ROADMAP
   from this executor task.
5. On the Godot path, add `docs/decisions/0009-platform-providers.md` recording:
   - ads/consent provider and bounded fallback;
   - Android Billing and iOS StoreKit 2 provider;
   - analytics and crash providers plus HTTP/native fallback;
   - final minimum Android API and iOS version;
   - haptics implementation and Settings-off behavior;
   - iOS silent-switch audio-session approach;
   - FR-A11Y-04 mobile screen-reader limitation and Later follow-up.
6. Resolve PRODUCT Q8 and Q9 by referencing decision 0009 without changing unrelated product text.

### Gate outcomes
- **Accept Godot:** all available evidence contains no F1-F4 failure, required dependency evidence is
  merged, Chris explicitly chooses the Godot path, and residual deferred checks are listed as follow-up
  device/store validation rather than silently treated as PASS.
- **One credible fix:** leave decision 0001 proposed and create a new bounded S1/S2 follow-up task.
- **Switch:** supersede decision 0001 with Unity 6 LTS; re-planning is a separate planner-owned change.

### Edge cases
- A provider fails but the documented HTTP/native fallback satisfies the same product contract:
  record the fallback; provider failure alone does not fail Godot where decision 0001 says it does not.
- OpenIAP's iOS floor remains 17+: final Q9 cannot be below iOS 17 while that implementation is selected.
- A small haptics bridge is allowed and is not an engine failure.
- Mobile screen-reader support missing on Godot 4.7 is recorded as a known accessibility limitation,
  not silently claimed as supported.
- Missing Galaxy A15 evidence keeps the gate blocked because F4 cannot be evaluated.

## Out of scope
Production SDK installation, store accounts, secrets/signing, new plugin dependencies, device execution,
changing monetization/consent rules, or editing ROADMAP.

## Tests
- `python tools/tasks.py lint`.
- `make check` after the gate is unblocked and final docs are written.
- Verify only files in `touch` changed.
- Verify every P1-P11/F1-F4 statement in the final decision is traceable to merged spike evidence.
- Verify Q8/Q9 point to the final provider decision.
- Verify no deferred device/store row is described as PASS.

## Acceptance
- T-0028 and T-0029 are done on `main`.
- Chris explicitly selects Accept Godot / one more bounded round / switch.
- Decision 0001 is accepted or superseded accordingly.
- Decision 0009 records providers, minimum OS versions, haptics, silent switch and FR-A11Y-04.
- PRODUCT Q8/Q9 are resolved by reference.
- CI is green.

## Rollback
Revert the T-0033 docs commit. If decision 0001 was superseded, never rewrite history: add a new
superseding decision instead.

## Escalation
**S1 — dependency/preflight failure.** T-0033 depends on T-0028 and T-0029, but neither is done on
`main`: PR #10 is open and T-0029 is still `review` with the Galaxy A15 evidence table unexecuted.
F4 therefore cannot be evaluated. Per AGENTS.md the executor stops here and must not guess the engine
gate outcome.

Options once unblocked:
1. Merge the accepted T-0028 scope, execute/rate T-0029 on Galaxy A15, then close this gate.
2. If Chris explicitly waives S2 device evidence, record that as a new human gate decision before
   accepting Godot; do not rewrite T-0029 evidence as PASS.
3. If T-0029 exposes engine-caused perceivable lag, apply decision 0001's bounded-fix/switch rule.

No engine/provider decision files were changed while blocked.
