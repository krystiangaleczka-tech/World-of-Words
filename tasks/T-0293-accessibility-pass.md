---
id: T-0293
title: Audit catalog accessibility metadata and describe the active level
epic: E21
type: feat
area: ui.components
risk: low
executor: sol
think: med
ui: med
status: review
depends_on: [T-0292, T-0246, T-0287]
touch:
  - game/features/level/level.gd
  - game/locale/level.csv*
  - game/tests/integration/test_accessibility_pass.gd*
  - docs/qa/T-0293/**
  - tasks/T-0293-accessibility-pass.md
revision: 1
---

## Goal
Keep all six existing interactive catalog types named and touchable, and expose
a translated summary of the current Level without adding a gameplay interaction.

## Context
- ROADMAP T-0293, FR-A11Y-01/04, NFR-11; DESIGN.md#accessibility.
- PRODUCT.md: mobile reader exposure is conditional on engine support, not full blind gameplay support.
- Decision 0001 records the unsupported mobile reader bridge; no native support claim.

## Current state
- IconButton, NavTab, Toggle, CatalogSlider, HintButton and CurrencyPill already expose translation-key names and token minimum targets, tested by their component tasks.
- LevelScreen._refresh_hud runs after load, committed state changes and translation changes. BoardState provides immutable LevelData, found_words and bonus_words snapshots.
- No level accessibility summary is exposed. Existing level locale resources are owned by LevelCopy.

## Specification
- Add translated Level accessibility name and description: level number, found/total board words, bonus count and available tile letters, using label:number copy, never plural-dependent sentences. Unknown/missing content uses existing error copy; no null access.
- Summary updates at the same HUD boundaries including hints, accepted words, bonus, restored board and locale switch. No Save writes, input interception, extra focus target, new component or per-frame polling.
- Audit all six real catalog types across PL/EN, themes and layout widths. Assert nonempty translated names, required keys, passive/interactive focus policy and Touch.MIN_TARGET. Existing component behavior stays unchanged.
- Native matrix evidence uses actual LevelScreen and catalog metadata; no desktop screenshot can certify TalkBack/VoiceOver or reference-device usability.

## UX rules
R-UI-1/2 catalog only, no new widget. R-UI-3 tokens/theme only. R-UI-4 translation keys, no plural-dependent strings. R-UI-5 generated themes untouched. R-UI-6 native screenshots per DESIGN.md#pr-screenshot-rules.

## Tests
New test_accessibility_pass.gd covers six catalog types, PL/EN keys and minimum touch geometry; Level summary fresh/bonus/hint/accepted/restart/missing-content/locale lifecycle, no writes caused by reads and no new focusable UI. Native layout matrix and QA script reuse actual Level scene.

## Wave refinement
The planned T-0288 dependency is replaced with merged T-0287: all six catalog types and the Level already exist. Unbuilt native privacy/restore rows remain T-0288's responsibility and are not certified by this pass. No roadmap edit or claim that T-0288 is done.
