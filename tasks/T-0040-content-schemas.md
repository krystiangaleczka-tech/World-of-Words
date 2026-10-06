---
id: T-0040
title: Define shared level, pack and manifest JSON schemas
epic: E03
type: contract
area: services.content
risk: high
executor: sol
think: xhigh
ui: none
status: review
depends_on: [T-0011]
touch:
  - pipeline/schema/**
  - pipeline/tests/test_content_schemas.py
  - tasks/T-0040-content-schemas.md
revision: 1
---

## Goal
Freeze machine-readable v1 content shapes for the pipeline and future game loader.

## Context
- CONTENT.md#level-schema and #manifest own these formats.
- PRODUCT.md FR-CONT-01/02 and FR-WHEEL-09; ROADMAP T-0040 (HS).
- CONTENT: "schema_version sits on the pack, not on each level."
- AGENTS: "The game only reads the output"; no generated game/content files are hand-edited.

## Current state
T-0011 is done. No pipeline/schema directory, content schemas, runtime LevelData, fixture packs
or content validator exist. T-0039 supplies a repository-vocabulary schema assertion evaluator;
pytest and the Python standard library are installed. No JSON-schema package is a project dependency.
CONTENT's manifest example includes P2/P3 fields; its text explicitly says regions/locations/
landmarks are absent in P1. Decision 0005 requires separate EN/DE rules before their pipelines run.

## Specification
### Behavior
1. Publish Draft 2020-12 level.schema.json, pack.schema.json and manifest.schema.json. Stable v1
   URN identifiers and local registered references resolve without network access. Include a
   schema README describing registration, version ownership and semantic-validation boundaries.
2. P1 language is pl; reject other languages pending their rules decisions. Level IDs use
   pl-c/pl-d plus six digits. Campaign levels require positive slot; daily levels forbid slot.
   Require every documented level field except the conditional slot; reject unknown fields.
3. Letters are 3-7 uppercase Polish alphabet tiles, 8 only with landmark true; repeated tiles are
   allowed. Words have nonempty placements, uppercase Polish strings of length 3-8, x/y integers
   0-9 and dir h/v. Grid dimensions are integers 1-10. Bonus words use the same spelling shape,
   may be empty and must be unique. Difficulty is numeric, landmark boolean, source generated/
   handmade, seed integer, pipeline a semantic-version string. Do not impose undocumented balance
   values, seed sign or P2 difficulty limits.
4. Pack requires exactly schema_version=1, lang=pl, kind=campaign/daily and a nonempty levels
   array referencing the shared level schema. Enforce level ID kind agrees with pack kind.
   Do not enforce approximately 100 levels as a hard limit.
5. P1 manifest requires schema_version=1, lang=pl, positive integer content_version/slots,
   semantic-version pipeline, and nonempty campaign packs. Every pack entry has exactly file,
   kind, first, last and sha256; positive integer bounds; safe packs/c-NNNN-NNNN.json path;
   full 64-hex hash. daily may be absent or null. P2 regions/locations/landmarks and a non-null
   daily calendar are not part of this P1 schema.
6. Structural schema checks do not pretend to prove tile formability, dictionary tiers, bonus
   completeness/sorting, grid connectivity/intersections/word fit, ID-slot matching, first<=last,
   manifest coverage/order/uniqueness or actual hashes. Document these future validator checks.
7. CI pipeline tests must exercise positive and negative documents against the schema assertions,
   including local references, with existing dependencies only. Reuse T-0039's tested assertion
   evaluator and add test-only reference/maxLength/uniqueItems support, scoped to this schema vocabulary.
   These tests are not a general Draft validator or production content-validate implementation.

## Tests
File: pipeline/tests/test_content_schemas.py
- Valid campaign/daily levels, pack and minimal manifest; integer JSON numbers and repeated tiles.
- Schema identifiers/dialect and offline reference resolution; semver releases/prereleases/builds.
- Required/unknown fields, level IDs and campaign/daily slot conditions; version ownership.
- Tile count/landmark, alphabet/case/length, placements/directions, grid bounds, primitive types.
- Bonus empty/unique, pack kind/version/language and nested invalid level.
- Manifest required fields, version/language/numeric types, safe file paths, full hashes, P1 metadata.
Run pinned Godot 4.7.2 make check, task/scope/test-count checks, and all CI jobs.

## Out of scope
New dependencies, generated content, game loader/LevelData (T-0041), semantic validators/export,
released-slot locks and gameplay; P2/P3 manifest additions and EN/DE alphabet decisions.

## Acceptance
Shared schema contracts and regression checks pass; schema_version belongs only to containers.

## Rollback
Revert this squash before dependent consumers ship; no data or save migration exists.

## Deviations / concerns
A pack schema is necessary to specify the version field at its documented owner. Tests use the
existing repository schema assertion vocabulary, not a new third-party validator. Formal-schema
meta-validation can additionally run with the host's existing jsonschema installation. P1 schemas
exclude future languages and manifest fields deliberately. Four production files (three schemas and their README) plus the contract regression suite exceed
the approximate 300-line guidance. Independent fresh-chat review is not claimed.
