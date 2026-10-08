---
id: T-0119
title: Complete every shipped level through the runtime board
epic: E07
type: test
area: services.content
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0101, T-0042]
touch:
 - game/tests/integration/test_content_bot.gd
 - tasks/T-0119-content-bot-play.md
revision: 1
---

## Goal
Upgrade the existing content bot to complete every fixture and shipped level through BoardState.evaluate, without hints or a runtime dictionary.

## Context
- tasks/ROADMAP.md T-0119, FR-CONT-07.
- docs/CONTENT.md#principles: "The game only reads the output."
- docs/GAME_DESIGN.md#word-classes: tile identity is its index.

## Current state
- game/tests/integration/test_content_bot.gd checks every manifest language, slot, word formability and grid coordinate.
- BoardState.new(level), evaluate(PackedInt32Array), found_words(), revealed_cells(), is_complete() and completed exist.
- LevelData supplies words and tile letters; no production API changes are needed.

## Specification
Preserve all existing tests and checks. For each loaded level create an isolated BoardState, select distinct original tile indices greedily for each level word, and evaluate it. Accept LEVEL or ALREADY_FOUND for a word already filled by crossing words; verify that word is found. Assert the board completes, all occupied grid coordinates are revealed, and completed emits once. Never call reveal_cell/HintLogic. A repeated completed word must not change the snapshot or emit completion again. Include fixture repeated letters and crossings and a formable word absent from level/bonus lists that remains INVALID and cannot complete the board. Iterate all shipped languages; an empty shipped root retains the explicit existing not-yet-shipped notice.

## Tests
- Preserve test_fixture_levels_are_formable, test_shipped_levels_are_formable, test_bot_rejects_unformable_word.
- test_bot_completes_crossings_and_repeated_letters: slot 3 fixture completes with distinct tile indices and one completion effect.
- test_formable_unknown_word_cannot_complete_board: TOK from KOT tiles is invalid and leaves the board untouched.

## Acceptance
Pinned Godot 4.7.2 make check, task lint, scope and independent review pass. One task/branch/PR; actual Codex provenance recorded.
