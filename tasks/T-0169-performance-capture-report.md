---
id: T-0169
title: Report debug APK performance captures
epic: E08
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0168]
touch:
  - tools/performance_report.py
  - tools/tests/test_performance_report.py
  - docs/qa/T-0169-device-performance-capture.md
  - tasks/T-0169-performance-capture-report.md
revision: 1
---

## Goal
Report debug APK performance captures. Owner requested five more technical tasks before pending P2 human gates.

## Context
Astra Q3 in docs/qa/T-0142-architecture-preflight.md accepts the P1 allocation exception and requires actual device observations; no speculative wheel rewrite.

## Current state
T-0168 emits WOW_PERF_V1 JSON windows with snapshot fields; no performance report Python module, tests or capture note exists.

## Specification
Implement T-0165 Offline report interfaces/validation. Report schema_version1, operator_supplied {device,apk_sha256,source_sha}, windows unchanged in order and summary counts/maxima. Strip outer device whitespace; require nonempty device, lowercase hexadecimal APK64/source40. Stats exact keys and finite numbers, p50<=p95<=max, frame_mean<=frame_max, unavailable fps iff no intervals; available fps agrees 1000/frame_mean within rounding tolerance. Counts int excluding bool. Valid reports diagnostic only. Document reproducible read-only adb logcat capture plus explicit test scenarios and limitations.

## Tests
Known mixed-log records, unrelated/empty/malformed/unknown/nonfinite/count/availability/range failures, multi-window totals/max-window-p95 and ordered preservation, supplied metadata errors, CLI success/error/entrypoint and read-only input bytes. Use synthetic fixtures labeled synthetic; full checks and fresh review.

## Acceptance
All behavior and tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/device/FUN GATE approval invented.
