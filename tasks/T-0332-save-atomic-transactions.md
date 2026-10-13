---
id: T-0332
title: Save-wide atomic lease commit and recovery
epic: E16
type: feat
area: services.save
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0330, T-0331]
touch:
  - game/services/save.gd
  - game/services/progress.gd
  - game/services/economy.gd
  - game/services/save/atomic_*.gd*
  - game/services/save/save_transaction.gd*
  - game/services/save/progress_prepared.gd*
  - game/services/save/economy_prepared.gd*
  - game/tests/integration/test_save_atomic.gd*
  - game/tests/integration/test_save_v1.gd
  - game/tests/integration/test_save_v2.gd
  - game/tests/integration/test_debug_save_reset.gd
  - game/tests/integration/test_debug_screen.gd
  - docs/qa/T-0332-save-atomic-transactions.md
  - tasks/T-0331-save-v4-migration.md
  - tasks/T-0332-save-atomic-transactions.md
revision: 2
---

## Goal
Implement split 2 of owner-approved T-0330 before Economy/real-port split 3 and T-0242.

## Current state
Main d16fa902 contains merged T-0331/PR166 v4 migration and T-0247/PR167. Save exposes
P1 dirty sections, SaveStorage has five interruption checkpoints and temp promotion. Economy
serializes independent pending work; Progress has P1 completion retries and unavailable P2 stubs.
No atomic lease API exists. Reconcile merged T-0331 status to done.

## Specification
Implement T-0330 Save interfaces, opaque handles, closed canonical request validation, one
Save-owned lease, registered-owner validation, full-document commit, durable proofs, conservative
recovery and reset/revision rules. Block every competing Save/Economy/Progress write without staging
or clearing pending work. Publish complete document before callbacks with a reentrancy guard.
The shared typed AtomicSaveOwner base avoids circular preloads; configure_atomic additionally
verifies concrete Progress/Economy script ancestry and binds them only before load. Production
owners remain unavailable pending split 3/T-0242; no permissive approval implementation or boot wiring.
Tests use concrete-owner subclasses with private issuance records. Existing P1 behavior remains.
Listed historical test oracles change only for successful revision increments and reset lineage;
retain all original assertions. No balance/reward rules, schema, UI, port activation or roadmap edits.

## Tests
Closed request/hash/copy validation; manufactured/wrong-owner/mismatched handles, changed context;
dirty/pending/reentrant competing writers; all five checkpoint restart old-or-one consistency;
error after promotion replay; old primary retry; contradictory replacement and unknown reads;
proof survival after journal trimming; historical replay preserves current view; historical slot
without proof cannot regrant; reset overflow/lineage and invalidation; lost callbacks/restart;
production remains unavailable and v3 compatibility stays P1. Full make check, scope/task lint,
fresh independent exact-head review and all CI before merge.

## Rollback
Keep v4 reader and proofs. Disable activation rather than discard committed metadata.

## Resolved escalation
S5 scope extension approved by Chris on 2026-10-13: finish T-0332 after the explicit
debug-screen test scope question. Include its reset atomic metadata oracle; keep all other assertions.
