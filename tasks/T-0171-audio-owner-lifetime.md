---
id: T-0171
title: Correct the P1 lifecycle plan from runtime evidence
epic: E08
type: docs
area: features.debug
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0170]
touch:
  - docs/qa/T-0170-p1-lifecycle-contract.md
  - tasks/T-017[1-4]-*.md
revision: 2
---

## Goal
Correct false Audio/Haptics defect claims and freeze the owner's approved remaining scope. Still five tasks total, T-0170..T-0174.

## Current state
T-0170 merged; its original null-guard assessment is disproved by Godot4.7.2. PR109 was blocked and closed without merge. Main Audio/Haptics production guards are unchanged, new lifetime tests absent. LevelScreen still routes debug globally; overlay still resumes on individual focus-in/resume notifications.

## Specification
Correct docs/qa/T-0170-p1-lifecycle-contract.md, replace T-0172 with existing-behavior lifetime regression tests only, expand T-0173 to explicit supplied-owner flag/configure_navigation scope, remove T-0174 four-fixes claim. No production or test files in this task; keep stable task paths/IDs/dependencies and human/P2 gates.

## Tests
Verify exact runtime/baseline evidence, current APIs, future paths and revised scopes. Full checks, scope/count/task lint and fresh independent review.

## Acceptance
Full make check, fresh review and final-head12job CI before sequential squash merge. No unproven guard rewrite or human approval inferred.

## Escalation resolution
S4 in revision1: runtime disproved frozen null-guard defect claim. Owner approved concrete corrected five-task scope with "Rób". PR109 discarded; this revision reimplemented on fresh main under the approved documentation scope. Baseline Audio3tests/53assertions pass; standalone compile-failed probe excluded. Project-context asserted probe reproduces the two real defects (debug owner0 instead1; paused pending1 instead0).

## Outcome
Fresh review approved 90ebfe41587eb400717d1fbee15566c86d715034.
Full check:260GUT/13171assertions,311pipeline,183tools,65levels.
Scope5files,count461 unchanged. Final-head12job CI required before merge.
