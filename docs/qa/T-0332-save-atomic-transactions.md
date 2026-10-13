# T-0332 Save-wide atomic transactions

Base main d16fa902; clean baseline 485/485 GUT tests on pinned Godot 4.7.2. Split 2 of T-0330,
following the merged v4 migration. This adds the Save transaction capability only. Production
Progress/Economy approval remains unavailable until split 3/T-0242; no boot, port or UI activation.

## Ownership and serialization

Save keeps one private lease bound to identity, immutable original request, lineage and revision.
Closed requests hash sorted full-precision JSON, with strict validated integers and no float/string
coercion. Read methods return deep copies. Prepared objects alone/error flags never authorize writes;
only both registered owners' private identity records, matching Progress approval and current context
can certify candidate sections. A shared typed AtomicSaveOwner boundary plus concrete Progress/Economy
script ancestry replaces circular SCRIPT preloads, retaining the concrete owner restriction.

Every competing Save write, independent Economy grant/spend and Progress persistence rejects while
leased or publishing. Owner reconfiguration also rejects without clearing pending state. P1 dirty
work remains independent; begin cannot adopt it. Committed views stay durable while P1 staging keeps
its existing behavior. All atomic sections/revision/proof publish together before Economy callbacks;
notification failure never erases success. Recovery and same-handle commit are blocked inside a storage write callback.
Independent review identified the latter reentrancy gap; its regression exercises every checkpoint.

## Recovery, proofs and reset

At each storage failure re-read primary/temp/backup with the same historical adaptation policy.
Exact old baseline keeps pending and permits only identical approved retry; matching proof publishes
replayed success, promoting temp first. A newer matching-proof document supplies the CURRENT view,
while the receipt retains its historical snapshots. Contradictory valid replacement reloads and
invalidates the lease without overwriting it; unknown reads remain unresolved. Backup retry does not
rotate a corrupt primary over the valid backup. Unavailable v3 migration collisions preserve P1.

Proofs survive journal trimming and reject different hashes for the same completion identity.
Historical slots without a proof cannot earn again. Abort only precedes writing. Reset rejects
unresolved work, durably increases lineage/revision, clears gameplay proofs and preserves all other
identity/settings/purchase metadata. Every successful P1 mutation also increases revision; retries
use the same next revision. Candidate validation precedes I/O, including overflow and reset.
The unchanged reader's numeric ceiling in the pinned engine is MAX_SAFE_COUNT-1 because its floating
literal ceiling rounds down; boundary tests seed that highest reader-valid value and reject increments
before storage. No schema/reader widening is included in this task.

## Verification

25 new integration tests cover closed request/hash/copy rules; manufactured, foreign and mismatched
handles; malformed owner payloads/wallet/notifications; stale owner context; dirty/pending/reentrant
writers; all five storage checkpoints and restart old-or-one consistency; old-primary and backup
retry; unavailable reads/temp promotion failure; contradictory v3/v1 replacements; proof replay,
current-view preservation, journal trimming, historical no-grant, receipt forgery, reset bounds,
owner unbind and lost callbacks. Existing independent Economy/Progress tests stay unchanged.
GUT 510/510 passed. Full make check, task/scope checks, fresh exact-head independent review and all
14 CI checks are merge gates; the PR records their final results. No hardware fsync claim is made.

## Resolved S5

Chris authorized completion after the explicit request to include test_debug_screen.gd. Task revision
2 adds its reset metadata oracle to touch; all original identity/settings/purchase assertions remain.
Listed historical save/reset tests similarly adjust only revision/lineage expectations.
