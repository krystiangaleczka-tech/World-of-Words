---
id: T-0116
title: Level scene
epic: E07
type: feat
area: level.flow
risk: medium
executor: sol
think: med
ui: med
status: ready
depends_on: [T-0115, T-0113, T-0114, T-0108, T-0112]
touch:
  - game/features/level/**
  - game/services/nav.gd
  - game/tests/integration/test_level_scene.gd*
  - game/tests/integration/test_nav.gd
  - game/tests/integration/test_debug_navigation.gd
  - game/tests/integration/test_debug_screen.gd
  - game/ui/gallery/level.tscn
  - tasks/T-0116-level-scene.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0116 prototype slice, with deterministic tests and explicit service boundaries.

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
Compose actual Level scene rootedexistingScreenScaffold: catalog BoardView,WordPreview,LetterWheelView andtranslatedLabels only. Component creation remainsincomponenttasks. Nav injects loadedSave/Content andown slot before_ready; level usesisolatedProgressinstance configuredto sameSave/Content, globalEvents onlysideeffects. MountLEVELafter settingvalidslot. Emptyrealcontentbootfail remainsdiagnosableF3; debuggalleryusesfixtureexplicitly, never hand-create game/content. Controller evaluate→persist orcomplete→refreshviews→emit sideeffects; I/O failure surfaced and subsequent explicitactionretriespendingdurability withoutdoublegrant, ignoreshort/drag-cancel. Connect tile_added→Events.tile_touched (HapticsListener); disconnectownedconnections/unbindProgressonexit. Fit wheel&board responsiveportrait; provisionalscreen noHUDactionsuntilT117. Completionlocksinput; ContinuelayerT118outofscope. Update existingmount-nulltests toinjectednullfactory when testingemptyroutes, orassertrealLEVELnode when testingapplication. Preservealltestnames/count, avoidautoloadSaveinjectionsinfixtures. Test resumptionacrossmountedscenes.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_nav_mounts_injected_playable_level.
- test_submit_persists_before_effects_and_completion.
- test_scene_resume_and_cancel.
- test_responsive_scene_layout.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## UX
Reference: DESIGN.md#level-p1-provisional and named catalog components.
"A screen task may not create a component." This wave creates reusable components in their explicit
component scopes before screens compose them. "No raw numbers in scenes or feature scripts" applies
to visual styling: use Tokens. Text uses translation keys. Include actual runtime screenshots where
available; headless geometry assertions do not establish device feel.
