---
id: T-0362
title: Enforce release locks in content validation before evidence writes
epic: E22
type: feat
area: pipeline.validate
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0361]
touch:
  - pipeline/src/wordgame_pipeline/content.py
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/tests/validate/test_content_locks.py
  - docs/contracts/release-lock.md
  - tasks/epics/E22-content.md
  - tasks/T-0362-content-lock-guard.md
revision: 1
---

## Goal
Enforce T-0301's released geometry guard in the existing shipped-content validator,
including evidence preparation, without inventing a production release baseline.

## Current state
Preflight main263c82f: validate.locks exposes load_release_lock(root,lang) and
verify_release_lock(lock,levels). content.validate_content(root,config,content_root,
*,prepare=False)->int|None calls bundle then provenance/semantic checks, writing
content-evidence only at the end of prepare=True. Missing initial content/evidence
can SKIP. cli.main exposes validate-content and --prepare-evidence. Existing
pipeline/tests/test_content.py workspace(root) builds a complete temporary P1
fixture; no actual production lock file exists. Prior release-lock checks are unused.

## Specification
- Explicitly extend validate_content with keyword require_lock:bool=False. Validate
  bool; load the canonical root/locks/pl.lock.json before initial-content SKIP.
  If require_lock and absent, fail. Malformed/unsafe existing lock always fails.
- Missing lock with require_lock=False keeps pre-release P1 behavior. Existing lock
  with absent content cannot SKIP. After bundle checks, verify complete campaign
  against the lock before provenance/evidence construction or any evidence writes.
- Existing semantic/provenance/tier/handmade/bonus checks remain in force, including
  prepare=True and ordinary read-only paths. Valid appended slots are accepted;
  bonus repairs still require independent valid dictionary/handmade evidence.
- CLI validate-content --require-release-lock maps to require_lock=True. Error uses
  existing exit1/stderr and no success output. No export/build CLI behavior changes.
- No automatic lock generation/repair, shipped changes, production activation,
  config defaults, dependency, CI wiring or released-slot override mechanism.

## Tests
New test_content_locks imports existing fixture without editing it. Cover normal/
strict CLI and API, locked repeat readonly bytes/mtime, optional absence unchanged,
required absence, missing content with existing lock not SKIP, malformed/unsafe
existing lock, changed released geometry in otherwise valid content/authored input
fails before prepare evidence updates, allowed seed change, appended campaign tail,
and independent tier/bonus/provenance failures still reject. Full check/review/CI.

## Rollback
Revert restores P1 validation without this lock gate; no content/locks were changed.


## Status reconciliation (2026-10-30)

Implementation merged through PR [#245](https://github.com/krystiangaleczka-tech/World-of-Words/pull/245) before this plan; its exact-head CI passed 16/16 checks. This metadata correction does not change code, content packs or review policy.
