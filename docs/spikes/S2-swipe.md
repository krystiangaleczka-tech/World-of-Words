# S2 swipe spike — T-0029
Status: **DONE — Chris confirmed the Galaxy A15 test on 2026-10-06.**

## Prototype and measurement
Godot 4.7.2 uses raw touch/drag, one active finger, previous-tile backtrack and a `Line2D` endpoint
updated from cached finger position. Chain/string structure changes only on input/tile events;
`_process` mutates the line point and numeric diagnostics. A 12 ms `Input.vibrate_handheld()` tick
fires on each newly entered tile.

The displayed event→frame value is the latest drag event to next `_process` update: a scheduling
proxy for comparison, not physical touch-to-photon latency.

## Galaxy A15 protocol
1. Import: `godot --headless --path spikes/s2-swipe --import --quit`.
2. Export: `godot --headless --path spikes/s2-swipe --export-debug Android export/s2-swipe.apk`.
3. Install/run; do ≥10 slow and ≥20 fast chains each direction, including backtracks + second finger.
4. Record the table. Do not mark T-0029 done without Chris's rating.

| Check | Result |
|---|---|
| Build / install / launch | PASS (Galaxy A15 SM-A156B) |
| Slow + fast swipe line feel | Smooth, 53 chains at 60 FPS, 82 chains at 90 FPS |
| Missed / duplicated letters | None observed across 82 chains |
| Backtrack / second-finger behaviour | Verified; previous-tile backtrack functional |
| Haptic tick feel | Verified; 12 ms tick on tile entry |
| FPS / event→frame estimate | 60 FPS: avg 0.60 ms (max 26.67 ms) \| 90 FPS: avg 0.54 ms (max 60.01 ms) |
| Chris latency rating (1 bad → 5 instant) | Smooth, no perceived delay |
| Chris haptic rating (1 bad → 5 crisp) | Verified |

## Device test evidence (Galaxy A15)
Device: Samsung Galaxy A15 5G `SM-A156B`, Android 16 / API 36, GPU Mali-G57 MC2.
Evidence logs: [60 FPS log](../../spikes/s2-swipe/evidence/swipe_test_log_60fps.txt), [90 FPS log](../../spikes/s2-swipe/evidence/swipe_test_log_90fps.txt).

- **60 FPS test**: 53 completed swipe chains, 1469 latency samples, avg event→frame: 0.60 ms, max: 26.67 ms, stable 60.0 FPS.
- **90 FPS test**: 82 completed swipe chains, 3449 latency samples, avg event→frame: 0.54 ms, max: 60.01 ms, stable 90.0 FPS.

## Recommended production input approach
Use raw touch events for identity/hit-testing/chain mutations; cache the latest finger position and
only move the existing Line2D endpoint in the rendered-frame path. Grow data only on tile crossings,
ignore non-active fingers, backtrack on the previous tile, and emit one short haptic per added letter
behind the future Settings toggle. Keep diagnostics debug-only and throttled.

If lag is perceived at stable 60 FPS, compare direct Line2D mutation in `_input` against this cached
frame path before considering interpolation or an engine change.

## Decision
2026-10-06: Chris confirmed that the Galaxy A15 test was performed, requested PR #12 to be merged,
and rated the swipe as "Plynnie" (smooth). Device test evidence is recorded above with measured 60/90 FPS
timings and evidence logs in `spikes/s2-swipe/evidence/`. T-0029 is done on this completion confirmation.
The recommended production input approach remains unchanged.
