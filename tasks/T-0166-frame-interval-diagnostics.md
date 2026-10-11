---
id: T-0166
title: Measure foreground frame intervals
epic: E08
type: feat
area: features.debug
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0165]
touch:
  - game/features/debug/performance_metrics.gd
  - game/tests/integration/test_frame_metrics.gd
  - game/tests/integration/test_frame_metrics.gd.uid
  - tasks/T-0166-frame-interval-diagnostics.md
revision: 1
---

## Goal
Measure foreground frame intervals. Owner requested five more technical tasks before pending P2 human gates.

## Context
Astra Q3 in docs/qa/T-0142-architecture-preflight.md accepts the P1 allocation exception and requires actual device observations; no speculative wheel rewrite.

## Current state
performance_metrics.gd provides record_input, mark_drawn, frame_post_draw, reset and snapshot; no frame interval test file exists.

## Specification
Implement the T-0165 Frame intervals section. Preserve input consumption, existing snapshot meanings and fixed storage; add exactly frame_intervals, frame_mean_ms, frame_max_ms, frame_budget_usec and frame_over_budget. Nonpositive intervals ignore anchor updates. No core/public gameplay changes.

## Tests
Injected timestamps: unavailable initial/first frame, exact and above budget, uneven intervals with exact mean/max/FPS, equal/backwards stamps, reset and unchanged draw/pending behavior. No real clocks or sleeps.

## Acceptance
All behavior and tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/device/FUN GATE approval invented.

## Outcome
Fresh independent review approved 6351db35be4813dbb5e8bc151b8c4409e35f6ef1.
Full make check:251 GUT /13086assertions,311pipeline,142tools,65levels.
Scope four files; count444 vs440. Final-head CI required before merge.
