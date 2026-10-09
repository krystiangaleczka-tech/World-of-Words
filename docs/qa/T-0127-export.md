# T-0127 export evidence

## Scope
Exporter mechanism only; no generated campaign is committed. Reviewed handmade
onboarding and playable P1 content belong to T-0130/T-0131. No runtime/schema/save
changes, dependencies, release locks or T-0128 CI entry point are added.

## Local checks
`make check GODOT=/tmp/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`:
199/199 GUT tests; 170 pipeline tests; 81 tools tests; format, lint and registries
pass. Full output: `/tmp/t0127-check.log` in the execution workspace.

Export tests cover three pack boundaries, canonical byte identity under reversed
input order, full-level/schema checks, IDs and P1 metadata, wheel-count ordering,
99/100-slot spacing, handmade lookahead, the eight-tile gate and handmade landmark,
exhaustion and duplicate identities. They cover identical/versioned publication,
missing/extra/corrupt files, symlinks/unmanaged directories, rollback after injected
replacement failure, stage provenance and read-only CLI comparison.

## Deterministic synthetic fixture export
The test fixture uses invented strings and an injected tier index to exercise the
contract. It is not source dictionary content and is not intended for players.
201 slots, 15 handmade test entries, three packs. Rebuilt and compared with
`publish(..., check=True)`; all bytes identical. Local output is ignored/outside the
repository at `/tmp/t0127-fixture-content/pl`.

| File | SHA256 |
|---|---|
| manifest.json | aa03157ec2814418cd96ddf7eb871ba278dddf68c3af36439a9257282359cb5a |
| packs/c-0001-0100.json | a090ca9226b61a8ed99d61ad1420f05f004bfd4c8de44c19236552960c20de05 |
| packs/c-0101-0200.json | 7c9630f9b89b591a75fb94afa8a3e525bdce74c8af178d48c2696d135f802558 |
| packs/c-0201-0201.json | 078d2ad43e0f0a9625074115bf8db4884a2ad7a97665a58045b9d992aeae6d44 |

## Full-source attempt
Input: real T-0126 validation artifact, 31,949 automatic entries, zero handmade.
SHA256: `809bf9efdf3b2e9e83a7eaf00a6ac83602749543061e38c2dcd4d8e6689ed888`.
Command:

```sh
uv run wg build --lang pl --from export --to export --slots 30 \
  --content-version 1 --output /tmp/t0127-native-content/pl
```

Exit code 1 after revalidating pinned source/grid evidence and all 31,949 entries:
`wg: Export requires handmade onboarding slots 1–15 (T-0130/T-0131)`.
No export stage artifact or output directory was created. The input hash above is
unchanged. This is a required content readiness failure, not a successful native
campaign build. Actual shipping remains blocked until authored onboarding is ready.

## Publication limits
A single writer stages a full language directory and rolls back handled replacement
failures. There is a short directory-rename window and no power-loss/concurrent-reader
transaction guarantee. If rollback fails, the old directory remains in the sibling
temporary folder for recovery. An ignored export artifact may be newer than content
when publication fails; no partial campaign is treated as successfully published.

## Independent review correction
The fresh reviewer reproduced a FIFO being silently removed by revision publication.
Publication now rejects special filesystem entries before replacement, including a
non-directory output target. The regression test requests a valid +1 revision and
asserts that the FIFO survives rejection. Running this updated test with the original
publisher's directory inspection fails with `DID NOT RAISE`; the corrected publisher
passes. This demonstrates that the regression detects the actual reviewed defect.

Fresh independent reviewer APPROVE: implementation commit
`3a9aad360d2919cc04850e677bd0fc01c08bb63f`. The final full local check
passes; CI is a required merge gate. Only status/evidence bookkeeping follows review.
