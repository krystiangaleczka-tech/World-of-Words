# T-0333 concrete owner preparation and Progress port

Base f176abf / merged T-0332 PR168. This is split3 of T-0330. No ordinary P1, configure_p2,
feature, boot or default ProgressCommitPort activation changes are included. Explicit construction
binds concrete Progress/Economy to one Save before load and separately configures owner dependencies.
The port reports availability only with matching owners and verified active-language adaptation.
T-0242 still owns P2 service integration and Progress/meta event publication.

## Preparation and ownership

Progress builds an intent only from its current completed bound BoardState matching Content. The
private intent retains the board and exact request, config, lineage/revision and content identity;
screen unbind does not discard it. Preparation revalidates the private intent through Save's active
lease and recomputes candidate/delta through ProgressLedger. Opaque prepared handles have private
issuance records; copied payloads or a caller-made error:OK cannot create authorization. Repeated
preparation for the same validated lease returns the same approval identity. Content hashes the
exact accepted manifest bytes; invalid loads retain the previous accepted fingerprint/version.

Economy requires the registered Progress approval and independently reconstructs the canonical
ordered completion batch. Supported commands are configured positive base level_complete and the
one-time global onboarding_hints at an actual future Hint threshold crossing. Existing global or
per-language Hint unlocks, historical progress past the threshold and current-lineage durable grant
proofs deny regrant. Zero configured rewards produce an empty successful batch. Caller-selected
spends, rewarded/double/chest commands and changed amounts/reasons reject. Bonus_counter remains
unchanged under this initial T-0330 preparation contract; bonus discovery/settlement and provider
proofs require their separately scoped integration before those features activate.

Both joint and independent grant/spend use the same value-only WalletSnapshot/journal builder,
injected Clock and configured history bound. It preserves extensions and prepares the whole batch
without writing or emitting. Owner records bind the matching Save, lease, original hash and current
config/context. Altered boards, manifest/version, language/config or candidate/delta invalidate them.
No caller-controlled approval field or generic owner Dictionary commit API exists.

## Durability, publication and port

The real AtomicProgressPort serializes calls and keeps unresolved Save lease/approval identities.
Different requests cannot replace pending work; identical retry recovers first, then reuses the same
approved candidate on an exact old baseline. Uncertain outcomes remain pending, proven success is
replayed and contradictory replacements are never overwritten. Results copy the CURRENT committed
language snapshot and historical receipt independently. Diagnostic journal trimming cannot evict proof.

Save.publish_receipt and receipt_publishing retain Save's write barrier during replay publication.
Economy accepts only Save-issued/resolved current-lineage receipts; notifications and current wallet
views are copied, published at most once per in-process identity and never applied as grants.
Failed callbacks leave durable success intact; restart/recovery rebuilds state and may publish once
in that process. This is no exactly-once side-effect claim across processes.

Read context is closed {content_version:int,manifest_hash:String}; recovery context is closed
{request_hash:String}. Reads do not write, allocate old stars or backfill grants. Unsupported/inactive
language metadata fails closed rather than loading a guessed catalog. A missing active language
has a fresh read-only view and persists only on explicit completion. Nonsequential markers, current
slot outside content, incompatible saved board, known local credits/cards ahead of endpoints and
blocked v3 migration return needs_migration, preserving P1 and original files. Global stars remain
unallocated; retired IDs/extensions/unrelated languages survive. Threshold-derived feature union
is persisted only by an explicit approved completion, not by getters.

## Verification

Clean baseline: 510/510 pinned Godot4.7.2 GUT. Added26 integration cases with real concrete owners,
Config/Content and SaveStorage: value-only preparation, immutable payloads/identity, canonical rewards,
global onboarding/history, forged/wrong-owner/changed commands/candidates/deltas, config/content/board
changes, closed contexts, all5 storage boundaries/restart/retry, independent pending work, competing/
reentrant writers, proof replay beyond journal trim, reset/receipt forgery, missing languages and
retired credits, v3 golden/collision and invalid v4 semantics, manifest byte identity/failure retention,
zero rewards, preserved bonus/extensions, screen unbind and actual lost-publication recovery.
Existing tests are unchanged, including P1 and unavailable P2/default-port assertions.
GUT536/536 passes. Full make check, scope/task lint, fresh independent exact-head review and all14CI
are merge gates; final results are recorded in the PR. No hardware fsync claim or device UI claim.
