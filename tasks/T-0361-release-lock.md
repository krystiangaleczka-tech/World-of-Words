---
id: T-0361
title: Define immutable released campaign geometry locks
epic: E22
type: contract
area: pipeline.validate
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0360]
touch:
  - pipeline/src/wordgame_pipeline/validate/locks.py
  - pipeline/tests/validate/test_locks.py
  - docs/contracts/release-lock.md
  - tasks/epics/E22-content.md
  - tasks/T-0361-release-lock.md
revision: 1
---

## Goal
Prepare T-0301's released-slot guard without declaring any prototype released.
CONTENT.md#slot-policy: hashes protect letters, placed words and grid; allowed
bonus/difficulty/seed/pipeline repairs must not change geometry identity.

## Current state
Preflight main47994fe: config exposes strict parse_json/canonical_bytes;
validate.schema.json_value rejects nonfinite/non-JSON/cyclic values. No locks module
or pipeline/locks/pl.lock.json exists. validate-content and export do not yet enforce
release locks. SlotPlan reserves identity only. T-0360 reports released geometry
unverified. Existing campaign identity is pl-c-NNNNNN, slots1..9999 (pack limit).

## Specification
- New pure geometry_sha256(level:object)->str hashes canonical bytes of exactly
  {letters,words,grid}, preserving array order and coordinates. Validate finite JSON,
  campaign identity/slot consistency and structural projection shapes. This is not
  tier/geometry semantic approval; those gates remain separate.
- Frozen LockedSlot(slot,id,geometry_sha256) and ReleaseLock(lang,levels:tuple)
  validate constructors. PL only; nonempty contiguous canonical released prefix1..R,
  exact campaign ID per slot, lower-case64hex digests, manifest/pack-safe slot bounds.
  from_dict accepts exact version1 {schema_version,lang,levels}; exact slot entries.
  to_dict returns fresh JSON containers; no mutable retained caller data.
- verify_release_lock(lock,levels:list|tuple)->None validates full ordered unique
  campaign1..N and every projection before comparison. Locked prefix must be present
  at same IDs/slots with equal hashes. Reject missing/reordered/renumbered/changed
  geometry; allow appends and changes to unprotected fields. No mutations/writes.
- load_release_lock(root:Path,lang:str)->ReleaseLock|None reads only
  root/locks/pl.lock.json. Missing is None (pre-release P1), not an empty lock or
  implicit approval. Existing empty/malformed/duplicate-key/nonfinite files fail.
  Reject symlinks including parent/dangling links, special files and nondirectory
  ancestors before reading; never block on FIFO. No lock creation/update/repair.
- Bounded wave: T-0361 contract; T-0362 validate-content enforcement; T-0363 guarded
  export/publication. Release cutting/update command, actual release baseline,
  production calibration, token/difficulty hard rules and human review stay open.

## Tests
Hash sensitivity to each locked field/order/coordinates and stability for allowed
metadata/bonus changes/key order; immutable roundtrip and strict constructor/input
fields/types/prefix/identity/hash; verify append/missing/reorder/change and complete
input validation; safe missing/valid/malformed/duplicate/nonfinite/file/ancestor/
symlink/FIFO paths; no mutations/writes. Full check/fresh pack review/exact CI.

## Rollback
Revert unused contract; no release baseline or shipped files have changed.
