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
| Build / install / launch | Device test performed, confirmed by Chris |
| Slow + fast swipe line feel | Chris reports smooth swipe; individual protocol counts not supplied |
| Missed / duplicated letters | NOT RATED |
| Backtrack / second-finger behaviour | NOT RATED |
| Haptic tick feel | NOT RATED |
| FPS / event→frame estimate | NOT RECORDED |
| Chris latency rating (1 bad → 5 instant) | Qualitative: smooth, no perceived delay; numeric rating not supplied |
| Chris haptic rating (1 bad → 5 crisp) | NOT RATED |

## Recommended production input approach
Use raw touch events for identity/hit-testing/chain mutations; cache the latest finger position and
only move the existing Line2D endpoint in the rendered-frame path. Grow data only on tile crossings,
ignore non-active fingers, backtrack on the previous tile, and emit one short haptic per added letter
behind the future Settings toggle. Keep diagnostics debug-only and throttled.

If lag is perceived at stable 60 FPS, compare direct Line2D mutation in `_input` against this cached
frame path before considering interpolation or an engine change.

## Decision
2026-10-06: Chris confirmed that the Galaxy A15 test was performed, requested PR #12 to be merged,
and rated the swipe as "Plynnie" (smooth). This is human device evidence against F4 (perceived swipe
lag), not an instrumented touch-to-photon measurement. No numeric FPS, timing or haptics rating was
provided; the other unreported observations remain NOT RATED / NOT RECORDED rather than PASS.
T-0029 is done on this completion confirmation. The recommended production input approach remains
unchanged; detailed haptic/backtrack diagnostics still need evidence during production device QA.
