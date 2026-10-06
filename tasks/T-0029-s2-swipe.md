---
id: T-0029
title: Execute S2 swipe feel spike
epic: E02
type: spike
area: level.wheel
risk: medium
executor: cheap
think: high
ui: high
status: done
depends_on: [T-0014]
touch:
  - spikes/s2-swipe/**
  - docs/spikes/S2-swipe.md
  - tasks/T-0029-*.md
revision: 1
---
## Goal
Build a disposable Godot 4.7.2 letter wheel for the Galaxy A15 so Chris can judge swipe latency
and haptic feel before production wheel code exists.

## Context
- PRODUCT.md FR-WHEEL-02 / NFR-01: next-frame line/selection, no per-frame allocations or perceived lag.
- DESIGN.md#letterwheelview: raw touch/drag, enlarged hit radius, backtrack, second finger ignored, haptic.
- TESTING.md: Samsung Galaxy A15 is the low-end Android for swipe-latency review.
- Roadmap T-0029 / design-pass 11 section 4: S2 is a throwaway device-rated wheel.

## Current state
T-0014 pins Godot 4.7.2 and Android export templates. T-0012 has no task file, but TESTING.md records
its accepted Galaxy A15 decision. No S2 project/report exists.

## Specification
1. Keep the spike under `spikes/s2-swipe/`; do not touch `game/`.
2. Use raw screen touch/drag and one active finger.
3. Cache the finger; `_process` mutates only the existing Line2D endpoint and numeric diagnostics.
4. Append each tile once, backtrack to the previous tile, and vibrate only on newly entered tiles.
5. Throttle event-to-frame/FPS diagnostics; export VIBRATE as `com.mazen.worldofwordgame`. Play Console setup is out of scope for T-0029.

## Tests / acceptance
- Repository CI green; disposable project imports and exports an Android debug APK in the T-0014 toolchain.
- Chris tests slow/fast swipes on Galaxy A15 and records latency, haptics, misses/backtracks and metrics.
- Report recommends the production input path. Keep status `review` until device evidence exists.

## Escalation log
ROADMAP has T-0029 but no task file; Chris explicitly requested execution, so this records that scope.
T-0012 is omitted from `depends_on` because its task file does not exist; TESTING.md records its result.

## Completion evidence
2026-10-06: Chris confirmed the Galaxy A15 device test was performed, requested PR #12 to be merged,
and reported smooth swipe. See docs/spikes/S2-swipe.md for the qualitative latency evidence and the
explicitly unreported numeric/haptics observations. No missing measurement is represented as PASS.
