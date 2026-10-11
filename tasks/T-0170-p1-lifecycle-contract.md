---
id: T-0170
title: Freeze bounded P1 lifecycle corrections
epic: E08
type: docs
area: features.debug
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0169]
touch:
  - docs/qa/T-0170-p1-lifecycle-contract.md
  - tasks/T-017[0-4]-*.md
revision: 1
---

## Goal
Freeze bounded P1 lifecycle corrections. Owner requested another five pre-P2 technical tasks.

## Context
AGENTS.md requires owned signal cleanup and injected services; T-0165 diagnostics exclude background observations. Original Astra P2 ownership requirements and human gates remain separate.

## Current state
Audio configure/_volume/_disconnect_settings and HapticsListener dependency checks use null comparisons; LevelScreen _on_debug calls global Nav despite configure_navigation; PerformanceOverlay notifications map focus-in/resume individually to active=true. No future test files exist.

## Specification
Freeze the four correction sections in docs/qa/T-0170-p1-lifecycle-contract.md and ready tasks T-0171..T-0174, with bounded exact existing-function edits and new tests.

## Tests
Verify actual functions/fields/signatures/behaviors, future-path absence, metadata/dependencies/scopes; full checks and fresh independent review.

## Acceptance
All specified behavior/tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/phase approval inferred.

## Outcome
Fresh review approved 8e2f1024186495e07bbf35b491cf3f3f727b1815.
Full make check:260GUT /13171assertions,311pipeline,183tools,65levels.
Scope6files,count461 unchanged. Final-head CI required before merge.
