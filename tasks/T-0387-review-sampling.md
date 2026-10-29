---
id: T-0387
title: Build an explicit protected and flagged human review slot sample
epic: E22
type: feat
area: pipeline.qa
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0376]
touch:
  - pipeline/src/wordgame_pipeline/qa/sample.py
  - pipeline/tests/qa/test_sample.py
  - tasks/T-0387-review-sampling.md
revision: 1
---

## Goal
Build an explicit protected and flagged human review slot sample. Provide readonly, stable P2 production content provenance and review evidence.

## Current state
Authoritative pinned source or content planning contracts already exist on main. This dedicated diagnostic is not yet implemented.

## Specification
- Implement the named pure/read-only audit interface with explicit verified inputs.
- Reject malformed evidence rather than assuming approval. Preserve stable output.
- Do not make external calls, write production files, change stages or infer release permission.

## Out of scope
Content production, AI requests, network downloads, stage activation and publication.

## Tests
- Exact fixture behavior, deterministic outputs, malformed inputs, no mutation/writes.

## Acceptance
- Full exact-head CI, scope and fresh review before squash merge.
