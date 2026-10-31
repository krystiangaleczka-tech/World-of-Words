---
id: T-0386
title: Fingerprint pinned morphology and frequency source evidence
epic: E22
type: feat
area: pipeline.annotate
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0127]
touch:
  - pipeline/src/wordgame_pipeline/annotate/fingerprint.py
  - pipeline/tests/annotate/test_fingerprint.py
  - tasks/T-0386-annotation-fingerprint.md
revision: 1
---

## Goal
Fingerprint pinned morphology and frequency source evidence. Provide readonly, stable P2 production content provenance and review evidence.

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
