---
id: T-0385
title: Inspect pinned dictionary archive for repeated word rows
epic: E22
type: feat
area: pipeline.ingest
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0127]
touch:
  - pipeline/src/wordgame_pipeline/ingest/inventory.py
  - pipeline/tests/ingest/test_inventory.py
  - tasks/T-0385-ingest-word-inventory.md
revision: 1
---

## Goal
Show duplicate source rows and basic bounds before generating campaign candidates.

## Current state
ingest.source.read_words verifies SJP member count, size and archive SHA256.
It has no frozen, descriptive duplicate-row report.

## Specification
- Accept explicit archive bytes and immutable SourcePin; delegate checksum checks
  to read_words with no extraction or downloads.
- Count source rows, unique spellings, duplicate rows and sorted repeated words.
- Return lengths and source SHA; no removal or normalization of source rows.
- No filesystem writes, network calls or production content modifications.

## Out of scope
Dictionary filtering, tier rules, fetching or licensing changes.

## Tests
- In-memory checksum-pinned ZIP fixture with duplicate rows and different lengths.
- Clean archive, bad checksum, incorrect pin count and wrong types rejected.

## Acceptance
Exact-head CI and independent review.
