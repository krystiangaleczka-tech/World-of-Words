---
id: T-0121
title: Pin, ingest and normalize the Polish SJP validity source
epic: E08
type: feat
area: pipeline.ingest
risk: medium
executor: sol
think: med
ui: none
status: done
depends_on: [T-0120, T-0030]
touch:
  - pipeline/src/wordgame_pipeline/ingest/**
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/sources/sjp-pl.json
  - pipeline/tests/ingest/**
  - pipeline/tests/test_pipeline_contract.py
  - docs/qa/T-0121-ingest.md
  - NOTICE
  - tasks/T-0121-pl-ingest-normalize.md
revision: 1
---

## Goal
Run the first two real P1 stages with a checksum-pinned SJP source, reproducible Polish normalization and explicit reporting of annotation coverage.

## Context
- tasks/ROADMAP.md T-0121; FR-CONT-05; docs/CONTENT.md#stages-and-artifacts — stage boundaries.
- docs/CONTENT.md#determinism: byte-identical rebuilds, recorded provenance.
- docs/decisions/0004-language-rules-pl.md: Polish alphabet, minimum 3, no proper nouns/abbreviations.
- docs/decisions/0008-pl-word-sources.md: SJP validity only; no usable lemma means at most bonus_ok. Pin archive URL/version/SHA256; derived public data gets attribution.
- docs/spikes/S3-pl-word-sources.md: distinguish inflected-form counts from lemma/level-candidate counts.

## Current state
T-0120 supplies LanguageConfig, canonical stage artifacts, injected StageHandler(config, previous_payload), run_build and CLI with an empty production registry. PL config uses 32 letters and length 3..8. Archive sjp-20260901.zip at the already selected SJP endpoint contains UTF-8 slowa.txt and README.txt; it has no lemma, POS, proper-name or abbreviation metadata. T-0122 annotation is not implemented. NOTICE does not exist yet.

## Specification
1. Pin the selected archive in pipeline/sources/sjp-pl.json: source id/version, HTTPS URL, SHA256, archive size, UTF-8 member name/size, entry count and CC BY 4.0 provenance. Verify all pins from the downloaded archive; no floating latest URL.
2. Add a stdlib-only download script via python -m wordgame_pipeline.ingest --root pipeline. Cache only under ignored pipeline/build/pl/sources/. Reuse only verified cache; checksum/size mismatch fails closed. Inject the byte fetcher in unit tests; no test performs network I/O. Validate before atomic replacement, avoid archive extraction/path traversal, and verify pinned member size/entry count/encoding. No secrets, new dependencies or mobile network/settings changes.
3. Register ingest/normalize handlers bound to CLI --root. wg build --lang pl --to normalize writes the existing versioned artifacts. Full default build still fails preflight at unimplemented annotate without downloading/writing. Preserve the existing run_build contract and update only the existing CLI unimplemented-stage expectation in test_pipeline_contract.py.
4. Normalize NFC then uppercase, preserving Polish diacritics. Validate source characters against upper/lower Polish alphabet before case conversion (reject Q/V/X and foreign case-expanding characters), enforce config length 3..N, sort and deduplicate. A typed WordEntry accepts optional explicit proper_noun/abbreviation flags; known true flags are excluded without guessing from capitalization. Report rejection reasons and accepted counts by length deterministically.
5. The flat SJP list has no classification evidence: preserve that fact, never assert flags false or infer commonness. Normalized forms await T-0122 morphology and T-0123 tiers. Report verified lemma and verified level-candidate counts as zero with explicit pending-annotation status, not as the actual lemma pool size; no level_ok/bonus_ok/banned decisions in this task. Raw archive/word corpus/artifacts are never committed.
6. Record the real pinned-source run/rebuild evidence and normalized 3–7/8-letter counts in docs/qa/T-0121-ingest.md, with the annotation limitation above. Add repository NOTICE attribution, selected CC BY 4.0 link and modification statement. No shipped content/schema/validator/lock changes.

## Tests
pipeline/tests/ingest/test_ingest.py:
- test_verified_download_cache_and_mismatch: injected download, verified cache with no second fetch, corrupt bytes/member/count failure and old cache preservation.
- test_normalization_rules_and_determinism: NFC/diacritics, lengths, Q/V/X/foreign/punctuation, explicit proper-name/abbreviation flags, duplicate forms and stable sorted output regardless input order.
- test_stage_cli_build_and_resume: local pinned synthetic archive, both stages, CLI download/module entrypoints, byte-identical rebuild, normalize-only resume, correct source metadata/counts and pending annotation.
- test_no_unverified_level_candidates: absent morphology never creates eligible level words; known disallowed metadata rejected.

## Acceptance
Required cases, pinned Godot 4.7.2 make check, task lint, scope and independent review pass. Real selected-source build repeated byte-identically; no raw corpus committed. One task/branch/PR; actual Codex provenance recorded.
