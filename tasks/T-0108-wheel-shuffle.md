---
id: T-0108
title: Wheel shuffle
epic: E06
type: feat
area: level.wheel
risk: medium
executor: sol
think: med
ui: med
status: ready
depends_on: [T-0107, T-0049]
touch:
  - game/ui/components/LetterWheelView.gd
  - game/ui/components/IconButton.gd*
  - game/ui/components/IconButton.tscn
  - game/ui/components/HintButton.gd*
  - game/ui/components/HintButton.tscn
  - game/ui/gallery/controls.gd*
  - game/ui/gallery/controls.tscn
  - game/ui/gallery/wheel.gd
  - game/tests/integration/test_wheel_shuffle.gd*
  - tasks/T-0108-wheel-shuffle.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0108 prototype slice, with deterministic tests and explicit service boundaries.

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
shuffle uses existing Shuffle.permute with injected RNG and stable tile IDs. Reject while dragging/externally locked/shuffling, null RNG or nonchangeable visible sequence. Tween all tile positions to shuffled slots over Tokens.Motion.BASE; lock until finished, ensure external lock remains and queued callbacks cannot unlock newer states. Reduced-motion immediate placement; destroy/resize/set_letters safely terminates tween and relayout. Public tile_order()->PackedInt32Array. Add provisional catalog IconButton with exported text_key and native pressed; translated accessible name, minimum touch target, token styling. Create catalog HintButton as a translated free-hint variant of IconButton, with a controls gallery, before T-0117 screen composition. Gallery shuffle uses injected seeded RNG; screen composition later.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_shuffle_preserves_identity_and_changes_layout.
- test_reject_during_drag_lock_and_uniform.
- test_reduced_motion_and_reconfigure_unlock.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
