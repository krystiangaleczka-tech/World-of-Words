---
id: T-0389
title: Audit letter exposure across candidate wheels
epic: E22
type: feat
area: pipeline.candidates
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0366]
touch:
  - pipeline/src/wordgame_pipeline/candidates/letter_audit.py
  - pipeline/tests/candidates/test_letter_audit.py
  - tasks/T-0389-wheel-letter-audit.md
revision: 1
---

## Goal
Measure wheel-letter coverage before selecting candidate puzzles, without guessing
a target distribution.

## Current state
WordIndex.automatic produces a deterministic set of one record per seed-eligible
letter multiset. No separate letter exposure report exists.

## Specification
- Add readonly audit_wheel_letters(index), returning frozen rows ordered by letter.
- Count distinct candidate wheels containing each letter and total tile
  multiplicity independently; two anagram seeds remain one wheel.
- Preserve exact Polish letters, and return an empty report when no wheel is eligible.
- Do not classify, mutate, persist, approve or select content.

## Out of scope
Production calibration, gameplay changes and source acquisition.

## Tests
Exact counts, repeated tiles, seed-anagram deduplication, no candidates, immutability.

## Acceptance
Full CI green, bounded scope and independent review.
