---
id: T-0175
title: Freeze offline outsider playtest evidence wave
epic: E10
type: docs
area: tools
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0174]
touch:
  - docs/qa/T-0175-playtest-evidence-contract.md
  - tasks/T-017[5-9]-*.md
revision: 1
---

## Goal
Freeze offline outsider playtest evidence wave. Owner requested five further tasks; prepare real P1 observations while human phase gates remain pending.

## Context
T-0154 baseline: five outsiders, at least 20 active minutes, no instructions/help, same build, isolated slot-1 campaign, answers/overlays hidden. Astra T-0142 separates deterministic checks from human device/FUN evidence. AGENTS.md requires public behavior tests, bounded scope and independent review.

## Current state
Existing T-0154 baseline specifies five outsider sessions, at least 1200 active seconds, no instructions/help, isolated slot-1 campaigns with answers hidden and exact build/device observations. No tools/playtest_*.py or matching tools/tests/test_playtest_*.py files exist.

## Specification
Freeze the artifact and interfaces in docs/qa/T-0175-playtest-evidence-contract.md and ready tasks T-0176..T-0179. No observed results, gate completion or P2 changes.

## Out of scope
No runtime/save/content changes, personal campaign resets, automatic human judgments, simulated phone results, participant names, new dependencies, secrets or P2 entry.

## Tests
Verify cited baseline, future-file absence, metadata/dependencies/touch allowlists. Full checks and fresh review.

## Acceptance
All specified behavior and tests. Full make check, scope/count, fresh independent review and final-head 12-job successful CI before sequential squash merge. Helpers never close T-0139/T-0140/T-0141/T-0143.

## Outcome
Frozen schema/interfaces and ready tasks T-0176..T-0179, grounded in T-0154. Fresh independent review APPROVE on 1d7ba6e27cbac70bea3d28aa8607725d146f1931. Full make check: 275 GUT /13332 assertions, 311 pipeline, 183 tools, 65 levels. Scope six files; test count476 unchanged. Final-head CI required before merge. No human observations, task gates or phase approval fabricated.
