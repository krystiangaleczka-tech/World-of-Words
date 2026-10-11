---
id: T-0182
title: Render diagnostic captures as readable Markdown
epic: E10
type: feat
area: tools
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0181]
touch:
  - tools/performance_markdown.py
  - tools/tests/test_performance_markdown.py
  - tasks/T-0182-performance-markdown.md
revision: 1
---

## Goal
Render diagnostic captures as readable Markdown. Owner requests five further tasks possible before P2 without new human results.

## Context
T-0165/T-0169: engine render diagnostics are not physical latency or an NFR/FUN verdict. Original Astra Q3 and T-0139 remain human measurements. AGENTS.md requires bounded scope, public behavior tests and fresh review.

## Current state
T-0181 provides validate_report/parse_report; Markdown module/tests absent.

## Specification
Implement render_report(document: dict) -> str per contract. Include identity, summary, all ordered windows/reasons/14 stats, unavailable as not available and valid zero as 0. Escape device data and include units/coverage/interpretation limits. Validate before rendering; no mutation or acceptance verdict.

## Out of scope
No runtime, existing parser/tests, schema, APK, save/content, game visuals, dependencies, secrets or P2/gate changes. No invented device observations.

## Tests
Complete ordered windows/fields, values/units, sentinels vs zero, boundary coverage counters, escaped malicious Markdown/HTML and Unicode device, deterministic output, invalid report rejection, original input unchanged, no invented capture percentile or averaged FPS.

## Acceptance
Specified behavior/tests; full make check, scope/count, fresh independent review and final-head successful12jobCI before sequential squash merge.
