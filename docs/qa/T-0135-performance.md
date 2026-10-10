# T-0135 — all-event render diagnostics

Debug boot dynamically owns a non-global observer and attaches optional wheel
probes. The readout uses existing Label/tokens in the Level ScreenScaffold body,
so safe-area padding applies and input passes through. No release preload or
new autoload is introduced. Copy is imported from debug.csv (PL/EN).

A fixed 512-event ring retains every accepted primary pointer input timestamp.
Wheel draw marks its covered events; frame_post_draw consumes only that prefix.
Later events stay pending until a later wheel draw. System layout/lock/focus
cancellations do not count as dispatched input. Samples, pending and dropped
counts accompany mean/max; unavailable differs from a valid zero duration.
FPS derives from rendered foreground intervals; focus and navigation start a new
measurement window. Snapshot/text allocation is limited to the refresh timer.

This is input dispatch to an engine render boundary, excluding sensor/OS delivery,
GPU completion and display scanout. No physical latency, device FPS, NFR-01 gate
or human evaluation is claimed. Desktop software rendering timing is diagnostic.

Injected-clock GUT tests cover all-event coalescing, draw boundaries, pending
inputs, overflow, ring wrap, zero duration, foreground reset/FPS, pointer ownership,
overlay navigation/focus/cleanup and real boot ownership. Headless tests explicitly force a rendered frame to assert the wheel draw probe,
post_draw sampling, locale changes and owned signal/translation cleanup. The
normal automatic rendering path was also separately exercised under
Xvfb/Mesa Compatibility at REGULAR 1080×1920 PL. A real boot + three pointer events
produced three measured samples with zero pending/drops, proving the wheel draw
and post_draw hooks are wired. The screenshot was visually inspected: labels fit,
controls remain unobscured and the three-letter connector is visible.
Local artifact: /workspace/artifacts/T-0135-REGULAR-PL.png; render smoke script/log
at /tmp/t135-runtime-smoke.gd and /tmp/t135-runtime-smoke.log.

T-0051/T-0136 human gates remain unperformed. T-0137/T-0138 exclude and inspect
these dedicated debug scripts in an actual unsigned release resource export.

Full make check passed: 214 GUT / 8,440 assertions, 199 pipeline and 87 tools
tests, registry and 65 shipped levels. Task/scope lint pass.

Review follow-up: added real forced-draw assertions and PL/EN readout, owned
translation and RenderingServer callback cleanup coverage; full check passed.
Fresh independent follow-up review approved f68a7a02e0593e7dae784b169ed693e40b628e62; no blockers.
