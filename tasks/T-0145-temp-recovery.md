---
id: T-0145
title: Preserve a sole recovered temp save before rewriting it
epic: E10
type: contract
area: services.save
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0142]
touch:
  - game/services/save.gd
  - game/services/save/save_storage.gd
  - game/tests/integration/test_save_temp_recovery.gd
  - game/tests/integration/test_save_temp_recovery.gd.uid
  - tasks/T-0145-temp-recovery.md
revision: 1
---

## Goal
Address Astra A2 in the requested technical follow-up wave: a failed replacement
must not destroy the sole valid temp document from which Save just recovered.

## Context
- docs/ARCHITECTURE.md#save: "Each write step has an interruption test."
- docs/qa/T-0142-architecture-preflight.md: A2 names the open/truncate window.
- AGENTS.md: "Other services use only their own section."
This follow-up does not complete device tests or FUN GATE. It introduces no v3
schema, economy, signing or production phase gate.

## Current state
At 0086c50013acafcaef01aa70cad1f0cf61d3d2b4 Save.load accepts primary/temp/backup.
A recovered temp is dirty but not preserved before SaveStorage.commit reopens it.
Both flush and debug_reset call commit. Storage has four post-write checkpoints.

## Specification
1. Track whether the loaded source was temp. Immediately before any explicit
   write, promote that validated original temp to primary. Update source flags
   only after successful promotion; on failure report the error and remain retryable.
2. Normal load remains read-only. Recovery still emits backup_restored once;
   corrupt primary/valid backup handling and primary-first order remain unchanged.
3. Both flush and debug_reset use this preparation. Rotate the preserved valid
   primary to backup using the existing protocol. Do not rotate corrupt primaries.
4. Add SaveStorage.promote_temp() -> Error as a narrow rename seam, and a
   temp_opened checkpoint after opening output and before writing. A checkpoint
   failure closes the handle and propagates its error without writing.
5. Preserve identity, settings and progress after an open/truncate/write failure,
   including v1 temp migration, first-install interrupted temp and debug reset.
   Cover promotion failure, successful retry and a failure after actual promotion.

## Tests
File: game/tests/integration/test_save_temp_recovery.gd
- Sole v2 temp survives a commit override that truncates output then fails; reload
  retains prior slot/identity/settings, retry persists the new values.
- Promotion failure leaves the temp unchanged and causes no replacement commit.
- temp_opened interruption is safe after temp recovery and normal primary load.
- Recovery from v1 temp preserves the original document as backup on migration.
- Failed debug reset preserves recovered gameplay and can retry successfully.
- load alone neither promotes nor rewrites the recovered source.
Run focused save tests, full make check, task lint, scope, test-count and fresh review.

## Acceptance
New behavior survives reloading through a fresh Save; production tests fail if
promotion is removed. Existing recovery and golden tests remain green.

## Rollback
Reverting this task changes no on-disk schema; it restores the known sole-temp
resilience limitation. Existing v1/v2 documents remain readable.

## Outcome
Full make check passed: 224 GUT / 8611 assertions, 199 pipeline and 142 tools tests,
65 PL levels. Fresh independent review approved 2fafc8ded941080aec8e05bdfeec970e393a0ede
with no blockers. Final changes clarify the recovery comment, add the generated
test UID and record completion. Remote CI remains required before merge.
