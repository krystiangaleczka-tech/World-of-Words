---
id: T-0372
title: Rank campaign slots outside explicit difficulty-curve review windows
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
  - pipeline/src/wordgame_pipeline/sequence/deviation_review.py
  - pipeline/tests/sequence/test_deviation_review.py
  - tasks/T-0372-curve-deviation-review.md
revision: 1
---

## Goal
Prepare a deterministic, read-only sequence-difficulty exception list for
human review before changing any level allocation (ROADMAP T-0303).

## Context
- CONTENT.md#curve defines explicit region-local trends, landmark spikes and
  breathers, while onboarding slots 1–15 have no generated targets.
- T-0357/T-0358 provide immutable regional curve targets and slot ownership.
- No production curve calibration or accepted difficulty window exists.

## Current state
- `SlotPlan.requirement(slot)` returns curve and region/location identities.
- Allocation preview reports deviations but no isolated ranked QA diagnostics.
- P1 shipped difficulty is 0, not a calibrated production score.

## Specification
- Add pure `review_curve_deviations(plan, scores, *, max_deviation)`.
- Require exactly one normalized finite score for each planned campaign slot,
  validated before returning any diagnostics. Limit to exported campaign size.
- Skip onboarding as it has no target; otherwise flag only deviations strictly
  larger than explicitly supplied window, ordered by descending deviation and
  ascending slot, with region/location, target and actual score.
- Do not allocate, rewrite, classify, adjust weights or endorse a threshold.

## Out of scope
- Stage activation, level export, score provenance, released lock mutation,
  production calibration or human approval.

## Tests
- Exact landmark/breather/regular deviations, boundary equality and sorting.
- Onboarding skipped yet validated, deterministic reordering and nonmutation.
- Missing/extra/malformed score keys and nonfinite inputs rejected.

## Acceptance
Full check, scope and independent review; P1 content and game unchanged.
