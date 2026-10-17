---
id: T-0279
title: Offer contextual Hint help once per active level
epic: E20
type: feat
area: level.hud
risk: low
executor: sol
think: med
ui: med
status: review
depends_on: [T-0278]
touch:
  - game/features/level/level.gd
  - game/features/level/stuck_offer.gd*
  - game/locale/level.csv*
  - game/tests/integration/test_stuck_offer.gd*
  - docs/qa/T-0279/**
  - tasks/T-0279-stuck-offer.md
revision: 1
---

## Goal
Help a stuck player notice the existing paid Hint action without interrupting play.

## Context
FR-HINT-07; GAME_DESIGN.md#hints: "Ignored attempts (under 3 tiles) do not count toward the streak; any LEVEL, BONUS or ALREADY_FOUND resets it."
DESIGN.md#flow-stuck-player: "At most once per level" and "No popup, no sheet opens by itself."
Reference: DESIGN.md#level-p2-final.

## Current state
LevelScreen explicitly opts into P2 and durable paid tools before mount. Controller
state_changed publishes durable board changes, including paid reveals;
result_ready publishes only committed LEVEL/BONUS results and immediate INVALID /
ALREADY_FOUND. HintButton already has a highlighted state with at most three stock
pulses and static reduced-motion presentation. Clock.monotonic_msec is injectable.
Canonical hint.offer_idle_seconds and hint.offer_invalid_streak keys exist.
No stuck-offer feature exists; T-0278 is merged in main (#205).

## Specification
- Compose a LevelStuckOffer feature helper only for explicitly configured paid P2.
  A before-mount configure_offer_clock(clock) injection supports deterministic tests;
  production uses Clock. Keep P1 and presentation-only P2 unchanged.
- Trigger after configured monotonic idle time without a new LEVEL/BONUS word, or
  configured consecutive INVALID results. Short ignored releases neither increment
  nor reset the streak. LEVEL, BONUS and ALREADY_FOUND reset the invalid streak;
  only newly found words reset idle, including a word completed by a paid reveal. Read thresholds from Config, no balance changes.
- Show only for an unlocked visible actionable Hint, exact current paid bindings,
  live current board and active screen. No offers during modal/reward, pending write,
  paid feedback, drag/shuffle, completion, paused tree or suspended application.
  A blocked due offer remains eligible for the next safe refresh, not consumed.
- Use existing HintButton.highlighted (stock bounded pulses) and a Caption Label
  immediately below the play area, aligned with Hint. Body layout reserves caption
  height even while hidden; showing/dismissing must not shift the wheel; do not overlap tile hit circles or block input. Keep copy for TOAST_HOLD,
  including reduced motion. Hide on action/progress, unavailability, exit or timeout;
  never reset the shown latch during retained reentry. A new screen/process is a new
  level visit; no persisted offer flag or save format change.
- One-shot idle and hold Timers only; no frame polling. Stop timers and disconnect
  controller signals on exit; reentry reconnects once and starts a fresh idle window,
  excluding background time. Honor application pause/resume similarly.
- Expose local LevelScreen.stuck_offer_shown(trigger) with idle / invalid_streak for
  the future T-0328 analytics listener. No direct Analytics calls or registry change.

## UX rules
R-UI-1: "A screen task may not create a component." Compose existing HintButton and
Caption text only. R-UI-3: "Use Tokens.*, theme type variations or theme constants."
R-UI-4: "Strings shown to players use translation keys." R-UI-5: generated themes
unchanged. R-UI-6: native screenshots per DESIGN.md#pr-screenshot-rules, including
COMPACT/REGULAR/TABLET, PL/PSEUDO, default/HC130 and reduced motion.

## Tests
Actual paid screen / owners, fake Clock and real public controller input: idle
boundary and threshold config, invalid/reset/ignored attempts, new word resets idle,
once-only trigger and timeout, completion/unlock/binding/modal/pending suppression,
retained exit/reentry, no mutation or auto Sheet, motion cleanup, native geometry /
copy matrix and existing paid Hint action remains functional.

## Acceptance
Full make check, declared scope, independent fresh review, all CI green before merge.
Native evidence and runtime limitations recorded in docs/qa/T-0279. No Boot activation.
