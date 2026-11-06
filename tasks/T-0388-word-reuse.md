---
id: T-0388
title: Report crossword word reuse across campaign slots
epic: E22
type: feat
area: pipeline.qa
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0366]
touch:
  - pipeline/src/wordgame_pipeline/qa/word_reuse.py
  - pipeline/tests/qa/test_word_reuse.py
  - tasks/T-0388-word-reuse.md
revision: 1
---

## Goal
Expose exact cross-slot word reuse as readonly evidence for human P2 content QA.

## Current state
The merged campaign QA summary reports counts only. No standalone report lists
repeated selected crossword forms and their campaign slots.

## Specification
- Pure `review_word_reuse(levels, *, minimum_levels)` with explicit cutoff >=2.
- Reject malformed identities, repeated slots and words, missing/partial campaign.
- Return immutable word and sorted slot tuples, ranked by frequency then form.
- Empty input returns an empty report; no changes to source data or release gates.

## Out of scope
Dedupe policy changes, source/seed inference, AI and content publication.

## Tests
Exact slots, cutoff, order independence, immutability, nonmutation and bad evidence.

## Acceptance
Full CI green, task scope and independent review.
