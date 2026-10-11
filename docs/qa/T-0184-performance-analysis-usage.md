# T-0184 — Read and compare actual performance captures

This adds readable output to the [T-0169 capture flow](T-0169-device-performance-capture.md).
It reads existing capture JSON; it does not measure a phone or verify operator metadata.
Keep the raw log, exact source/APK identity and scenario notes for every run.

## Capture and convert

Follow T-0169: capture the current game process, exercise the scenario, then navigate
or background the game so the window closes. Stop logging afterward. A process
kill/crash may lose the open window; absent data does not demonstrate smoothness.

Use the actual APK file's SHA-256 and exact source of the selected CI/local build.
The CI artifact ZIP digest is not the APK digest; a squash merge or newer checkout
may have a different source identity. Keep the chosen APK during a measurement round.
Include device/model, Android, refresh mode and scenario in the device description.
Replace placeholders in the existing capture command:

```sh
uv run python tools/performance_report.py device-performance.log \
  --device 'ACTUAL_DEVICE; Android; refresh mode; scenario' \
  --apk-sha256 ACTUAL_64_LOWERCASE_HEX_APK_SHA256 \
  --source-sha ACTUAL_40_LOWERCASE_HEX_SOURCE_SHA > capture.json
```

## Read the capture

```sh
uv run python tools/performance_cli.py report capture.json > capture.md
```

The command validates the existing report schema, rejects duplicate JSON keys and
recomputes its summary from the windows. Edited/inconsistent summaries, invalid
identities or nonfinite/wrong numeric values fail before any report is printed.
Readable output includes identity, all summary fields, every ordered window, units
and pending/dropped coverage. Original capture/parser/schema remain unchanged.

`not available` represents an unavailable measurement; `0` is a valid zero.
Latency/frame values use ms, budget uses us, and counters use count. Window fps in
Hz is rendered frame frequency, not a detector of the phone's refresh setting.

## Compare two captures

Prefer the same device, OS, refresh/power settings, scenario and comparable active
coverage. Record these conditions manually; equal device text cannot authenticate
comparability. Source/APK differences may be intentional and are reported.

```sh
uv run python tools/performance_cli.py compare baseline.json candidate.json > comparison.md
uv run python tools/performance_cli.py compare baseline.json candidate.json \
  --format json > comparison.json
```

Inputs are original T-0169 capture reports, not comparison JSON. Markdown is the
default; JSON preserves both full validated captures and their ordered windows.
Metadata differences compare operator strings/hashes exactly after device trimming.
Deltas are candidate minus baseline for all nine summary fields. A missing maximum
on either side gives null/`not available`; a genuine negative difference, including
-1 ms or -1 count, stays numeric. Different window counts and coverage remain visible.
No windows are aligned by index or assumed to represent the same gesture.

Keep input/output paths different: shell redirection onto an input truncates it
before reading. Commands read UTF-8 inputs and print stdout; they do not write
files. Exit 0 means valid output format, input/read/encoding errors use stderr and
exit 1, usage errors exit 2. No partial stdout report is printed on input failure.

## Interpretation and human evidence

Input mean/max describe the whole window; p50/p95 describe its latest 512 consumed
inputs. `max_window_p95_ms` is maximum window p95, not a capture percentile. Comparing
these maxima is descriptive, not a merged distribution or causal build effect.
The fixed 16667 us budget is a diagnostic near-60Hz reference, not an NFR verdict.
No capture FPS average or weighted comparison score is invented. Pending/dropped
samples and differing durations/contexts affect what the numbers can show.

Timing starts at accepted engine event dispatch and ends at post-draw, excluding
sensor/OS delivery, GPU completion and display scanout. Actual A15 feel and observed
submission/persistence stalls still require device tests. Prior S26 Ultra approval,
per-word review, five outside-player sessions and Chris's FUN GATE are separate
records; these commands do not close them or start P2. All automated test fixtures
are explicitly synthetic and are not recorded phone measurements.
