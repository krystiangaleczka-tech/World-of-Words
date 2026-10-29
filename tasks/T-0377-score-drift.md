---
id: T-0377
title: Compare deterministic candidate difficulty before and after scoring revisions
epic: E22
type: feat
area: pipeline.scoring
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0354, T-0355, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/scoring/drift.py
  - pipeline/tests/scoring/test_drift.py
  - tasks/T-0377-score-drift.md
revision: 1
---

## Goal
Expose score changes for the same candidates under two explicit configurations,
for safe human P2 difficulty-calibration review.

## Context
- CONTENT.md#curve: difficulty derives from explicit feature weights.
- T-0355 defines strict complete bounded scoring configurations and explanations.
- No production weights, calibration threshold or content release is approved.

## Current state
scoring.score_features computes bounded deterministic totals from exact
feature mappings. No side-by-side candidate score-change report exists.

## Specification
- review_score_drift(candidates, previous, proposed, *, minimum_delta) accepts
  complete raw features and both previously validated ScoringConfig objects.
- Independently recompute both scores; return frozen candidate ID, previous,
  proposed and signed delta if |delta| strictly exceeds explicit cutoff.
- Sort by descending absolute delta then candidate ID. Always validate every
  source record even when no result is flagged. Cutoff finite [0,1].
- No mutations, config defaults, writes, production edits or level reordering.

## Out of scope
Recalibration, persistence, score assignment, source/seed review and release.

## Tests
- Exact signed positive/negative shifts and strict equality boundary.
- Stable output regardless of candidate insertion order, no mutation, no drift.
- Malformed identities, raw features, configs and thresholds rejected.

## Acceptance
Exact-head CI, scope and independent review. No changes to shipped levels.
