---
id: T-0300
title: Bind explicit difficulty curve and immutable allocation to campaign locations
epic: E22
type: feat
area: pipeline.sequence
risk: medium
executor: sol
think: high
ui: none
status: blocked
depends_on: [T-0299, T-0238]
touch:
  - pipeline/src/wordgame_pipeline/sequence/campaign.py
  - pipeline/tests/sequence/test_campaign.py
  - tasks/T-0300-sequence-campaign-preview.md
revision: 1
---

## Goal
Map existing validated T-0357..T-0360 region/curve/slot allocations to a
deterministic, immutable per-location preview. Preserve all authored/released
reservations and reject any missing/duplicate candidates via the allocator.

## Specification and tests
Expose slot, region, location, fixed/generated mode, exact candidate ID,
explicit normalized difficulty and curve target/kind. Do not activate P1
export, write content, supply unapproved `curve.yaml` parameters or infer
human release acceptance. Regression fixtures preserve onboarding1–15,
location boundaries, deterministic candidate-order independence and failure
on missing reserved candidates.

## Blockers
T-0299 and approved P2 scoring/curve/landmark content are pending. This is
read-only planning and remains draft/blocked until real owner-reviewed inputs,
full CI and independent review. P2 export and release gates are later tasks.
