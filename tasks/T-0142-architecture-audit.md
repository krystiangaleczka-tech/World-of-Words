---
id: T-0142
title: Review the P0 and P1 architecture before P2 contracts
epic: E10
type: docs
area: docs
risk: low
executor: human
think: high
ui: none
status: done
depends_on: [T-0118, T-0127]
touch:
 - docs/qa/T-0142-architecture-preflight.md
 - tasks/T-0142-architecture-audit.md
revision: 2
---

## Goal
Deliver the ROADMAP architecture checkpoint on the actual P0/P1 implementation.
The roadmap row originally assigns Claude Opus. On 2026-10-10 Chris explicitly
selected Astra instead: "Zróbmy audyt z astra teraz". The assigned independent
reviewer for this task is therefore GPT-6 Astra (`gpt-6-astra`), with its actual
identity recorded. Preparation or routine PR review alone does not close the audit.

## Context
- docs/ARCHITECTURE.md#layers: core is pure; services own persistence; features
  call services; Events carries effects, not game logic.
- docs/ARCHITECTURE.md#autoloads: "The closed list. No task adds, removes or
  renames one; that needs a decision record."
- docs/CONTENT.md#principles: identical inputs/pipeline version produce identical
  output; the runtime has no dictionary.
- tasks/ROADMAP.md#model-usage-summary: T-0142 is the P0/P1 architecture audit.

## Current state
At main 68d7ccd55d01160c4512347b550136a2f16c93ec, T-0118 and T-0127 are done.
The project registers the documented 12 autoloads, Clock remains injected, Save
uses v2 with the v1 migration, and 65 generated PL levels ship. LevelData and
BoardState are pure classes; LevelController calls Progress for durable changes.
Eight typed Platform adapter boundaries and Fakes exist. P1 pipeline stages and
versioned intermediate artifacts are implemented. Android debug APK and actual
release-resource inspection passed the 12-job CI run 38015068644. Neither device
playtests, FUN GATE nor production signing has been completed.
Draft PR83 contains the factual preflight and task. Its preparation passed all
12 CI jobs in run 38036637940. Context/source review artifacts and an earlier
independent Codex opinion exist; Astra must independently examine the source and
challenge those conclusions. No runtime changes exist on the audit branch.

## Specification
1. Prepare docs/qa/T-0142-architecture-preflight.md with the exact audited source
   commit, provenance and a reproducible context-pack command. Do not commit a
   copied source snapshot or modify runtime, schemas, pipeline, roadmap or gates.
2. Check all ROADMAP dimensions: layer boundaries, exact autoload list/order,
   Platform contracts/Fake selection, LevelData and manifest/pack schemas, Save
   v1-to-v2/recovery chain, BoardState/LevelController APIs, and stage contracts.
   Cite actual paths/APIs/tests. Distinguish verified P1 behavior from P2 stubs.
3. Record confirmed issues and bounded design questions with evidence; do not
   turn task-approved P1 choices into fabricated regressions. Source inspection
   and desktop/headless tests do not prove Android performance or playtest results.
4. Obtain an actual independent Astra opinion covering all eight dimensions,
   ownership, durability, schemas, pipeline trust and P2 compatibility. Include
   exact source SHA, reviewer identity, reproducible findings and severity, Q1-Q4
   dispositions, verification limits and final architecture verdict in the report.
5. Keep the task blocked and PR draft if the assigned opinion is unavailable or
   critical findings lack a disposition. No Opus provenance may be claimed.
6. Complete the task after the Astra opinion is attached, findings are dispositioned,
   final documentation passes fresh independent review and CI is green. Required
   P2 contracts are recorded as follow-up requirements, not implemented in this
   documentation task. T-0143 remains a separate human FUN GATE.

## Tests
- Generate the context pack with tools/context_pack.py; all cited anchors resolve.
- Verify source references, exact autoload order, migration and reviewed contract
  boundaries; run full make check, task lint, scope and test-count checks.
- Fresh independent review validates the preparation and provenance. Existing
  tests are retained; no runtime tests are added for documentation-only changes.
- CI must pass on the final published audit documentation before merge.

## Acceptance
Complete architecture opinion with explicit reviewer identity, source SHA,
findings/disposition and P2 risks. A preflight alone does not satisfy this.

## Reviewer decision
Chris explicitly selected Astra on 2026-10-10, replacing the roadmap's Opus
assignment for this task only. This resolves the reviewer-availability escalation;
it does not approve device results, outsider playtests or FUN GATE.

## Outcome
Astra completed the independent audit on source
68d7ccd55d01160c4512347b550136a2f16c93ec: PASS for the architecture checkpoint,
with no confirmed critical/high P1 blocker and no required P1 runtime fix.
The full opinion is in docs/qa/T-0142-architecture-preflight.md. A1 (bonus-update
snapshot compatibility), A2 (sole-temp recovery) and Q1-Q4 have explicit dispositions
and named follow-up tasks. A3 (stale Platform header) is assigned to the next
Platform edit; it has no separate task ID yet.
Astra's focused verification passed 18 GUT tests / 100 assertions on Godot 4.7.2
and an in-memory artifact hash-boundary probe. The human gates remain open.
