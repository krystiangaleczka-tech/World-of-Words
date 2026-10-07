---
id: T-0102
title: Hint next cell
epic: E05
type: feat
area: core.board
risk: medium
executor: sol
think: med
ui: none
status: ready
depends_on: [T-0101]
touch:
  - game/core/board/hint_logic.gd*
  - game/tests/unit/board/test_hint_logic.gd*
  - tasks/T-0102-hint-next-cell.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0102 prototype slice, with deterministic tests and explicit service boundaries.

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
Pure HintLogic.next_cell(board:BoardState)->Vector2i returns first unrevealed cell of shortest unfound level word; ties use original level word order. Sentinel Vector2i(-1,-1) for null or complete. Does not mutate board. Revealing returned cells must finish all crossing words and terminate.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_shortest_and_data_order_tie.
- test_skip_revealed_and_complete.
- test_repeated_hints_terminate.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.
