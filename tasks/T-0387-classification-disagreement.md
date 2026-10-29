---
id: T-0387
title: Compare two offline classification passes and flag ban boundary conflicts
epic: E22
type: feat
area: pipeline.classify
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0296]
touch:
  - pipeline/src/wordgame_pipeline/classify/__init__.py
  - pipeline/src/wordgame_pipeline/classify/disagreement.py
  - pipeline/tests/classify/test_disagreement.py
  - tasks/T-0387-classification-disagreement.md
revision: 1
---

## Goal
Prepare a deterministic human review disagreement queue without any paid or
network AI service; never accept automatic guesses for banned words.

## Current state
TIERS is the closed classification vocabulary and valid_word enforces Polish
normalized spelling. Production AI classification T-0296 remains gated.

## Specification
- Compare two explicitly supplied classification dictionaries with equal keys.
- Validate all words and tier values and flag only mismatches.
- Report frozen alphabetical word/first/second/banned-boundary evidence.
- Empty agreement is not human approval; no classifier or stage activation.

## Out of scope
AI endpoints, keys, paid services, cache changes, tier overrides and P1 builds.

## Tests
- Exact two disagreements including banned boundary, stable ordering.
- Empty/agreed results, malformed keys and tiers rejected.

## Acceptance
Exact-head CI and independent review; runtime remains model-free.
