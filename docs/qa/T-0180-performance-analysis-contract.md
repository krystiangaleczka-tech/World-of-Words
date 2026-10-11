# T-0180 — Offline readable performance analysis

## Authorization and purpose
Owner requested another five tasks and explicitly answered that there are no new human results: continue work possible before P2. Existing T-0169 emits JSON; add strict roundtrip validation, readable Markdown and two-capture comparison to help analyze actual future observations. No new measurement source, runtime changes, fabricated phone evidence or phase approval. T-0139/T-0140/T-0141/T-0143 and original Astra audit remain separate.

## Existing report
T-0169 report root exact keys: schema_version integer1, operator_supplied, windows, summary. Identity exact keys device (nonblank string), apk_sha256 (64 lowercase hex), source_sha (40 lowercase hex). Windows retain ordered schema v1 records and 14 stats; build_report validates these and computes summary.
Summary exact keys: samples, pending, dropped, frame_intervals, frame_over_budget, window_count (nonnegative integer counts, window_count positive), max_frame_ms, max_latency_ms, max_window_p95_ms (finite numbers, -1 unavailable). Summary maxima represent window maxima; max_window_p95_ms is a maximum of window p95 values, not capture p95.

## T-0181 validation interfaces
validate_report(document: object) -> dict validates exact root/schema/identity shape, calls existing build_report on windows and supplied identity to validate values and recompute summary. Windows must be a nonempty list. Validate summary exact keys and exact computed values; reject boolean numbers, nonfinite measures, wrong count types and any tampering. Normalize identity as existing build_report does (device strip); return a deep copy of the recomputed report, independent from inputs. Numeric int/float equality allowed for finite measures, never booleans. Counts require exact int. No authentication, input writes or original parser changes.
parse_report(text: str) -> dict parses strict JSON, rejects duplicate keys at any nesting depth and NaN/Infinity literals, then calls validate_report. Errors ValueError, including wrong types/overflow/deep JSON, with field context where possible. Existing parser/main remain unchanged. New modules support both package imports and direct CLI sibling imports.

## T-0182 Markdown
render_report(document: dict) -> str validates first. Deterministic Markdown with operator-supplied warning, all identity fields, every summary field, ordered indexed windows with reasons and all 14 stats (stable sorted field order). Known -1 unavailable values render 'not available'; zero remains '0'. Attach ms to latency/frame measurements, Hz to fps and microseconds to frame_budget_usec; counters are labeled as counts. Identity data escaped: raw HTML, Markdown pipes/backticks/brackets/backslash/newlines must not introduce markup; preserve Polish text.
Explain engine dispatch-to-post-draw boundary, latest512 window percentiles, fixed16667us diagnostic budget, pending/drop gaps and max-of-window p95. No averaged FPS, merged/capture percentile, PASS/FAIL or human acceptance. Input intact, UTF8 string plus single trailing newline.

## T-0183 comparison
compare_reports(baseline: dict, candidate: dict) -> dict validates both then returns exact keys schema_version=1, operator_supplied=true, baseline, candidate, metadata_differences, deltas. baseline/candidate are independent full validated report copies. metadata_differences sorted list of changed identity keys (device, apk_sha256, source_sha) comparing normalized identity exactly. Different source/APK are observations, not errors. Operator device text includes OS/refresh/scenario context; exact string change is visible but text equality cannot authenticate comparability.
Deltas contain all nine summary fields, each candidate-minus-baseline. Counts always integers. For max_frame_ms/max_latency_ms/max_window_p95_ms, if either side is -1 use null, never subtract unavailable sentinels. No ratios, artificial weighting/averaged FPS, capture percentile or matched window inference. Different scenario/window counts/coverage remain explicit in preserved inputs and deltas. Deep independent outputs; no causal or winner/regression/gate verdict.
render_comparison(baseline: dict, candidate: dict) -> str renders deterministic Markdown: warning on operator context and lack of causal/acceptance verdict, metadata differences and a table with all summary fields and baseline/candidate/delta (units, unavailable/null as 'not available'). Include full render_report for both inputs so per-window coverage is retained. Escape user text using same renderer rules. Single trailing newline; no mutation.

## T-0184 CLI and note
python tools/performance_cli.py report PATH prints Markdown from existing T-0169 JSON.
compare BASELINE CANDIDATE --format json|markdown defaults Markdown; JSON prints comparison with ensure_ascii false, allow_nan false, sorted keys, indent2 and trailing newline. UTF8 read only/stdout only; input/I/O/encoding/validation errors stderr with prefix and exit1, argparse errors exit2, no partial output/writes. Script and module entrypoints. Existing tools/performance_report.py capture CLI unchanged.
Note documents raw log -> existing report -> Markdown/compare commands; operator actual APK/source identities, comparable device/OS/refresh/scenarios and coverage, absence of closed windows does not show smoothness, engine boundary limitations and pending human gates. Output redirection must not target an input file. Any shown fixtures must be labeled synthetic, not phone measurements.

## Sequencing
T-0180 freezes this contract and T-0181..T-0184. Each branch starts fresh main after dependencies merge, full checks, fresh independent review, final-head successful12jobCI and sequential squash merge. No future implementation before dependency merge.
