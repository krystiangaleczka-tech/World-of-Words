# T-0165 — device performance evidence contract

The Astra Q3 audit accepts the current P1 allocation exception and requires actual
reference-device observations. Improve diagnostics before those observations;
do not rewrite the wheel, change tokens, infer physical latency or approve NFR/FUN gates.

## Frame intervals (T-0166)
Retain all existing snapshot fields. Add frame_intervals (count), frame_mean_ms,
frame_max_ms (-1.0 when unavailable), frame_budget_usec=16667 and frame_over_budget.
The fixed diagnostic budget approximates 60 Hz; it is not an acceptance threshold,
refresh-rate detector or economy/config value. Strictly greater intervals count.
First frame establishes an anchor; repeated/backwards timestamps are ignored and
never move that anchor backwards. Reset clears all history. Storage stays fixed;
no allocations in input/frame paths.

## Recent input distribution (T-0167)
Add latency_window_samples, p50_ms and p95_ms. Keep the latest 512 consumed input
latencies in a preallocated ring, independent of the pending-input ring. Snapshot
copies/sorts only the occupied prefix; nearest-rank percentile uses ceil(p*N)-1.
No samples gives -1.0, valid zero remains zero. Existing mean/max/samples remain
whole-window statistics. Percentiles describe only the recent window, never
all-history or finger-to-photon. Reset clears ring occupancy.

## Debug log windows (T-0168)
Close an observed level window before navigation, foreground loss or observer
exit. Emit one stdout line with marker WOW_PERF_V1 followed by one JSON object:
{schema_version:1, reason:navigation|background|exit, stats:<entire snapshot>}.
Only emit when attached to a wheel and at least one interval/input sample/pending
input/drop exists. Empty/duplicate transitions emit nothing; repeated foreground
notifications preserve the current window. Navigation/background reset; background
frames/input are excluded. Logging/serialization occurs only at window close, not
on input/frame/refresh paths. No device IDs, personal data, analytics, new singleton,
files, release resources or player UI changes. Existing translations/readout stay.
Expose signal window_closed(record: Dictionary) for deterministic observation;
listeners receive the same record printed, independent of later metrics resets.

## Offline report (T-0169)
Add tools/performance_report.py: parse_capture(text: str) -> list[dict],
build_report(windows: list[dict], device: str, apk_sha256: str, source_sha: str) -> dict,
and main(argv: list[str] | None = None) -> int. CLI positional log path, required
--device, --apk-sha256, --source-sha; UTF-8 read only; JSON stdout. Parse marker
anywhere in logcat lines; ignore unrelated lines, reject malformed marked records,
unknown schema/reason/fields, nonfinite/wrong numeric types, negative counts,
inconsistent counts/availability/ranges/budget. No marked records is an error.
Validate latest-window count=min(samples,512), pending<=512, interval budget16667,
over_budget<=intervals, zero-input/zero-frame sentinels and percentile ordering.
Do not authenticate metadata: label device/APK/source values as operator supplied.
Keep ordered windows, sum counts; report maximum frame/latency and maximum WINDOW
p95, never synthesize a capture percentile/FPS from window means. No PASS/FAIL or
phase approval. Validation/I/O errors stderr + exit1, valid diagnostic report exit0;
normal argparse errors. No writes, dependencies, native binaries or CI edits.

## Scope and evidence
One branch/PR per task, fresh independent review, full make check and final-head
12-job CI before each sequential squash merge. Future task files freeze allowlists.
Read-only capture/report instructions include drag, rapid tile changes, submission
and persistence/retry, shuffle, cancellation, navigation and foreground transitions.
Reference Galaxy A15 tests, S26 observations and the separate five-outsider FUN GATE
remain human evidence; no synthetic device observations are recorded as completed.
