---
id: T-0005
title: Write decision 0003 (local device date for daily and streak)
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
  - docs/decisions/0003-local-date.md
  - tasks/T-0005-*.md
revision: 1
---

<!-- Record only: done on `main` before the task tooling existed. -->

## Goal
Day boundaries for daily and streak are a written decision with defined (not "safe") edge behaviour.

## Acceptance
- `docs/decisions/0003-local-date.md`, status accepted (planner; Chris confirms in T-0011).
