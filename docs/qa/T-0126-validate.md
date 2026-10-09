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
81 tools tests; formatting/lint, registries and task lint pass. Actual source-stage
counts/hashes are recorded below once the full native run completes. Corpora and generated artifacts remain ignored; game content
and runtime settings are unchanged. Export and P2 sequencing/locks remain later tasks.
