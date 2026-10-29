---
id: T-0374
title: Review grid crossing density and shape without changing layouts
epic: E22
type: feat
area: pipeline.grid
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0127, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/grid/quality.py
  - pipeline/tests/grid/test_quality.py
  - tasks/T-0374-grid-quality.md
revision: 1
---

## Goal
Provide an offline crossword geometry review record for human QA
before P2 content publication.

## Context
- CONTENT.md#hard-validation: connected, intentional, portrait <=10x10 grids.
- T-0354 scoring features are descriptive, not content approval.
- No default production minimum crossing requirement is approved.

## Current state
grid.geometry.validate_geometry validates canonical placement connectivity,
bounds and accidental runs. No standalone review record of grid fill/crossings.

## Specification
- review_grid_quality(layout, selected, *, minimum_crossings) uses the authoritative
  geometry validator; no geometry bypass.
- Return frozen dimensions, selected count, occupied cells, crossing count,
  occupied/area fraction and the explicitly reviewed minimum-crossing result.
- Reordering valid placements must not change measurements. No mutations/writes.
- Minimum crossing threshold >=0; no production default.

## Out of scope
Grid search, layout changes, cell sizing, exported content and production gates.

## Tests
- Hand-calculated crossed grid 3x3 with five cells and one crossing.
- One-word zero crossings, threshold, input order and immutable result.
- Malformed/disconnected/accidental layouts are rejected.

## Acceptance
Full exact-head CI, scope and independent review.
