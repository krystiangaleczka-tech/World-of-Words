---
id: T-0104
title: Wheel contract
epic: E06
type: contract
area: level.wheel
risk: high
executor: sol
think: high
ui: low
status: done
depends_on: [T-0103, T-0041, T-0029]
touch:
  - game/ui/components/LetterWheelView.gd*
  - game/ui/components/LetterTile.gd*
  - game/core/wheel/wheel_geometry.gd*
  - game/tests/unit/wheel/test_wheel_geometry.gd*
  - game/tests/integration/test_wheel_contract.gd*
  - tasks/T-0104-wheel-contract.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0104 prototype slice, with deterministic tests and explicit service boundaries.

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
Freeze LetterWheelView extends Control, signals chain_changed(indices:PackedInt32Array), word_attempted(indices:PackedInt32Array), tile_added(index:int). set_letters(PackedStringArray), set_locked(bool), is_locked()->bool, is_dragging()->bool, current_chain()->PackedInt32Array, tile_position(index:int)->Vector2, shuffle(rng:RandomNumberGenerator)->bool. configure input geometry through resize; 3–8letters. LetterTile extends Control with letter:String,index:int,selected:bool. Pure WheelGeometry.positions(count:int,radius:float,center:Vector2)->PackedVector2Array and hit_test(point,positions,radius)->int returns nearest hit or-1. No .tscn untilT105; actual drag/shuffle behavior subsequent tasks.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_positions_three_to_eight_and_nearest_hit.
- test_wheel_public_contract.

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
