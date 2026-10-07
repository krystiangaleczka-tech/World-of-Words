---
id: T-0106
title: Wheel line preview
epic: E06
type: feat
area: level.wheel
risk: medium
executor: sol
think: med
ui: med
status: ready
depends_on: [T-0105]
touch:
  - game/ui/components/LetterWheelView.gd
  - game/ui/components/WordPreview.gd*
  - game/ui/components/WordPreview.tscn
  - game/ui/gallery/wheel.gd
  - game/tests/integration/test_wheel_preview.gd*
  - tasks/T-0106-wheel-line-preview.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0106 prototype slice, with deterministic tests and explicit service boundaries.

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
Draw selected tile state and connector ending at current pointer from a preallocated buffer, redraw only on events. No _process allocations. Expose line_point_count()->int,line_point(index:int)->Vector2 for geometry checks. WordPreview extends Label with set_building(text:String), clear(), show_result(result:AttemptResult); result detailsT107. Use token typography/palette. Gallery wires chain to preview. Pointer-only movement updates endpoint without duplicate chain signals.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_line_tracks_pointer_and_backtrack.
- test_preview_building_and_clear.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
