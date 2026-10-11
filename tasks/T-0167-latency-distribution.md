---
id: T-0167
title: Measure recent input latency percentiles
epic: E08
type: feat
area: features.debug
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0166]
touch:
  - game/features/debug/performance_metrics.gd
  - game/tests/integration/test_latency_distribution.gd
  - game/tests/integration/test_latency_distribution.gd.uid
  - tasks/T-0167-latency-distribution.md
revision: 1
---

## Goal
Measure recent input latency percentiles. Owner requested five more technical tasks before pending P2 human gates.

## Context
Astra Q3 in docs/qa/T-0142-architecture-preflight.md accepts the P1 allocation exception and requires actual device observations; no speculative wheel rewrite.

## Current state
T-0166 frame fields exist; input queue capacity512 and cumulative sample/mean/max semantics exist; no latency distribution test file exists.

## Specification
Implement the T-0165 Recent input distribution section, adding latency_window_samples/p50_ms/p95_ms. Fixed preallocated consumed-duration ring512, allocation only in snapshot. Preserve draw boundary, pending overflow and cumulative metrics.

## Tests
No-sample vs valid zero; nearest rank for known unsorted inputs; partial-draw coalescing excludes pending; >512 consumed events proves recent percentiles differ from cumulative mean/max; snapshot repeat/nonmutation, reset and pending overflow.

## Acceptance
All behavior and tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/device/FUN GATE approval invented.
