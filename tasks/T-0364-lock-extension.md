---
id: T-0364
title: Propose append-only release lock extensions without rewriting protected slots
epic: E22
type: contract
area: pipeline.validate
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0363]
touch:
  - pipeline/src/wordgame_pipeline/validate/locks.py
  - pipeline/tests/validate/test_lock_extension.py
  - docs/contracts/release-lock.md
  - tasks/epics/E22-content.md
  - tasks/T-0364-lock-extension.md
revision: 1
---

## Goal
Prepare T-0302's explicit release-cut tool with a pure append-only lock proposal.
Existing released geometry must never be rehashed into a replacement baseline.
CONTENT.md#slot-policy: released slots cannot be removed/renumbered/reordered.

## Current state
Preflight mainea3079d: validate.locks exposes frozen LockedSlot/ReleaseLock,
geometry_sha256 and verify_release_lock. verify validates complete ordered campaign
and all projections, enforcing every existing locked hash. MAX_SLOT=9999 matches
current pack filename bounds. No lock extension helper or actual PL release lock
exists. Content/export gates enforce existing locks; creation is not implicit.

## Specification
- Add extend_release_lock(previous:ReleaseLock|None,levels:list|tuple,
  released_through:int)->ReleaseLock. Require real positive integer<=MAX_SLOT,
  within provided campaign and not below previous released prefix length.
- Validate previous type and complete ordered unique campaign1..N, including
  unlocked tail projections. Existing lock must verify BEFORE constructing the
  extension; no overwrite of changed/missing/moved previously released geometry.
- Without previous, create only an in-memory explicit prefix1..released_through.
  With previous, retain exact immutable old entries and append hashes for new
  slots. Same cutoff returns an equal lock after full validation, without mutation.
- Explicit cutoff may be below full campaign length. Allowed metadata/bonus repairs
  do not alter protected entries. New suffix geometry is hashed only for extension.
- No file reads/writes, publication, release authorization, default cutoff or hidden
  geometry normalization. Caller owns full tier/source/content semantic validation.
- Bounded T-0302 wave: T-0364 pure extension; T-0365 validated readonly release
  proposal; T-0366 explicit guarded update command. Actual release cut/approval,
  production calibration/content and other T-0301/T-0302 gates remain separate.

## Tests
Initial explicit prefix; append retains old entries; same cutoff validates; allowed
metadata repairs; shrink/overshoot/bool/invalid types; changed/missing/reordered old
geometry rejected; malformed unlocked tail rejected even outside cutoff; immutable
outputs and unchanged inputs, deterministic hashes. Full check/fresh review/all CI.

## Rollback
Revert removes unused pure helper; no actual release baseline has been created.


## Status reconciliation (2026-10-30)

Implementation merged through PR [#247](https://github.com/krystiangaleczka-tech/World-of-Words/pull/247) before this plan; its exact-head CI passed 16/16 checks. This metadata correction does not change code, content packs or review policy.
