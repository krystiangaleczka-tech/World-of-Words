---
id: T-0004
title: Write decision 0002 (content in packs, no runtime dictionary)
epic: E00
type: docs
area: docs
risk: low
executor: human       # done in a Claude Code session Chris started
think: low
ui: none
status: done
depends_on: [T-0002]
touch:
  - docs/decisions/0002-content-in-packs.md
  - tasks/T-0004-*.md
revision: 1
---

<!-- Record only: done on `main` before the task tooling existed. -->

## Goal
The rule "the game has no dictionary; every level carries its complete bonus list" is a decision record
that CONTENT.md, the schemas and the Content autoload build on.

## Acceptance
- `docs/decisions/0002-content-in-packs.md`, status accepted (planner; Chris confirms with docs v1 in
  T-0011): no runtime dictionary, complete bonus lists, packs + manifest, generated content only,
  released-slot policy, bundled packs in v1, daily pool format.
