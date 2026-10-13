---
id: T-0333
title: Concrete owner preparation and atomic Progress commit port
epic: E16
type: feat
area: services.progress
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0332, T-0241]
touch:
  - game/services/economy.gd
  - game/services/progress.gd
  - game/services/content.gd
  - game/services/save.gd
  - game/services/save/atomic_save.gd
  - game/services/progress/progress_save_adapter.gd*
  - game/services/progress/atomic_progress_port.gd*
  - game/tests/integration/test_atomic_owner_port.gd*
  - docs/qa/T-0333-owner-preparation-port.md
  - tasks/T-0332-save-atomic-transactions.md
  - tasks/T-0333-owner-preparation-port.md
revision: 1
---

## Goal
Implement split 3 of owner-approved T-0330 after PR168, before T-0242 Progress/Events activation.
Owner requested this next integration step. Reconcile technically merged T-0332 status to done.

## Current state
Main f176abf contains Save v4, concrete-owner binding, lease/commit/recovery APIs, opaque handles
and writer barriers. Production AtomicSaveOwner preparation is unavailable. Progress P2/default port
stubs stay inert. ProgressLedger/Rules and RewardTable/WalletSnapshot are pure and shipped;
Content exposes copied metadata but no manifest fingerprint. Economy independent writes are serialized.

## Specification
1. Append Content.manifest_hash()->String, fingerprint the exact accepted manifest on load and keep
   previous identity on failed load. No manifest, content, config or reward value edits.
2. Append explicit Progress.configure_atomic(Config)->Error and completion_request(commands:Array[Dictionary])
   ->Dictionary, prepare_completion(SaveTransaction)->ProgressPrepared and registered-owner predicates/
   copied payloads, atomic_save_matches(Save)->bool and read_atomic(language:String,context:Dictionary)
   ->Dictionary for the concrete port. Only current bound completed BoardState matching Content may issue a request;
   keep private request/board/config/content/Save lineage/revision records. Prepare from committed
   language via ProgressLedger, verify exact candidate/delta/context. Retain approved board through
   lease/retry, independently of screen unbind. No P1 completion rewiring or P2 activation.
3. ProgressSaveAdapter maps only declared domain fields, postcards to completed_locations; rejects
   nonsequential markers, local credits/cards ahead of endpoints, bad current board or out-of-range
   slot as needs_migration. Preserve global unallocated stars, retired IDs, all owner extensions and
   unrelated languages. Missing active language is fresh read-only state; no getters write or grant.
   Explicit completion persists threshold feature union; no historical monetary backfill.
4. Append Economy.completion_commands(language:String,slot:int)->Array[Dictionary], prepare_commands
   (SaveTransaction,ProgressPrepared)->EconomyPrepared, predicates/copied payload and accept_commit.
   Canonical supported batch: configured positive base level_complete, plus one-time global Hint
   onboarding only at its actual future threshold crossing and without prior historical unlock or
   durable grant evidence in any language. Reject spend/double/ad/chest/other caller-selected commands;
   bonus_counter is preserved as T-0330 requires. Bonus discovery/settlement and provider grants need
   their separately scoped integration; this foundation does not activate their behavior. Never issue
   approval without Save-approved Progress identity. Both owners expose atomic_save_matches(Save)->bool. Whole batch derives wallet/journal using existing
   rules and injected Clock, unchanged extensions, bounded history. Independent grant/spend reuse
   the same value-only command/journal builder; public behavior stays unchanged.
5. Owner issuance records bind Save/lease/full request/hash/context/config and immutable copied payload;
   manufactured, wrong-owner, altered or stale handles reject. Same approved lease returns same handle.
   Add Save.publish_receipt(Dictionary)->Error and receipt_publishing()->bool with a Save-wide callback
   barrier; Economy accepts only Save-issued/resolved current-lineage proofs, publishes copied events
   once per in-process identity, never regrants. Current wallet supplies event view, historical amounts
   remain in receipt. Lost callbacks/restart do not erase proof or imply exactly-once delivery.
6. AtomicProgressPort implements existing port signatures, boot-only configure(Save,Progress,Economy)
   binds exactly those owners through Save before load. Read context is closed content_version:int /
   manifest_hash:String; recover context is closed request_hash:String. Port serializes calls, retains
   unresolved lease/approvals, retries identical hash only; rejects different requests without cancelling
   pending work. Map Save results to {error,state,snapshot,receipt}, CURRENT committed language snapshot,
   historical receipt; unknown/replaced outcomes remain conservative. Read legacy incompatibility is
   needs_migration with preserved data; no auto repair, unlock allocation, retro rewards or boot wiring.
7. Existing tests stay unchanged. Preserve unavailable default port and configure_p2/read stubs.
   No new Events signals, schema keys, dependencies, autoloads, UI, provider proof or roadmap edits.

## Tests
Real concrete owners/storage: value preparation without writes/events, exact configured batch, global
one-time crossing/no historical grants, forged/wrong-owner handles/changed candidate/delta/commands,
stale content/config/language/board and immutable copies; independent grant/spend behavior unchanged;
all five checkpoint restart old-or-one/retry/recovery, current view on historical replay, proof survives
journal trim, competing/dirty/pending/reentrant callers; receipt forgery/reset invalidation and lost
callbacks/screen unbind; v3/v4 golden lossless/P1 compatibility, nonsequential progress/cards/local stars,
missing language/retired credits/unallocated stars, fail-closed unsupported/default/no boot activation.
Full make check, scope/task lint, fresh exact-head independent review and all14CI before merge.

## Rollback
Leave v4 proofs intact; disable explicit coordinator construction. P1 boot remains unchanged.
