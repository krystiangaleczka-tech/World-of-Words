---
id: T-0291
title: Teach the first player-solved word on the level-one wheel
epic: E21
type: feat
area: level.flow
risk: medium
executor: sol
think: high
ui: high
status: review
depends_on: [T-0290, T-0276, T-0326]
touch:
  - game/features/level/level.gd
  - game/features/level/level_controller.gd
  - game/features/level/tutorial_ui.gd*
  - game/locale/level.csv*
  - game/tests/integration/test_level_tutorial.gd*
  - docs/qa/T-0291/**
  - tasks/T-0291-first-level-tutorial.md
revision: 1
---

## Goal
Explicitly opt the P2 level-one screen into the passive gesture lesson. A real,
durable player solve ends the lesson; hints and failed persistence never do.

## Context
- ROADMAP T-0291; FR-ONB-02; DESIGN.md#flow-first-launch: "animated hand traces the first word on the wheel until the player finds a word".
- DESIGN.md#level-p2-final and #tutorialhand-addition: first level has board, preview, wheel, level number, hand and one Caption.
- docs/contracts/onboarding.md: accepted LEVEL/BONUS only after real Progress commit; touch is presentation only.
- Reference docs/design/T-0205 onboarding mockup.

## Current state
- LevelScreen.configure(save,content,slot,event_bus), configure_p2(economy,config) explicitly opt in before mount. P2 hides slot-one actions/settings; P1 remains default.
- LevelController._commit saves Progress, then emits state_changed/result_ready; hints have null result. AttemptResult is mutable and state_changed observers may mutate pending presentation objects.
- BoardState.found_words is derived from revealed cells, including hints; bonus_words records attempted bonus words. Neither found cells nor found_words prove a player-solved board word after restart.
- Save.configure_onboarding(events), onboarding_snapshot(), complete_tutorial(), retry_onboarding() own existing metadata, dirty pending retries, and Events.onboarding_step.
- TutorialHand.configure(path,loop), hide_for_touch(), cancel(), play() and LetterWheelView.tile_position(index) exist. LevelCopy registers level.csv.
- No first-level tutorial helper/opt-in exists.

## Specification
1. Add LevelScreen.configure_tutorial()->Error before mount, requiring configured P2, loaded Save and campaign slot 1. Reject malformed/off-campaign binding; no boot/Nav activation or P1 changes. Bind Save's real event bus via existing configure_onboarding; never add metadata/schema.
2. Add LevelController.player_word_committed signal for accepted player LEVEL/BONUS after successful persisted Progress only, before state_changed/result_ready. Freeze eligibility before persistence/presentation callbacks. Never emit for diagnostic non-persisting sessions, hints, repeats, invalid/short input, failed writes. Successful exact Progress retry emits once.
3. Mount catalog TutorialHand above wheel/below feedback and one external Caption level.tutorial.connect. Use actual immutable tile IDs for the first level word and current tile positions; resize updates the path without restarting dismissed teaching. No new component/tokens.
4. First native wheel press fades only hand; same press/drag/release still reaches wheel; caption stays until durable accepted solve. Completed committed onboarding suppresses both, including reentry.
5. On player_word_committed hide both before any presentation callbacks; invoke Save.complete_tutorial. Metadata failure keeps live lesson hidden, reports existing persistence-failed status, and exposes explicit retry_tutorial()->Error for the exact pending action. No automatic loop or false durable success. A retry never resubmits/rewards the word. prepare_navigation retries this pending metadata before navigation.
6. Restart reconciliation: committed tutorial step>=1 suppresses lesson. A currently eligible restored bonus word proves a prior persisted player solve: complete tutorial through the same Save command. Revealed cells and found_words alone are ambiguous (hint-derived), so never infer completion from them: show the lesson again if no durable metadata/bonus proof. No history replay/backfill for later slots. A later real solve qualifies even if cells were hinted.
7. Exit cancels hand and disconnects manually connected signals. Retained reentry reconnects once, respects live accepted/touch-hidden state, updates layout without reviving dismissed hand. Locale/theme/reduced-motion follow catalog behavior. No per-frame polling/allocations.

## UX rules
- R-UI-1 "A screen task may not create a component"; R-UI-2 "New component = separate task". Use TutorialHand, Caption and existing level catalog only.
- R-UI-3 "No raw numbers in scenes or feature scripts"; use Tokens/theme. R-UI-4 "Strings shown to players use translation keys".
- R-UI-5 "Never edit game/ui/theme/generated/". R-UI-6 "Every UI PR with UI: med|high attaches screenshots".
- Screenshots per DESIGN.md#pr-screenshot-rules. Native matrix: COMPACT/REGULAR/TABLET, PL/PSEUDO, default/HC130, playing/touched/completed/reduced. Physical-device feel/playtest gates remain open.

## Tests
File game/tests/integration/test_level_tutorial.gd:
- Opt-in rejection/P1 unchanged, no writes at fresh mount, non-slot-one/off-campaign guard.
- Real native press/drag/release through hand submits first target, touch leaves caption, committed solve hides lesson and emits one onboarding event.
- Controller commit eligibility: LEVEL/BONUS, hint/invalid/repeat/short/diagnostic exclusions, failed Progress and exact retry, hostile presentation callbacks cannot change frozen eligibility.
- Metadata failure after Progress commit: live suppression, committed snapshot unchanged, explicit exact retry, one event, no extra progress/reward; navigation retry; foreign pending coach is never retried by the lesson; actual atomic P2 checkpoint/completion.
- Restored hinted found_words never completes; eligible persisted bonus reconciles; committed step suppresses with empty board; no historical board-word guesses.
- Lifecycle/retained reentry and resize preserve dismissal, one connection, no old Tween; reduced motion static arrow.
- Native layout matrix keeps caption/board/wheel in bounds, correct path and P2 hidden actions.

## Acceptance
Full pinned make check, scope and task lint, fresh independent review, all CI including Android; no invented human/device approval.
