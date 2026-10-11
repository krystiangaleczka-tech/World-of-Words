---
id: T-0151
title: Fix diagnostic level playtesting and record device feedback
epic: E09
type: fix
area: level.flow
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0116, T-0134, T-0148]
touch:
  - game/features/level/level.gd
  - game/features/level/level_controller.gd
  - game/tests/integration/test_debug_level_playtest.gd*
  - docs/qa/T-0151-debug-level-playtest.md
  - docs/qa/word-difficulty-feedback.md
  - tasks/T-0151-debug-level-playtest.md
revision: 1
---

## Goal
Allow a debug playtester to solve any slot opened through diagnostics without
an invalid campaign-save error or changing the saved campaign position. Record
Chris's word-difficulty feedback for future content work, without regenerating packs.

## Context
- `docs/PRODUCT.md` FR-DEBUG-01: diagnostics can jump to any slot.
- `docs/PRODUCT.md` FR-PROG-06: production replay remains out of scope.
- `docs/ARCHITECTURE.md#level-flow`: the controller owns orchestration,
  Progress owns campaign persistence.
- User-directed device follow-up: opening slot 21 with campaign current_slot 24
  rejects the correct word BOA; this also reproduces without shuffling.

## Current state
- `LevelController.configure(board, progress, event_bus) -> bool` rejects busy
  reconfiguration; `_commit()` requires Progress persistence before publishing.
- `LevelScreen._load_board()` configures an isolated Progress service and binds
  a board only when its slot matches the campaign current slot.
- `Progress.save_level()` rejects a board outside the current campaign slot;
  this protection must remain intact.
- `test_debug_level_playtest.gd` and the two QA files do not exist yet.

## Specification
### Behavior
1. Add an optional `persist_progress: bool = true` parameter to controller
   configuration. Preserve the busy-reconfiguration guard and existing defaults.
2. In debug builds only, configure non-current slots for session-only play:
   words, bonus words, hints, already-found feedback and completion work normally,
   but neither save_level nor complete_level is called. Existing P1 feedback
   effects and screen-completion signals are preserved.
   The existing final-slot resume screen after finishing the campaign is retained.
3. Current-slot play retains durable-before-feedback ordering and failure retry.
   Release builds do not enable session-only play automatically.
4. Leaving a non-current diagnostic slot discards its session-only state. It
   cannot overwrite the active campaign snapshot or advance/regress campaign
   progress. Completed and future slots are both supported for playtesting.
5. Record the reported word-selection preferences in an English Markdown file:
   familiar opening words (WODA, DWA) are acceptable; less obvious inflections
   belong later; future content needs multiple lexical-difficulty bands. Do not
   produce thousands of levels or change the pipeline/content in this task.

## Tests
File: `game/tests/integration/test_debug_level_playtest.gd`
- Open an earlier multiword slot through diagnostics with a different saved
  current slot, shuffle three times, return through diagnostics, and solve a
  word and bonus. Feedback succeeds; storage and campaign snapshot are unchanged.
- Hint and finish the earlier slot; completion works without Save writes.
- Open a future slot and solve it; saved current slot remains unchanged.
- Current-slot persistence failure still suppresses feedback until explicit retry.
- Busy reconfiguration cannot change the persistence mode; idle reconfiguration
  resets it to the default.

## Acceptance
- Required regression tests and `make check` pass.
- On the connected Android device, the reproduced BOA failure no longer occurs
  after rebuilding; the existing save remains intact.
- Feedback is recorded without hand-editing generated content or changing rules.

## Rollback
Revert controller mode, screen wiring, tests and QA notes together. No save
schema migration or generated-content rollback is necessary.

## Outcome
Fresh independent review approved d7b831b9817cd10a65e23ee53c568c621ebd41e1
without blockers. Full local make check with Godot 4.7.2 passed: 244 GUT tests,
8921 assertions, 199 pipeline tests and 142 tools tests; 65 shipped levels validated.
Historical author-operated Android evidence is recorded in the QA report; this
review did not repeat device testing or close the Galaxy A15 or FUN GATE checks.
The final metadata head still requires green remote CI before merge.
