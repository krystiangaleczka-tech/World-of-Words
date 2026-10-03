# S2 swipe spike — T-0029

Status: **repository implementation complete; Galaxy A15 review pending**.

## Purpose

Validate the input path before production wheel code exists. The product bar is NFR-01: the line and
selection should react on the next rendered frame with no perceivable lag on the Samsung Galaxy A15.
This spike is disposable and does not change `game/`.

## Prototype

- Godot 4.7.2, 1080×1920 portrait, GL Compatibility.
- Raw `InputEventScreenTouch` / `InputEventScreenDrag`.
- One active finger; additional fingers are ignored.
- `Line2D` contains selected tile positions plus one cached finger endpoint.
- `_process` only moves the existing endpoint and updates numeric diagnostic counters.
- Tile-chain structure and word strings change only on touch/tile events, not every frame.
- 12 ms `Input.vibrate_handheld()` tick when a new letter is entered.
- Android preset enables `permissions/vibrate` and uses `com.mazen.worldofwordgame.spike`.

The displayed event→frame value is a scheduling proxy from the most recent drag event to the next
`_process` update. It is useful for relative checks; it is not physical touch-to-photon latency.

## Build / device protocol

1. Import: `godot --headless --path spikes/s2-swipe --import --quit`.
2. Export: `godot --headless --path spikes/s2-swipe --export-debug Android export/s2-swipe.apk`.
3. Install the APK on the Galaxy A15 and launch it from the app icon.
4. Do at least 10 slow chains and 20 fast chains in both directions.
5. Include deliberate backtracks and a second-finger touch during an active chain.
6. Record the observations below. Do not call the task done without Chris's rating.

## Device evidence — Galaxy A15

| Check | Result |
|---|---|
| Build / install / launch | NOT EXECUTED |
| Slow swipe line feel | NOT RATED |
| Fast swipe line feel | NOT RATED |
| Missed / duplicated letters | NOT RATED |
| Backtrack feel | NOT RATED |
| Second finger ignored | NOT RATED |
| Haptic tick feel | NOT RATED |
| Visible FPS / event→frame estimate | NOT RECORDED |
| Chris latency rating (1 bad → 5 instant) | NOT RATED |
| Chris haptic rating (1 bad → 5 crisp) | NOT RATED |

## Recommended production input approach

Use this split unless the Galaxy A15 review disproves it:

1. Capture touch identity, hit-testing and chain mutations from raw screen events.
2. Cache the latest finger position; in the rendered-frame path only call
   `Line2D.set_point_position()` on the existing endpoint.
3. Allocate/grow data only when the player crosses a tile, never once per rendered frame.
4. Ignore non-active fingers; treat moving onto the previous tile as backtrack.
5. Trigger one short haptic on entry into a new tile, behind the future Settings haptics toggle.
6. Keep diagnostic strings/FPS sampling throttled and debug-only in production.

If Chris sees perceivable lag despite stable 60 FPS, the next experiment should compare direct
Line2D mutation in `_input` against the cached-position frame path before changing engines or adding
interpolation.

## Decision

Pending Chris's Galaxy A15 rating. T-0033 must not treat S2 as accepted until this table has real
device evidence.
