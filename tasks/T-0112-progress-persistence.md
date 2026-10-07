---
id: T-0112
title: Progress persistence
epic: E07
type: feat
area: services.progress
risk: high
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0111, T-0101]
touch:
  - game/services/progress.gd
  - game/tests/integration/test_progress_persistence.gd*
  - tasks/T-0112-progress-persistence.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0112 prototype slice, with deterministic tests and explicit service boundaries.

## Context
- docs/GAME_DESIGN.md#word-classes and #hints: ignored short attempts; identity is tile index.
- docs/ARCHITECTURE.md#level-flow and #save: gameplay calls services directly; Events carry effects only.
- docs/DESIGN.md#level-p1-provisional and #tokens: P1 uses provisional token-driven visuals.
- docs/qa/P1-authorized-wave.md records Chris's explicit instruction to execute T-0100–T-0117 now.

## Current state
Read the corresponding dependency commits before execution. LevelData, Save v1, Nav debug routing,
ScreenScaffold/TextButton and the diagnostic token subset already exist. Other listed APIs are created
by this wave in dependency order. Verify actual signatures before editing.

## Specification
Implement save_level then synchronous Save.flush on meaningful word/hint/bonus mutations; complete_level advances current slot exactlyonce and highest/legacy completed markers, clears level_state, may store nextslot beyondlastcontent. Requires matching active language/content/slot. Repeated completedslot returnsOK without rewriting; out-of-order/foreignslot rejected. Keep dirty state afterI/O failure for explicit retry, emit service completed(slot) onlyafter successful durable commit; prevent duplicate signals/retrylossevents. Background flush saves current boundboard through bind_board(board) and disconnectsunbind whenleaving; controller will call save/complete explicitly, never Events for logic. Never per-frame writes. Progress.reload reflectedafterdebugreset via reads not cache.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_word_and_background_roundtrip.
- test_completion_idempotence_and_language_isolation.
- test_flush_failure_retry_and_no_premature_signal.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## Rollback
Revert the isolated squash commit before dependent tasks merge; after dependent integration revert
in reverse order. Save v2 migration is a forward format change: keep v1 backup before any downgrade.
