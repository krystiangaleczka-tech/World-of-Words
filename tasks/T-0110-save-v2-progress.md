---
id: T-0110
title: Save v2 progress
epic: E07
type: contract
area: services.save
risk: high
executor: sol
think: xhigh
ui: none
status: ready
depends_on: [T-0100, T-0036]
touch:
  - game/services/save.gd
  - game/services/save/save_schema.gd
  - game/services/save/save_migrations.gd
  - game/services/save/migrate_v1_to_v2.gd*
  - game/tests/fixtures/save/v2.json
  - game/tests/integration/test_save_v2.gd*
  - game/tests/integration/test_save_v1.gd
  - tasks/T-0110-save-v2-progress.md
revision: 1
---

## Goal
Deliver the ROADMAP T-0110 prototype slice, with deterministic tests and explicit service boundaries.

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
Save schema2 adds highest_completed_slot per language, retains legacy completed_slot for existing integrations, and validates progress language states and JSON board snapshots. Pure v1→v2 migration preserves identity/settings/economy/daily/monetization and extension keys; copies completed_slot to highest_completed_slot, retains level_state for validation by BoardState when matching content loads. Register built-in step only in default target2 migrations; explicitly constructed custom target3 test chain remains caller-owned. Auto-upgraded primary marked dirty until durable flush. Update legacy future-version test to SaveSchema.VERSION+1, preserve immutable v1 golden and add exactv2 golden. No save reset on migration. Production downgrade needs restored backup becausev1 cannot readv2.

## Tests
Required public-behavior cases in the task's declared test file(s):
- test_golden_migration_and_preservation.
- test_migrated_primary_is_flushed.
- test_multilanguage_and_bad_progress.

## Acceptance
Required cases pass; pinned Godot4.7.2 make check, task lint, scope and independent review pass.
One task/branch/PR. Actual Codex provenance is recorded; no claim of cheap-executor gate evidence.

## Rollback
Revert the isolated squash commit before dependent tasks merge; after dependent integration revert
in reverse order. Save v2 migration is a forward format change: keep v1 backup before any downgrade.
