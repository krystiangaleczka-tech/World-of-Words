# Atomic Save/Economy and P2 adaptation contract (T-0330)

This is a proposed implementation contract, not an available capability. T-0241 remains unavailable
and T-0242 blocked until the following separately scoped implementation and tests pass. Owner
approved preparation of this prerequisite after the S1/S4 escalation in draft PR #164.

## Baseline and ownership

Save v3 exposes a dirty document through get_section after set_section; Economy masks only its own
pending candidate. A shared dirty flush cannot prove joint completion. SaveStorage writes temp,
flushes, rotates primary, then promotes temp; primary/temp/backup recovery already exists.
Save owns the file, settings, meta, revision and lease. Economy alone prepares/validates wallet changes
using its existing wallet rules; Progress alone prepares progress through ProgressLedger. A new
RefCounted coordinator is injected, never an autoload. No feature writes another owner's section.
Preparation changes no balance. Existing grant/spend entry points remain the independent monetary
path; their future internals and joint completion path share Economy-owned preparation/publication.
No balance value or reward formula changes; reward amounts/reasons must already be canonical.

## Proposed typed interfaces

These signatures are future APIs, not new stubs in this PR. All returned containers are deep copies.
SaveTransaction is a RefCounted lease handle with no public mutable candidate or constructor for
callers. Save binds its identity to the issuing instance, revision, lineage and original request.

```gdscript
# Save, appended APIs
func committed_view() -> Dictionary
func configure_atomic(progress: PROGRESS_SCRIPT, economy: ECONOMY_SCRIPT) -> Error
func migration_state() -> String
func validates_transaction(transaction: SaveTransaction) -> bool
func validates_progress(value: ProgressPrepared, transaction: SaveTransaction) -> bool
func begin_transaction(request: Dictionary) -> Dictionary
func commit_transaction(
    transaction: SaveTransaction, progress: ProgressPrepared, economy: EconomyPrepared
) -> Dictionary
func recover_transaction(operation_id: String, request_hash: String) -> Dictionary
func abort_transaction(transaction: SaveTransaction) -> Error

# SaveTransaction, read-only deep copies; owners first check bound Save.validates_transaction.
func request() -> Dictionary
func committed_view() -> Dictionary

# Economy, value preparation only; never mutates Save, wallet, journal or emits signals.
func prepare_commands(transaction: SaveTransaction, progress: ProgressPrepared) -> EconomyPrepared
func validates_prepared(value: EconomyPrepared, transaction: SaveTransaction) -> bool
func prepared_payload(value: EconomyPrepared, transaction: SaveTransaction) -> Dictionary
# Validate durable owner-issued receipt, publish committed wallet/cache once; no grant/reapply.
func accept_commit(receipt: Dictionary) -> Error

# Progress, owner checks Board/Content/context and uses ProgressLedger.
func prepare_completion(transaction: SaveTransaction) -> ProgressPrepared
func validates_prepared(value: ProgressPrepared, transaction: SaveTransaction) -> bool
func prepared_payload(value: ProgressPrepared, transaction: SaveTransaction) -> Dictionary

# Pure additive migration, selected by SaveMigrations default v4 chain.
static func migrate(source: Dictionary) -> Dictionary # MigrateV3ToV4

# Real coordinator implements the existing ProgressCommitPort signatures exactly.
```

committed_view: {error:Error, lineage:int, revision:int, sections:Dictionary}. On unloaded Save return
ERR_UNCONFIGURED and empty sections. sections contains copied known sections; callers ask owners
for interpretation. begin returns {error:Error,state:String,transaction:SaveTransaction|null,
view:Dictionary,receipt:Dictionary}. Success state preparing has one lease and committed view;
replayed has no lease and an existing durable receipt. Same ID with a different request hash rejects.
Hashes use canonical sorted-key JSON, normalized validated integers, SHA-256; no float/string coercion.
The hash covers the complete original request including commands, delta, context and candidate.
begin accepts the complete T-0241 request, validates its closed shape, calculates its hash itself and
stores a deep immutable copy in the lease. Owners read that copy; callers cannot swap commands or
baselines after begin. Only campaign_complete is supported by this initial coordinator contract.

