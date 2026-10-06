---
id: T-0045
title: Freeze the E04 dry-run wave and reconcile merged task statuses
epic: E04
type: docs
area: docs
risk: low
executor: sol
think: med
ui: none
status: done
depends_on: [T-0044, T-0039, T-0042, T-0025]
touch:
  - tasks/T-0046-fake-haptics.md
  - tasks/T-0047-config-registry-bounds.md
  - tasks/T-0048-debug-shell.md
  - tasks/T-0049-shuffle.md
  - tasks/epics/E04-workflow-dry-run.md
  - docs/qa/E04-dry-run-plan.md
  - tasks/T-0025-review-pack.md
  - tasks/T-0026-s1-plan.md
  - tasks/T-0032-generator-prototype.md
  - tasks/T-0053-s2-independent-measurement.md
  - tasks/T-0045-dry-run-plan.md
revision: 1
---

## Goal
Freeze four small E04 task files against the integrated E03 skeleton and release runnable work
with `tools/tasks.py plan`. Reconcile completed-task metadata with verified main commits so the
scheduler sees the actual repository state.

## Context
- `docs/design-pass/05-workflow-ai.md#1-hierarchia-pracy`: detailed tasks use fresh main for the current wave.
- `docs/design-pass/06-standard-taskow.md#4-przykład-poprawiony-task042-shuffle`: freeze the pure shuffle contract.
- `docs/DESIGN.md#rules-quote-these-into-ui-tasks`: "A screen task may not create a component."
- ROADMAP T-0045 and epic E04; Chris requests sequential execution and an audit of completed tasks.

## Current state
- T-0042 and T-0044 are integrated; T-0039 and T-0025 tooling exist on main.
- T-0025, T-0026, T-0032 and T-0053 have verified merge commits but stale `review` statuses.
- `tools/tasks.py plan` selects ready tasks with done dependencies and disjoint areas/touch globs.
- No E04 implementation task files exist. No UI components/tokens, Nav debug entrypoint or Save reset API exist.

## Specification
1. Change only the four verified merged tasks' status fields to `done`; preserve their frozen bodies.
2. Write T-0046/T-0047/T-0049 as ready tasks with exact APIs, concrete cases and narrow scopes.
3. Write T-0048 as blocked with the missing prerequisite contracts and R-UI-1/S1/S3/S4 evidence.
   Do not invent a screen's components or reset persistent data in the planning task.
4. Record merge evidence, preflight, scheduling output and the blocker in the QA plan.
5. Update E04 to describe sequential execution requested by Chris and the blocked UI lane.
   Classify T-0049 medium under the template's new-core-logic rule; keep the other runnable lanes low.
6. With this planning task done, `tools/tasks.py plan` releases exactly T-0046, T-0047 and T-0049.

## Out of scope
Production implementation, roadmap edits, phase exit, changes to merged task specifications,
component/token or Save contracts, fake model/device review evidence.

## Acceptance
`tasks.py lint`, `tasks.py plan`, scope validation and `make check` pass. Four task files exist;
three are runnable and T-0048 has a concrete escalation. No Phase 0 exit is claimed.
