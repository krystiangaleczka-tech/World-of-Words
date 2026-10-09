# T-0126 — full schema and hard content validation

Implemented by Codex on 2026-10-09 from main c3a2638 (T-0125 merged).
Chris approved jsonschema==4.26.0 plus its resolved dependencies on 2026-10-09
("Zatwierdzam"). The original full Draft 2020-12 contract is implemented.

## Backend and offline behavior

SchemaRegistry(root) loads and meta-validates the level, pack and manifest schemas
once, registers their local IDs and rejects retrieval of unknown resources.
validate_schema(name, document) uses jsonschema's Draft202012Validator; fragment
validation retains the parent level resource for local references. Programmatic
values must be finite JSON, with string object keys and no cycles. Integral JSON
numbers remain valid integers; booleans are rejected as coordinates and slots.
Errors report deterministic paths/reasons as ValueError.

validate_level checks complete exported objects against their shared schema plus
source-tier membership, tile multiplicity, exact sorted bonus sets, placements,
matching grid dimensions and connected portrait geometry with no accidental runs.
validate_grid_entry applies the same semantics and available schema properties
without manufacturing final IDs, landmark flags or difficulty. Final eight-tile
landmark gating remains required at export. Handmade content has identical hard
gates and retains authored membership, words, expected bonuses and explicit layout.

## Automated evidence

The four required tests exercise local schema cross-references, full-Draft `not`,
meta-schema failures, unknown/cyclic references, invalid/nonfinite programmatic JSON,
large integer seeds, repeated deterministic error paths, campaign/daily and
landmark rules, spelling/tile overuse, tiers, missing/extra bonuses, geometry,
identity and handmade intent. Fixture stage/CLI runs repeat byte-identically;
malformed artifacts, duplicate IDs and stale provenance leave prior output intact.

Full pinned Godot 4.7.2 `make check` passes: 199 GUT, 165 pipeline and
81 tools tests; formatting/lint, registries and task lint pass. The native source-stage evidence below completes the full-data acceptance. Corpora and generated artifacts remain ignored; game content
and runtime settings are unchanged. Export and P2 sequencing/locks remain later tasks.


## Full pinned-source evidence

Rebuilt the actual pinned SJP/SGJP/KWJP sources through candidates: 450122
annotated forms, 31949 automatic candidates and zero handmade entries. Native
annotation used Morfeusz 1.99.15 / pl.sgjp.sgjp-2026.06.01.

Grid preparation used ordered two-process calls to the unchanged T-0125
`make_level`; the unchanged grid handler supplied pins/search options and the
official `run_build` supplied the full predecessor hash and canonical envelope.
The temporary driver was independently reviewed. The resulting artifact exactly
matches the prior full native T-0125 hash recorded in PR #70:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| 06-candidates | 18704149 | f1f9649cdc54674c17af971859c82063e3d528d516da35ec53e21f861ab95721 |
| 07-grid | 26495096 | 98f123eacdf9efbaf1b163e1163b157a09bda92eed5be683e40fd6cc50855666 |
| 09-validate | 26495402 | 809bf9efdf3b2e9e83a7eaf00a6ac83602749543061e38c2dcd4d8e6689ed888 |

Two consecutive real CLI validation runs succeeded for all 31949 automatic
entries (0 handmade). Sizes and SHA-256 were identical. The validation artifact's
input hash matches the full grid artifact, and every input payload field and
collection is preserved exactly; only deterministic validation evidence is added.
These are actual corpus results, separate from the handmade fixture tests.

From repository root, the normal serial CLI can reproduce the same preparation:

```sh
uv run --all-packages --extra annotate wg build --lang pl --to candidates
uv run wg build --lang pl --from grid --to grid
uv run wg build --lang pl --from validate --to validate
uv run wg build --lang pl --from validate --to validate
```

The last two commands are the actual native acceptance runs performed here.
Raw corpora and artifacts remain in ignored pipeline/build/pl directories.
All 9 GitHub CI jobs passed for full-Draft code head 0354598; final evidence/status
publication is checked again before merge. Independent final review approved exact commit
7f64bed40c0582861f81d3f62395115f77db929f after independently verifying the actual
artifact counts, hash, predecessor identity and unchanged input collections.

## Resolved dependency lock

Approved direct dependency: jsonschema 4.26.0. Its locked dependencies are attrs
26.1.0, jsonschema-specifications 2025.9.1, referencing 0.37.0, rpds-py 2026.9.1
and typing-extensions 4.16.0. Default pipeline checks run with the native Morfeusz
extra uninstalled; no game runtime dependency is introduced.
