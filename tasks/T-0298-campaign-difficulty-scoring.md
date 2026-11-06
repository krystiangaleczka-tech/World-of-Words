---
id: T-0298
title: Wire deterministic explicit difficulty features into P2 campaign slot scores
epic: E22
type: feat
area: pipeline.scoring
risk: medium
executor: sol
think: high
ui: none
status: blocked
depends_on: [T-0297]
touch:
  - pipeline/src/wordgame_pipeline/scoring/campaign.py
  - pipeline/tests/scoring/test_campaign.py
  - tasks/T-0298-campaign-difficulty-scoring.md
revision: 1
---

## Goal
Combine existing T-0354 raw features and T-0355 immutable weighted scorer into
a read-only, sorted campaign score pass for **explicit** `ScoringConfig`.
Reject missing exact-form source frequency, malformed geometry and slot gaps.

## Scope and tests
- Read-only helper; returns each slot, its normalized score, exact configuration
  hash and ordered per-feature contributions.
- Reuses already authoritative geometry, frequency and numeric validation.
- Tests cover deterministic reordering, no mutation, source gaps, invalid values,
  duplicate/noncontiguous slots and invalid geometry.
- Does not assume production scoring weights, so no `scoring.yaml` is invented.

## Blockers
T-0297 and T-0296 are not merged; production weights, difficulty calibration and
T-0304 editorial review are still unapproved. Source tier validation must precede
scoring. Keep this PR draft until dependencies, full CI and independent review.
No released content or P1 stage code is changed.
