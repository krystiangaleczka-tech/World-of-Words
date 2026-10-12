---
id: T-0191
title: Randomize the visible wheel order when a level opens
epic: E14
type: fix
area: level.wheel
risk: medium
executor: sol
think: med
ui: low
status: review
depends_on: [T-0203]
touch:
  - game/features/level/level.gd
  - game/ui/components/LetterWheelView.gd
  - game/tests/integration/test_initial_wheel_order.gd*
  - game/tests/integration/test_level_scene.gd
  - docs/GAME_DESIGN.md
  - tasks/T-0191-random-initial-wheel.md
revision: 1
---

## Goal
Start each level presentation with a freshly randomized visible wheel instead of pack order.
Keep tile identities, letters, word evaluation, saved progress and manual Shuffle unchanged.

## Context
- Chris explicitly requested randomized wheel letters after installing T-0208 on phone.
- `docs/GAME_DESIGN.md#letter-wheel`: tiles remain addressed by index.
- `docs/GAME_DESIGN.md#power-ups`: Shuffle is position-only and does not save its order.

## Current state
- Fresh main ab67ff0 fast-forwarded to reviewed T-0208 ea3704f (12/12 CI PASS), stacked draft.
- LevelScreen.configure_rng(rng:RandomNumberGenerator)->void supports deterministic injection.
  _load_board creates a fallback RNG seeded with hash(level id) and calls wheel.set_letters.
- LetterWheelView.set_letters(letters:PackedStringArray)->void initializes identity order;
  tile_order()->PackedInt32Array and tile_position(index:int)->Vector2 expose stable identities.
- Shuffle.permute(order:PackedInt32Array,letters:PackedStringArray,rng:RandomNumberGenerator)
  ->PackedInt32Array already handles duplicates, bounded retries and identity-only movement.
- No saved wheel-order field; old resume text describes the initial pack order.

## Specification
1. Change set_letters signature to add optional initial_rng:RandomNumberGenerator=null.
   Null retains existing identity ordering for standalone callers/gallery. A supplied RNG
   uses existing Shuffle.permute after building identity indices, before laying out tiles.
   Valid 3–8 letters retain every original identity, including duplicate-letter tiles.
2. Initialization is immediate and silent: no tween, input lock, drag, event, sound/haptic or
   allocation in swipe/_process. Invalid letter count stays empty; uniform letters stay valid.
3. LevelScreen passes its injected RNG into initialization. When absent, create and randomize
   the production RNG once per screen instead of reseeding with level-id hash. No clock or
   unseeded randomness in core, no changes to core API or generated content.
4. Opening/resuming a level gets a new random presentation; an exact previous random order
   can occur by chance. Preserve source letters, found/bonus words, hints and save format.
   Seeded test/review injection remains reproducible. Manual Shuffle behavior/gating stays intact.
5. Update GAME_DESIGN presentation/resume wording to the requested behavior. This is not a
   new power-up, cost/unlock/economy rule; do not write permutation data into save.

## Tests
- New test_initial_wheel_order.gd: same seed reproduces initial order; sampled fixed seeds
  yield different valid orders; duplicates preserve tile identities and submitted indices;
  initial shuffle neither locks input nor creates tweens; input letters remain immutable;
  null RNG and invalid/uniform inputs preserve their documented behavior.
- Add seeded LevelScreen test to test_level_scene.gd: initial order is shuffled and injected
  seeds reproduce it; initial presentation does not change board snapshot or storage writes.
  Retain all existing level/HUD/shuffle/restore tests without changing their expectations.
- make check, scope/task checks, independent review and final-head CI green before phone APK.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: Reuse existing components; no new widget/state.
- R-UI-2: New components require their own task/gallery.
- R-UI-3: Geometry/motion remain token-driven.
- R-UI-4: No new player copy; translation keys unchanged.
- R-UI-5: Generated themes untouched.
- R-UI-6: Capture changed wheel layout (REGULAR, PL) on the installed phone build.

## Acceptance
Letters start permuted; dragging still uses their original identities; no data loss or
power-up side effects. Automated checks pass and phone build launches with restored save.

## Out of scope
Pack editing, new letters/words, save/economy/config changes, font/theme/layout restyling,
tutorial implementation, new dependencies/autoloads/exports/platform settings.

## Escalation log
2026-10-12: owner request explicitly changes startup wheel presentation and old fixed-order
resume wording; task authorizes that API addition and documentation update. Work as an
isolated stacked fix on the installed/reviewed T-0208 source; merge parent first. Scheduling
T-0203 is done; previous device/Opus/release gates stay open. The ongoing phone-build request
includes installing this requested follow-up, preserving/restoring its verified save.

Automated implementation evidence: make check PASS (292 GUT,311 pipeline,370 tools,
registries and65 campaign levels). Required seeds/permutation/identity/immediate-input/
save-write tests pass; original shuffle/HUD/restore expectations are retained.
Fresh independent review, final-head CI and phone installation remain pending.
