---
id: T-0225
title: Complete bonus invalid already and hint presentation motion
epic: E14
type: feat
area: level.wheel
risk: high
executor: sol
think: high
ui: low
status: done
depends_on: [T-0224, T-0219]
touch:
  - game/ui/components/WordPreview.gd
  - game/ui/components/GridCell.gd
  - game/ui/components/BoardView.gd
  - game/ui/components/LetterWheelView.gd
  - game/ui/gallery/powerups.gd
  - game/features/level/level.gd
  - game/ui/tokens.gd
  - game/ui/theme/generate_theme.gd
  - game/tests/unit/ui/test_v1_tokens.gd
  - docs/design/tokens.css
  - game/tests/integration/test_word_feedback.gd
  - game/tests/integration/test_board_feedback.gd
  - game/tests/integration/test_board_view.gd
  - game/tests/integration/test_reward_postcard.gd
  - game/tests/integration/test_feedback_motion_final.gd*
  - docs/qa/T-0225-feedback-motion.md
  - tasks/T-0225-feedback-motion.md
revision: 2
---

## Goal
Complete motion B with translated noncolour cues and reduced-motion lifecycle safety.

## Context
Roadmap T-0225; docs/DESIGN.md#level-motion/#reduced-motion-mapping/#feedback-matrix; FR-A11Y-02.
Bonus BASE flight/scale0.4 then existing meter BASE fill/FAST pop; already1.06 twiceFAST; invalid
±24 three cycles BASE then FAST fade; hints0.6→1 +alpha BASE/SPRING; reveal STAGGERx2 then flash.

## Current state
Fresh main75b2b2ba contains technically merged T-0224. WordPreview translated results, bubble,
owned tint/feedback lifecycle; GridCell reveal/highlight/wave via BoardView; preallocated flight
pool and bounded completion; BonusMeter.set_count/pulse_already and HintButton amount pop exist.
LevelScreen P1 has bonus Label, not final BonusMeter HUD (T-0276); Powerups gallery has meters.
LetterWheelView clears before result, ignores short releases; tracking remains fixed-buffer.

## Specification
1. Preview valid pop1→1.08→1 FAST/SPRING; already fades BASE with label; invalid three sinusoidal
   ±24cycles over BASE/OUT plus TEXT→ERROR FAST tint, then FAST fade. Shape/label preserved in HC
   and reduction. All previous motion killed on new input, theme/resize/exit; no stale callbacks.
2. Add WordPreview.fly_bonus(target:Control)->Error, bonus_arrived(target:Control),
   pulse_already_target(target:Control)->Error, fade_short()->Error. Validate mounted same-viewport
   distinct non-descendant target and matching feedback state atomically. Preallocate passive top-level
   ghost Label; normal bonus flies BASE/IN_OUT to target, scales0.4, hides source word while translated
   cue holds TOAST_HOLD then FAST fade. Arrival exactly once; replacement/exit cancel silently;
   reduction/resize settle arrival once and restore static word. Signal is presentation only,
   never gameplay/persistence/reward intent. Target freed/removed cancels safely; reentrant arrival safe.
3. Generic already target pulses twiceFAST1.06 and restores original scale/pivot; BonusMeter uses its
   own existing pulse API. Powerups gallery shows bonus flight followed by caller-owned meter fill/
   icon pop; existing HintButton count pop retained. LevelScreen flies to existing P1 bonus label and
   pulses it for bonus-already; final Meter composition remains T-0276. No game-value/event changes.
4. Add LetterWheelView.short_released(indices:PackedInt32Array) on noncancelled1–2letter release;
   word_attempted still only≥3. LevelScreen shows a silent FAST/IN short preview fade. No sound/result
   or core attempt, stable input identities. No new allocations during pointer tracking.
5. GridCell.reveal(hinted:bool,delay:float=0) starts0.6/alpha0, BASE/SPRING; reduction FAST fade only.
   Invalid delay ignored atomically. highlight(delay=0) becomes already1.06 twiceFAST/IN_OUT;
   add wave(delay=0) retaining T-0224 wave1.12. Live reduction settles owned transforms/state.
6. BoardView.reveal_word retains immediate logical fill and hint correction, schedules ordered
   cell reveal at STAGGERx2, then whole-word flash. Reuses board-owned cancellable pipeline and
   records its nominal duration so completion budget stays correct. Reduced has no stagger/flash.
7. Visual ratios/cycle count and SHAKE_OFFSET24 live in tokens with CSS/unitless mirror. Existing
   word/board feedback tests retain assertions, updating exact old P1 pop/shake timing oracles to
   final documented peaks. No new copy keys/dependencies or theme hand edits.

## UX rules
R-UI-1: "A screen task may not create a component."
R-UI-3: "Use Tokens.*, theme type variations or theme constants."
R-UI-4: "Strings shown to players use translation keys."
R-UI-5: "Never edit game/ui/theme/generated/."
R-UI-6: native screenshot rules; physical/taste/Opus gates open.

## Tests
New tests: bonus target atomic validation, actual ghost movement/scale/passivity/arrival once,
replay/reentrant/target deletion/resize/reduction/exit; native already peaks/restoration; invalid
shake/tint/fade, short-release silence; hinted/staggered reveal/flash/live reduction and completion
budget retained. Existing suite, full make check, independent exact-head review and13CI before merge.

## Out of scope
Gameplay/economy/save/controller/event schemas, final HUD composition, platform/device certification.

## Rollback
Squash revert only presentation and visual constants; no migration or saved-state change.

## Revision2
Existing immediate-wave state oracle now expects filled while ordered reveal is pending.
Reward CSS oracle scopes its negative assertion to Reward-PARTICLE_COUNT: SHAKE_OFFSET24 is
a legitimate dimensional token, so an unqualified ban on all calc(24*unit) was overbroad.
Existing exact reward count/angle assertions retained. Canonical reveal includes hint correction
and full affected found-word flash, including already filled intersections.
