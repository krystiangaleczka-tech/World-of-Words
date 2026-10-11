---
id: T-0177
title: Validate operator-supplied outsider observations
epic: E10
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0176]
touch:
  - tools/playtest_validation.py
  - tools/tests/test_playtest_validation.py
  - tasks/T-0177-playtest-validation.md
revision: 1
---

## Goal
Validate operator-supplied outsider observations. Owner requested five further tasks; prepare real P1 observations while human phase gates remain pending.

## Context
T-0154 baseline: five outsiders, at least 20 active minutes, no instructions/help, same build, isolated slot-1 campaign, answers/overlays hidden. Astra T-0142 separates deterministic checks from human device/FUN evidence. AGENTS.md requires public behavior tests, bounded scope and independent review.

## Current state
T-0176 tools/playtest_worksheet.py provides build_worksheet and render_worksheet; validator and its tests do not exist.

## Specification
Implement parse_worksheet(text: str) -> dict and validate_worksheet(document: object) -> None per contract. Accept null/partial/early exit/assisted sessions as observations. Reject duplicate/unknown keys, wrong types, duplicate IDs, invalid dates/hashes/counts and nonfinite values. No mutation or gate verdict.

## Out of scope
No runtime/save/content changes, personal campaign resets, automatic human judgments, simulated phone results, participant names, new dependencies, secrets or P2 entry.

## Tests
Blank/partial/full packets accepted; duplicates at top/nested JSON rejected; required keys, ID/date/hash syntax, true versus numeric, finite refresh, duration/slot bounds, malformed text, cardinality, help/early exits accepted, input independence. Error paths identify the field/session.

## Acceptance
All specified behavior and tests. Full make check, scope/count, fresh independent review and final-head 12-job successful CI before sequential squash merge. Helpers never close T-0139/T-0140/T-0141/T-0143.
