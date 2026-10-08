---
id: T-0113
title: Board view
epic: E07
type: feat
area: level.board
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0041, T-0103, T-0101]
touch:
  - game/ui/components/BoardView.gd*
  - game/ui/components/BoardView.tscn
  - game/ui/components/GridCell.gd*
  - game/ui/components/GridCell.tscn
  - game/ui/gallery/board.gd*
  - game/ui/gallery/board.tscn
  - game/tests/integration/test_board_view.gd*
  - tasks/T-0113-board-view.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0113 prototype slice, with deterministic tests and explicit service boundaries.

## Context
- docs/GAME_DESIGN.md#word-classes and #hints: ignored short attempts; identity is tile index.
- docs/ARCHITECTURE.md#level-flow and #save: gameplay calls services directly; Events carry effects only.
- docs/DESIGN.md#level-p1-provisional and #tokens: P1 uses provisional token-driven visuals.
- docs/qa/P1-authorized-wave.md records Chris's explicit instruction to execute T-0100–T-0117 now.

## Current state
Read the corresponding dependency commits before execution. LevelData, Save v1, Nav debug routing,
ScreenScaffold/TextButton and the diagnostic token subset already exist. Other listed APIs are created
by this wave in dependency order. Verify actual signatures before editing.

## Specification
Catalog GridCell has letter:String and state enum EMPTY,HINTED,FILLED,HIGHLIGHTED; hinted dot marker, token colors/type. BoardView.set_board(board:BoardState),refresh(),cell_global_position(cell:Vector2i)->Vector2,reveal_word(cells:Array[Vector2i]),reveal_cell(cell,hinted:bool),play_wave(); feedback motionT114. Fit grid bounds to availableControl rect withoutscrolling, CELL_MIN/MAX andSpaceXS; ifviewporttoo small stillcontainallcells and expose fits_minimum()->bool forcontentchecks. One nodeperoccupiedcoordinate (intersectionsunique). Public cell_node(cell)->GridCell forstatechecks. Gallery demos irregular/crossing boards; all geometry derivesfromlevel.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_shared_cells_and_visual_states.
- test_fit_and_resize_bounds.
- test_global_cell_position.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
