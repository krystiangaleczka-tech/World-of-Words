---
id: T-0317
title: Report CI package sizes against the app download budget
epic: E24
type: infra
area: ci
risk: high
executor: sol
think: low
ui: none
status: review
depends_on: [T-0137]
touch:
  - tools/check_app_size.py
  - tools/tests/test_check_app_size.py
  - .github/workflows/ci.yml
  - docs/qa/T-0317/**
  - tasks/T-0317-app-size.md
revision: 1
---

## Goal
Warn on package growth at 90 percent of the NFR-05 download budget, preserving
an honest distinction between today's debug APK and a store download measurement.

## Context
- docs/PRODUCT.md#non-functional-requirements: NFR-05 specifies download <=80 MB
  at P3 with one content language, with CI warning at 90 percent.
- ROADMAP T-0317 and rolling-wave rule: implement independent tooling against
  merged T-0137 now. T-0226/T-0315 remain prerequisites for release measurements,
  not for building this checker. This task does not close either release gate.

## Current state
- .github/workflows/ci.yml android-build exports builds/world-of-words-debug.apk
  then uploads that APK and android-debug-verification.txt.
- tools/android_debug_build.py verifies the real exported APK. No size report exists.
- tools/tests is run by make check. Python standard library suffices.

## Specification
- Add a CLI accepting one existing nonempty regular file, a required measurement
  label (debug-apk, release-apk, release-aab, release-ipa or store-download), and
  a required JSON report path. Stream bytes to calculate exact size and SHA256;
  no archive extraction or network calls. Missing/empty/directory input fails.
- Fix budget to 80,000,000 decimal bytes and warning threshold to 72,000,000.
  Report schema version, basename, measurement label, size, SHA256, budget,
  threshold, percentage, warning and over-budget booleans. Equality warns;
  over-budget means strictly greater than budget. Neither size condition fails
  this warning-only check. Invalid input/report I/O exits nonzero.
- Console summary clearly identifies measurement and bytes. Emit a GitHub Actions
  warning at/above threshold with fixed text (never interpolate untrusted filenames
  into workflow commands). Optional GITHUB_STEP_SUMMARY appends a concise fixed-label
  summary including proxy limitations. Print errors to stderr without traceback.
- Run after verified Android debug export and before upload in the existing job;
  upload JSON with the APK. Checker failure fails the job. No extra job, permissions,
  secrets, dependencies, export settings, SDK or application-code changes.
- Debug APK is only a growth proxy; AAB/IPA container sizes are also not store
  download sizes. Always state that actual per-device store download with one
  content language remains a release gate. The tool accepts an independently
  obtained store-download artifact; it does not calculate split/thinned download.

## Tests
- Exact bytes/hash and decimal budget; below/equal warning and budget boundaries.
- CLI real file produces valid report and optional summary, explicit proxy label.
- Warning and over-budget succeed with annotation; missing/empty/directory and
  report write failures fail without success output; absent summary is supported.
- CI wiring runs after export before upload and includes the JSON artifact.
- Full make check, fresh independent review, all exact-head CI checks pass.

## Acceptance
CI publishes the measured real debug APK report. Download and compare its exact
byte count and SHA256 with the associated APK before merge. Record the evidence
and open release-size gates in docs/qa/T-0317/README.md.

## Rollback
Squash revert removes tooling and CI step; no player data or exports change.
