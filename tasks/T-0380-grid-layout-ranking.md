---
id: T-0380
title: Rank fully valid alternative crossword geometries for human review
epic: E22
type: feat
area: pipeline.grid
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0374]
touch:
  - pipeline/src/wordgame_pipeline/grid/ranking.py
  - pipeline/tests/grid/test_ranking.py
  - tasks/T-0380-grid-layout-ranking.md
revision: 1
---

## Goal
Provide stable layout comparison without allowing QA heuristics to bypass the
authoritative grid geometry validator.

## Current state
grid.quality.review_grid_quality validates and scores one immutable geometry.
There is no ranking of explicitly authored alternatives.

## Specification
- Accept named layouts and the same selected words, with an explicit crossing bar.
- Validate every alternative, reject invalid geometry, no partial result.
- Rank satisfying layouts first, then crossings descending, fill descending, ID.
- Return frozen records, never mutate placements or select a production grid.

## Out of scope
Grid search, UI, COMPACT fit, production layout changes.

## Tests
- Same-quality crossing alternatives tied by ID, deterministic input order.
- Threshold changes flag only, malformed options reject.

## Acceptance
Exact-head CI and independent review.
