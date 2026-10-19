---
id: T-0365
title: Bind readonly release lock proposals to validated content and evidence
epic: E22
type: feat
area: pipeline.export
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0364]
touch:
  - pipeline/src/wordgame_pipeline/filesystem.py
  - pipeline/src/wordgame_pipeline/validate/locks.py
  - pipeline/src/wordgame_pipeline/release_plan.py
  - pipeline/tests/validate/test_locks.py
  - pipeline/tests/test_release_plan.py
  - docs/contracts/release-lock.md
  - tasks/epics/E22-content.md
  - tasks/T-0365-release-plan.md
revision: 1
---

## Goal
Prepare a deterministic reviewable release-lock proposal against already validated
shipped content, without writing files or claiming real release approval.

## Current state
Preflight maind3c1001: validate.locks exposes immutable ReleaseLock and
extend_release_lock(previous,levels,released_through), safe optional loader via
no-follow directory/nonblocking regular-file descriptors. content.validate_content
validates current P1 content/evidence readonly; bundle returns ordered levels and
canonical manifest bytes. SchemaRegistry.raw contains local schema bytes; config
load_config/canonical_bytes are public. No release proposal service exists.

## Specification
- Extract existing descriptor traversal into filesystem.directory_fd(path) context
  manager and filesystem.read_regular(path)->bytes|None. Preserve loader safety and
  missing semantics; no-follow directories/final entries, nonblocking final open,
  regular descriptor check and closing every owned descriptor. Shared helper is
  Linux/Docker tooling, not game code. Existing race tests target the shared module.
- New frozen ReleasePlan(previous:ReleaseLock|None,proposed:ReleaseLock,
  campaign_slots:int,manifest_sha256:str,evidence_sha256:str,validation_sha256:str)
  validates all direct constructors: bounds, hashes, and exact append-only overlap.
  to_dict returns fresh version1 scope=release-lock-proposal JSON; sha256 property
  hashes canonical to_dict. Report previous semantic lock hash/null, proposed lock
  and hash, counts and validation/content hashes, without machine paths/timestamps.
- plan_release_lock(root:Path,content_root:Path,released_through:int)->ReleasePlan
  reads complete canonical bundle, safe existing lock and required evidence. Take
  snapshots before/after existing readonly validate_content; reject changed inputs
  or missing content/evidence, stale/invalid semantics/provenance or unsafe lock.
- Snapshot identity covers manifest bytes (hence pack hashes), exact evidence bytes,
  semantic old lock, current normalized language config and exact local schema bytes.
  Validation context hash covers config/schema/evidence. A changed unlocked tail,
  bonus/metadata, evidence/context or prefix/cutoff must change proposal identity.
- Only use existing append-only helper after successful validation/stability check.
  Optional missing baseline permits initial proposal; never auto-create locks/evidence
  or prepare/repair content. Full P1 validation is not all P2/human release gates.
- Existing lock whitespace/key-order changes preserve semantic baseline identity.
  Assumes single-writer stable inputs; snapshots are stale-input detection, not a
  hostile concurrent filesystem transaction or release approval certificate.

## Tests
Validated initial/extension/noop proposals, deterministic/key-order/immutable report,
read-only bytes/mtime, content/evidence/config/schema/cutoff identity binding, malformed
content/provenance/evidence/unsafe lock, missing content/evidence, protected geometry,
invalid constructors/cutoff, deterministic mutation during validation rejected. Rerun
existing loader static/race suite. Full check/fresh pack review/exact-head CI.

## Rollback
Revert proposal service and shared-read extraction; no baseline/content was written.
