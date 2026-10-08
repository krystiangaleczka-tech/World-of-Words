---
id: T-0111
title: Progress contract
epic: E07
type: contract
area: services.progress
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0110]
touch:
  - game/services/progress.gd
  - game/tests/integration/test_progress_contract.gd*
  - tasks/T-0111-progress-contract.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0111 prototype slice, with deterministic tests and explicit service boundaries.

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
Progress configures Save and Content via configure(save:SAVE_SCRIPT,content:CONTENT_SCRIPT). current_slot(language:String="")->int and highest_completed_slot(language="")->int read per-language state (default fromSave setting); absentlanguage starts1/0. restore_level(level:LevelData)->BoardState validates saved ID/state; stale/invalid state gives fresh board without erasingunrelateddata. save_level(board:BoardState)->Error and complete_level(slot:int)->Error frozen but unavailable untilT112; _save_language helper onlyprivate. No direct raw progress ownership outside service for newlywrittenfeatures. Contract readiness checks reject unloadedSave/content mismatch.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_language_defaults_and_isolation.
- test_restore_matching_or_stale_snapshot.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## Rollback
Revert the isolated squash commit before dependent tasks merge; after dependent integration revert
in reverse order. Save v2 migration is a forward format change: keep v1 backup before any downgrade.
