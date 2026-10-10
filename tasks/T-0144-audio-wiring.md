---
id: T-0144
title: Relay durable P1 gameplay effects to named sounds
epic: E09
type: feat
area: level.flow
risk: low
executor: cheap
think: low
ui: low
status: done
depends_on: [T-0118, T-0132, T-0133, T-0135]
touch:
 - game/services/audio/audio_listener.gd*
 - game/services/nav/boot.gd
 - game/tests/integration/test_audio_wiring.gd*
 - docs/qa/T-0144-audio-wiring.md
 - tasks/T-0144-audio-wiring.md
revision: 1
---

## Goal
P1 tile, valid, bonus, repeated, invalid and completed effects use Audio.play.
Level copy remains translated from the existing CSV; no new visible elements.

## Current state
T-0133 provides six named preloaded cues, live volume and an injected sink. Events
exposes tile_touched/word_found/bonus_found/already_found/invalid_word/level_completed.
LevelScreen emits tile effects; LevelController publishes accepted words/completion
only after durable persistence, ignores short attempts and rejects completed-board
submissions. Boot owns a disconnecting HapticsListener. LevelCopy already uses
imported PL/EN translations. No audio event listener exists.

## Specification
1. Add one nonglobal Node listener owned by Boot, connecting the existing six
   Events signals to Audio.play(tile_touch,word_valid,word_bonus,word_already,
   word_invalid,level_complete). No hint cue is introduced. Effects never control
   gameplay. Configure before mount; reconnect idempotently on replacement/reentry
   and disconnect old bus/exit. No new autoloads or event contracts.
2. Boot attaches the listener to Events/Audio after loading audio and navigating.
   Failure/mute remains Audio's responsibility. No persistence/core/Save/economy/
   analytics/project edits, no direct effects inside Level logic.
3. Every Level-visible string is already in level.csv (T-0132/LevelCopy). Verify
   real PL/EN screen text and required cue mapping, preserve the current ownership.

## UI rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1 A screen task may not create a component; if missing STOP (S4).
- R-UI-2 New component = separate ui.components task and gallery entry.
- R-UI-3 Visual values use Tokens/theme.
- R-UI-4 Player-visible strings use translation keys.
- R-UI-5 Never hand-edit generated theme.
- R-UI-6 UI med/high attaches prescribed screenshots.
This is event wiring only; existing Level composition/copy remain unchanged.

## Tests
Real registry/sink: six cues, mute, ignored hint, replacement bus/exit/reentry with
no duplicates. Real Level/controller with in-memory Save: tile input, bonus,
repeat, invalid, valid and completion; short attempts make no result sound;
failed durability emits no success/completion, retry emits once. Real boot wiring
must produce the intended cue. Verify PL/EN HUD/completion/feedback keys resolve
through CSV translations. Full make check, scope/task lint, fresh review and CI.

## Acceptance
All six side effects produce registered sounds after appropriate durable state;
no fabricated audible/device assessment. Human T-0051/T-0136 gates remain open.

## Rollback
Remove the listener and boot ownership; gameplay and saved data are unaffected.
