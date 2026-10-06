---
id: T-0053
title: Separate S2 swipe runs and measure render timing
epic: E02
type: fix
area: level.wheel
risk: medium
executor: sol
think: high
ui: high
status: done
depends_on: [T-0029]
touch:
  - spikes/s2-swipe/**
  - tools/tests/test_s2_measurement.py
  - docs/spikes/S2-measurement.md
revision: 1
---

## Goal
Make separate 60/90 FPS swipe attempts independently reproducible and correctly report what the
engine timing instrumentation measures. Chris explicitly requested this follow-up on 2026-10-06.

## Current state
- T-0029 is done on main; its isolated project has main.gd, main.tscn and project.godot.
- main.gd stores cumulative timing and overwrites the event timestamp on each drag.
- t/0029-s2-device-logs exports cumulative 53/82-chain snapshots from two human test attempts.
- Normal CI imports game/ only; tools pytest can run a dedicated headless spike regression script.

## Specification
1. Add Start 60 / Start 90 / Start 120 / Start Adaptive (uncapped, Engine.max_fps = 0) and Stop + save
   controls inside the portrait viewport, plus live HUD feedback. A new attempt resets every counter
   and histogram and assigns a unique run ID. Never mix attempts in one export.
2. Set the requested engine FPS cap on start (or remove cap with Engine.max_fps = 0 for Adaptive).
   Report the requested cap/mode separately from observed FPS and device refresh rate; do not claim
   that 90/120 FPS requests are achievable on every device or prove OS dynamic refresh rate switching.
3. Record all queued touch/drag events affecting a frame, rather than only the latest timestamp.
4. Measure dispatch-to-line-update and dispatch-to-frame_post_draw separately. Explicitly label these
   engine scheduling/render proxies, not hardware touch-to-photon latency.
5. Measure frame intervals throughout the run. Export mean FPS, timing means/maxima, 1 ms p95 bins,
   sample counts, overflow/drop/pending counts, budget applicability and completed/aborted swipes.
6. Preallocate fixed event queues/histograms outside the input/frame path; account for saturation.
7. Stop freezes the run; export unique JSON and text files. Repeat export retries the same frozen
   run. A save failure is visible; starting a new attempt is blocked until the prior run is saved.
8. Interruption cancels an active swipe and stops the run, preventing background time from being
   classified as normal foreground performance.

## Scope and UI
This is the disposable S2 diagnostic, not production UI. Preserve the existing wheel geometry,
hit-testing/backtrack behavior and haptic tick; no production components/config/tokens are changed.
No project/export settings, SDKs, dependencies or historical logs are changed.

## Tests
- Inject timestamps to verify independent run resets, both timing endpoints, multi-event sampling,
  actual frame-interval FPS, over-budget count and applicability metadata, bounded-queue drops
  and saturation, frozen stop, aborted swipe count and empty-run behavior.
- Invoke the headless GDScript suite from tools pytest so pinned-runtime CI actually executes it.
- Import and smoke-run the diagnostic scene locally; use pinned Godot CI as the authoritative check.

## Acceptance
Task lint/scope and repository CI pass. The dedicated spike suite runs, not merely game/ imports.
Document the new device protocol and the limits of existing cumulative logs.

## Completion evidence
2026-10-06: Chris tested the independent measurement build on Samsung Galaxy A15 5G (SM-A156B) and Samsung Galaxy S26 Ultra (SM-S948B, 120Hz display).
Logs are split by FPS category under `spikes/s2-swipe/evidence/{60fps,90fps,120fps,adaptive}/`:
- **60 FPS**: Verified on A15 (60.09 FPS, avg 1.89 ms latency proxy) and S26 Ultra (60.05 FPS, avg 1.50 ms latency proxy).
- **90 FPS**: Verified on A15 (90.04 FPS, avg 6.16 ms latency proxy) and S26 Ultra (historical run at 78.01 FPS with 340 over-budget events preserved alongside second run at 90.07 FPS, avg 1.27 ms latency proxy).
- **120 FPS**: Verified on S26 Ultra (mean 120.00 FPS, avg frame interval 8.33 ms, avg 3.95 ms latency proxy, 22 swipes; 14/2461 over-budget events noted).
- **Adaptive**: Verified on S26 Ultra (mean 120.00 FPS, avg frame interval 8.33 ms, avg 4.16 ms latency proxy, 13 swipes, uncapped Engine.max_fps = 0; over-budget comparison marked unavailable).
Mini-log & comparison table recorded in docs/spikes/S2-measurement.md.


