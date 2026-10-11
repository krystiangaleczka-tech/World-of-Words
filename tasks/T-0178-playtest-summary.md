---
id: T-0178
title: Summarize session completeness and protocol deviations
epic: E10
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0177]
touch:
  - tools/playtest_summary.py
  - tools/tests/test_playtest_summary.py
  - tasks/T-0178-playtest-summary.md
revision: 1
---

## Goal
Summarize session completeness and protocol deviations. Owner requested five further tasks; prepare real P1 observations while human phase gates remain pending.

## Context
T-0154 baseline: five outsiders, at least 20 active minutes, no instructions/help, same build, isolated slot-1 campaign, answers/overlays hidden. Astra T-0142 separates deterministic checks from human device/FUN evidence. AGENTS.md requires public behavior tests, bounded scope and independent review.

## Current state
T-0177 validator provides validate_worksheet and parse_worksheet. Summary module and tests do not exist.

## Specification
Implement build_summary(document: dict) -> dict and render_summary(document: dict) -> str per contract. Validate first; preserve separate missing fields and observed protocol deviations, exact build comparison, raw observations and aggregate counts. Deterministic JSON and escaped Markdown; no pass/go/qualifying or gate conclusion.

## Out of scope
No runtime/save/content changes, personal campaign resets, automatic human judgments, simulated phone results, participant names, new dependencies, secrets or P2 entry.

## Tests
Blank, partial, complete five-session records, early exit, assistance, insider, campaign/start/answer deviations, missing and mismatched build identity, unknown versus no word/no stalls, counts, zero duration, special Markdown characters, invalid data reject, deterministic output and no mutation.

## Acceptance
All specified behavior and tests. Full make check, scope/count, fresh independent review and final-head 12-job successful CI before sequential squash merge. Helpers never close T-0139/T-0140/T-0141/T-0143.
