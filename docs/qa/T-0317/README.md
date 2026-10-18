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
Full local checks, independent review and exact-head CI evidence are recorded in
the PR. The CI artifact measurement will be recorded here after verification.
