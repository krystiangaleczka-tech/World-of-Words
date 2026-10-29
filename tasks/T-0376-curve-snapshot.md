---
id: T-0376
title: Expose readonly regional curve and slot ownership snapshot
epic: E22
type: feat
area: pipeline.sequence
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0357, T-0358, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/sequence/snapshot.py
  - pipeline/tests/sequence/test_snapshot.py
  - tasks/T-0376-curve-snapshot.md
revision: 1
---

## Goal
Let content reviewers inspect exact selected regional target points,
onboarding/landmark/breather kinds and protected slot identities without
allocating or changing any level.

## Context
- CONTENT.md#curve specifies a rising regional trend, landmark spikes and breathers.
- T-0357 supplies region-local targets; T-0358 reserves authored/released slots.
- Production curve parameters and source approvals are not committed.

## Current state
SlotPlan.requirement(slot) computes exact region, location, curve target and
authored/released status. There is no standalone immutable plot-ready snapshot.

## Specification
- snapshot_curve(plan, slots) returns a tuple of frozen SlotCurveRow values.
- Require a nonempty tuple of distinct in-range integer slots; sort results.
- Delegate target and ownership calculations to SlotPlan.requirement, including
  onboarding target None and landmark/breather semantics.
- Support a sparse slot subset without materializing a whole huge campaign.
- No implicit curve settings, writes, recomputation of scoring or content changes.

## Out of scope
Sequence assignment, stage activation, calibration and release updates.

## Tests
- Exact onboarding/landmark/breather/regular fixture points and reservation flags.
- Reordered input gives same output; immutable result.
- Duplicate/bool/fractional/out-of-range slots and missing plan rejected.

## Acceptance
Full exact-head CI, scope and independent review.
