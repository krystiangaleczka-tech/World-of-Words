---
id: T-0378
title: Compose deterministic read-only P2 quality dossier
epic: E22
type: feat
area: pipeline.qa
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0373, T-0374, T-0375, T-0376, T-0377]
touch:
  - pipeline/src/wordgame_pipeline/qa/__init__.py
  - pipeline/src/wordgame_pipeline/qa/dossier.py
  - pipeline/tests/qa/test_dossier.py
  - tasks/T-0378-qa-dossier.md
revision: 1
---

## Goal
Collect independent campaign planning diagnostics into a canonical, auditable
read-only report without mistaking diagnostic coverage for content approval.

## Current state
Merged T-0373..T-0377 expose immutable coverage, geometry, dedupe, curve
and score-drift records. There is no merged QA dossier package.

## Specification
- Accept exactly the typed objects from T-0373..T-0377 and produce canonical
  JSON-compatible report data with no file writes.
- Enforce increasing unique curve slots and stable score-shift ranking.
- Include all five evidence sections and explicit 'not-established' approval.
- Preserve input evidence; each call returns fresh nested data.

## Out of scope
AI, publish/release, scoring calibration, P1 runtime, missing human approvals.

## Tests
- Canonical deterministic bytes, complete sections and nonmutation.
- Reject malformed evidence, wrong order and false inferred approval.

## Acceptance
Exact-head CI and independent review before squash merge.
