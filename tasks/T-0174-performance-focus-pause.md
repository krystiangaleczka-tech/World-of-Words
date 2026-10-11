---
id: T-0174
title: Keep diagnostics inactive until pause and focus clear
epic: E08
type: fix
area: features.debug
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0173]
touch:
  - game/features/debug/performance_overlay.gd
  - game/tests/integration/test_performance_focus_pause.gd
  - game/tests/integration/test_performance_focus_pause.gd.uid
  - docs/qa/T-0174-p1-lifecycle-followup.md
  - tasks/T-0174-performance-focus-pause.md
revision: 2
---

## Goal
Keep diagnostics inactive until pause and focus clear. Owner requested another five pre-P2 technical tasks.

## Context
AGENTS.md requires owned signal cleanup and injected services; T-0165 diagnostics exclude background observations. Original Astra P2 ownership requirements and human gates remain separate.

## Current state
PerformanceOverlay _active=true, set_foreground(active: bool), snapshot(), window_closed(record: Dictionary), and _notification use separate one-event booleans; _application_paused/_application_focused do not exist.

## Specification
Implement T-0170 Pause/focus section. Only add two flags and change _notification dispatch. Keep direct set_foreground, snapshot/schema/readout and locale behavior. Document two actual fixes plus existing lifetime regression coverage, corrected false source assumptions, deterministic evidence and remaining human gates.

## Tests
Real Nav/Save/Content/wheel injectedclock+forceddraw: pause→focus-in remains inactive untilresume; focus-out→resume stays inactive untilfocus-in; reverse paired notifications close once and new foreground window excludes background gaps; duplicate notifications preserve pending/history; emission snapshots stable; teardown callbacks disconnected. Use Node.notification public dispatch, no private-field inspection or real time. Full checks/freshreview/CI.

## Acceptance
All specified behavior/tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/phase approval inferred.

## Outcome
Implemented revision 2 independent pause/focus state through notification dispatch only. Five deterministic regression tests / 61 assertions pass; isolated reverted overlay fails four tests / 17 assertions with no script errors. Full make check passes: 275 GUT tests / 13332 assertions, 311 pipeline tests, 183 tools tests, 65 levels. Scope: five allowed files; test count 476 vs 471. Fresh independent review APPROVE on f1a59fec7b398bd5913b630f50e7b3e21f6a0dde; this outcome is metadata only. QA follow-up documents two confirmed fixes, existing lifetime coverage, discarded PR109 and pending human gates. Final-head CI required before squash merge; no phone acceptance or phase gate inferred.
