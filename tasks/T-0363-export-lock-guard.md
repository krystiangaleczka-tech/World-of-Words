---
id: T-0363
title: Guard export artifacts and publication with released geometry locks
epic: E22
type: feat
area: pipeline.export
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0362]
touch:
  - pipeline/src/wordgame_pipeline/export/__init__.py
  - pipeline/src/wordgame_pipeline/export/publish.py
  - pipeline/src/wordgame_pipeline/validate/schema.py
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/tests/export/test_release_locks.py
  - docs/contracts/release-lock.md
  - tasks/epics/E22-content.md
  - tasks/T-0363-export-lock-guard.md
revision: 1
---

## Goal
Protect CONTENT.md#slot-policy released geometry through normal export and actual
publication, including read-only checks and direct publisher API calls.

## Current state
Preflight main35e5b96: export.handlers_for(root,slots,version) validates provenance
then assemble produces {options,files}; run_build writes artifact after handler
returns. publish(payload,output,registry,*,check=False) checks schemas/hashes,
then existing files/version/check/no-op before staging/replacement. SchemaRegistry
loads package-local raw schemas but retains no root. CLI uses handler+publisher for
normal export and --check, with --plan returning paths without export. T-0362 adds
validate-content --require-release-lock; export has no release guard. T-0361 loader/
verifier exist. Existing temporary content/export test fixtures are reusable.

## Specification
- SchemaRegistry retains absolute root Path as registry.root at construction to
  anchor its lock source independent of subsequent cwd; schema behavior unchanged.
- handlers_for gains keyword require_lock:bool=False. Its export closure validates
  bool, loads canonical root/locks/pl.lock.json, rejects absence when required,
  assembles/revalidates normally then verifies complete output campaign against any
  existing lock BEFORE returning payload (hence before export artifact write).
- publish gains keyword require_lock:bool=False. Always load registry.root's canonical
  PL release lock; malformed/unsafe locks always fail, strict absence fails. Verify
  complete proposed levels in manifest pack order after schemas/hashes but before
  existing-output checks, check/no-op/version returns, mkdir/staging/replacement.
  No caller-supplied bypass lock or dependency on --output directory is introduced.
- CLI build --require-release-lock passes through to both gates for normal export
  and --check, including custom --output. Reject the flag with non-export stage
  selection. --plan remains no-export/no-lock-read planning even when flag is set.
- Missing lock in ordinary P1 keeps current behavior. Valid appends, independently
  valid metadata/bonus repairs, version checks/rollback and readonly --check remain.
  Existing lock is reread at publication, not trusted only from an earlier stage.
- No release baseline/update command, override, content changes, P2 activation,
  schema document changes, CI wiring, dependencies or human release approval.
  Single-writer publication remains the existing concurrency contract.

## Tests
Direct publish with rooted registry: changed/missing/reordered locked slots fail
without output/artifact/temp writes, even check/no-op; strict/unsafe/missing lock;
valid prefix/append/seed repair retain versions and readonly repeat/check. Stable
registry root after cwd change. Root-aware handler and CLI normal/check/custom output:
valid export, strict absence, changed geometry despite valid revised authorship
fails before existing export artifact/output changes, optional P1 absence, --plan
no lock read and non-export strict flag error. Reload changed lock at publication.
Full check, fresh generated-pack review and all exact-head CI before merge.

## Rollback
Revert removes export guard; existing locks and shipped content are unchanged.


## Status reconciliation (2026-10-30)

Implementation merged through PR [#246](https://github.com/krystiangaleczka-tech/World-of-Words/pull/246) before this plan; its exact-head CI passed 16/16 checks. This metadata correction does not change code, content packs or review policy.
