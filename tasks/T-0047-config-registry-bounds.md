---
id: T-0047
title: Exercise shipped hint and unlock registry type and range validation
epic: E04
type: test
area: data.config
risk: low
executor: cheap
think: low
ui: none
status: done
depends_on: [T-0045]
touch:
  - game/tests/integration/test_config_registry_bounds.gd*
  - tasks/T-0047-config-registry-bounds.md
revision: 1
---

## Goal
Tests validate the actual shipped hint/unlocks definitions, including inclusive bounds and rejection
of bad types/ranges, so a change to a registry cannot silently weaken the contract.

## Context
- `docs/PRODUCT.md#fr-cfg-configuration-remote-config-ab` FR-CFG-01: "Every balance number has a registry entry in `data/config/*.json`: default, type, range, description, owner."
- `docs/ARCHITECTURE.md#registries`: file names are key prefixes; validation is atomic.
- ROADMAP T-0047; do not change any balance value.

## Current state
- `game/data/config/hint.json` contains two int entries; `unlocks.json` contains seven int entries.
- `ConfigRegistry.append_document(prefix: String, document: Dictionary) -> Error` exists.
- `has_key`, `definition` and `read_value(key, expected_type, fallback)` are public APIs.
- T-0037 tests generic validation; this task exercises copies of every actual shipped entry.

## Specification
1. Read both shipped JSON documents; assert expected key counts, prefix and int type, then append successfully.
2. For each actual entry, independent copies with defaults equal to lower and upper bounds are accepted
   and read as ints; original default, including JSON integral floats, is accepted.
3. Reject defaults below/above bounds, fractional values, strings, booleans, arrays and null.
4. Reject inverted bounds, fractional/boolean/string/null endpoints, wrong lengths and null range.
5. Every rejection is atomic: no entry from that document appears; a previously appended other-prefix
   document remains readable with its original values.
6. Mutate copies only; do not alter the shipped files or existing tests.

## Tests
File `game/tests/integration/test_config_registry_bounds.gd`:
- `test_actual_documents_and_inclusive_bounds`
- `test_actual_defaults_reject_wrong_types_and_out_of_range_values`
- `test_actual_ranges_reject_bad_endpoints_and_shapes`
- `test_rejected_document_preserves_prior_prefix_and_publishes_nothing`
Use all nine keys and assert failed documents expose none of their valid siblings.

## Acceptance
Every listed test passes against the existing implementation; production registry files are unchanged.

## Execution evidence
Implemented in the Codex session, not a cheap-model run. Fresh independent review and CI are
required before merge; this completion alone does not satisfy the Phase 0 cheap-executor gate.
