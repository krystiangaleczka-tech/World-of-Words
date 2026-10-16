---
id: T-0276
title: Compose an explicit opt-in P2 Level HUD with unlock gating
epic: E20
type: feat
area: level.flow
risk: medium
executor: cheap
think: med
ui: high
status: review
depends_on: [T-0225, T-0242, T-0233, T-0219]
touch:
  - game/features/level/level.gd
  - game/features/level/p2_hud.gd*
  - game/ui/tokens.gd
  - game/tests/integration/test_level_p2_composition.gd*
  - docs/qa/T-0276-level-p2-composition.md
  - docs/qa/T-0276/*
  - tasks/T-0276-level-p2-composition.md
revision: 1
---

## Goal
Compose final P2 HUD from existing catalog components, explicitly opted in before mount.

## Context
DESIGN.md#level-p2-final and #level-screen-geometry; FR-PROG-04.
Mockup: docs/design/T-0205/evidence/shuffle_REGULAR_PL_default.png.

## Current state
LevelScreen retains P1 behavior by default. HintButton/CurrencyPill/BonusMeter and
ScreenScaffold exist. Save/Config/Economy/Progress own balances, unlocks and progress.
No explicit P2 composition API exists. All metadata dependencies are merged.

## Specification
configure_p2(economy, config) before mount enables a separate presentation helper.
Compose home, level number, coins, settings, BonusMeter and wheel corner actions:
shuffle bottom left, hint bottom right, reveal top right. Use canonical unlocks
and committed Progress/Save data; slot 1 exposes only board, preview, wheel and number.
Emit navigation/shop/powerup intents; no platform calls, debit, free P2 hint, paid
mutation or boot activation. T-0278 owns paid actions; caller owns UI navigation.
Retain P1 configure and behavior unchanged. Update displayed balances after Economy
notifications. No double connection on exit/reentry. Resize in COMPACT/REGULAR/TABLET
and reject button/tile-hit overlap; use token geometry only. Existing BoardView,
preview, wheel and completion layer remain their owners.

## UX rules
R-UI-1/2 existing catalog only; no new component. R-UI-3 tokens/theme; R-UI-4 locale
keys; R-UI-5 generated themes untouched; R-UI-6 screenshots attached. Physical device,
taste/FUN and later paid integration gates remain open.

## Tests
Native layout matrix across three classes, PL/PSEUDO, default/HC130; unlock boundaries,
first level, live balances, intents only/no debit, all corner/tile overlap assertions,
P1 unchanged, lifecycle/reentry. Screenshots and QA notes required.

## Acceptance
make check, scope, fresh review, all CI green; no human approval fabricated.
