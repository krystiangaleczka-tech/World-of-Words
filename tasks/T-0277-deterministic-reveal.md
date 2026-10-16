---
id: T-0277
title: Select the longest unfound word for Reveal deterministically
epic: E20
type: feat
area: core.board
risk: medium
executor: cheap
think: med
ui: none
status: review
depends_on: [T-0102, T-0203]
touch:
  - game/core/board/hint_logic.gd
  - game/tests/unit/board/test_reveal_word.gd*
  - tasks/T-0277-deterministic-reveal.md
  - tasks/T-0276-level-p2-composition.md
  - tasks/T-0278-paid-tools.md
  - tasks/epics/E20-level-integration.md
revision: 1
---

## Goal
Provide the pure target selector needed by the later paid Reveal flow.

## Context
GAME_DESIGN.md#hints: "longest unfound level word (ties: first in the level data)".
FR-HINT-04; roadmap T-0277. HintLogic callers own board mutation and persistence.

## Current state
HintLogic.next_cell(board: BoardState)->Vector2i selects the shortest unfound word's
first unrevealed cell. BoardState reveals cells, syncs crossing words and completion.
LevelData.word_count/word/word_cells preserve data order. No Reveal selector exists.
T-0102 and T-0203 are merged. Include the three-row E20 wave plan.

## Specification
Add static HintLogic.reveal_word(board: BoardState) -> String. Return the longest
unfound word, ties in data order; empty string for null or complete board. Ignore
bonus words. No mutation, signals, randomness, nodes, I/O or grant/debit.
Partial reveals do not change the length priority; fully revealed words are already
found by BoardState. Existing next_cell behavior remains unchanged.

## Planning refinement
P2 rolling-wave deps use merged selection/rule owners for this pure unactivated
helper; roadmap T-0143 remains an open release/runtime gate, never a fabricated PASS.
No caller/paid flow or P1 activation is introduced by this task.

## Tests
New unit suite: longest/first tie, skip found, partial reveal, null/complete,
all-cells caller reveal including crossings, stable repeated result and no mutation.

## Acceptance
Full check, scope, fresh review and all CI pass. No existing tests changed.

## Rollback
Revert the uncalled selector; persisted boards unchanged.
