---
id: T-0391
title: Report observed raw difficulty-feature ranges
epic: E22
type: feat
area: pipeline.scoring
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0366]
touch:
  - pipeline/src/wordgame_pipeline/scoring/ranges.py
  - pipeline/tests/scoring/test_ranges.py
  - tasks/T-0391-feature-ranges.md
revision: 1
---

## Goal
Provide deterministic, source-validated raw feature ranges for P2 score review.

## Current state
The scoring model provides normalized explanations per candidate but no
cross-candidate descriptive raw-feature range report.

## Specification
- Pure review_feature_ranges(candidates, config).
- Require nonempty explicit candidate mapping with valid, control-free identities.
- Use score_features for exact feature/schema validation; calculate min, max and
  mean per canonical feature name with stable sorted candidate ordering.
- Return frozen rows and never infer production weights or calibration.

## Out of scope
Release gates, score defaults, P1 runtime and content edits.

## Tests
Exact two-candidate counts, order invariance, immutable output, invalid source/config.

## Acceptance
Exact-head CI, bounded scope and independent review.
