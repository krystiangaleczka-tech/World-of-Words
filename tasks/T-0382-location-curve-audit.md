---
id: T-0382
title: Audit curve and reservation composition per location
epic: E22
type: feat
area: pipeline.sequence
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0376]
touch:
  - pipeline/src/wordgame_pipeline/sequence/location_audit.py
  - pipeline/tests/sequence/test_location_audit.py
  - tasks/T-0382-location-curve-audit.md
revision: 1
---

## Goal
Audit curve and reservation composition per location. Prepare deterministic offline P2 content QA without asserting production or human approval.

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
