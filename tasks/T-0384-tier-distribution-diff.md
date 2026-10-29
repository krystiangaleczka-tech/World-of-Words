---
id: T-0384
title: Audit tier distribution before and after explicit review decisions
epic: E22
type: feat
area: pipeline.tiers
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0297]
touch:
  - pipeline/src/wordgame_pipeline/tiers/distribution.py
  - pipeline/tests/tiers/test_distribution.py
  - tasks/T-0384-tier-distribution-diff.md
revision: 1
---

## Goal
Make unexpected changes to eligible, bonus and banned word classes visible to QA.

## Current state
tiers.core exposes exact ordered TIERS and validates normalized Polish word forms;
assign_tiers returns classified records, but no frozen comparison report exists.

## Specification
- Accept two explicit word/tier snapshots with exactly the same vocabulary.
- Reject duplicates, invalid tiers, malformed words or addition/deletion.
- Return immutable full tier counts and alphabetical changes with both classes.
- Never infer authorization to override a banned/bonus decision.

## Out of scope
AI classification, threshold changes, CSV override writes or production publish.

## Tests
- Exact counts, two transitions, stable order and frozen output.
- Empty, unchanged, mismatched and malformed records.

## Acceptance
Exact-head CI and independent review.