ProgressPrepared and EconomyPrepared are opaque RefCounted handles, not Dictionary values. A caller
may instantiate a handle class, but only a matching registered owner can issue a valid handle. Each
owner keeps a private issuance record keyed by object identity, bound to Save instance, lease identity,
lineage/revision, full request hash and immutable candidate/notification values. No public constructor,
setter, deserializer or supplied approval flag can create a valid issuance record.
configure_atomic is boot-only before load, binds exactly one concrete Progress and Economy instance
and cannot replace them after load. Typed SCRIPT aliases refer to services/progress.gd/economy.gd.
Save calls those bound owners' validates_prepared methods at commit, checks both identities, and
obtains copied payloads through the bound owners prepared_payload only after validation. Payloads
are {section:Dictionary,delta:Dictionary,notifications:Array[Dictionary]}; Economy delta is {} and
Progress notifications is []. Invalid handles return {}. Copies cannot mutate issuance records or
replace handle payloads. Public validation methods are read-only predicates; Save validates_progress
delegates to its bound Progress instance so Economy can check the supplied Progress approval.
Save.validates_transaction checks its active private lease record; both owners require it before
reading or preparing from a handle. Issued handles are invalidated after abort, resolution or reset; a
second handle cannot authorize different content for the same lease. Forged/direct Save callers can
begin a syntactically valid request but cannot commit arbitrary sections without BOTH owner approvals.

Economy prepare_commands reads the lease's committed economy section and original commands. A
command is {operation:String,reason:String,amounts:Dictionary}; operation is grant or spend, reason
and amounts follow canonical owner/WalletSnapshot rules. For campaign_complete, Economy verifies
commands against the configured completion rewards and Progress-approved completed-board request;
caller-chosen amounts/reasons cannot authorize a grant. Whole ordered batch succeeds or returns an
invalid handle whose public error is non-OK. Valid handles expose error:OK and no mutable payload.
Economy derives wallet, bounded journal and unchanged bonus_counter/extensions using injected Clock.
Preparation mutates no Save state, wallet or journal and emits no signal. An independent pending
Economy request cannot be adopted or cleared. Progress similarly returns a handle with public error,
validating the original request against its current completed board, Content, language and ledger.
Economy must call its bound Save.validates_progress before issuing its own approval for completion
rewards; preparation records the approved Progress handle identity in the Economy issuance record.
Save commit requires that same Progress handle, not another independently valid approval.

The trusted injected coordinator first obtains Progress approval, then Economy approval, then calls
Save commit with both opaque handles. Save assembles only their immutable progress/economy sections,
delta and notifications plus its own revision/proof. Validate both owner candidates and full document,
and revalidate current board/Content/language/context immediately before storage write through owners.
A forged lease or handle, a handle issued by an unbound owner, changed payload or stale owner context
rejects. No generic Dictionary commit API exists. Owners never certify arbitrary caller candidates
solely because they are structurally valid. Tests directly call Save with forged/wrong-owner handles.

## Durable format and identities

The separately implemented Save v4 adds meta.atomic = {lineage:0,revision:0,processed:{}};
per-language location_stars defaults to {}. All old fields/extensions survive. meta.atomic is
Save-owned and validated; collisions with an existing extension of that name reject migration.
If any valid v3 document cannot be losslessly upgraded (including a meta.atomic collision), Save
loads its original copied v3 document in compatibility mode using a frozen v3 validator/canonicalizer;
migration_state returns needs_migration and atomic APIs return ERR_UNAVAILABLE. Do not continue
to backup or create a fresh save solely because migration is blocked. Preserve the primary file
until an explicit P1 write; P1 writes validate and persist v3, preserving the conflicting extension.
Recovered valid v3 temp/backup follows the same compatibility mode and existing promotion rules.
Reload/restart selects that document again; no automatic v4 conversion or replacement. Unreadable or
structurally invalid v3 still uses the existing corrupt-save recovery policy. migration_state is ready
only after a valid v4 document, and unconfigured before load. P2 semantic incompatibility after v4
load is independently needs_migration at the Progress adapter and also retains P1.
lineage/revision are nonnegative safe integers, with checked overflow. Successful durable mutations
increment revision, including settings, independent Economy, progress writes and reset. A debug
reset increments lineage, discards gameplay processed proofs and preserves current reset semantics
for identity/settings/purchases. Old handles and receipts cannot republish after reset.

