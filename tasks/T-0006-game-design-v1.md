---
id: T-0006
title: Write GAME_DESIGN.md v1 from PRODUCT.md
epic: E00
type: docs
area: docs
risk: medium
executor: human       # done in a Claude Code session Chris started
think: high
ui: low
status: done
depends_on: [T-0002]
touch:
  - docs/GAME_DESIGN.md
  - tasks/ROADMAP.md
  - tasks/epics/E03-*.md
  - tasks/T-0006-*.md
revision: 1
---

<!-- Record only: done on `main` before the task tooling existed. -->

## Goal
Every `GAME_DESIGN.md#…` anchor PRODUCT.md cites exists, with testable rules, and every config key has
a default, type, range and owner.

## Acceptance
- All 16 cited anchors exist; canonical timeline defaults copied unchanged; registry of 42 keys.
- Starting values and intents are marked as proposals for Chris (T-0011). Q2–Q5 drafted with
  recommendations.
- ROADMAP T-0037 / T-0047 and E03: first config files are `unlocks.json` and `hint.json` (no `level.*`
  config keys exist).
