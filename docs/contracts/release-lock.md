# Released campaign geometry locks

CONTENT.md#slot-policy releases slots only at open testing/production or App Store
publication. Internal/closed/TestFlight builds do not create released slots. This
contract supplies protection mechanics, not release approval or an initial baseline.

## Version1 format (T-0361)

`pipeline/locks/pl.lock.json` is a strict JSON object with exactly schema_version=1,
lang="pl" and nonempty levels=[{slot,id,geometry_sha256}]. Entries cover the ordered
contiguous prefix1..R, bounded by the current campaign pack limit9999. Identity is
exactly pl-c-NNNNNN for its slot; SHA256 is lower-case64hex. Frozen LockedSlot and
ReleaseLock validate direct construction and parsing. to_dict returns fresh JSON.
No lock file is created by installing this module or by running a content build.

`validate.locks.geometry_sha256(level)` hashes canonical UTF-8 JSON bytes (including
final newline) of exactly {letters,words,grid}. Object key order is immaterial;
array order, tile multiplicity, word spelling/direction/coordinates and grid sizes
are retained without normalization. Changing bonus/difficulty/seed/pipeline does
not change this hash. Source/landmark and other metadata are not geometry hashes;
normal source/schema/semantic validation still applies to them and allowed repairs.
This function checks campaign identity and structural projection shapes/finite JSON,
not dictionary tiers, actual grid validity, source approval or calibration.

`verify_release_lock(lock,levels)` checks the complete ordered campaign1..N,
validates every projection before comparing hashes, and requires the locked prefix
unchanged at the same IDs/slots. Missing, moved, renumbered or changed locked levels
fail. Appended slots and unlocked-tail geometry may change. Allowed bonus/metadata
repairs still pass their independent validation gates. No input mutation or writes.

`load_release_lock(root,lang)` reads only root/locks/pl.lock.json. Missing returns
None for the existing pre-release P1 path. Empty/malformed/duplicate-key/nonfinite
files fail; an empty levels list cannot act as a lock. Symlinks (including dangling
or parent links), non-directory ancestors and nonregular files fail before reading.
The loader walks directory descriptors with no-follow protection, opens the final
entry nonblocking and checks its descriptor is regular before reading. Deterministic
file/ancestor replacement races cannot redirect it through symlinks or block on FIFO.
The loader never creates, updates, deletes or repairs a lock. Callers must not turn
malformed existing locks into absence or silently replace their hashes.

## Bounded integration wave

T-0362 wires this contract into read-only validate-content and evidence preparation;
T-0363 guards root-aware export and publication. Until those tasks merge the module
is not an active content/export gate. No new lock establishes a real released prefix
without the release-cut process and Chris's approval. Lock updates/release cutting,
remaining T-0301 token/difficulty hard rules, production content/calibration and
human review remain open. T-0360's generic preview remains explicitly unverified
for released geometry; this contract alone does not change that report.

## Content validation gate (T-0362)

`validate_content(...,require_lock=False)` now loads the canonical lock before any
initial-content SKIP. Every existing lock is enforced on the complete bundled
campaign, before provenance processing or evidence writes, including prepare=True.
Missing content with an existing lock cannot SKIP. Malformed/unsafe locks are always
errors, never treated as absent or overwritten. Ordinary read-only validation and
all tier/bonus/handmade/provenance checks remain in force after the geometry guard.

`uv run wg validate-content --require-release-lock` requires an existing valid lock;
absence fails with exit1/stderr. The API keyword requires bool and has the same
behavior. Without the flag, absent locks preserve the pre-release P1 validation path;
a successful P1 check without a lock is not released geometry certification.
Valid appended content and independently validated repairs are allowed. Neither
normal validation nor --prepare-evidence creates or updates release lock files.

## Export and publication gate (T-0363)

The root-aware export handler now loads the canonical lock and verifies the entire
assembled campaign before returning it, so a lock failure cannot replace the export
stage artifact. The actual `publish` API independently reloads and verifies the lock
before output checks, check/no-op/version returns, directory creation or staging.
SchemaRegistry retains its absolute construction root to anchor publication's lock
source even after cwd changes. A custom output path cannot change the lock source.
No optional caller-provided lock object can bypass loading an existing canonical file.

`uv run wg build --lang pl --from export --to export --slots N --content-version V
--require-release-lock` requires an existing valid lock at both gates. The keyword
require_lock=True is also available on export.handlers_for and publish; it must be
bool. --check enforces the same guards and remains read-only. A strict flag with a
non-export selection fails; --plan only lists paths and performs no export/lock read.
Without the flag, missing locks preserve pre-release P1 behavior; malformed/unsafe
existing locks always fail. Valid appends and independently valid bonus/metadata
repairs retain existing content-version and publication rollback requirements.

