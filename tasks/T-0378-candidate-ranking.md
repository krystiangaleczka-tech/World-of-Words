---
id: T-0378
title: Rank eligible candidate wheels for manual content review
epic: E22
type: feat
area: pipeline.candidates
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0373]
touch:
  - pipeline/src/wordgame_pipeline/candidates/ranking.py
  - pipeline/tests/candidates/test_ranking.py
  - tasks/T-0378-candidate-ranking.md
revision: 1
---

## Goal
Rank eligible candidate wheels for manual content review. Provide offline, deterministic P2 content-review evidence without activating production stages.

## Current state
The existing authoritative pipeline stage is implemented on main; its pure validator or index is reused. No separate review report for this specific dimension exists.

## Specification
- Add only the new immutable/read-only analytical helper from this change.
- Require explicit review inputs and propagate validation errors from authoritative stage contracts.
- Produce stable order-independent results, with no file writes, no AI calls and no runtime/P1 changes.

## Out of scope
Production content, calibration thresholds, release gates, publishing and manual approval.

## Tests
- Exact fixture results and sorting, source order independence, invalid inputs and nonmutation.

## Acceptance
- Tests, scope/format/lint, full exact-head CI and independent review before merge.
