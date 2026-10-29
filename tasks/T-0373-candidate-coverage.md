---
id: T-0373
title: Report available wheel supply before production content selection
epic: E22
type: feat
area: pipeline.candidates
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0127, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/candidates/coverage.py
  - pipeline/tests/candidates/test_coverage.py
  - tasks/T-0373-candidate-coverage.md
revision: 1
---

## Goal
Expose exact tier-backed wheel supply and shortages for planning P2 production
without approving or selecting a candidate.

## Context
- CONTENT.md#pipeline: candidate generation groups normalized wheel multisets.
- T-0299/T-0300 production assignment and calibration remain separate.
- No paid AI, new source, default content target or pipeline stage is allowed.

## Current state
WordIndex.automatic() enumerates stable seed-eligible multisets, each with
seeds, level_ok and bonus_ok pools; no summary of pool sufficiency exists.

## Specification
- audit_candidate_coverage(index, *, minimum_words) returns immutable
  CoverageReport, sorted wheel-size counts, eligible total and shortages.
- The caller explicitly supplies the positive minimum selected-word count.
- Every candidate is counted once regardless of multiple seed anagrams.
- Shortages contain candidate identity, wheel size, seed and tier pool counts.
- No input mutation, filesystem writes, hidden defaults or content generation.

## Out of scope
Tier overrides, source acquisition, actual levels, sequencing and release.

## Tests
- Two seeds sharing one wheel count once; one-word wheels are flagged.
- Bonus-only source produces zero candidate wheels.
- Stable sorted output and invalid parameters rejected.

## Acceptance
Exact-head CI, scope, independent review. Existing P1 output unchanged.
