---
id: T-0223
title: Finish board theme and shared play-area geometry
epic: E14
type: feat
area: level.board
risk: medium
executor: sol
think: high
ui: low
status: done
depends_on: [T-0222]
touch:
  - game/ui/components/GridCell.gd
  - game/ui/components/BoardView.gd
  - game/features/level/level.gd
  - game/tests/integration/test_board_final_style.gd*
  - docs/qa/T-0223-board-style.md
  - tasks/T-0223-board-style.md
revision: 1
---

## Goal
Apply generated Ceramic palette/heavy glyph font and centralize final layout-class geometry.

## Context
Roadmap T-0223; docs/DESIGN.md#gridcell, #boardview, #level-screen-geometry; FR-BOARD-02.
"The grid scales to fit and never scrolls." "wheel shrinks towards WHEEL_MIN first."

## Current state
Fresh main e1ba01d4 contains technically merged T-0222 with manual gates open. GridCell passive
states/reveal/highlight use cached StyleBoxFlat and raw palette/default font. BoardView has unique
cells, refresh/reveal/cell centres/wave and rect fitting. LevelScreen._layout_play_area already
uses class ratios but repeats geometry and omits wheel top/bottom Space.L padding. Generated
TileLetter uses same800weight as documented CELL_LETTER_RATIO_WEIGHT; no new generated variation.

## Specification
1. GridCell uses generated CELL_*/TEXT/STROKE/PRIMARY palette and heavy TileLetter font scaled
   by CELL_LETTER_RATIO. Cached style radius, hint dot, explicit highlight outline preserve all
   states and passive behavior. Theme changes redraw; no change to motion (T-0224/0225).
2. BoardView adds static play_area_rects(available:Vector2,layout:StringName,preview_height:float,
   actions_height:float=0)->Dictionary[StringName,Rect2] with board/preview/actions/wheel rectangles.
   Invalid/nonfinite/negative extents or unknown class return empty. Centre capped1080column;
   COMPACT ratio0.62 and gapXS, REGULAR/TABLET0.66 and gapS; wheel cap800, preferred minimum450,
   Space.L top/bottom. Reserve GRID_MIN_RATIO, shrink wheel before grid. Impossible tiny geometry
   stays nonnegative and in bounds; it does not pretend to meet cell minimum.
3. Existing per-cell gapXS, max150, min64 fit flag, unique intersections/global targets unchanged.
4. LevelScreen uses this shared geometry, preserves responsive action-row fallback, connects
   preview minimum/class changes so text and caption wrapping relayout. Disconnect on exit.
   No new HUD components or controller changes. Future corner composition remains T-0276.

## UX rules
R-UI-1: "A screen task may not create a component."
R-UI-3: "Use Tokens.*, theme type variations or theme constants."
R-UI-4: "Strings shown to players use translation keys."
R-UI-5: "Never edit game/ui/theme/generated/."
R-UI-6: screenshots per DESIGN.md#pr-screenshot-rules; device/taste gates stay open.

## Tests
New integration tests: generated HC cell colours/heavy font/passivity/states; three-class geometry
ratios/caps/centering/padding/grid share; constrained/zero/invalid input; actual board fitting and
centres unchanged. Populated LevelScreen impossible-host/recovery regression; existing scene responsive assertions retained. Full make check, task/scope,
fresh independent final-head review, native board gallery and13CI before merge.

## Out of scope
Gameplay/save/economy/services, final screen composition, motion A/B, physical-device certification.
