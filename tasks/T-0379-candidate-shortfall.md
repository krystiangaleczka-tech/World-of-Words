---
id: T-0379
title: Rank candidate word shortages without generating source data
epic: E22
type: feat
area: pipeline.candidates
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0373]
touch:
  - pipeline/src/wordgame_pipeline/candidates/shortfall.py
  - pipeline/tests/candidates/test_shortfall.py
  - tasks/T-0379-candidate-shortfall.md
revision: 1
---

## Goal
Prioritize deficient word wheels before committing to content generation.

## Current state
WordIndex.automatic returns eligible wheel records with exact level_ok
and seed pools. Existing T-0373 reports aggregate shortages only.

## Specification
- Require an explicit positive selected word target and validated WordIndex.
- Return immutable records ranked missing-word count descending, ID ascending.
- Count each multiset once, report actual selected and seed availability.
- Empty and already-complete supply yield no records. Never invent words.

## Out of scope
Dictionary updates, classification, generation, released content or AI.

## Tests
- Exact two-wheel deficits, ordering and anagram seed grouping.
- Empty, satisfied targets, nonmutation and invalid arguments.

## Acceptance
Full exact-head CI and fresh independent review.
