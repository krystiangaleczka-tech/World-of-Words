# T-0169 — debug APK performance capture

Use a debug APK built from T-0168 or later. Record its actual SHA-256, source commit,
phone/model, OS version, refresh mode and scenario notes. Report identity is operator
supplied, not authenticated. A reference Galaxy A15 run is still required by T-0139;
S26 results and headless fixtures are separate evidence.

## Capture

Connect the phone with authorized USB debugging and open the debug game. Capture
only its current process (restart capture if the game process restarts):

```sh
adb shell pidof org.worldofwords.prototype.debug
adb logcat --pid=REPLACE_WITH_PRINTED_PID -v threadtime > device-performance.log
```

Start capture before the scenario. Stop it with Ctrl-C AFTER navigating to another
screen or putting the app in the background. Those transitions close a window and
emit `WOW_PERF_V1` JSON. A process kill/crash may lose the open window; absence is
not a good result. Capture includes ordinary game logs; review before sharing.
The diagnostic JSON contains only counters/measurements and a close reason.

From the same source checkout, with actual APK/source hash values:

```sh
uv run python tools/performance_report.py device-performance.log \
  --device 'Galaxy A15; OS and refresh mode; scenario name' \
  --apk-sha256 REPLACE_WITH_ACTUAL_64_LOWERCASE_HEX \
  --source-sha REPLACE_WITH_ACTUAL_40_LOWERCASE_HEX > device-performance.json
```

The command reads only; shell redirection creates the requested report. Exit0 means
valid diagnostic data, not acceptance. Invalid marked records fail with their line
number. Unrelated log lines are ignored. Keep original capture and scenario notes.

## Scenarios and interpretation

- Slow pointer motion and rapid tile changes; short and long words, backtracking,
  cancellation and a secondary touch. Note visible line response and sound response.
- Submit a required word and a bonus; finish a level. Observe the submission AND
  persistence/next-level frame. If a save failure is actually encountered, record
  feedback/retry/advance behavior; do not induce destructive device faults.
- Shuffle, resize/orientation constraints, navigation, background/resume. Close each
  scenario window before stopping capture. Repeat comparable runs at the same device
  refresh mode; record perceived stalls alongside numbers.

Frame mean/max and `frame_over_budget` use a diagnostic 16667µs budget near60Hz, not
an NFR threshold or refresh detector. FPS is rendered foreground intervals only.
Input mean/max cover the whole window; p50/p95 cover its latest512 consumed events.
`pending` and `dropped` expose coverage gaps. The summary's `max_window_p95_ms` is
maximum of window percentiles, not a capture percentile; no averaged FPS is invented.

Input timing starts at accepted event dispatch and ends at engine post-draw; sensor,
OS delivery, GPU completion and display scanout are excluded. Allocation exceptions
from Astra Q3 remain. This tooling neither certifies physical latency nor replaces
human A15 feel, per-word review, five-outsider playtests or Chris's FUN GATE decision.
