---
id: T-0382
title: Summarize onboarding, landmark and breather coverage per location
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
  - pipeline/src/wordgame_pipeline/sequence/phase_coverage.py
  - pipeline/tests/sequence/test_phase_coverage.py
  - tasks/T-0382-curve-phase-coverage.md
revision: 1
---

## Goal
Give reviewers explicit location-level counts of protected/curve slot types.

## Current state
SlotPlan.requirement(slot) identifies region, location, authored/released
state and onboarding/regular/landmark/breather kind.

## Specification
- Accept a reviewed inclusive window of at most 10,000 slots.
- Aggregate only authoritative slot requirements by region/location.
- Count all four kinds, authored and released flags, preserve slot bounds.
- Immutable deterministic output, no assignment or approval.

## Out of scope
Production curve calibration, content writes, release boundaries.

## Tests
- Location partition including authored landmark and breather.
- Released onboarding prefix, deterministic repeatability and invalid ranges.

## Acceptance
Exact-head CI and independent review.
