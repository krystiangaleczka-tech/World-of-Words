---
id: T-0109
title: Android haptics
epic: E06
type: feat
area: platform.haptics
risk: medium
executor: sol
think: med
ui: low
status: review
depends_on: [T-0046, T-0104]
touch:
  - game/platform/haptics/haptics_android.gd*
  - game/platform/platform.gd
  - game/services/haptics_listener.gd*
  - game/services/events.gd
  - game/services/nav/boot.gd
  - game/tests/integration/test_haptics_listener.gd*
  - game/tests/unit/platform/test_android_haptics.gd*
  - tasks/T-0109-android-haptics.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0109 prototype slice, with deterministic tests and explicit service boundaries.

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
Add Events.tile_touched(index:int), word_found(word:String), bonus_found(word:String), already_found(word:String), invalid_word(word:String), level_completed(slot:int), hint_used; effects only. Existing analytics registry names unchanged: these signals do not invoke analytics. A service HapticsListener child of boot listens/disconnects Events and reads Save setting on every effect, then calls Platform.haptics. tick per append only, no backtrack. Android adapter uses built-in Input.vibrate_handheld via injected callable for deterministic tests, named bounded duration/strength patterns. Select Android only on actual device, preserving --fakes/editor/headless/iOS and force_fake. No new autoload, plugin, permissions/export edits. Physical Android feel/VIBRATE export validation belongs device/export tasks and is not claimed by headless tests.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_events_preference_and_disconnect.
- test_android_patterns_and_unknown.
- test_adapter_selection_preserves_fakes.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
