---
id: T-0115
title: Level controller contract
epic: E07
type: contract
area: level.flow
risk: high
executor: sol
think: high
ui: low
status: ready
depends_on: [T-0101, T-0104, T-0111, T-0109]
touch:
  - game/features/level/level_controller.gd*
  - game/tests/integration/test_level_controller_contract.gd*
  - tasks/T-0115-level-controller-contract.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0115 prototype slice, with deterministic tests and explicit service boundaries.

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
Typed LevelController extends Node with configure(board:BoardState,progress:PROGRESS_SCRIPT,event_bus:Node), get_board()->BoardState, submit(tiles:PackedInt32Array)->AttemptResult, hint()->bool, is_complete()->bool. Signals result_ready(result),state_changed,completed, persistence_failed(error). Freeze lifecycle and injectable sideeffectbus; no platformcalls fromfeature. Pure ignoredattempts produce noresult/event. Matching, persistence-before-effects and completion orchestration implementedT116. No scene/components inventedhere.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_configure_board_and_ignored_attempt_contract.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.

## Rollback
Revert the isolated squash commit before dependent tasks merge; after dependent integration revert
in reverse order. Save v2 migration is a forward format change: keep v1 backup before any downgrade.
