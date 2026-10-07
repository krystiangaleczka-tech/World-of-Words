---
id: T-0105
title: Wheel input
epic: E06
type: feat
area: level.wheel
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0104]
touch:
  - game/ui/components/LetterWheelView.gd
  - game/ui/components/LetterWheelView.tscn
  - game/ui/components/LetterTile.gd
  - game/ui/components/LetterTile.tscn
  - game/ui/gallery/wheel.gd*
  - game/ui/gallery/wheel.tscn
  - game/tests/integration/test_wheel_input.gd*
  - tasks/T-0105-wheel-input.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0105 prototype slice, with deterministic tests and explicit service boundaries.

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
Implement single-pointer wheel input via _gui_input for InputEventScreenTouch/Drag and desktop mouse. Hit radius uses Tokens.Touch.TILE_HIT_RATIO, drag slop uses Tokens.Touch.DRAG_SLOP. Down outside inert, owner finger only, previous tile backtracks, earlier tile ignored, canceled/background/lock clears without submission. Stable original tile indices. Preallocate chain and geometry buffers; no resize/allocation on motion hot path. Only emit copied active prefix when chain changes/submits, not each motion. Public pointer_begin(id:int,position:Vector2), pointer_move(id,position), pointer_end(id,canceled:bool=false) seams exercise same state machine as GUI events. Catalog wheel/tile scenes and gallery include3/8 letters.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_owner_backtrack_and_release.
- test_outside_short_cancel_lock.
- test_gui_touch_and_mouse_paths.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
