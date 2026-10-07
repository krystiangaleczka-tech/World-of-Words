---
id: T-0107
title: Word preview results
epic: E06
type: feat
area: level.wheel
risk: medium
executor: sol
think: med
ui: med
status: ready
depends_on: [T-0106, T-0101]
touch:
  - game/ui/components/WordPreview.gd
  - game/locale/level.csv*
  - game/ui/level_copy.gd*
  - game/ui/gallery/wheel.gd
  - game/tests/integration/test_word_feedback.gd*
  - tasks/T-0107-word-preview-results.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0107 prototype slice, with deterministic tests and explicit service boundaries.

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
Implement LEVEL/BONUS/ALREADY_FOUND/INVALID result states, color plus readable symbol/translated label. Empty attempt has no feedback. Replace prior tween before starting pop/shake/fade, reset visual transform when interrupted, reduced-motion gives static symbol. Local PL/EN translation resources from imported CSV via preload (exportable, no project.godot mutation), ownership balanced on exit; component labels refresh on locale change. Keys cover prototype level number, bonus counter, hint, shuffle, unavailable content and debug. Expose feedback_kind()->int (-1 empty/building). Gallery demonstrates states.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_result_cues_and_translations.
- test_interrupted_and_reduced_motion_feedback.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
