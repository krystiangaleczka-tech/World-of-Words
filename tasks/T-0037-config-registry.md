---
id: T-0037
title: Add validated config registries and typed default reads
epic: E03
type: contract
area: services.config
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0034]
touch:
  - game/services/config.gd*
  - game/services/config/**
  - game/data/config/unlocks.json
  - game/data/config/hint.json
  - game/tests/integration/test_config_registry.gd*
  - tasks/T-0037-config-registry.md
revision: 1
---

## Goal
Implement the next roadmap contract: canonical local defaults validated before typed Config reads.

## Context
- ARCHITECTURE.md#registries: each entry has default, type, range, description, owner, remote.
- ARCHITECTURE.md#registries: get_int/get_float/get_bool/get_string fail loudly on unknown/wrong types.
- GAME_DESIGN.md#config-key-registry: canonical values, inclusive ranges and owners.
- PRODUCT.md FR-CFG-01 and first-10-minutes-timeline; ROADMAP T-0037.

## Current state
- T-0034 is done/merged; Config extends ServiceStub with inherited Clock injection and no domain logic.
- data/config contains only .gitkeep; no runtime registry files or loader exist.
- GUT discovers integration tests; main includes Platform and Save contracts with 27 passing tests.

## Specification
### Behavior
1. Add unlocks.json with seven documented defaults: 2, 5, 7, 10, 12, 12, 15 in canonical key order;
   ranges 1..50 except daily 1..100; owner Chris. hint.json has idle 45 (10..600) and streak 5 (2..50),
   owner Sol. All nine are int, descriptive, remote false until the separate remote policy task.
2. Define registry.schema.json under services/config, outside the root scanned for prefix registries.
   Each entry requires exactly default/type/range/description/owner/remote. Non-numbers use null range.
3. Validate dotted canonical key syntax and first-segment filename prefix, type/default compatibility,
   finite safe numbers, integer-integrality, inclusive ordered bounds, nonblank metadata and bool remote.
   Reject remote=true for unlocks/consent per v1 policy. No economy or unlock-order rules introduced.
4. Config.load sorts root JSON files and publishes defaults atomically only after every file validates.
   JSON, I/O and schema errors return Error and retain the prior registry. Missing/empty directories fail.
5. Four strict typed getters: no coercion between registered types; JSON int defaults return GDScript int.
   Unknown/wrong-type access emits push_error in debug; release fallback is 0/0.0/false/empty string.
   has_key allows callers to query without errors. Definition metadata is an independent copy.
6. Registration is inert until explicit Config.load. Remote fetch/cache/overrides remain T-0254.

### Interface
- Config.load(directory: String = "res://data/config") -> Error; has_key(StringName) -> bool.
- Config.get_int(StringName) -> int; get_float(StringName) -> float;
  get_bool(StringName) -> bool; get_string(StringName) -> String.
- ConfigRegistry.append_document(String, Dictionary) -> Error; has_key(StringName) -> bool;
  definition(StringName) -> Dictionary; read_value(StringName, StringName, Variant) -> Variant.
The roadmap's generic Config.get means these architecture-prescribed typed getters;
Object.get is inherited unchanged and is not overridden.

### Edge cases
Failed append/load leaves all prior values intact. Duplicate keys, mismatched filename prefixes,
wrong metadata/default/ranges and malformed JSON fail. Repeated successful load replaces the registry.
Non-JSON root files ignored; no subdirectory scan. Integer bounds reject fractional numbers and booleans.

## Out of scope
Remote config/cache, new canonical keys, balance changes, cross-registry unlock/consent constraint (T-0256),
CI registry scanning (T-0039), dedicated config rejection suite (T-0047), Save/Platform or boot changes.

## Tests
File: game/tests/integration/test_config_registry.gd
- test_shipped_defaults_match_canonical_documented_values
- test_all_four_types_survive_json_loading_without_coercion
- test_invalid_reads_fail_loudly_in_debug (expected GUT push errors)
- test_inclusive_range_boundaries_and_integer_validation
- test_metadata_schema_prefix_remote_and_duplicate_validation
- test_document_append_is_atomic_and_metadata_is_a_copy
- test_failed_load_keeps_prior_registry_and_never_publishes_partial_files
- test_empty_missing_directory_and_non_object_json_errors
Run pinned Godot 4.7.2 make check, metadata/scope/test-count and headless boot smoke.

## Acceptance
All specified tests pass and nine defaults/ranges/owners match the canonical docs exactly.

## Rollback
Squash revert removes local registry loading; save format and content are untouched.

## Deviations / concerns
Five production files include two scripts, two registries and the formal schema. The full diff including
contract/tests exceeds the ~300-line guideline; the registry/getter contract is one atomic task.
JSON Schema describes entry shape/types; runtime additionally checks ordered bounds/default membership,
nonblank text, filename prefix and the unlock/consent remote prohibition.
