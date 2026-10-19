---
id: T-0366
title: Expose reviewed release proposals and explicit atomic append-only updates
epic: E22
type: feat
area: pipeline.export
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0365]
touch:
  - pipeline/src/wordgame_pipeline/release_apply.py
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/tests/test_release_command.py
  - docs/contracts/release-lock.md
  - tasks/epics/E22-content.md
  - tasks/T-0366-release-command.md
revision: 1
---

## Goal
Complete T-0302's bounded lock-update tooling: inspect a proposal first, then explicitly
apply that exact reviewed identity. Never infer an actual release or human approval.

## Current state
Preflight maineeece41: release_plan.plan_release_lock(root,content_root,cutoff)
returns frozen ReleasePlan with sha256/to_dict, validating complete content/evidence
between snapshots. filesystem.directory_fd yields no-follow directory descriptors.
cli.main exposes build/validate-content but no release-lock command. Existing locks
are enforced by content/export; no actual PL release baseline exists.

## Specification
- Add apply_release_lock(root,content_root,released_through,*,expected_sha256:str,
  approved:bool=False)->tuple[ReleasePlan,bool]. Require approved is True and exact
  lower-case64hex expected proposal hash before any writes. Recompute full validated
  proposal; mismatch rejects before even creating the locks directory.
- Write ONLY canonical root/locks/pl.lock.json; no alternate target/override. Open
  root/locks through existing no-follow descriptors; create missing locks directory
  only after first validation/hash agreement. A later failure may leave that empty
  directory, never altered baseline/content/evidence or retained temporary files.
- Serialize cooperating tool writers with nonblocking exclusive flock on the canonical
  locks-directory descriptor (Linux/Docker). Recompute/hash-check under the mutex,
  then for changes write/fsync an exclusive random temporary regular file through
  the directory descriptor, revalidate/hash-check immediately before atomic replace.
  All old entries must verify through proposal service; no shrink/rebaseline option.
- Same already-protected prefix is a validated no-op, preserving baseline bytes/mtime.
  Close descriptors/release mutex/clean temporary files on success and failure.
  Failure before replace preserves old baseline. Existing single-writer content/
  config contract remains; no cross-file transaction or power-loss guarantee.
- CLI wg release-lock --released-through N with --root/--content-root and --lang pl
  emits canonical JSON {schema_version:1,status:proposal,plan_sha256,proposal} without
  writes. --apply additionally REQUIRES --expected-plan-sha256 HASH and passes explicit
  approval; output status written/unchanged. Hash without --apply is an error.
  Errors use exit1/stderr and empty stdout; no new stages or build behavior changes.
- The explicit apply flag expresses operator intent, not evidence of a store release.
  Use only after Chris approves a real open-testing/production/App Store release.
  This implementation/tests must never apply to the repository's actual campaign.

## Tests
Temporary validated fixture only: readonly canonical CLI proposal; explicit initial/
extension/noop writes; stale/malformed expected hash and unapproved API fail; changed
baseline/content/evidence/protected geometry rejects; direct competing writer fails
nonblocking; injected write/fsync/replace failures preserve baseline and clean temps;
no symlink/FIFO bypass; CLI flag/error paths, existing export/content gates accept
new baseline; no artifact/content/evidence writes. Full check/review/exact-head CI.

## Rollback
Revert removes command/writer; any real baseline would require separate explicit
review and remains committed independently. This task creates none in the repo.
