---
id: T-0003
title: Write decision 0001 (engine), status proposed
epic: E00
type: docs
area: docs
risk: medium
executor: human       # done in a Claude Code session Chris started
think: med
ui: none
status: done
depends_on: [T-0002]
touch:
  - docs/decisions/0001-engine.md
  - AGENTS.md
  - tasks/T-0003-*.md
revision: 1
---

<!-- Record only: done on `main` before the task tooling existed. -->

## Goal
The engine choice is written down with the S1 pass and failure criteria fixed before the spike starts,
so T-0013 can pin a version and T-0026 can plan S1 against it.

## Acceptance
- `docs/decisions/0001-engine.md`, status proposed: Godot 4.7 (latest 4.7.y at T-0013, 4.7.2 on
  2026-10-02), typed GDScript, S1 pass criteria P1–P11, failure criteria F1–F4, gate outcomes, plan B
  Unity 6.3 LTS, plugin landscape as input for T-0026.
- `AGENTS.md` names Godot 4.7.
