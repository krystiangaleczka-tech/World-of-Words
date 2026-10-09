---
id: T-0126
title: Validate Polish level geometry, dictionary evidence and shared schemas
epic: E08
type: contract
area: pipeline.validate
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0125, T-0040]
touch:
  - pipeline/src/wordgame_pipeline/validate/**
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/pyproject.toml
  - uv.lock
  - pipeline/tests/validate/**
  - pipeline/tests/test_pipeline_contract.py
  - pipeline/tests/ingest/test_ingest.py
  - pipeline/tests/tiers/test_tiers.py
  - pipeline/tests/candidates/test_candidates.py
  - pipeline/tests/grid/test_grid.py
  - docs/CONTENT.md
  - docs/qa/T-0126-validate.md
  - tasks/T-0126-pl-validate.md
  - tasks/T-0125-pl-grid.md
revision: 1
---

## Goal
Reject structurally or semantically invalid levels before export, using the pinned source tiers and the existing shared Draft 2020-12 schemas. Provide a reusable full-level validation API for the subsequent exporter.

## Context
- ROADMAP T-0126; CONTENT.md#hard-validation; FR-CONT-01 and FR-CORE-05.
- pipeline/schema/README.md: structural schema success does not prove source validity, formability, complete bonuses or geometry.
- T-0127 owns exported IDs, slots, difficulty and pack/manifest assembly. This task does not invent those values for intermediate candidates.

## Current state
- T-0040 done: level/pack/manifest.schema.json, registered opaque URNs, local cross-references, structural contract tests.
- T-0125 grid artifact has upstream pins/hashes/search options, automatic and handmade entries with words (strings), placements, letters, grid w/h, bonus and seed; handmade also slot/expect_bonus.
- grid.geometry.validate_geometry checks exact intended maximal runs, connectivity, same-axis overlap, matching crossings, portrait/10x10/zero-origin and unique placements.
- candidates.core.WordIndex provides strict tier membership and complete multiset pools.
- stages.read_artifact validates canonical config/version envelopes; STAGES contains tiers/grid/validate/export. CLI stops at validate; five scoped test files assert the boundary.
- No validate package or jsonschema runtime dependency yet. Mark merged T-0125 done as scoped bookkeeping.

## Specification
1. After Chris approves S7, pin jsonschema==4.26.0 as a pipeline runtime dependency. Register the three local shared schemas by their $id with a retrieval callback that always rejects unknown references; no network schema fetching. Meta-validate schemas and validate the full shared Draft vocabulary. Reject invalid/nonfinite JSON values even for programmatic callers. Report stable human-readable paths/reasons as ValueError, not opaque library tracebacks.
2. SchemaRegistry(root) loads schemas once; validate_schema(name, document) validates level/pack/manifest structures. validate_level(level, index, registry) additionally checks alphabet/multiset formability, source level_ok for selected crossword words, source non-banned bonuses, sorted unique complete bonuses, one placement per word, exact grid dimensions and T-0125 geometry. Full campaign IDs must correspond to their slot. Respect Draft integer semantics (e.g. 1.0) while rejecting booleans as coordinates/slots. Do not impose P2 difficulty curves or released-slot rules.
3. validate_grid_entry(entry, index, registry, handmade) validates intermediate common fields against their shared schema fragments (letters, placement words, bonus, grid, seed), exact selected-string/placement agreement and the same semantic checks. For handmade entries validate positive slot and expect_bonus membership. Intermediate candidates have no fabricated exported IDs, landmark flags or difficulty; final full schema conditions (including eight-tile landmark status) run through validate_level at export. No claim that intermediate fragment validation proves export readiness.
4. Register validate through existing runner. Read the current canonical tiers artifact via read_artifact and validate provenance/rules/override hashes against the grid payload. Use WordIndex for complete pools; validate every automatic/handmade entry. Duplicate candidate IDs or handmade slots fail. Preserve input collections/metadata and append deterministic validation counts and hashes of local schemas. Invalid input or stale tier evidence leaves previous validation artifact untouched.
5. CLI next unimplemented stage becomes export; update only five scoped boundary assertions/requests. Unchanged repeated validation output is byte-identical. No content-validate command, Makefile/CI wiring or generated game content (T-0128/T-0127).
6. Document full-level API versus intermediate checks, local-only schema resolution, hard validation and remaining export responsibilities. Keep schemas and existing schema contract tests unchanged.

## Tests
pipeline/tests/validate/test_validate.py:
- test_shared_schema_validation: registered schema cross-references, invalid types/fields, campaign/daily and eight-letter conditions, integer-valued floats, unknown refs rejected without network, nonfinite values, deterministic error paths.
- test_level_semantics: alphabet, repeated tiles, formability, source tiers, unknown/banned words, missing/extra/unsorted bonus, mismatching coordinates/dimensions, accidental adjacency, ID/slot and selected-word agreement; valid full fixture.
- test_intermediate_and_handmade_validation: common fragments, all semantic checks, correct expected bonus, partial/final schema distinction, no input mutation.
- test_stage_provenance_and_atomicity: injected tiers/grid, stale pins/hash mismatch, duplicate identities, valid repeat, malformed prior artifact, invalid entry preserving artifact, CLI export boundary.

## Acceptance
make check, scope/task lint, independent fresh review and all CI. Validate every actual full-source T-0125 grid candidate, repeat and report counts/hashes. No source dictionary replacement, runtime dictionary or exported packs.

## Escalation
S7 resolved: Chris approved jsonschema==4.26.0 and its resolved dependencies
on 2026-10-09 by replying "Zatwierdzam" to the concrete dependency proposal.
The original full Draft 2020-12 contract is selected; the finite-vocabulary
alternative is replaced. QA documentation remains in the declared scope.

## Rollback
Revert task commits and rebuild ignored validation artifacts. No runtime saves or shipped content changes.

