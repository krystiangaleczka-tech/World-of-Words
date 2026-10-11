# T-0175 — Offline outsider playtest evidence

## Purpose and boundary
Owner requested five more tasks after T-0174. No new ready task/remote commit exists. Prepare evidence collection for pending T-0141 using the T-0154 baseline, without claiming sessions occurred. This is operator-entered data, not authenticated telemetry or a FUN GATE verdict. T-0139/T-0140 prerequisites, original Astra audit and Chris's T-0143 decision remain separate. No game/save/content changes or personal campaign resets.

## Worksheet schema v1
Exact root keys: schema_version (integer 1), build, sessions. Build has exact keys source_sha, apk_sha256, content_sha256; each null when unknown or lowercase hex of length 40/64/64. This is the intended common build; each session separately records the same three fields so mixed/unknown builds are visible.

Each session has these exact fields:
- participant_id: unique anonymous string P followed by two digits, P01..P99.
- date: null or a valid YYYY-MM-DD calendar date.
- device, android_version: null or nonblank strings.
- refresh_hz: null or finite positive number; booleans are not numbers.
- power_saving, outsider, clean_campaign, answers_hidden, instructions_given, help_given, wants_continue: null or boolean.
- start_slot, final_slot: null or positive integer (booleans rejected).
- active_seconds: null or nonnegative integer; measure actual active play, excluding pauses.
- source_sha, apk_sha256, content_sha256: null or lowercase hex of the specified length.
- first_word: null means unknown; empty string means explicitly observed no self-discovered word; otherwise nonblank string.
- stalls: null means unknown; [] means observed none; otherwise an array of nonblank strings describing actual stalls.
- notes: string, empty allowed.

No additional keys. Every key must exist. One to 99 sessions allowed; duplicate IDs rejected. Nullable fields make partial/assisted/short sessions valid records without asserting a successful protocol. Valid syntax does not establish device identity, truth or acceptance. Parser rejects duplicate JSON keys at any nesting level and NaN/Infinity; validation errors identify field/session paths. Validation does not mutate inputs.

## T-0176 blank worksheet
build_worksheet() returns schema v1, five P01..P05 sessions. All observed fields and build hashes null; notes empty. participant IDs/schema are structural defaults, not observations. Fresh nested containers per call. render_worksheet() returns deterministic Unicode-preserving sorted/indented strict JSON plus newline. No CLI or file writes yet.

## T-0177 validation
parse_worksheet(text: str) -> dict parses strict JSON and validates; validate_worksheet(document: object) -> None raises ValueError for invalid shape/types/values. Missing keys are invalid structure, null means missing evidence. Error messages include a path (e.g. sessions[0].active_seconds). Reject boolean schema_version/counts, nonfinite refresh, invalid dates/hashes and duplicate IDs. Legitimate early exits, help, no first word, no stalls remain accepted observations. No cross-field guesses about what happened.

## T-0178 summary
build_summary(document: dict) -> dict validates first and returns independent data with exact root keys schema_version=1, operator_supplied=true, build, sessions, totals. Each session row has participant_id, observations (deep copy of session), missing (sorted field paths), deviations (sorted codes). Missing includes every null session field and build.KEY for each unknown common hash; first_word="" and stalls=[] are observed, not missing. Notes are optional.

Deviations apply only to known observations: insider (outsider=false), campaign_not_clean (clean_campaign=false), start_not_one (start_slot!=1), answers_visible (answers_hidden=false), instructions_given, help_given, under_20_active_minutes (active_seconds<1200), and mismatched_source_sha/apk_sha256/content_sha256 when both session and intended common hashes exist and differ. Unknown evidence is missing, never a deviation or fabricated failure. Wants_continue=false is an observation, never a protocol deviation. No automated reference-device or perceived-lag verdict.

Totals exact keys: recorded_sessions, sessions_with_missing, sessions_with_deviations, sessions_with_complete_protocol_record, active_seconds_observed, wants_continue_yes, wants_continue_no, wants_continue_unknown. Complete protocol record means no missing and no deviations, not gate acceptance. Active seconds sums known values only; continue counts retain unknown. No pass/go/qualifying/FUN verdict or arbitrary scores. Fewer than five complete protocol records is visible in counts, not a synthetic gate outcome.

render_summary(document: dict) -> str emits Markdown: operator-supplied warning; common build identities; totals; each participant's observed fields, missing paths and deviations. Unknown rendered as 'not recorded', first_word="" as 'none observed', stalls=[] as 'none observed'. Escape raw HTML/Markdown including pipes, backticks, brackets, backslashes, newlines; preserve Polish text. Include no answer keys or participant names. Original notes are printed as escaped observations. Deterministic ordering/output; no input mutation.

## T-0179 commands and collection note
python tools/playtest_cli.py template prints blank JSON.
validate PATH prints 'Valid worksheet format; observations and gates are unverified.' on success.
report PATH --format json|markdown defaults to Markdown; JSON renders build_summary with sorted keys/indent, strict numbers and trailing newline. Stdout only; input files read UTF-8. Input/OSError/UnicodeError/ValueError yield concise stderr and exit1, usage errors argparse exit2. No partial output on failure. No file writes or metadata authentication; shell redirection is the operator's output choice.

Note records actual APK/source/content hash, date, Android/device/refresh/power saving and actual active duration. Five people outside project, same recorded build, isolated clean campaign slot1, no instructions/help, answers and debug overlays hidden. Do not reset Chris's campaign. Record early exits/help/stalls honestly. Keep participants anonymous. Tool completion is distinct from pending human T-0139/T-0140/T-0141/T-0143, A15 feel evidence, per-word review and FUN decision.

## Execution
T-0175 freezes this contract and T-0176..T-0179 scopes. Each task uses fresh main, own branch/PR, full checks, fresh independent review, final-head successful 12-job CI and sequential squash merge. Synthetic test fixtures are labeled and never committed as observed results.
