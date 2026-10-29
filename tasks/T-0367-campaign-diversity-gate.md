---
id: T-0367
title: Reject campaign repetitions using explicit seed provenance
epic: E22
type: contract
area: pipeline.validate
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0356, T-0366]
touch:
  - pipeline/src/wordgame_pipeline/validate/diversity.py
  - pipeline/tests/validate/test_diversity_gate.py
  - tasks/T-0367-campaign-diversity-gate.md
revision: 1
---

## Goal
Provide a read-only P2 diversity hard gate that rejects campaign multiset, word-set,
crossword spacing and explicit seed-word repetition, without guessing seed provenance.

## Context
- CONTENT.md#hard-validation: no identical letter multiset or word set over threshold.
- CONTENT.md#p1-repetition-spacing: crossword words recur no sooner than 100 slots.
- T-0356 supplies the deterministic pair auditor; no production duplicate thresholds exist.

## Current state
- `dedupe.audit_duplicates(records, policy, config)` returns immutable pair conflicts.
- `content.validate_levels` enforces P1 crossword word spacing, not full P2 diversity.
- No P2 campaign-wide hard-gate adapter currently exists.

## Specification
- Add `validate_campaign_diversity(levels, seed_by_slot, policy, config) -> None`.
- Require nonempty contiguous campaign slot identities and exactly one explicit seed
  word per slot. Never treat the exported integer RNG seed as seed-word evidence.
- Derive selected words only from crossword placements and delegate normalized
  formability, multiset, Jaccard and spacing checks to the existing pair auditor.
- Reject conflicts deterministically by the auditor's first ordered pair and reasons;
  on success return None. Never mutate inputs, save reports or publish content.

## Out of scope
- Runtime/stage activation, production policy thresholds, seed provenance approval,
  daily pool, release lock changes, shipped content, tier/bonus/geometry certification.

## Tests
- A clean two-slot campaign passes independent of input order.
- Multiset, Jaccard, crossword-word and seed-distance conflicts are rejected.
- Missing, duplicate, noncontiguous or malformed slots/seed maps fail.
- Existing pair-audit 99/100 spacing boundary remains demonstrably correct.
- The inputs remain unchanged.

## Acceptance
- Tests pass; full make check, scope check and independent generated review.
- Existing P1 validation/export behavior and all shipped content remain unchanged.

## Rollback
Revert the isolated pure helper, test and task file; there is no persisted state.
