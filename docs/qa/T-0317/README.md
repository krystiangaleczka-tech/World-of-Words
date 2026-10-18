# T-0317 — package size warning

NFR-05 uses decimal MB: budget 80,000,000 bytes, warning from 72,000,000 bytes
inclusive. A size warning succeeds; unavailable/empty artifacts or report I/O
failure fail the step. Report records exact bytes and SHA256 from the same stream.

The existing Android debug job measures its verified APK before uploading it and
includes `android-debug-size.json` in `world-of-words-android-debug`. The summary
and JSON explicitly label debug APK size as a growth proxy. No export, signing,
permissions, plugin or player-facing change is made.

## Open release gates

T-0226/T-0315 must provide actual iOS/Android release builds. AAB and IPA container
bytes do not establish per-device store download size. NFR-05's P3 <=80 MB download
with one content language still needs store split/thinning measurement. This task
neither waives these gates nor claims a passing release measurement.

## Validation

Preflight: fresh main c253a60; T-0137 merged in 5bb5748. Existing CI exports and
verifies the debug APK, with no size report. Phase-2 rolling-wave planning moves
tooling ahead of external release prerequisites; no roadmap IDs or rows changed.
Fourteen new tests cover exact boundaries, actual bytes/hash, summary append,
warning-only over-budget behavior, invalid input/output and artifact overwrite
protection including hard links, plus real CI step ordering and artifact wiring.
Local make check passed: Godot 1002 tests / 34043 assertions, pipeline 329 tests,
tools 588 tests. Registry, content, UI guards and 14 generated theme outputs passed.
Independent fresh Sol review: PASS from the generated review pack.

Implementation commit `3427846` passed all 16 checks in
[CI run 39137857128](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/39137857128).
Downloaded `world-of-words-android-debug` artifact `12141000250`; independently
streamed the enclosed APK and compared its byte count and SHA256 to the enclosed
`android-debug-size.json`:

- Exact APK size: 30,283,665 bytes (30.283665 decimal MB), 37.85458125% of budget.
- SHA256: `ae114f9db7dec5fbdf4b02414dddc040675cf98e391eb7442f0613234b2c3d02`.
- Warning: false; over budget: false. Both values independently recomputed.

The same run's gallery artifact `12140363279` passed all 180 image size/hash and
complete-matrix checks; a native Actions/PL/default screenshot was visually inspected.
Final documentation commit CI and its independently checked APK are recorded in
PR #221; the implementation measurement above identifies its exact source run.
