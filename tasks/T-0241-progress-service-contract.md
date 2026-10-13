---
id: T-0241
title: Define committed P2 Progress reads and atomic transaction port
epic: E16
type: contract
area: services.progress
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0240, T-0229, T-0238]
touch:
  - game/services/progress.gd
  - game/services/progress/progress_commit_port.gd*
  - game/tests/integration/test_progress_p2_contract.gd*
  - docs/qa/T-0241-progress-service-contract.md
  - tasks/T-0240-progress-ledger.md
  - tasks/T-0238-content-metadata.md
  - tasks/T-0241-progress-service-contract.md
revision: 1
---

## Goal
Define typed P2 Progress reads and the required atomic coordinator boundary without activating
new save/grant behavior. Owner requested creating/executing this missing next task.

## Context
GAME_DESIGN.md P2 ownership and T-0203 D2 require one validated durable candidate for progress,
wallet/items/bonus/one-time grants; a shared dirty Save then flush is not proof. Events are side
effects, never correctness. FR-PROG-04/05 and roadmap T-0241 own persisted per-language unlocks.

## Current state
Progress.configure(Save,Content), current_slot, highest_completed_slot, restore_level, save_level,
complete_level, bind_board/unbind_board implement active P1 with pending flush retries.
Save v3 has per-language stars/location_pieces/postcards/unlocked and preserves extensions;
location_stars is not an existing field. Content supplies copied catalog metadata. ProgressLedger
provides unused domain state. Economy.grant/spend persist independently; no real joint atomic
Save/Economy coordinator/preparation capability exists. Events has no P2 meta signals yet.
Reconcile technically merged T-0238/T-0240 statuses to done within task scope.

## Specification
1. Preserve every P1 signature, body, signal and caller. Append configure_p2(config,port,events)
   ->Error, p2_ready()->bool, language_progress(language="")->Dictionary, stars(language="")->int,
   is_feature_unlocked(feature:StringName,language="")->bool, location_state(id,language="") and
   region_state(id,language="")->Dictionary. Inject concrete Config/Events and ProgressCommitPort.
   This task stubs return ERR_UNAVAILABLE/false/0/{} even for apparently available fake dependencies;
   no dependency reads, writes, binding changes, event emission or boot wiring.
2. New ProgressCommitPort RefCounted exposes is_available()->bool, read_committed(language:String,
   context:Dictionary)->Dictionary, transact(request:Dictionary)->Dictionary, recover(operation_id:
   String,context:Dictionary)->Dictionary. Default always unavailable; responses are independent
   {error:ERR_UNAVAILABLE,state:"unavailable",snapshot:{},receipt:{}}. No I/O or mutable global state.
3. Future read semantics: only committed language state; missing language starts at slot1/zero
   stars and no credits. Preserve current/highest/completed markers, board snapshots, old credits,
   retired IDs, unrelated languages and owner extensions. Map domain completed_locations to
   saved postcards; preserve exact existing identifiers. No implicit allocation of old global
   stars into location_stars and no retrospective monetary/meta grants in getters. A legacy
   snapshot lacking canonical domain fields returns needs_migration and cannot become P2 ready;
   explicit verified legacy adaptation policy is mandatory before activation, not guessed here.
   Location state separates campaign_complete (endpoint) from postcard_complete (durable credits).
4. Future normalized port results: state committed/replayed/pending/rejected/unavailable/
   needs_migration; error OK only for committed/replayed. snapshot is committed domain data only,
   never a pending candidate; receipt is {} unless durable operation proof exists. A receipt contains
   operation_id, language, slot, context_hash, committed_snapshot and copied core delta.
5. transact request contract: operation_id:String, kind:"campaign_complete", language:String,
   context:{content_version:int,manifest_hash:String,level_id:String,slot:int,
   expected_current_slot:int,expected_highest_completed_slot:int,board_hash:String,
   expected_progress_hash:String}, progress_candidate:Dictionary, economy_commands:Array[Dictionary],
   delta:Dictionary. Hashes are canonical SHA-256 values. Stable completion identity is
   campaign_complete:<language>:<slot> within the save lineage, independent of content-version.
   Commands are prepared/validated by Economy ownership, never applied by Progress directly.
6. Required backend protocol before T-0242 activation: serialize competing owners, verify expected
   committed revisions/context and completed current Board/Content/language, build one structurally
   validated full Save candidate through owning services, atomically commit all owned sections plus
   durable processed operation proof. Progress must not call live Economy.grant/spend as a substitute
   for atomic preparation, nor update progress before a separately committed reward. Current APIs
   cannot implement this capability; a separately scoped hotspot Save/Economy contract is required.
   Default port keeps P2 unavailable until that real contract and legacy policy exist.
7. Failed/ambiguous write exposes old committed views and no success; identical retry/recover uses
   stable operation identity, never double star/card/unlock/economic credit. Other-owner flush cannot
   prove success by itself. Restart resolves old state or exactly one full operation; processed proofs
   survive bounded journal trimming. Stale/duplicate/skipped/content-changed/wrong-language/board/
   reentrant requests reject without overwriting replacement state. Screen destruction does not own
   or cancel a valid committed operation. Lost notifications recover committed views/receipts;
   at-most-once in-process effects, no impossible exactly-once effect-delivery claim across crashes.
   User/gameplay reset invalidates pending context; never reinstates discarded state.
8. Future Progress complete_level delegates only after P2 capability is ready; completion logic uses
   service completed(slot), with meta Events added in T-0242 after durability. Clear pending before
   callbacks while guarding reentrancy. Signals never decide persistence. Per-language changes never
   reset global wallets, consent or purchases. No Save schema, economy, signals or migration edits now.

## Tests
New test_progress_p2_contract.gd: typed default/injected unavailable APIs; independent returned
collections/port responses; a fake reporting available still cannot activate these stubs;
no port/Config calls, Save writes or signals; preconfigured P1 slot/highest/Clock unchanged and
existing contract signatures callable; missing/other language queries have inert defaults.
Full make check, task/scope checks, independent fresh review and CI.

## Acceptance boundary
This contract satisfies the interface/specification step, not production atomic/migration proof.
T-0242 must remain fail-closed at activation until the required separately scoped hotspot capability
and verified legacy policy are available. Do not silently broaden T-0242 into Save/ Economy work.

## Rollback
Unused P2 stubs/port only; P1 runtime and persisted data unaffected.
