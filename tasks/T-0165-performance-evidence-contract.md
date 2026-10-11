---
id: T-0165
title: Freeze device performance evidence wave
epic: E08
type: docs
area: features.debug
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0164]
touch:
  - docs/qa/T-0165-performance-evidence-contract.md
  - tasks/T-016[5-9]-*.md
revision: 1
---

## Goal
Freeze device performance evidence wave. Owner requested five more technical tasks before pending P2 human gates.

## Context
Astra Q3 in docs/qa/T-0142-architecture-preflight.md accepts the P1 allocation exception and requires actual device observations; no speculative wheel rewrite.

## Current state
Existing debug performance metrics expose fps, mean_ms, max_ms, samples, pending and dropped; overlay probes wheel draw/post_draw and resets on navigation/focus. Future metrics/tests/report modules do not exist.

## Specification
Freeze docs/qa/T-0165-performance-evidence-contract.md and ready tasks T-0166..T-0169 with exact additive APIs, scopes and tests. Preserve Astra Q3 boundaries and human phase gates.

## Tests
Verify cited existing APIs and future-path absence, task metadata/dependencies/allowlists; full checks and independent review.

## Acceptance
All behavior and tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/device/FUN GATE approval invented.

## Outcome
Fresh independent review approved 098ff061e78458858bf84db62c8be294d2676934.
Full check: 247 GUT /13049 assertions, 311 pipeline, 142 tools,65levels.
Scope six files; test count440 unchanged. Final-head CI required before merge.
