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
status: blocked
depends_on: [T-0118, T-0127]
touch:
 - docs/qa/T-0142-architecture-preflight.md
 - tasks/T-0142-architecture-audit.md
revision: 1
---

## Goal
Deliver the ROADMAP architecture checkpoint on the actual P0/P1 implementation.
The row explicitly assigns Claude Opus in a session started by Chris. Codex may
prepare a factual preflight and reproducible context pack, but cannot label that
preparation as the requested Opus opinion or close the checkpoint.

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
No T-0142 task/report exists yet. Claude Opus is not available in this session.

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
4. Prepare an explicit Opus review brief covering ownership, durability, schemas,
   pipeline trust boundaries and P2 compatibility. Leave its verdict pending.
5. If the assigned reviewer is unavailable, keep status blocked and the PR draft.
   Document the missing Opus opinion and any alternative requires Chris's explicit
   choice. The independent routine Codex PR review is not relabeled as Opus.
6. Complete the task only after the actual assigned review (or Chris's explicit
   replacement) is attached and critical findings have an agreed disposition.
   T-0143 remains a separate human FUN GATE.

## Tests
- Generate the context pack with tools/context_pack.py; all cited anchors resolve.
- Verify source references, exact autoload order, migration and reviewed contract
  boundaries; run full make check, task lint, scope and test-count checks.
- Fresh independent review validates the preparation and provenance. Existing
  tests are retained; no runtime tests are added for documentation-only changes.
- CI must pass before the preparation is ready for the assigned audit reviewer.

## Acceptance
Complete architecture opinion with explicit reviewer identity, source SHA,
findings/disposition and P2 risks. A Codex preflight alone does not satisfy this.

## Remaining required input
The assigned Claude Opus architecture opinion is unavailable in this session.
Codex preparation is complete; task remains blocked and PR stays draft until
the actual opinion or Chris's explicit replacement is provided.
