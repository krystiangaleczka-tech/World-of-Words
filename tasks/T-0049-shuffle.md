---
id: T-0049
title: Permute tile indices deterministically and change the visible order when possible
epic: E04
type: feat
area: core.board
risk: medium
executor: cheap
think: low
ui: none
status: done
depends_on: [T-0045]
touch:
  - game/core/board/shuffle.gd*
  - game/tests/unit/board/test_shuffle.gd*
  - tasks/T-0049-shuffle.md
revision: 1
---

## Goal
Provide the pure shuffle operation before the wheel UI exists: retain original tile identities and
letters while guaranteeing a different visible order whenever at least two letters differ.

## Context
- `docs/GAME_DESIGN.md#power-ups`: "Uses an injected, seeded RNG; never `randi()`."
- `docs/ARCHITECTURE.md#layers`: core is pure logic; RNG is injected.
- `docs/design-pass/06-standard-taskow.md#4-przykład-poprawiony-task042-shuffle`: pure part of the example.
- ROADMAP T-0049; FR-WHEEL-08 and FR-HINT-06. New core logic is medium per TEMPLATE risk rules.

## Current state
- `game/core/board/level_data.gd` uses original integer tile indices and PackedStringArray letters.
- No Shuffle class or wheel UI exists; built-in RandomNumberGenerator accepts deterministic seeds.

## Specification
### Interface
```gdscript
class_name Shuffle extends RefCounted
static func permute(order: PackedInt32Array, letters: PackedStringArray,
        rng: RandomNumberGenerator) -> PackedInt32Array
```
1. Valid order is a full permutation of indices 0..letters.size()-1; return a new permutation of them.
2. Never mutate inputs. Same seed and inputs yield the same result.
3. When at least two letters differ, the sequence read by result indices differs from the current
   order's sequence. Duplicate letters remain distinct tile indices.
4. Empty/single/identical-letter cases terminate and preserve the multiset, without a must-differ condition.
5. Two differing tiles always swap. Use only the injected RNG; no Node, I/O, clock or global randomness.
6. Null RNG or malformed order (wrong length, repeated, negative, out-of-range indices) returns empty.
   A valid empty order also returns empty.

## Out of scope
Wheel animation, buttons, dragging, Events, analytics, haptics, Economy, Progress or BoardState changes.

## Tests
File `game/tests/unit/board/test_shuffle.gd`:
- `test_preserves_tiles`: [0,1,2,3], letters [D,O,M,A], seed 1 yields a full permutation; inputs stay unchanged.
- `test_differs_when_possible`: seeds 1..50 for distinct and repeated letters, including a non-identity input order.
- `test_identical_letters_terminates`: [A,A,A], seed 7 returns a 3-index permutation.
- `test_two_tiles_swap`: [O,D] always swaps for seeds 1..50 and either current order.
- `test_deterministic`: equal initial seeds/inputs produce equal results.
- `test_empty_single_and_invalid_inputs`: empty/single valid inputs and every invalid case above.

## Acceptance
All pure tests pass; no production file outside the pure Shuffle class changes.

## Implementation notes
Use bounded random attempts (up to 10), then rotate by one when the visible order still matches.
Rotation guarantees difference for a nonconstant visible sequence and cannot loop forever.

## Execution evidence
Implemented in the Codex session, not a cheap-model run. An additional seed-174 regression covers
ten identity draws followed by the guaranteed changed result. Fresh independent review and CI are
required before merge; this completion alone does not satisfy the Phase 0 cheap-executor gate.
