---
id: T-0176
title: Generate blank outsider session worksheets
epic: E10
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0175]
touch:
  - tools/playtest_worksheet.py
  - tools/tests/test_playtest_worksheet.py
  - tasks/T-0176-playtest-worksheet.md
revision: 1
---

## Goal
Generate blank outsider session worksheets. Owner requested five further tasks; prepare real P1 observations while human phase gates remain pending.

## Context
T-0154 baseline: five outsiders, at least 20 active minutes, no instructions/help, same build, isolated slot-1 campaign, answers/overlays hidden. Astra T-0142 separates deterministic checks from human device/FUN evidence. AGENTS.md requires public behavior tests, bounded scope and independent review.

## Current state
T-0175 contract is merged. tools/playtest_worksheet.py and its test file do not exist.

## Specification
Implement build_worksheet() -> dict and render_worksheet() -> str, deterministic JSON for five P01..P05 sessions per contract. New objects on every call. All observed/build fields null; notes empty string. No CLI yet.

## Out of scope
No runtime/save/content changes, personal campaign resets, automatic human judgments, simulated phone results, participant names, new dependencies, secrets or P2 entry.

## Tests
Five unique IDs, exact keys/schema, all observation fields blank, repeated output deterministic, escaped JSON/newlines, deep independence, JSON roundtrip. No fabricated evidence.

## Acceptance
All specified behavior and tests. Full make check, scope/count, fresh independent review and final-head 12-job successful CI before sequential squash merge. Helpers never close T-0139/T-0140/T-0141/T-0143.
