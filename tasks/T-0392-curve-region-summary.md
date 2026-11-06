---
id: T-0392
title: Summarize generated difficulty coverage per region
epic: E22
type: feat
area: pipeline.sequence
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0366]
touch:
  - pipeline/src/wordgame_pipeline/sequence/region_review.py
  - pipeline/tests/sequence/test_region_review.py
  - tasks/T-0392-curve-region-summary.md
revision: 1
---

## Goal
Expose region-local target score ranges, without changing any protected slots.

## Current state
SlotPlan provides precise curve targets and authored/released reservations.
No read-only regional descriptive summary is integrated.

## Specification
- Provide pure review_region_targets(plan) over an existing validated SlotPlan.
- Count onboarding target-less slots separately from generated curve slots.
- Report explicit regional min, max and mean generated targets, or None when
  a region only has onboarding slots. Preserve input region order.
- Do not infer calibrated scores, allocate or mutate release data.

## Out of scope
Production level assignment, calibration and publication.

## Tests
Exact landmark/breather target bounds and mean, onboarding-only region,
invalid plan, deterministic and frozen results.

## Acceptance
Full CI green, scope and independent review.
