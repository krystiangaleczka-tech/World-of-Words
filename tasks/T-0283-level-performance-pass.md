---
id: T-0283
title: Measure and optimize low-end Android Level performance
epic: E20
type: feat
area: level.flow
risk: medium
executor: cheap
think: high
ui: low
status: blocked
depends_on: [T-0282]
touch:
  - game/features/level/level.gd
  - game/features/level/level_perf.gd*
  - game/tests/integration/test_level_performance.gd*
  - docs/qa/T-0283-performance.md
  - tasks/T-0283-level-performance-pass.md
revision: 1
---

## Goal
Prove 60 fps Level gameplay on the reference low-end Android, no continuous idle redraw, debug Level load <= 100 ms, and measured cold start with bounded, evidence-driven fixes only.

## Context
NFR-02..04, NFR-08; TESTING.md#device-checklist; ROADMAP.md T-0283. Animations and inputs must retain T-0282 approved feel and reduced-motion accessibility.

## Current state
T-0282 is unplanned/blocked and no device frame-time, idle redraw, load or cold-start evidence is linked. T-0281 and other Level UI work has not been owner-certified. No measured bottleneck is known.

## Specification
1. Capture hardware model, OS, build SHA, debug/release modes, target frame rate, frame times over gameplay/swipe/idle and thermal state over a repeatable 30-minute session. Compare with a fixed content slot and same settings.
2. Test Level stable 60 fps on low-end Android, no swipe frame >33 ms, responsive wheel and zero unnecessary idle redraw; on high-refresh devices report 120 Hz behavior without silently changing a cap.
3. Instrument a one-shot **debug-only** monotonic Level load timer (scene/content initialization boundary, not network) and assert <=100 ms for representative P2 levels. No recurring allocations or instrumentation in the swipe path.
4. Measure cold launch separately: <=3s on reference Android and <=2s on reference iPhone, excluding consent. Do not claim these from CI/emulator runs.
5. Only after profiling identifies a regression, change the minimal Level script path; no new plugin, persistence/contract changes, renderer replacement or global configuration. Split/escalate if other touched files or APIs are needed. Preserve no loading screens between levels.
6. Include deterministic instrumentation tests, normal/reduced motion and enter/exit lifecycle. Repeat measurements after any optimization.

## Tests
`docs/qa/T-0283-performance.md`: profiling method, baseline and post-fix frame-time percentiles/max, idle redraw counters, repeated per-level load timing, cold starts, thermal notes, devices/builds, owner sign-off and PASS/FAIL/BLOCKED per metric. `game/tests/integration/test_level_performance.gd` verifies debug timer and lifecycle once T-0282 is delivered; `make check`/scope green.

## Acceptance
Remain blocked until T-0282 owner approval. Device threshold measurements and regression tests are required before marking review/done; no invented fps or launch data.

## Rollback
Revert only measured Level changes; do not undo approved game-feel tokens from T-0282.