This enforces existing baselines; it does not create or update them. No prototype
has been declared released by this wave. Release cutting, lock extension, explicit
human overrides and remaining production gates are still separate. Publication
retains its existing single-writer contract, without a concurrent release-lock writer
or cross-file transaction guarantee. Generic T-0360 preview remains unverified.

## Append-only proposal (T-0364)

`extend_release_lock(previous,levels,released_through)` creates an immutable in-memory
prefix proposal. The explicit cutoff is a real integer1..9999 within the complete
campaign and cannot shrink the old released prefix. Every projection and campaign
position validates, including the unlocked tail beyond the cutoff. Any old prefix
must verify before constructing an extension: changed/missing/reordered released
geometry is an error, never a new baseline hash. Old entries are retained exactly;
only newly included slots are hashed for append. Same cutoff validates and returns
an equal lock. Metadata/bonus repairs do not change protected hashes.

A missing previous lock permits an initial proposal only, without disk writes or
release authority. The caller still owns complete content/tier/source validation
and real release approval. T-0365 will bind a readonly proposal to validated content;
T-0366 will add an explicit guarded update command. No actual release is cut by
installing or testing these helpers, and no current prototype is declared released.

## Validated readonly release proposal (T-0365)

`release_plan.plan_release_lock(root,content_root,released_through)` runs the existing
readonly P1 content/evidence validator between two snapshots. A missing campaign or
evidence, changed snapshot, unsafe/malformed lock, stale provenance or invalid
semantics fails. Evidence is never prepared or repaired by planning. Only then does
the append-only helper propose a prefix. Existing hashes cannot be rebaselined.

Frozen ReleasePlan retains old/proposed locks, campaign count, exact manifest and
evidence SHA256 and a validation-context hash covering normalized language config,
exact local schemas and evidence. Its fresh version1 scope=release-lock-proposal
report includes old semantic lock hash/null, proposed lock/hash and explicit cutoff.
`plan.sha256` identifies canonical report bytes, including final newline. Every
relevant content/config/schema/evidence/prefix/cutoff change affects proposal identity
or fails validation; equivalent old-lock key order/whitespace preserves identity.
No paths/timestamps appear. Direct constructors validate hashes/counts/old overlap.

`filesystem.directory_fd` and `read_regular` share the previous loader's no-follow,
nonblocking descriptor reads; lock safety/static/replacement tests remain in force.
Proposal snapshots detect stale inputs under the existing single-writer contract;
they are not a hostile concurrent filesystem transaction. Passing P1 validation and
hash identity does not certify outstanding P2 gates or actual human release approval.
This service writes no files; explicit guarded command integration follows T-0366.

## Explicit lock command (T-0366)

`uv run wg release-lock --released-through N` emits canonical JSON with status=proposal,
plan_sha256 and the complete version1 proposal. Root/content paths and lang options
match validate-content. Default mode writes nothing. Review the proposal and the
actual release boundary before using `--apply --expected-plan-sha256 HASH`; HASH must
be the exact proposal identity just reviewed. Hash without --apply or --apply without
hash fails. Success status is written or unchanged; errors exit1 with stderr/empty
stdout. No alternate lock target or protected-geometry override is available.

`release_apply.apply_release_lock(...,expected_sha256=HASH,approved=True)` is the
explicit API. It validates/recomputes before creating the canonical locks directory,
uses nonblocking flock on its verified no-follow directory descriptor to serialize
cooperating tool writers, revalidates under that mutex, writes/fsyncs an exclusive
owned temporary file and rechecks proposal identity immediately before atomic
replacement. Stale hashes, unsafe locks, protected changes and competing writes fail.
No-op preserves old baseline bytes/mtime. Failed pre-replace writes preserve the old
baseline and clean owned temporary files; a collided unowned file is never deleted.
A failure after directory creation may leave the empty locks directory. Content,
evidence and export artifacts are not written by this command.

This Linux/Docker tool retains the existing single-writer content/config contract;
there is no concurrent uncooperative-writer, multi-file or power-loss transaction
guarantee. The apply flag expresses operator intent; it cannot verify store release
or human approval. Chris must approve an actual open-testing/production/App Store
release before applying a real baseline. Implementation/tests in T-0364..T-0366 use
temporary fixtures only: the repository's prototype remains without a release lock.
Manifest v1.1/regions integration, remaining hard rules and production/human gates
are separate; this completes the bounded lock-update tooling portion of T-0302.
