---
id: T-0381
title: Rank raw difficulty feature contributions for human QA
epic: E22
type: feat
area: pipeline.scoring
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0377]
touch:
  - pipeline/src/wordgame_pipeline/scoring/contributions.py
  - pipeline/tests/scoring/test_contributions.py
  - tasks/T-0381-feature-contributions.md
revision: 1
---

## Goal
Rank raw difficulty feature contributions for human QA. Prepare deterministic offline P2 content QA without asserting production or human approval.

## Current state
The stage's authoritative inputs and pure contracts exist on main. This dedicated read-only diagnostic does not yet exist.

## Specification
- Implement the explicitly named immutable, no-I/O review function with stable output.
- Reject invalid input and never infer thresholds, proof or configuration.
- Do not alter campaign assignments, shipping stages or game content.

## Out of scope
Production content changes, stage activation, AI, publishing, calibration and release locks.

## Tests
- Exact ordered fixture, invalid inputs, deterministic repeatability and immutable results.

## Acceptance
- Full exact-head CI green, scope, and separate review before merge.
