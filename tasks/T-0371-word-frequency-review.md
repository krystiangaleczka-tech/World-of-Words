---
id: T-0371
title: Flag low-frequency and missing-evidence crossword words
epic: E22
type: feat
area: pipeline.scoring
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0354, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/scoring/word_review.py
  - pipeline/tests/scoring/test_word_review.py
  - tasks/T-0371-word-frequency-review.md
revision: 1
---

## Goal
Prepare deterministic, auditable exact-form word flags for human production QA
(ROADMAP T-0303). Missing evidence never silently becomes a frequency of zero.

## Context
- CONTENT.md#qa-sampling: unusual level words require a human QA queue.
- T-0354: frequencies are exact selected-form ARF, nullable when unknown.
- T-0296 classification, T-0297 overrides and production thresholds remain gated.

## Current state
Raw scoring accepts explicit form-to-ARF values; no word-level QA triage helper
exists. There is no approved unusual-word threshold.

## Specification
- Add `flag_word_evidence(levels, frequencies, *, low_arf, limit)` returning
  immutable WordReviewFlag records (slot, word, reason, arf).
- Require complete campaign identities, finite valid nonnegative ARF evidence,
  explicit threshold and positive count cap, exact matching selected-form keys.
- Flag unknown frequency separately from known low frequency including zero;
  known cutoff equality counts as low. All source values are validated before
  truncation, with deterministic missing-first, ARF, slot, word ordering.
- Never infer lemmas, banned words, model classifications or human approval.

## Out of scope
Source acquisition, classifier/API calls, overrides, tier changes, content writes.

## Tests
- Known0 vs missing, threshold equality, order and cap semantics.
- Nonmutation, frozen records, empty result when all evidence is above threshold.
- Reject malformed slots, source maps, values, duplicate words, unapproved flags.

## Acceptance
Full check, scope and independent review. P1 output remains identical.
