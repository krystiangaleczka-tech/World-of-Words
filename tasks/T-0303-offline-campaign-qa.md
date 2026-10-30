---
id: T-0303
title: Produce deterministic P2 offline campaign QA and unresolved lexical review report
epic: E22
type: feat
area: pipeline.qa
risk: low
executor: sol
think: medium
ui: none
status: blocked
depends_on: [T-0302]
touch:
  - pipeline/src/wordgame_pipeline/qa/p2_report.py
  - pipeline/tests/qa/test_p2_report.py
  - tasks/T-0303-offline-campaign-qa.md
revision: 1
---

## Goal
Prepare human-readable/mechanical campaign QA evidence: slots, word and
bonus totals, wheel-size histogram, explicit difficulty histogram, hardest
slots and lexical uncertainty flags from T-0296. Never guess subjective
weirdness or convert missing source evidence into safety approval.

## Specification
Consume canonical T-0296 review JSON and already validated campaign levels.
Reject false `semantic_approval_inferred`, unsorted/duplicate review rows
and malformed score/slot evidence. Emit sorted canonical JSON with source
hash and explicit scope `offline_review_not_release_approval`.

## Tests and blockers
Deterministic input reorder, histogram boundaries, hardest slots, source
flags, failed input and no fabricated human approval. No player runtime.
Production output still depends on actual T-0302 exporter and T-0304/T-0305
human review. Task blocked, PR draft pending exact-head CI and independent
review.
