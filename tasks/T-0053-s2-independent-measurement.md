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
status: review
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
1. Add Start 60 / Start 90 and Stop + save controls inside the portrait viewport. A new attempt resets
   every counter and histogram and assigns a unique run ID. Never mix attempts in one export.
2. Set the requested engine FPS cap on start. Report the requested cap separately from observed FPS
   and device refresh rate; do not claim that a 90 FPS request is achievable on every device.
3. Record all queued touch/drag events affecting a frame, rather than only the latest timestamp.
4. Measure dispatch-to-line-update and dispatch-to-frame_post_draw separately. Explicitly label these
   engine scheduling/render proxies, not hardware touch-to-photon latency.
5. Measure frame intervals throughout the run. Export mean FPS, timing means/maxima, 1 ms p95 bins,
   sample counts, overflow/drop/pending counts and completed/aborted swipes.
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
  actual frame-interval FPS, over-budget count, bounded-queue drops and saturation, frozen stop,
  aborted swipe count and empty-run behavior.
- Invoke the headless GDScript suite from tools pytest so pinned-runtime CI actually executes it.
- Import and smoke-run the diagnostic scene locally; use pinned Godot CI as the authoritative check.

## Acceptance
Task lint/scope and repository CI pass. The dedicated spike suite runs, not merely game/ imports.
Document the new device protocol and the limits of existing cumulative logs.

## Completion evidence
2026-10-06: Chris tested the independent measurement build on Samsung Galaxy A15 5G (SM-A156B) and Samsung Galaxy S26 Ultra (SM-S948B, 120Hz screen).
Captured independent logs:
- Galaxy A15 (90Hz display):
  - Run 1 (target 60 FPS): 13 completed swipes, avg render FPS 60.09, event_to_post_draw avg 1.89 ms (max 16.47 ms, p95 3 ms).
  - Run 2 (target 90 FPS): 18 completed swipes, avg render FPS 90.04, event_to_post_draw avg 6.16 ms (max 10.75 ms, p95 10 ms).
- Galaxy S26 Ultra (120Hz display):
  - Run 1 (target 60 FPS, 60Hz mode): 6 completed swipes, avg render FPS 60.00, event_to_post_draw avg 16.16 ms.
  - Run 2 (target 90 FPS, 120Hz mode): 16 completed swipes, avg render FPS 78.01, 340 events over frame budget due to 90 FPS vs 120 Hz mismatch.
  - Run 3 (target 60 FPS, 120Hz mode): 15 completed swipes, avg render FPS 60.08, event_to_post_draw avg 1.15 ms.
Logs captured in spikes/s2-swipe/evidence/.
Operator note / mini-log: The UI buttons currently test fixed 60 and 90 FPS caps. The tool should detect and visibly display the screen refresh rate (display_refresh_hz, e.g. 90 Hz on A15, 120 Hz on S26 Ultra, adaptive VRR) so users know their screen's native mode and can test accordingly.

