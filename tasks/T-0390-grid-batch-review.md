---
id: T-0390
title: Rank crossword layouts needing crossing review
epic: E22
type: feat
area: pipeline.grid
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0366]
touch:
  - pipeline/src/wordgame_pipeline/grid/batch_review.py
  - pipeline/tests/grid/test_batch_review.py
  - tasks/T-0390-grid-batch-review.md
revision: 1
---

## Goal
Show a deterministic per-candidate grid quality queue for human P2 review.

## Current state
The merged GridQuality helper validates and describes a single crossword.
There is no batch queue that retains candidate identity.

## Specification
- Pure review_grid_batch(candidates, *, minimum_crossings).
- Require explicit nonnegative integer threshold, exact candidate identities,
  layout and selected-word tuples; use the canonical geometry validator.
- Rank insufficient crossings first and then ascending crossings and ID.
- Return frozen records, no output files, guessing or content changes.

## Out of scope
Grid search, content selection, P1 game, releases.

## Tests
Crossed and un-crossed fixture, rank, nonmutation, malformed evidence and empty batch.

## Acceptance
Full CI green, scope and independent review.
