---
id: T-0386
title: Audit missing, zero and low ARF evidence for selected Polish words
epic: E22
type: feat
area: pipeline.annotate
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0354]
touch:
  - pipeline/src/wordgame_pipeline/annotate/coverage.py
  - pipeline/tests/annotate/test_coverage.py
  - tasks/T-0386-annotation-arf-coverage.md
revision: 1
---

## Goal
Give scoring and human reviewers a deterministic exact-form ARF evidence summary.

## Current state
annotate.frequency.Frequency records exact ARF/IPM values and missing source
evidence uses None. There is no independent source coverage review record.

## Specification
- Accept complete distinct normalized word keys, exact Frequency/None mapping,
  explicit LanguageConfig and nonnegative finite low-ARF threshold.
- Separate no evidence, known zero and values at or below the cutoff.
- Return sorted frozen records. Do not infer lemma, classification or frequency.
- Never fetch sources or alter any production calibration.

## Out of scope
Tier assignment, dictionary filtering, AI calls and content writes.

## Tests
- Mixed missing/zero/low/normal frequencies, deterministic ordering and empty case.
- Invalid keys, metrics, duplicates and thresholds fail.

## Acceptance
Exact-head CI and independent review.
