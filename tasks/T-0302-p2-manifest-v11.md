---
id: T-0302
title: Generate explicitly authored P2 region/location manifest metadata
epic: E22
type: contract
area: pipeline.export
risk: high
executor: sol
think: high
ui: none
status: blocked
depends_on: [T-0301, T-0238]
touch:
  - pipeline/src/wordgame_pipeline/export/p2_manifest.py
  - pipeline/tests/export/test_p2_manifest.py
  - tasks/T-0302-p2-manifest-v11.md
revision: 1
---

## Goal
Build additive manifest 1.1 region, location, postcard and landmark metadata
from a trusted complete `SlotPlan` and explicitly editor-provided assets and
translation keys. Preserve the base manifest, pack bytes, content hashes, and
release slot geometry. No guessed names/facts/assets.

## Specification
Use the canonical manifest schema and existing semantic partition validator.
Reject missing or extra authoring metadata, unsafe asset names, nonmatching
planned total, preexisting metadata and layout gaps. Do not write files.
Existing `release_apply.py` (T-0366) already owns reviewed atomic release-lock
updates; do not duplicate this dangerous operation or create release baselines.

## Tests
Real 65-slot P1 manifest is used as an unchanged fixture, with explicitly
supplied **test-only** region names/postcard paths. Assert exact partition,
schema validation, input immutability and malformed key/path rejection.

## Blockers
Manifest production export integration, actual 200-level build and genuine
region assets still require T-0301, T-0305, T-0306, human review and signed
release decision. PR stays draft until dependencies, exact-head CI and
independent review pass.
