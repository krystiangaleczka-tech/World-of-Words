---
id: T-0393
title: Review tier decision reasons and manual overrides
epic: E22
type: feat
area: pipeline.tiers
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0366]
touch:
  - pipeline/src/wordgame_pipeline/tiers/reason_review.py
  - pipeline/tests/tiers/test_reason_review.py
  - tasks/T-0393-tier-reason-review.md
revision: 1
---

## Goal
Make tier decision reasons and overridden forms visible for human P2 QA.

## Current state
assign_tiers already produces explicit tier and tier_reason metadata per word,
but there is no separate immutable aggregate review view.

## Specification
- Implement readonly review_tier_reasons(records, config).
- Validate every normalized word, unique identity, known tier and known
  decision reason, without inferring missing evidence.
- Return frozen ordered tier/reason counts and sorted forms marked as override.
- No override writes, tier reclassification, human approval or source calls.

## Out of scope
Classification changes, AI, source download and production publish gates.

## Tests
Exact known reason counts, override inventory, record order independence,
empty input and malformed evidence.

## Acceptance
Full CI green, scope and independent review.
