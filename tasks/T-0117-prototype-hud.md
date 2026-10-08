---
id: T-0117
title: Prototype hud
epic: E07
type: feat
area: level.hud
risk: medium
executor: sol
think: med
ui: med
status: done
depends_on: [T-0116, T-0102]
touch:
  - game/features/level/level.gd
  - game/locale/level.csv*
  - game/tests/integration/test_level_hud.gd*
  - tasks/T-0117-prototype-hud.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0117 prototype slice, with deterministic tests and explicit service boundaries.

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
Use the existing catalog HintButton from T-0058, with a free translated label and no economy cost. HUD usesexistingLabel/IconButton: levelnumber, bonuscount, shuffle andunlimitedfreehint, debugbutton onlydebug. All composed components already exist. InjectseededRNG via screenconfigure_rng; defaultperlevelstablehashseed noTime/randi. Disablehint/shufflewhencompleted/dragging/shuffling; handlersguardtoo. HintusesHintLogic, persistsreveals/crossingcompletion; bonuslabelupdatesonce. Onsavefailure statuslabeltranslated withretryonaction; noautomaticrewrite, userSaveisolatedtest. LocaleupdatesPL/EN. Galleryshowsbuttonstates. CompletedleveldisabledHUD; nextlevelcompletionlayerremainsT118.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_hud_labels_bonus_and_free_hint_completion.
- test_shuffle_and_hint_guard_during_drag.
- test_hud_locale_and_persistence_failure.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
