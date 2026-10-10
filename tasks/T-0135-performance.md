---
id: T-0135
title: Display debug FPS and all-event input-to-line render estimates
epic: E09
type: feat
area: features.debug
risk: low
executor: cheap
think: med
ui: low
status: done
depends_on: [T-0134, T-0106, T-0133]
touch:
 - game/features/debug/performance_*.gd*
 - game/ui/components/LetterWheelView.gd
 - game/services/clock.gd
 - game/services/nav/boot.gd
 - game/locale/debug.csv*
 - game/tests/integration/test_performance_overlay.gd*
 - docs/qa/T-0135-performance.md
 - tasks/T-0135-performance.md
revision: 1
---

## Goal
A debug-only overlay displays foreground render FPS and input-dispatch to line
frame_post_draw mean/max estimates, with samples/pending/drops visible. Physical
sensor/OS/GPU/display latency is outside these measurements (S2 protocol).

## Current state
T-0134 debug tools are done. LetterWheelView owns pointer_begin/move/end and
synchronously updates a preallocated line then queue_redraw. Boot mounts Nav
screens; Nav.screen_changed and mounted_screen exist. Clock provides injectable
millisecond/calendar time but no microseconds. Debug copy CSV imports PL/EN.
T-0136 remains an unperformed human secret task; this needs no secrets.

## Specification
1. Explicitly add Clock.monotonic_usec()->int as an injectable elapsed-time API.
   Add optional wheel diagnostic input/drawn Callables, disabled in release.
   Record accepted primary pointer begin/move/end before updating the line; rejected
   pointers, locked input and misses do not produce samples. No file/node/array
   allocation in these hooks. Draw marks which queued events this line represents.
2. Non-global debug metrics use a fixed bounded 512 timestamp ring. All dispatched
   accepted events are measured at the first post_draw carrying their line update,
   including multiple events coalesced into one frame. Events after draw remain
   pending for the next drawn frame; post_draw without wheel draw never consumes.
   Show cumulative sample/mean/max, pending/dropped, and render interval FPS.
   Snapshot allocation occurs only on a refresh timer, never in swipe/_process.
3. A non-global debug CanvasLayer owns metrics, render callback and a refresh Timer;
   assembled Label/containers use existing Tokens and imported CSV translations.
   Input passes through. Boot dynamically loads it only in debug builds, attaches
   to the currently mounted LevelScreen wheel and disconnects previous hooks.
   Navigation and focus/background reset counters; background gaps are not FPS.
   Cleanup disconnects every owned signal/hook/translation. No new autoloads.
4. Display an explicit render-boundary estimate label, unavailable before samples
   (zero duration remains valid), and coverage counts. Never claim physical touch
   latency or device performance. No save/core/economy/config/analytics changes.

## UI rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1 A screen task may not create a component. If missing, STOP (S4).
- R-UI-2 New component = separate ui.components task with gallery entry.
- R-UI-3 No literal visual sizes/colors/durations; use Tokens/theme.
- R-UI-4 Player strings use translation keys.
- R-UI-5 Never hand-edit generated theme.
- R-UI-6 UI med/high attaches prescribed screenshots.
This low-impact developer overlay assembles existing Label/containers; capture
and inspect one real REGULAR PL screenshot as additional evidence.

## Tests
Injected timestamps: multiple events in one frame, events after draw, frames with
no wheel draw, zero-duration valid sample, bounded overflow, reset and FPS without
background gaps. Wheel integration: accepted/rejected pointer ownership and draw
hooks. Overlay lifecycle: detach/replacement/navigation/focus cleanup and
translation; real boot owns the overlay. Full make check, scope/lint, fresh review
and all CI. No sleeps or real clock assertions; screenshots aren't timing tests.

## Acceptance
Metrics cover all observed accepted events; coverage loss is visible; ordinary
wheel behavior is unchanged. Debug render diagnostics do not enter release code.

## Rollback
Remove boot overlay load and optional hooks together; no persisted data changes.
