---
id: T-0290
title: Define durable onboarding steps and the inline CoachMark API
epic: E21
type: contract
area: features.onboarding
risk: high
executor: sol
think: med
ui: low
status: review
depends_on: [T-0203, T-0242]
touch:
  - game/services/save.gd
  - game/services/events.gd
  - game/features/onboarding/onboarding_state.gd*
  - game/features/onboarding/coach_mark.gd*
  - game/tests/integration/test_onboarding_contract.gd*
  - tasks/T-0290-onboarding-contract.md
revision: 1
---

## Goal
One owner for tutorial and coach-mark progress that survives restart, emits each onboarding step
once and exposes a CoachMark that only highlights an existing target. Owner asked to continue
with the next roadmap tasks.

## Context
- DESIGN.md#feature-unlock-gating — "Coach mark = the target component's `highlighted` state plus
  one inline `Text(Type.CAPTION)` label beside it (copy key `onboarding.coach.<feature>`). Any tap
  anywhere dismisses it; it also ends after `Motion.TOAST_HOLD` x 2. No overlay, no scrim, no
  arrow, no new component. Shown once per feature, recorded in the save, and each emits
  `onboarding_step`."
- GAME_DESIGN.md#onboarding — "The first accepted player-solved LEVEL/BONUS word permanently
  completes teaching; Hint/debug completion does not qualify." "Queue eligible coaching rather than
  overlapping it with consent/another coach/completion feedback."
- ARCHITECTURE.md#autoloads — Save owns `meta`; "meta/settings changes must use Save-owned
  accessors". Roadmap T-0290; FR-ONB-03, FR-ONB-05.

## Current state
- Save v4 `meta` has `coach_marks_seen: Array[String]` and `onboarding_step: int`; Save has no
  accessor for them. `set_section` rejects `meta`.
- `onboarding_step {step:int}` is registered in `game/data/analytics/onboarding.json`; no emitter.
- Components expose `highlighted` (IconButton, ActionButton/HintButton, BonusMeter, NavTab, …).
- AdPolicy already exempts `coach_mark` from the prompt budget.

## Specification
1. Save: `onboarding_meta()` returns an independent copy; `mark_coach_seen(feature)` and
   `reach_onboarding_step(step)` are monotonic, flush immediately, return OK without a write when
   nothing changes, and restore the previous in-memory document when the write fails.
2. Events: `onboarding_step_reached(step: int)`, a side effect for the analytics listener (T-0328).
3. OnboardingState step ids: 1 tutorial shown, 2 tutorial complete, 3..7 coach marks for
   shuffle, bonus, hint, journey, reveal. Each newly durable step emits once, after the write.
4. `complete_tutorial(kind, player_solved)` accepts only LEVEL/BONUS solved by the player.
5. `can_coach(feature, target_visible, busy)` / `begin_coach` / `end_coach`: one coach at a time;
   unseen known feature, visible target, not busy. The flag is persisted before anything shows; a
   failed write shows and emits nothing, so the caller retries at the next eligible moment.
6. CoachMark (Node, no scene): `show_mark(feature, target, caption)` sets `target.highlighted`
   and the caption key; any pressed tap or 2 x `Motion.TOAST_HOLD` ends it and emits
   `finished(feature)` once. It never marks input handled.

## Out of scope
Level 1 tutorial (T-0291), coach-mark wiring and locale keys (T-0292, T-0289), the analytics
mapping (T-0328), save schema changes.

## Tests
`game/tests/integration/test_onboarding_contract.gd`: unconfigured fail-closed; first-word rules;
write failure and retry; once-per-feature across restart; step ids; copied meta; CoachMark tap
and timeout.

## Deviations / concerns
`save.gd` is also changed by open PR #180 (T-0251) in other functions; a rebase is mechanical.

## Rollback
Remove the two classes, the signal and the three Save accessors; no data shape changes.

## Escalation log
