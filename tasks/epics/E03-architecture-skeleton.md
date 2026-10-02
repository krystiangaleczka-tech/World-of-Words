---
id: E03
title: Architecture skeleton (contracts)
phase: 0
status: planning
---

## Goal
The contracts every later task builds against, built serially by Sol in lane `H`: autoloads, Platform
with Fakes, Save v1, registries with a CI check, LevelData schema and Content, and a boot that reaches
the level. Rows: `tasks/ROADMAP.md` E03.

## Player-facing outcome
None. Boot reaches an empty level screen in debug builds.

## Decisions
- D1: T-0034 onward waits for the engine gate (T-0033), branch protection (T-0023) and docs v1
  approval (T-0011). Only T-0040 (engine-independent schemas) needs just T-0011. If the gate picks
  Unity, this epic is re-planned before any task file is written.
- D2: The autoload list is closed: Config, Save, Progress, Economy, Daily, Content, Monetization,
  Analytics, Audio, Nav, Events, Platform (`ARCHITECTURE.md#autoloads`). No task adds one.
- D3: Platform is a container of adapter interfaces (ads, iap, analytics, crash, consent, haptics,
  review, notifications), each with a no-op Fake; tests and headless boot use the Fakes.
- D4: Save is JSON with `schema_version`, sections and `install_id`; writes are atomic (temp + rename)
  with a `.bak` fallback; a corrupt file means a clean start plus `Events.save_corrupted`; migrations
  form a chain; `game/tests/fixtures/save/v1.json` is the golden file (`ARCHITECTURE.md#save`).
- D5: Registries are directories with one file per area (`game/data/config/*.json`,
  `game/data/analytics/*.json`). `tools/check_registries.py` fails CI on any `Config.get` or
  `Analytics.track` literal that is not registered.
- D6: The LevelData and manifest JSON Schemas live in `pipeline/schema/` and are shared by the pipeline
  and the game tests. The game holds a level as `core/board/level_data.gd` with tiles as indices.
- D7: Time is injected through a Clock; the boot scene sits under `services.nav`
  (`ARCHITECTURE.md#areas`). In Phase 1 boot goes straight to Level (current slot); Home exists empty
  and is reachable from debug.

## Contracts
Signatures are written in `ARCHITECTURE.md` (T-0007) and as `## @api` stubs in T-0034; they are not
repeated here.
- Config files: `unlocks.json` with the `unlocks.*_slot` keys and defaults from
  `PRODUCT.md#first-10-minutes-timeline`; `level.json` with the keys `GAME_DESIGN.md` (T-0006) defines.
- Level data: `CONTENT.md#level-schema`, `CONTENT.md#manifest`, `schema_version` field.
- Signals: `Events.save_corrupted`.
- Analytics events: none in this epic; T-0038 builds the registry and its validation only.

## Waves
### Wave 1
- T-0034 autoload stubs + Clock + boot scene stub (depends: T-0033, T-0023, T-0011)
- T-0035 Platform container + adapter interfaces + Fakes (depends: T-0034)
- T-0036 Save v1 (depends: T-0034)
### Wave 2
- T-0037 Config registry + `Config.get` (depends: T-0034)
- T-0038 Analytics registry + `Analytics.track` validation (depends: T-0035)
- T-0039 registries CI check (depends: T-0037, T-0038)
### Wave 3
- T-0040 LevelData + manifest schemas (depends: T-0011)
- T-0041 Content autoload + LevelData class + fixture pack (depends: T-0040, T-0034)
- T-0042 runtime bot integration test (depends: T-0041)
### Wave 4
- T-0043 Nav: Boot → Level ↔ Home (depends: T-0036, T-0037, T-0041)
- T-0044 boot smoke integration test (depends: T-0043)

## Open questions
- None of its own. Every task except T-0040 needs the engine gate (T-0033) closed first.

## Exit criteria
- All twelve autoloads are registered with typed `## @api` stubs.
- Platform selects Fakes in tests and headless runs.
- Save v1 passes the golden-file and interruption tests.
- The registries check is wired into `make check` and CI.
- The bot test loads every shipped level and proves each level word is formable and placed.
- The boot smoke test reaches Level headless with no errors in the log.
