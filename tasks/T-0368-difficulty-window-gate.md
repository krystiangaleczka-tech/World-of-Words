---
id: T-0368
title: Validate campaign difficulty against explicit regional windows
epic: E22
type: contract
area: pipeline.validate
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0357, T-0358, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/validate/difficulty.py
  - pipeline/tests/validate/test_difficulty_gate.py
  - tasks/T-0368-difficulty-window-gate.md
revision: 1
---

## Goal
Add a pure P2 hard gate for normalized exported difficulty scores against reviewed
per-slot curve targets. Never apply default production weights or windows.

## Context
- CONTENT.md#hard-validation: from P2, difficulty is within the target window.
- CONTENT.md#curve: onboarding slots 1–15 are hand-made and outside the curve.
- T-0357 and T-0358 define normalized regional targets and protected slot ownership.

## Current state
- `sequence.slots.SlotPlan.requirement(slot)` yields the exact regional CurveTarget,
  authored flag and released reservation.
- P1 content validation requires difficulty0.0; no P2 difficulty hard gate exists.
- No reviewed production difficulty window/configuration exists.

## Specification
- Add `validate_difficulty_window(levels, plan, *, max_deviation) -> None`.
- Require all planned slots exactly once, matching campaign identities and authored
  source and landmark flags. Accept any deterministic input order.
- Require finite numeric difficulty0..1 on every level, including onboarding; reject
  bool/coercion/nonfinite. A finite explicit window0..1 is mandatory.
- For slots above onboarding, reject absolute deviation from their own regional
  target greater than the window; exact boundary passes.
- No input mutation, writes, hidden configuration, scoring recomputation or activation.

## Out of scope
- Scorer calibration, automatic content generation, evidence/source certification,
  production thresholds, ship/export hooks and the released geometry lock.

## Tests
- Complete fixture campaign, input reordering, and exact boundary pass.
- Out-of-window, invalid scores/windows, missing/duplicated IDs fail.
- Authored/onboarding and landmark flags must match protected plan.
- Changing regional curve target changes validation outcome.

## Acceptance
- Tests, full check, scope and independent review pass.
- Existing P1 behavior, production values and shipped content are unchanged.

## Rollback
Revert pure source/test/task files; no persistency or migration.
