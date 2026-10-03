# S2 swipe spike — T-0029

Status: **repository implementation complete; Galaxy A15 review pending**.

## Prototype and measurement

Godot 4.7.2 uses raw screen touch/drag events, one active finger, previous-tile backtrack and a
`Line2D` whose last point is updated from cached finger position. GDScript container/string
structure changes only on input/tile events; `_process` mutates the existing line point and numeric
diagnostics. A 12 ms `Input.vibrate_handheld()` tick fires on each newly entered tile.

The displayed event→frame value measures the latest drag event to the next `_process` update. It is
a scheduling proxy for comparison, not physical touch-to-photon latency.

## Galaxy A15 protocol

1. Import: `godot --headless --path spikes/s2-swipe --import --quit`.
2. Export: `godot --headless --path spikes/s2-swipe --export-debug Android export/s2-swipe.apk`.
3. Install and run on the Galaxy A15.
4. Do at least 10 slow and 20 fast chains in both directions, including backtracks and a second finger.
5. Record the table. Do not mark T-0029 done without Chris's rating.

| Check | Result |
|---|---|
| Build / install / launch | NOT EXECUTED |
| Slow + fast swipe line feel | NOT RATED |
| Missed / duplicated letters | NOT RATED |
| Backtrack / second-finger behaviour | NOT RATED |
| Haptic tick feel | NOT RATED |
| FPS / event→frame estimate | NOT RECORDED |
| Chris latency rating (1 bad → 5 instant) | NOT RATED |
| Chris haptic rating (1 bad → 5 crisp) | NOT RATED |

## Recommended production input approach

Use raw touch events for identity, hit-testing and chain mutations; cache the latest finger position
and only move the existing Line2D endpoint in the rendered-frame path. Grow data only when crossing a
tile, ignore non-active fingers, backtrack on the previous tile, and emit one short haptic per added
letter behind the future Settings toggle. Keep diagnostic strings/FPS sampling debug-only and
throttled.

If Chris still perceives lag at stable 60 FPS, compare direct Line2D mutation in `_input` against
the cached-position frame path before considering interpolation or engine changes.

## Decision

Pending Chris's Galaxy A15 rating. T-0033 must not treat S2 as accepted until this table has real
device evidence.
