---
id: T-0380
title: Rank candidate identities affected by duplicate conflicts
epic: E22
type: feat
area: pipeline.dedupe
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0375]
touch:
  - pipeline/src/wordgame_pipeline/dedupe/impact.py
  - pipeline/tests/dedupe/test_impact.py
  - tasks/T-0380-conflict-impact.md
revision: 1
---

## Goal
Rank candidate identities affected by duplicate conflicts. Provide offline, deterministic P2 content-review evidence without activating production stages.

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
