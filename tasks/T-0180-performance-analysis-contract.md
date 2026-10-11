---
id: T-0180
title: Freeze offline performance analysis wave
epic: E10
type: docs
area: tools
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0179]
touch:
  - docs/qa/T-0180-performance-analysis-contract.md
  - tasks/T-018[0-4]-*.md
revision: 1
---

## Goal
Freeze offline performance analysis wave. Owner requests five further tasks possible before P2 without new human results.

## Context
T-0165/T-0169: engine render diagnostics are not physical latency or an NFR/FUN verdict. Original Astra Q3 and T-0139 remain human measurements. AGENTS.md requires bounded scope, public behavior tests and fresh review.

## Current state
T-0169 tools/performance_report.py exposes parse_capture, build_report and main. Report root has schema_version, operator_supplied, windows, summary. No tools/performance_validation.py, performance_markdown.py, performance_compare.py or performance_cli.py exist.

## Specification
Freeze the contract and ready tasks T-0181..T-0184. User reconfirmed no new human results and requested five works possible before P2. No existing runtime/parser modifications.

## Out of scope
No runtime, existing parser/tests, schema, APK, save/content, game visuals, dependencies, secrets or P2/gate changes. No invented device observations.

## Tests
Verify report/API/schema, missing future files, scopes/deps and full checks; fresh review.

## Acceptance
Specified behavior/tests; full make check, scope/count, fresh independent review and final-head successful12jobCI before sequential squash merge.

## Outcome
Frozen existing-report validation, readable rendering, comparison and CLI scopes. User reconfirmed work before P2 without new human results. Fresh independent review APPROVE on c1615033db2c49cd4ed23aebe5dee179c53e5b93. Full check: 275 GUT / 13332 assertions, 311 pipeline, 286 tools, 65 levels. Scope six files; count 507 unchanged. Final-head successful 12-job CI required before merge. No runtime, human evidence or gate changes.
