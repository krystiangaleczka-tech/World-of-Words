---
id: T-0369
title: Verify COMPACT crossword fit from canonical Godot tokens
epic: E22
type: contract
area: pipeline.validate
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0206, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/validate/compact.py
  - pipeline/tests/validate/test_compact_gate.py
  - tasks/T-0369-compact-grid-gate.md
revision: 1
---

## Goal
Provide an offline P2 COMPACT grid fit hard gate without copying authoritative
CELL_MIN, CELL_MAX, GRID_MIN_RATIO or Space.XS constants into pipeline code.

## Context
- CONTENT.md#hard-validation: a crossword must fit CELL_MIN in COMPACT.
- DESIGN.md#level-screen-geometry: cell=min(area_w/cols,area_h/rows) minus Space.XS,
  clamped to CELL_MIN/CELL_MAX; grid retains its minimum body-height share.
- game/ui/tokens.gd owns the canonical Layout and Space constants.

## Current state
- The Godot token constants exist in game/ui/tokens.gd.
- The pipeline already validates a connected max10×10 declared crossword grid.
- There is no offline COMPACT cell-side check in the pipeline.

## Specification
- Parse exact four required constants from the canonical Godot class sections.
  Reject missing, duplicate, mistyped or invalid token values; no silent defaults.
- Add `validate_compact_grid(grid, *, area_width, area_height, body_height, tokens)`.
  Rectangle values must come from a measured COMPACT reference layout; never
  derive a fake available grid rectangle from the viewport alone.
- Reject invalid 1..10 grid dimensions, bool/nonfinite/negative rectangles, an
  area smaller than GRID_MIN_RATIO×body height, and cell side below CELL_MIN.
  Return the clamped computed side on success; never mutate files or levels.
- No stage activation, new tokens, dependencies, design changes or content edits.

## Out of scope
- Screenshot automation, game runtime resizing, safe-area measurement, unapproved
  screen rectangle assumptions, new production grid values, released geometry.

## Tests
- Real tokens.gd parses; fixture COMPACT rectangles pass or fail deterministically.
- Changed canonical CELL_MIN changes the result; missing, duplicate, wrong-type
  tokens fail.
- Invalid dimensions, nonfinite sizes and too-small grid share fail.
- No shipped content, Godot UI or configuration is edited.

## Acceptance
- Tests, full check, scope and independent review pass.
- The adapter is opt-in until reviewed COMPACT reference rectangle evidence exists.

## Rollback
Revert the pure helper, tests and task; no persisted state is involved.
