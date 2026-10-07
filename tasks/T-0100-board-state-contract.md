---
id: T-0100
title: Board state contract
epic: E05
type: contract
area: core.board
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0041]
touch:
  - game/core/board/board_state.gd*
  - game/core/board/attempt_result.gd*
  - game/tests/unit/board/test_board_state_contract.gd*
  - tasks/T-01*.md
  - tasks/T-0058-prototype-buttons.md
  - tasks/epics/E0[567]-*.md
  - docs/qa/P1-authorized-wave.md
  - tasks/T-0100-board-state-contract.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0100 prototype slice, with deterministic tests and explicit service boundaries.

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
Freeze AttemptResult.Kind {LEVEL,BONUS,ALREADY_FOUND,INVALID}, fields kind, word, cells_to_reveal:Array[Vector2i]. BoardState extends RefCounted, constructed with LevelData; getters get_level(), revealed_cells(), found_words(), bonus_words() return snapshots. evaluate(PackedInt32Array)->AttemptResult returns null for fewer than3 tiles; substantive matching is T-0101. reveal_cell(Vector2i)->bool, is_complete()->bool, to_dict()->Dictionary, static from_dict(level:LevelData,data:Dictionary)->BoardState. JSON snapshot keys level_id, found_words, bonus_words, revealed_cells (integer [x,y] arrays). Reject foreign level IDs, duplicate/non-board cells, unknown words, and found/revealed inconsistency. Invalid data returns null, never mutates input. Pure core: no Node/I/O/clock/randomness. Freeze the remaining17 task specs and E05–E07 now; these documents do not claim a Phase0 exit.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_fresh_contract_and_copies.
- test_ignored_and_invalid_attempts.
- test_json_round_trip_and_reject_corruption.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## Rollback
Revert the isolated squash commit before dependent tasks merge; after dependent integration revert
in reverse order. Save v2 migration is a forward format change: keep v1 backup before any downgrade.
