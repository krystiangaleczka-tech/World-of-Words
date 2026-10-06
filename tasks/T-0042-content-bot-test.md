---
id: T-0042
title: Bot test that every shipped level loads and its words are formable
epic: E03
type: test
area: services.content
risk: medium
executor: human       # done in a Claude Code session Chris started
think: med
ui: none
status: done
depends_on: [T-0041]
touch:
  - game/tests/integration/test_content_bot.gd*
  - tasks/T-0042-content-bot-test.md
revision: 1
---

## Goal
CI proves that every level the game can ship (test fixtures and `game/content/`) loads through
`Content` and that each word can be formed from the level's tiles and sits on its grid.
T-0119 later upgrades this to playing each level through `BoardState`.

## Context
- PRODUCT.md FR-CONT-07: every shipped level must be completable.
- CONTENT.md#hard-validation rule 1: "Every level word and bonus word can be formed from `letters`
  (each tile used at most once)."
- Roadmap row T-0042 (upgraded to BoardState in T-0119).

## Current state
- `Content.load_manifest`, `slot_count`, `level_for_slot`, `pack_failed` and `LevelData.spell`,
  `word_cells`, `grid_size` exist (T-0041).
- `game/tests/fixtures/content/pl/` has 3 levels; `game/content/` has no language folder yet.

## Specification
1. The test scans `res://tests/fixtures/content` and `res://content` for `<lang>/manifest.json`.
2. For each manifest: it loads with OK; every slot 1..slot_count returns a level whose slot matches;
   `pack_failed` never fires.
3. For every level word and bonus word the bot picks tile indices letter by letter (any unused tile
   with that letter) and asserts `spell(tiles)` equals the word, so tiles are used at most once.
4. Every level word has one cell per letter, all inside `grid_size()`.
5. With no shipped content the `res://content` part passes with a note; the fixture part always runs.

## Out of scope
Completing levels through BoardState (T-0119), dictionary/tier checks (pipeline validator).

## Tests
`game/tests/integration/test_content_bot.gd`: `test_fixture_levels_are_formable`,
`test_shipped_levels_are_formable`, `test_bot_rejects_unformable_word` (guards the helper itself).

## Acceptance
`make check` green; test count rises.
