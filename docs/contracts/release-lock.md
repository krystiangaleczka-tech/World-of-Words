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
