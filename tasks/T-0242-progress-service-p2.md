---
id: T-0242
title: Implement committed P2 Progress and durable meta notifications
epic: E16
type: feat
area: services.progress
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0241, T-0234, T-0333]
touch:
  - game/services/progress.gd
  - game/services/progress/*.gd*
  - game/services/events.gd
  - game/services/save/atomic_save.gd
  - game/tests/integration/test_progress_p2_implementation.gd*
  - game/tests/integration/test_atomic_owner_port.gd
  - docs/qa/T-0242-progress-service-p2.md
  - tasks/T-0333-owner-preparation-port.md
  - tasks/T-0242-progress-service-p2.md
revision: 3
---

## Goal
Finalize the blocked specification in draft PR164 against implemented T-0330–T-0333 prerequisites.
Owner requested this next roadmap task. Implement T-0241 Progress APIs and durable meta effects;
reconcile merged T-0333 status to done. No automatic boot/UI activation; T-0243 owns navigation.

## Current state
Main a5d2fdc / PR169 has concrete immutable owner preparation, real injected AtomicProgressPort,
Save v4 lease/recovery/proofs and verified lossless legacy adapter. P2 service/default port APIs
remain inert. Progress has active P1 configure/board persistence/completion and owner preparation;
Events has economy_changed but no meta signals. Clean baseline536 GUT. PR164's prerequisite blockers
are resolved; its docs-only escalation must not be merged as this implementation.

## Specification
1. Implement configure_p2(Config,ProgressCommitPort,Events)->Error, p2_ready and committed copied
   language_progress/stars/is_feature_unlocked/location_state/region_state. Append p2_state()->String
   with unavailable/needs_migration/ready. Activation requires actual AtomicProgressPort ancestry,
   exact Save/Progress binding, same configured atomic Config and verified current read; fake/default
   available claims remain unavailable without Config or port reads. Failed initial configuration
   preserves P1. Once configured, unavailable/stale P2 must fail closed instead of taking P1 advance.
2. Append port certifies(Save:Node,Progress:Node)->bool and completion_commands(language,slot)
   ->Array[Dictionary]; defaults false/empty, concrete implementation verifies its bound owners and
   delegates proposals to its Economy. This avoids circular preload/API ownership guessing.
3. language_progress returns persisted domain fields only; current/highest use committed state in
   configured P2. Inactive-language metadata fails closed; explicit Save language/Content changes
   select its independent state without resetting global wallets/purchases. Missing active language
   starts read-only slot1/zero credits. No getter writes, derived-unlock publication or retro grants.
   location_state={metadata,stars,pieces,piece_count,campaign_complete,postcard_complete}; endpoints
   and earned card credits are separate. region_state={metadata,stars,unlocked,campaign_complete};
   region stars sum only known local credits, never unallocated global stars. Unknown IDs return {}.
4. Route complete_level to P2 only after explicit activation. Validate actual bound completed current
   board; use owner completion_request and port commands, one stable request and matching receipt.
   Retain pending request for exact retry/recover even after screen unbind. Dirty/competing writes
   remain busy. Historical/duplicate slots never regrant or announce again; skipped/wrong/stale
   board/context reject. Pause retries pending P2 before any legacy flush. Reset/replacement invalidates
   stale service state; no repair or cancellation of uncertain durable work.
5. Implement Progress.accept_commit on existing AtomicSaveOwner protocol: validate Save-issued/resolved
   current-lineage receipt/delta, clear matching pending request and mark at-most-once before callbacks.
   Add private Save coordinator dispatch to Progress.accept_commit after Economy.accept_commit in
   BOTH existing guarded publication paths. This is notification wiring only: no new Save public API,
   schema, values or economic rules. Replayed/lost delivery never decides persistence. Once activated,
   append typed Events stars_earned(language:String,slot:int,stars:int), postcard_piece_revealed
   (language:String,location_id:String,pieces:int), location_complete(language:String,location_id:String),
   feature_unlocked(language:String,feature:StringName,slot:int). Emit existing completed(slot) for the
   active receipt language, then four meta signals from receipt delta. Economy publication precedes
   Progress/meta; every competing writer rejects under Save guard, reads expose complete new state.
   Default/unconfigured Progress skips publication, preserving existing independent port/P1 tests.
6. Keep P1 behavior, persisted extensions/retired credits, current port protocol, default unavailable
   surface and existing tests unchanged except the two post-activation expectations in
   test_independent_grant_spend_use_shared_builder_without_activating_p2: real configuration now
   returns OK and exposes a fresh committed ProgressSnapshot. Preserve all other assertions.
   Bonus/provider integration remains separately scoped as in
   T-0333; no partial feature/SDK activation, analytics schema, content, config, autoload or roadmap edits.

## Tests
Explicit real activation/default/fake rejection, no implicit boot and initial P1 fallback; committed
reads/copies and missing/independent active languages; stars/local pieces/endpoints/cards/regions/
persisted feature union without getter grants; durable completion/event order, all5 storage checkpoints,
old views/failure/retry/restart/history/journal-trim; duplicate/skipped/incomplete/stale content/config/
board, dirty/pending competing owners, reset/replacement, screen unbind/pause, lost callbacks and
reentrant write/receipt/configuration attempts; v3/v4 historical compatibility without backfill.
Full make check, scope/task lint, fresh exact-head independent review and all14CI before merge.

## Rollback
Leave v4 proofs intact; disable explicit P2 configuration. P1 boot remains unchanged.

## Resolved S5 escalation
Chris explicitly approved revision3 scope after the 553/554 checkpoint: add
`game/tests/integration/test_atomic_owner_port.gd` and update only its two obsolete post-activation
oracles. Independent grant/spend and all pre-activation/default-port assertions remain unchanged.
