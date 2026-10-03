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
status: review
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
- PRODUCT.md FR-WHEEL-02 / NFR-01: line and selection update on the next rendered frame with no
  per-frame allocations and no perceivable lag on the low-end Android.
- DESIGN.md#letterwheelview: raw touch/drag, enlarged hit radius, previous-tile backtrack, second
  finger ignored, per-letter haptic, preallocated Line2D points.
- TESTING.md: Samsung Galaxy A15 is the low-end Android for swipe-latency review.
- Roadmap T-0029; design-pass 11 section 4 defines S2 as a throwaway device-rated wheel.

## Current state
Godot 4.7.2 and Android export templates are pinned by T-0014. T-0012 has no task file, but its
accepted Galaxy A15 decision is recorded in TESTING.md. No S2 project/report exists.

## Specification
1. Keep the spike under `spikes/s2-swipe/`; do not touch production `game/`.
2. Use raw screen touch/drag and one active finger.
3. Cache the finger position; `_process` only mutates the existing Line2D endpoint and numeric
   diagnostic counters. Chain/string changes happen only on input events.
4. Append each tile once, backtrack onto the previous tile, and vibrate only on newly entered tiles.
5. Show throttled event-to-frame and FPS diagnostics.
6. Export with VIBRATE permission as `com.mazen.worldofwordgame.spike`.

## Tests / acceptance
- Repository CI green: scope, tasks-lint, test-count, format, lint, production Godot/GUT, pytest.
- Disposable project imports and Android debug export succeeds in the T-0014 toolchain.
- Chris performs repeated slow/fast swipes on the Galaxy A15 and records latency, haptic feel,
  misses/backtracks and diagnostics in `docs/spikes/S2-swipe.md`.
- The report recommends the production input path. Keep status `review` until device evidence exists.

## Escalation log
ROADMAP has T-0029 but no task file on main; Chris explicitly requested execution, so this revision
records that fixed scope. T-0012 is omitted from machine-readable `depends_on` because its task file
does not exist; TESTING.md contains the accepted device decision.
