---
id: T-0370
title: Summarize campaign distribution for review without changing content
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
  - pipeline/src/wordgame_pipeline/qa/__init__.py
  - pipeline/src/wordgame_pipeline/qa/summary.py
  - pipeline/tests/qa/test_summary.py
  - tasks/T-0370-campaign-qa-summary.md
revision: 1
---

## Goal
Provide the first independent read-only slice of ROADMAP T-0303 QA:
campaign composition and difficulty histogram for a review packet.

## Context
- CONTENT.md#qa-sampling requires reviewing onboarding and landmark levels fully.
- CONTENT.md#determinism requires deterministic outputs with no timestamps.
- There are no approved production score thresholds, sampling parameters or launch gates.

## Current state
The shipped campaign exists as validated JSON packs. There is no pipeline QA stage
module. Existing score analysis is offline and not activated by P1 export.

## Specification
- Add pure `summarize_campaign(levels, *, bucket_edges)` for already validated
  campaign level dictionaries; no stage, artifact, or output writes.
- Require contiguous identities 1..N, finite normalized difficulty and explicitly
  supplied histogram edges partitioning [0,1] strictly.
- Report source counts, landmark count, tile-size distribution, selected/bonus
  counts, mean difficulty and half-open histogram with 1 in the final bucket.
- Input ordering must not change output or mutate data. This is descriptive,
  never content approval or a scoring-calibration decision.

## Out of scope
Production difficulty calibration, content changes, AI, export and release locks.

## Tests
- Exact known summary/histogram with 0, boundary .5 and 1.
- Input order independence, deterministic canonical JSON, freshness, nonmutation.
- Invalid scores, edges, missing/duplicate slots and malformed sources fail.

## Acceptance
Full check, scope and independent review. Existing build behavior unchanged.