Completion ID remains campaign_complete:<language>:<slot> within a lineage. Physical processed
key is lineage plus operation ID. Content changes do not change this identity. The durable processed
map is independent of the bounded diagnostic journal; do not evict proofs when trimming history.
Keep one proof per completion; size grows with completed campaign slots. Compression needs a
separate contract. This map grants no IAP/rewarded proof and never replaces monetization receipts.

Durable proof: {operation_id:String,request_hash:String,lineage:int,revision:int,language:String,
slot:int,context_hash:String,committed_snapshot:Dictionary,delta:Dictionary,
economy_snapshot:Dictionary,notifications:Array[Dictionary]}.
Snapshots are the owner-approved state at that commit, not a later state falsely paired with it.
Port results retain T-0241 {error,state,snapshot,receipt}; snapshot is the CURRENT committed language
view, receipt is the historical proof. Never overwrite current state from an old replay receipt.
The generic Save result uses {error,state,view,receipt}; map errors to the same state semantics.

## Serialization, visibility and recovery

Only one Save-wide lease or unresolved outcome exists. begin refuses a dirty legacy document,
unresolved independent Economy operation or competing writer with ERR_BUSY. Resolve existing work
through its owner, then begin on a clean durable baseline; do not flush another owner's work as proof.
During a lease, set_section, settings mutation, independent grant/spend, flush/pause and second begin
return busy without staging or side effects. All legacy/public readers expose the prior committed
state. New section candidates and processed proof are local until one full validated write.
Abort is permitted only before any storage write, releases the lease and does not touch persistence.
After writing starts, no cancellation can certify rollback; recover resolves the operation instead.
Screens hold no lease, and screen destruction cannot cancel it. User reset rejects while outcome is
unresolved; after resolution reset durably increments lineage and invalidates all old contexts.

On successful storage promotion, publish all committed sections/revision/proof before callbacks.
Release lease but retain a notification reentrancy guard; nested writes return busy while reads see
the new committed state. Economy publication precedes Progress/meta signals; no notification
controls persistence. accept_commit requires a proof issued/resolved by this Save in current lineage,
checks ID/hash and publishes no more than once in-process. Caller-made receipt copies cannot certify
new data. After a restart rebuild views from Save, not reapply monetary commands or promise exactly
once side effects. Lost notifications do not erase durable success.

On any non-OK storage return, retain the old visible committed document, no success signals and an
unresolved lease. A failure may have left a full temp or promoted primary. Immediately re-read with
the existing recovery priority and full schema/proof validation. If the selected document contains
this matching proof, promote recovered temp if required before further writes and publish replayed
success without reapplying commands. If it is the exact old baseline without proof, recover returns
pending and the SAME validated request may retry. A contradictory valid document/lineage/revision
rejects with ERR_BUSY, reloads its committed view and never overwrites replacement data. Invalid or
uncertain reads keep unavailable/pending; do not invent earned proof or mark operation rejected
merely because I/O is ambiguous. Successful recovery of a proof returns OK/replayed. Old baseline
visibility remains conservative until proof is established.

At every SaveStorage checkpoint and process restart recovery exposes either the old whole document
or exactly one whole new document (including proof), never mixed progress/wallet sections. A valid
old primary takes precedence over candidate temp; that resolves as old. Missing primary plus valid
temp resolves as new. A promoted primary followed by an error resolves as new. Test power-loss
boundaries available through this storage protocol; do not claim hardware fsync guarantees.

## Lossless historical adaptation

