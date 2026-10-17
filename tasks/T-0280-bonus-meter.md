---
id: T-0280
title: Present durable Level bonus progress and completion-only chest rewards
epic: E20
type: feat
area: level.hud
risk: medium
executor: sol
think: med
ui: med
status: review
depends_on: [T-0279, T-0231, T-0338]
touch:
  - game/features/level/level.gd
  - game/features/level/p2_hud.gd
  - game/features/level/bonus_ui.gd*
  - game/locale/level.csv*
  - game/tests/integration/test_level_bonus_flow.gd*
  - docs/qa/T-0280/**
  - tasks/T-0280-bonus-meter.md
revision: 1
---

## Goal
Show durable bonus progress, direct bonus feedback to the actual BonusMeter and
present its already committed chest reward only on the Level complete layer.

## Context
FR-BONUS-02/03; GAME_DESIGN.md#bonus-chest: "the chest opens on the next Level
complete layer, never mid-level" and "Surplus words carry over."
Reference DESIGN.md#level-p2-final, #level-complete, #feedback-matrix and #bonusmeter.

## Current state
T-0276 composes the real BonusMeter from Economy.snapshot, but every refresh calls
configure and no bonus settlement is active. T-0278 supplies exact paid owner
bindings; T-0279 supplies contextual help. T-0338 adds explicitly enabled atomic
bonus checkpoints, completion-only redemption and a live issued-approval-derived
Economy.bonus_chest_redeemed(chests, coins) presentation notification.
RewardBurst supports the chest variant and only non-Container overlay parents.

## Specification
- LevelScreen.configure_bonus_meter() -> Error is an explicit before-mount opt-in
  after configure_paid_tools, requiring current certified owners. Enable the same
  Progress owner's T-0338 bonus checkpoints; default P1/P2 remains unchanged.
- Mount a LevelBonusUI feature helper. Show the existing persisted BonusMeter;
  refresh target only when changed and animate changed counts with set_count,
  preserving animation on redundant HUD notifications. Measure the full-state
  catalog captions with active theme fonts (including completion glyph/spacing)
  so PSEUDO/HC130 does not force a narrow, tall meter column. Never grant from UI.
- Keep the meter noninteractive, including full state, during gameplay. A translated
  Caption above the play area explains that chests open on completion. Ordinary
  BONUS feedback flies to the visible actual meter; repeated bonus uses its existing
  already-found pulse. Before unlock retain ordinary word feedback without credit.
- Listen to the certified Economy owner's live chest notification, under Save's
  receipt publication barrier and the current screen slot's durable completion.
  Store presentation metadata only. When the actual completion layer is visible,
  show a catalog RewardBurst(chest, number_of_chests), a translated count/reward
  summary and the already committed HUD coin count-up. Zero reward still displays
  the chest count. Do not replay presentation on retained exit/reentry.
- On this opted-in completion layer, hide the finished play area and center the
  existing completion column, including the no-chest case. This prevents disabled
  wheel-corner controls from overlapping as reward content occupies vertical space;
  default P1/P2 remains unchanged.
- The burst lives inside an existing Control overlay in the completion VBox, never
  directly under a Container. Use settled container width for its origin. Cancel
  work and disconnect signals on exit; reconnect once on retained reentry. Label
  layout uses containers, existing theme and Tokens; no wheel/tile overlap.
- Save failures publish no counter/reward/burst; existing explicit retry/next action
  resolves the same registered request. Paid final completion uses the same flow.
  Full completion composition, x2 and Continue ordering remain T-0281.

## UX rules
R-UI-1: "A screen task may not create a component." Compose existing BonusMeter,
RewardBurst, Caption/Numeric text and Control overlay only. R-UI-3: "Use Tokens.*,
theme type variations or theme constants." R-UI-4: translated copy only. R-UI-5:
generated themes unchanged. R-UI-6: attach native screenshots per DESIGN.md#pr-screenshot-rules,
COMPACT/REGULAR/TABLET, PL/PSEUDO and default/HC130. Device feel remains a later gate.

## Tests
Real screen/services/storage: bonus increments once and survives screen/save restart;
threshold/full meter never pays mid-level or accepts a native open; already-found
and bonus flight use actual meter; ordinary and paid final completion, multiple
chests/surplus/zero reward; failed checkpoint/completion and retry without duplicate
money or presentation; forged non-publication signal ignored; live count animation
survives redundant HUD refresh; retained lifecycle cleanup; native geometry/copy
matrix and existing P1 behavior. Existing tests unchanged.

## Acceptance
Full pinned make check, scope, fresh independent review and all15 CI including both
Android jobs PASS before merge. No Boot activation, SDK or analytics schema change.
