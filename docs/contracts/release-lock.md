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
