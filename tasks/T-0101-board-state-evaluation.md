---
id: T-0101
title: Board state evaluation
epic: E05
type: feat
area: core.board
risk: medium
executor: sol
think: med
ui: none
status: done
depends_on: [T-0100]
touch:
  - game/core/board/board_state.gd
  - game/tests/unit/board/test_board_state.gd*
  - tasks/T-0101-board-state-evaluation.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0101 prototype slice, with deterministic tests and explicit service boundaries.

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
Implement GAME_DESIGN word-classes in BoardState.evaluate. Level matching precedes bonus matching. Tile identity is index-based, duplicate/out-of-range indices INVALID. Less than3 indices returns null with no mutation. A level word reveals only previously unrevealed cells; crossing words with all cells revealed count as found immediately. Bonus words count once independent of tile choices. Unknown/banned terms INVALID without counters. Emit completed exactly once on transition including hints; restored completed state never re-emits. reveal_cell valid new board coordinate returns true, duplicates/non-board false. Completion and persistence snapshots remain canonical and validate against actual revealed cells.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_membership_bonus_and_repeats.
- test_repeated_letters_use_distinct_indices.
- test_intersections_hints_and_completion_once.
- test_snapshot_round_trip.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.
