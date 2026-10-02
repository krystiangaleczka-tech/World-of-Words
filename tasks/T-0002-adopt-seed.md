---
id: T-0002
title: Adopt the seed (AGENTS.md, templates, PR template) and write epics E00–E04
epic: E00
type: docs
area: docs
risk: low
executor: human       # done in a Claude Code session Chris started
think: med
ui: none
status: done
depends_on: [T-0001]
touch:
  - AGENTS.md
  - CLAUDE.md
  - GEMINI.md
  - .github/pull_request_template.md
  - tasks/TEMPLATE.md
  - tasks/EPIC_TEMPLATE.md
  - tasks/epics/E0*.md
  - tasks/T-0001-*.md
  - tasks/T-0002-*.md
  - tasks/ROADMAP.md
revision: 1
---

<!-- Record only: done on `main` before the task tooling existed. -->

## Goal
Agents find their rules at the repo root, and Sol has a task template, an epic template and a PR
template that match PRODUCT.md, DESIGN.md and ROADMAP.md v2.

## Acceptance
- `AGENTS.md` from `docs/design-pass/seed/AGENTS.md`, updated for the v1 docs (source-of-truth table,
  who does what, PRODUCT.md as the canonical key list, plural-free strings, DESIGN.md rules for UI).
- `CLAUDE.md` and `GEMINI.md` point to `AGENTS.md`.
- `tasks/TEMPLATE.md` adds `think` and `ui` from the ROADMAP row; `tasks/EPIC_TEMPLATE.md` unchanged
  from the seed; `.github/pull_request_template.md` cites `DESIGN.md#pr-screenshot-rules`.
- `tasks/epics/E00`–`E04` written from the ROADMAP rows.
- ROADMAP: step 3 copies `think` and `ui`; T-0013 depends on T-0003, because it pins the Godot version
  decision 0001 names.
