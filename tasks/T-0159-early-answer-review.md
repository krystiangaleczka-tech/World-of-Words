---
id: T-0159
title: Check reviewed familiarity of early required answers on demand
epic: E08
type: feat
area: content.pl
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0158]
touch:
  - pipeline/src/wordgame_pipeline/familiarity_report.py
  - pipeline/tests/test_early_answer_review.py
  - docs/qa/T-0159-early-answer-review.md
  - tasks/T-0159-early-answer-review.md
revision: 1
---

## Goal
Offer an explicit offline early-answer readiness check that requires actual
curator-reviewed familiar words, while keeping optional bonus eligibility intact.

## Current state
- T-0158 build_report emits deterministic required-answer annotations and receipts.
- Current catalog contains proposals only; p1.build/check do not consume it.
- The new gate test and QA note do not exist.

## Specification
Add early_issues(report: dict, slots: int = 15, max_band: int = 2) -> list[dict].
Reject bool/noninteger/out-of-range slots (1..level count) or band (1..5).
For required words in first slots, return ordered slot/id/word/reason records:
missing, proposed, unknown_band or above_max_band. Only reviewed words with band
<= threshold pass. Proposed easy ratings still fail; hard valid bonuses never
enter this check. No current catalog rows are relabeled or assigned approvals.
Extend report CLI with --check-early, --early-slots (15), --max-band (2).
Default report CLI remains unchanged. With check enabled emit canonical JSON
including early_check configuration/issues, return 0 iff issues empty, else 1.
Reject threshold options without --check-early. Document current proposal-only
check as expected NOT READY; this is separate from successful engineering CI.
Do not integrate into make check, existing exporter/runtime or phase gates.

## Tests
New test_early_answer_review.py: reviewed easy pass, reviewed hard fail, proposed
easy fail, missing/unknown fail, later hard word excluded, bonus unaffected,
threshold bounds/types, stable ordering, report unmodified, default CLI backward
compatibility and gate CLI exit/JSON (including actual proposal-only campaign).

## Acceptance
Useful auditable gate/report plus meaningful tests, full make check, fresh review,
scope/count and green CI. No claim of editorial or P2 readiness is inferred.
