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
status: review
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
- Updated preflight on 2026-10-06: T-0028 and T-0029 are done on main.
- PR #10 and PR #12 are merged; PR #19 records Chris's Galaxy A15 smooth-swipe confirmation.
- Chris explicitly approved Godot 4.7.2 and accepted deferred SDK/store validation risk after the
  concrete T-0033 proposal. Deferred P1–P11 rows remain unexecuted rather than PASS.
- The original draft's dependency escalation is resolved; no runtime/plugin installation is needed.

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

## Escalation — resolved
S1 dependency/preflight failure is resolved: T-0028 and T-0029 are done on main after PRs #10, #12
and #19 merged. Chris confirmed the Galaxy A15 test and smooth swipe, then explicitly accepted the
Godot 4.7.2 development path with SDK/store checks deferred but mandatory before release.

## Completion record
2026-10-06: decision 0001 accepted under the explicit human gate exception, decision 0009 records
providers/OS floors/haptics/audio/accessibility, and PRODUCT Q8/Q9 refer to decision 0009.
No unreported measurement or deferred SDK/store row is marked PASS. Task remains review until
the completed PR is reviewed and merged.
