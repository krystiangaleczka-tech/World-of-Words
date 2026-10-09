---
id: T-0127
title: Export deterministic Polish campaign packs and manifest
epic: E08
type: contract
area: pipeline.export
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0126]
touch:
  - pipeline/src/wordgame_pipeline/export/**
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/tests/export/**
  - pipeline/tests/test_pipeline_contract.py
  - pipeline/tests/ingest/test_ingest.py
  - pipeline/tests/tiers/test_tiers.py
  - pipeline/tests/candidates/test_candidates.py
  - pipeline/tests/grid/test_grid.py
  - pipeline/tests/validate/test_validate.py
  - docs/CONTENT.md
  - docs/qa/T-0127-export.md
  - tasks/T-0127-pl-export.md
revision: 1
---

## Goal
Export validated P1 campaigns to canonical packs of 100 levels and a hashed manifest.

## Context
ROADMAP T-0127; FR-CONT-01, FR-CONT-02, FR-CONT-06, NFR-14.
CONTENT.md requires byte-identical rebuilds, P1 letter-count ordering and at least
100 slots between occurrences of each crossword word. GAME_DESIGN.md#onboarding
requires handmade slots 1–15. T-0130/T-0131 own authored and shipped P1 content.

## Current state
T-0126 is done. SchemaRegistry, validate_level and validation handlers exist;
WordIndex and read_artifact provide pinned tiers and canonical stage evidence.
CLI registers through validate; six scoped test files assert an export boundary.
No exporter or authored Polish onboarding exists yet.

## Specification
1. Add export handlers to the existing runner. Revalidate pinned source/grid/handmade
   provenance and entries using T-0126; reject changed validation schema evidence.
   Explicit --slots (15–9999) and --content-version (positive integer) are required
   for export. --plan stays read-only. No new dependencies or schema edits.
2. Deterministically fill contiguous slots, preserving handmade slot assignments.
   Require slots 1–15 handmade and no onboarding landmarks. Automatic wheels have
   3–7 tiles, nondecreasing tile count outside handmade slots; eight-tile automatic
   candidates are excluded, eight-tile handmade levels are landmarks. Choose by
   tile count then candidate ID, never reuse an automatic candidate. Enforce word
   distance >=100, including lookahead to pinned handmade slots; bonuses do not
   count. Fail clearly if no eligible candidate exists; never weaken constraints.
3. Assign matching campaign IDs, difficulty 0.0, pipeline version and source.
   Sort placements by word for deterministic hint ties; preserve grid/seed/bonus.
   Validate every complete level, pack and manifest. Packs have 100 levels except
   the last; filenames encode exact inclusive ranges, SHA256 hashes exact bytes.
   Stage artifact records export documents and their deterministic selection options.
4. Publish after stage construction to --output (default root.parent/game/content/pl).
   Stage all bytes before replacing the language directory, rollback on replacement
   failure; reject symlinks and unmanaged files rather than deleting them. Existing
   output must have valid manifest/schema/pack hashes. Same version requires exact
   identical files; a revision requires previous version +1. --check compares all
   output bytes without writing content or stage artifacts. No release-lock handling.
5. Update only the six boundary assertions to missing export options. Document
   commands, versions, deterministic selection, transactional limits and missing
   authored inputs. Do not ship generated content in this mechanism task.

## Tests
pipeline/tests/export/test_export.py:
- test_packs_and_repeat: 201 levels, three ranges, exact hashes, full validation,
  shuffled input determinism, metadata and P1 difficulty.
- test_selection_constraints: missing onboarding, word spacing at 99/100 slots,
  handmade lookahead, duplicate identities, eight-tile gate and exhaustion.
- test_publish_versions_and_check: fresh output, identical repeat, +1 revision,
  wrong versions, missing/extra/corrupt files, symlinks and read-only comparison.
- test_publication_failure: injected replacement failure preserves old bytes.
- test_cli_and_provenance: canonical export stage, repeated output, stale evidence,
  malformed input and --plan; CLI rejects missing options before any writes.

## Acceptance
make check, task/scope lint, fresh independent review and all CI pass. Report a
native full-source export attempt and its actual result; do not fabricate missing
handmade inputs or call unplayed content approved.

## Rollback
Revert code/task commits. This PR publishes no game content and changes no saves.
