---
id: T-0120
title: Establish the deterministic pipeline CLI and artifact contract
epic: E08
type: contract
area: pipeline.ingest
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0030, T-0040, T-0100]
touch:
  - pipeline/pyproject.toml
  - pipeline/src/wordgame_pipeline/**
  - pipeline/config/pl.yaml
  - pipeline/tests/test_pipeline_contract.py
  - uv.lock
  - tasks/T-0120-pipeline-skeleton.md
revision: 1
---

## Goal
Add the wordgame_pipeline package and wg CLI with a stable stage/artifact boundary for subsequent P1 stage implementations. Preserve the existing wow-pipeline distribution and wow_pipeline package.

## Context
- tasks/ROADMAP.md T-0120.
- docs/CONTENT.md#repository-layout: "wg build --lang pl [--from <stage>] [--to <stage>]".
- docs/CONTENT.md#stages-and-artifacts: P1 stages 1–3, 5–7, 9, 13; intermediate artifacts use build/<lang>/<NN-stage>/.
- docs/CONTENT.md#principles: identical inputs and pipeline version produce byte-identical results; stages can resume from artifacts.
- docs/decisions/0004-language-rules-pl.md: 32-letter alphabet, minimum 3, Q/V/X excluded.

## Current state
pipeline/pyproject.toml declares the wow-pipeline distribution and placeholder wow_pipeline package; schemas from T-0040 exist. No wg entrypoint, language config or stage runner exists. The roadmap's T-0051 placeholder has no task file; concrete schema/runtime prerequisites are already delivered in T-0040 and T-0100, which this specification uses without editing the roadmap.

## Specification
1. Introduce a versioned stdlib-only package, wg console entrypoint and python -m wordgame_pipeline equivalent. Existing package imports remain valid.
2. Define the 13 canonical stage numbers/names and P1 selection. Select inclusive P1 --from/--to by name or number. Reject unknown/P2 stages, reversed ranges and unsupported languages before writing artifacts.
3. Load pipeline/config/pl.yaml into an immutable typed config: lang pl, the 32 uppercase Polish letters, word length min 3 and max 8 (runtime tile limit). For this skeleton use the JSON-compatible flow-mapping subset of YAML, parsed with stdlib json; clearly report malformed files and unsupported YAML syntax. No new dependency. Preserve literal diacritics. Validate types, duplicate keys, distinct alphabet entries and language/path safety. No normalization, source downloads or word-tier decisions yet.
4. Stage handlers receive config and the previous artifact payload and return JSON-compatible data. The runner uses build/<lang>/<NN-stage>/artifact.json. Envelope keys: schema_version, pipeline_version, lang, stage, config_sha256, input_sha256, payload. config_sha256 hashes the canonical language config, preventing resume with changed rules. input_sha256 is null for ingest, otherwise SHA256 of the previous canonical artifact bytes. Sorted UTF-8 JSON, no timestamps/absolute paths/non-finite numbers; atomic replacement leaves an old artifact intact on invalid output/failure.
5. Starting at a later stage reads and validates the prior P1 artifact (identity/version/config digest/hash shape and canonical encoding). A missing or malformed prerequisite fails explicitly. Preflight every requested handler before executing; never fabricate successful stage output. Later tasks register actual production handlers.
6. wg build --lang pl --plan prints relative planned artifact paths without creating directories. An actual build with the initially empty registry fails clearly with the unimplemented stage name and nonzero exit. --root selects a pipeline workspace, defaults to pipeline. Normal build runs the same tested runner once handlers are registered.

## Out of scope
Ingest/normalize/annotate/tiers/grid/validators/export implementation; content/lock edits; source download; LLM classification; tier/curve/economy values; changing source/schema decisions.

## Tests
pipeline/tests/test_pipeline_contract.py:
- test_pl_config_contract_and_invalid_inputs: PL diacritics, limits, immutable config; malformed/duplicate/path-unsafe config rejects.
- test_stage_selection_and_read_only_cli_plan: exact P1 stage order, ranges, unknown/P2/reversed stages, CLI/module/console entrypoints, --plan performs no writes.
- test_deterministic_artifacts_and_resume: injected fake handlers produce byte-identical artifacts; resume consumes prior payload and hash; language/stage/version mismatch, noncanonical bytes or missing predecessor fail.
- test_unimplemented_or_invalid_output_does_not_replace_artifact: missing registry handlers fail before writes; invalid/NaN output leaves prior artifact intact; CLI build returns clear nonzero result.

## Acceptance
Pinned Godot 4.7.2 make check, task lint, scope and independent contract review pass. One task/branch/PR; actual Codex provenance recorded.

## Rollback
A squash revert removes the new package/CLI/config and tests; no player save, shipped slots or content are changed.