Pure v3-to-v4 migration never loads Content, allocates stars, generates cards/unlocks, grants coins
or emits notifications. Preserve current/completed/highest slot, global stars, board snapshots,
pieces/postcards/unlocked, every unrelated language/section and extension byte-equivalent values.
For absent location_stars add {}; preserve already present structurally valid location_stars exactly.
Require local totals <= global stars; reject malformed/conflicting added fields rather than erase
credits. Existing meta.atomic extension causes migration rejection, not replacement. Migration
input is never mutated. Validate migrated documents before Save exposes sections.

A language with highest_completed_slot != current_slot-1, completed_slot outside 0..highest,
known local stars exceeding completed slots, postcards ahead of current campaign endpoint,
out-of-range current slot or incompatible board is needs_migration for P2 activation. Preserve it
and keep P1; no silent repair or clean-save substitution solely due to semantic P2 incompatibility.
Retired IDs survive. Missing language is a fresh owner-created state, persisted only in an explicit
operation. Existing global unlocks are not copied into every language; persisted per-language IDs
survive, and threshold-derived feature union is explicitly owner-prepared and durably committed
before exposure as a newly persisted unlock. No getter writes or sends unlock notifications.

Historical global stars remain unallocated: location_stars initially {} and only future canonical
completions increase local stars. Existing pieces/cards remain monotonic. Historical campaign slots
at or below highest are ineligible for completion rewards even without a processed proof; endpoint
state and postcard credits remain separate. No retroactive base/chest/onboarding or meta grants.
A later completion uses existing ProgressLedger rules, including full pieces at an endpoint; that
is an explicitly earned future completion, not a migration backfill. No change to configured economy.
The real adapter must validate this policy with golden v3/v4 fixtures plus current Content before
claiming readiness; schema-version alone is insufficient capability evidence.

## Required implementation split and named tests

Separate branches/PRs: (1) v4 schema/migration and fixtures; (2) Save-wide lease/commit/recovery and
all competing writer paths; (3) Economy preparation/publication and real ProgressCommitPort adapter;
then T-0242 Progress/Events integration. Each must list affected existing tests in touch and remain
inactive until the complete capability passes. No partial boot wiring. Task IDs are assigned when
these specifications are prepared; this contract does not edit ROADMAP or authorize unrelated fixes.

| Required test | Evidence |
|---|---|
| test_v3_v4_lossless_extensions_and_languages | Deep copy, old fields preserved, absent local stars {}, no grants |
| test_v3_v4_conflicting_atomic_or_invalid_local_credits | Reject conflict/malformed, preserve originals |
| test_p2_legacy_incompatible_state_remains_p1 | needs_migration, preserved data, no readiness |
| test_historical_completed_slot_never_regrants | No proof needed to reject historical replay |
| test_joint_candidate_owner_validation | Reject forgery, invalid wallet, delta/proof mismatch and overflow |
| test_direct_save_forged_or_wrong_owner_handles | Reject structural dictionaries, manufactured handles and unbound owners |
| test_v3_atomic_collision_reopen_preserves_p1 | Original v3 selected, needs_migration, P1 write/restart preserves extension |
| test_competing_dirty_pending_and_reentrant_writers | Busy without staging; old/new committed views only |
| test_each_storage_checkpoint_restart_old_or_one | All five boundaries; wallet/progress/proof consistency |
| test_error_after_promotion_replays_without_grant | Ambiguous return resolves proof, one credit |
| test_retry_old_primary_ignores_temp | Same operation retries, no duplicated candidate |
| test_processed_proof_survives_journal_trim | Stable replay despite bounded history |
| test_old_receipt_preserves_newer_committed_view | Never roll back current state from historical receipt |
| test_wrong_hash_context_content_language_board | Reject skipped/stale/forged/reused IDs |
| test_reset_lineage_invalidates_pending_receipts | Busy while unresolved; durable reset invalidates prior lineage |
| test_screen_destroyed_and_notifications_lost | Correctness from durable view, not callbacks |
| test_configured_independent_grant_spend_behavior | Existing public behavior preserved; same serialization |

Exact fixtures and implementations must make these tests fail if atomicity, validation or dedup is
removed. Full make check, fresh independent review and CI are required per implementation PR.
