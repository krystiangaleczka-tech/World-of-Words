---
id: T-0381
title: Rank candidate identities most affected by duplicate conflicts
epic: E22
type: feat
area: pipeline.dedupe
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0375]
touch:
  - pipeline/src/wordgame_pipeline/dedupe/hotspots.py
  - pipeline/tests/dedupe/test_hotspots.py
  - tasks/T-0381-duplicate-hotspots.md
revision: 1
---

## Goal
Give human content reviewers a reproducible priority queue for duplicate repair.

## Current state
Authoritative dedupe.audit_duplicates returns immutable conflict pairs;
T-0375 reports aggregate conflict reasons, but not per-candidate peer counts.

## Specification
- Call the full existing duplicate auditor with explicit policy/config.
- Count distinct peer identities per candidate, not overlapping reasons.
- Rank descending peer count then identity. Report peers and sorted reason set.
- Do not filter, rewrite, resequence or publish any level.

## Out of scope
Automatic repairs, source changes, campaign content, scoring calibration.

## Tests
- Multiple overlapping conflicts count unique peers.
- Stable ordering, empty/singleton and invalid records.

## Acceptance
Exact-head CI and independent fresh-chat review.
