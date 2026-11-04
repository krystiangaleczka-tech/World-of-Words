---
id: T-0383
title: Explain exact per-feature difficulty score contribution shifts
epic: E22
type: feat
area: pipeline.scoring
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0377]
touch:
  - pipeline/src/wordgame_pipeline/scoring/feature_shifts.py
  - pipeline/tests/scoring/test_feature_shifts.py
  - tasks/T-0383-scoring-feature-shifts.md
revision: 1
---

## Goal
Expose reasons for proposed scoring calibration changes without applying them.

## Current state
scoring.score_features returns a complete normalized weighted FeatureScore list
for every supplied ScoringConfig, but does not compare explanations.

## Specification
- Score the same raw evidence independently under both explicit configs.
- Report signed contribution delta for each feature above caller supplied cutoff.
- Sort by magnitude descending, feature name ascending; return frozen records.
- Require finite cutoff in [0,1] and exact valid scoring inputs.

## Out of scope
Production scoring defaults, source data, reslotting and export.

## Tests
- Exact -1 and +0.5 feature effects, strict threshold boundary.
- No changes with same config, frozen values and invalid evidence.

## Acceptance
Full exact-head CI and independent review.
