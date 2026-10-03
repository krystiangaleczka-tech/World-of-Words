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
Build a disposable Godot 4.7.2 letter-wheel prototype for the Galaxy A15 so Chris can judge
swipe latency and haptic feel before the production wheel is designed.

## Context
- PRODUCT.md FR-WHEEL-02: the connecting line follows the finger every frame with no per-frame allocations.
- PRODUCT.md NFR-01: line and tile selection update on the next rendered frame after touch; Chris judges
  perceivable lag on the low-end Android.
- TESTING.md names Samsung Galaxy A15 as the low-end Android for swipe-latency review.
- Roadmap T-0029; design-pass 11 section 4 defines S2 as a throwaway wheel rated on device.

## Current state
- Godot 4.7.2 and Android export templates are pinned by T-0014.
- T-0012 has no task file, but its accepted device decision is recorded in TESTING.md.
- No S2 project or S2 report exists.

## Specification
### Behavior
1. Keep the spike isolated under `spikes/s2-swipe/`; production `game/` stays untouched.
2. Use raw screen-touch/drag events. Ignore a second finger while a chain is active.
3. Keep the finger endpoint in a two-or-more-point `Line2D`; the frame path only mutates the cached
   endpoint and numeric counters, with no GDScript container/string allocation in `_process`.
4. Append a tile once, support one-step backtrack, and vibrate briefly only when entering a new tile.
5. Show a throttled event-to-frame estimate and FPS for diagnostic use only.
6. Export as the approved throwaway package `com.mazen.worldofwordgame.spike` with VIBRATE permission.

### Edge cases
- Touch starts outside a tile: ignore it.
- Second finger during a chain: ignore it.
- Re-enter selected non-previous tile: ignore it.
- Backtrack onto the previous tile: remove the last tile without adding a duplicate.

## Out of scope
Production wheel API/scenes, final visuals, gameplay word validation, analytics, audio, save, economy.

## Tests
- Repository CI: scope, task lint, test-count, format, lint, production Godot import/GUT, pytest.
- Toolchain/device: import the disposable project and export Android debug APK.
- Galaxy A15: perform repeated slow and fast swipes; record Chris's latency rating, haptic rating,
  FPS/latency estimate and any missed/backtracked letters in `docs/spikes/S2-swipe.md`.

## Acceptance
- Disposable wheel and Android export preset are ready.
- Repository CI is green.
- Chris's Galaxy A15 observations are recorded before status changes to `done`.
- Report contains the recommended production input approach.

## Escalation log
- S1-style preflight: ROADMAP has T-0029 but no T-0029 task file on main. Chris explicitly requested
  execution, so this revision records the fixed roadmap scope without editing ROADMAP.
- T-0012 cannot be listed in machine-readable `depends_on` because no T-0012 task file exists;
  TESTING.md contains the accepted Galaxy A15 device decision.
