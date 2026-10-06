# Shared content schemas, v1

`CONTENT.md#level-schema` and `#manifest` own the contract. These Draft 2020-12 JSON
Schemas are shared by the future pipeline validator and game integration tests:

| File | Registered `$id` | Version field |
|---|---|---|
| level.schema.json | urn:world-of-words:level:v1 | None; version is inherited from its pack |
| pack.schema.json | urn:world-of-words:pack:v1 | schema_version: 1 |
| manifest.schema.json | urn:world-of-words:manifest:v1 | schema_version: 1 |

Register all three local documents by `$id` before resolving references. Pack items
reference the level schema; manifest pipeline versions reference its semver definition.
Identifiers are opaque URNs, with no network fetch or dependency on a working directory.
Godot reads JSON data; it need not interpret Draft 2020-12 at runtime. T-0041 adds the
loader and fixtures; the subsequent pipeline validator enforces exported content.

This P1 contract supports Polish, as decided in decisions 0004/0005. EN/DE alphabet
rules must be decided before adding those languages. Campaign levels require `slot`;
daily levels forbid it. Repeated letter tiles are permitted. Eight tiles require
`landmark: true`; the ordinary limit is seven. Pack size is not fixed to 100 levels.

P1 manifests have campaign packs. `daily` may be absent or null; its populated P3
calendar contract is not defined here. Regions, locations and landmarks are absent
in P1 and require the later manifest revision described in CONTENT. The documentation's
extended manifest example illustrates future fields, not a valid P1 fixture.

## Structural validation is only one gate

Schemas enforce types, required fields, exact v1 containers, Polish spelling shape,
coordinate/dimension bounds, unique bonus strings, safe relative pack paths, full
hash spelling, and level kind consistency with its pack. Semantic versions support
release, prerelease and build identifiers; numeric prerelease identifiers have no
leading zeros. JSON integer values such as `1.0` are integers under Draft semantics.

They do not prove word validity/tier, tile-multiset formability, bonus completeness or
sort order, connected/correct/non-overlapping placement, coordinates fitting a given
grid, ID/slot correspondence, ordered pack intervals, contiguous manifest coverage,
unique IDs/slots/files, actual file hashes or released-slot immutability. Those are
mandatory semantic checks in the later validator, not evidence supplied by a schema
pass. No P2 difficulty curve, undocumented seed sign, or live economy limit is imposed.

`pipeline/tests/test_content_schemas.py` runs positive and negative contract cases
in normal CI without adding dependencies. It resolves the registered local references
and uses the existing repository assertion evaluator, with test-only maxLength/uniqueItems
support. This is deliberately a test harness for this vocabulary, not a general Draft
validator or the production `content-validate` command. A full Draft implementation
can additionally meta-validate these schema documents and validate the same cases.
