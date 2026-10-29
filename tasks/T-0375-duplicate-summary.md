---
id: T-0375
title: Summarize duplicate reasons and affected candidate identities
epic: E22
type: feat
area: pipeline.dedupe
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0356, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/dedupe/summary.py
  - pipeline/tests/dedupe/test_summary.py
  - tasks/T-0375-duplicate-summary.md
revision: 1
---

## Goal
Provide a deterministic content-review summary of campaign and daily
candidate conflict reasons, without deleting any candidates.

## Context
- CONTENT.md#hard-validation: multiset/Jaccard and repeated word rules.
- T-0356 provides the authoritative explicit pairwise conflict auditor.

## Current state
dedupe.audit_duplicates returns ordered immutable pair conflicts;
no aggregate conflict counts or affected identity summary exists.

## Specification
- summarize_duplicate_conflicts(records, policy, config) must call the existing
  authoritative auditor and reject its invalid inputs unchanged.
- Return immutable total compared pairs, conflicting pairs, counts in the
  canonical four-reason order, unique sorted affected IDs and maximum Jaccard.
- Include zero counts for absent reasons; empty lists produce a zero summary.
- No stage activation, policy inference, filtering, content writes or mutation.

## Out of scope
Daily timestamp policy, production thresholds, resequencing or approval.

## Tests
- One pair with all four causes, another unrelated candidate, exact totals.
- Reordering and frozen output; no conflict and empty inputs.
- Cross-pool reasons and invalid records/policy/config.

## Acceptance
Full exact-head CI, scope and independent review.
