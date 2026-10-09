---
id: T-0122
title: Annotate SJP-valid forms with pinned SGJP and KWJP100 evidence
epic: E08
type: feat
area: pipeline.annotate
risk: medium
executor: sol
think: med
ui: none
status: done
depends_on: [T-0121]
touch:
  - pipeline/src/wordgame_pipeline/annotate/**
  - pipeline/src/wordgame_pipeline/cli.py
  - pipeline/sources/annotation-pl.json
  - pipeline/pyproject.toml
  - uv.lock
  - pipeline/tests/annotate/**
  - pipeline/tests/test_pipeline_contract.py
  - pipeline/tests/ingest/test_ingest.py
  - docs/qa/T-0122-annotate.md
  - NOTICE
  - tasks/T-0122-pl-annotate.md
revision: 1
---

## Goal
Add the third P1 stage: lemma, POS, inflection and nullable frequency evidence for exactly the normalized SJP forms. Morphology/frequency must never introduce valid words or decide tiers.

## Context
- tasks/ROADMAP.md T-0122; docs/CONTENT.md#stages-and-artifacts — annotation stage.
- docs/decisions/0008-pl-word-sources.md: Morfeusz SGJP, KWJP100 orth_lc/lemma lists, nullable frequency; no usable lemma means at most bonus_ok.
- docs/decisions/0004-language-rules-pl.md: Polish diacritics and word rules.
- AGENTS.md S7: Chris approved the optional Morfeusz dependency on 2026-10-09 ("Rób").

## Current state
T-0121 supplies normalized sorted uppercase forms and pinned SJP provenance; StageHandler and canonical artifacts exist. CLI registers ingest/normalize only. Morfeusz is absent from the project. PyPI offers morfeusz2 1.99.15, SGJP dictionary date 2026.06.01 visible in the pinned Linux wheel; the verified native dictionary ID is pl.sgjp.sgjp-2026.06.01. KWJP repository full commit is 26d82bd8b906dfed1cfcf8f903b1650b56daeabf; both chosen gzipped CSVs have named ARF/ipm columns and unique word or (lemma, POS) keys.

## Specification
1. After approval only, add optional dependency annotate = [morfeusz2==1.99.15] and update uv.lock. Default installs and CI remain stdlib-only; invoke real builds from the workspace root with uv run --all-packages --extra annotate. No other dependency or project/game setting change.
2. Pin engine version/dictionary id/date and KWJP full commit, URLs, SHA256, sizes and CC BY 4.0 provenance in sources/annotation-pl.json. Verify the loaded engine/dictionary identity before downloads or artifacts. Verify downloaded/cached frequency bytes before use; cache under ignored build/pl/sources, atomic writes only. No floating latest sources or committed raw corpus.
3. Parse gzip CSVs strictly, keeping ARF and IPM as finite nonnegative numeric metrics. Orthographic keys and lemma/POS keys remain separate. Missing exact form or lemma frequency is null; never substitute a more frequent homonym or use frequency as validity.
4. Inject an analyzer protocol for offline tests. Analyze original normalized forms with pinned Morfeusz SGJP ignoring case, generation disabled. Keep all deterministic sorted unique whole-form interpretations; do not attach partial DAG segment lemmas to the entire word. Discard unknown ign interpretations; retain raw lemma, canonical NFC uppercase lemma, POS, full tag, source names/labels and inflection flag. Preserve homonym numbering in lemma_raw while stripping it only for canonical frequency lookup. Do not guess proper-name status or sensitivity; metadata remains evidence for T-0123.
5. Output exactly one record per input form, no rows from morphology/frequency-only words. Include exact source pins and SJP provenance; per-record analyses and form frequency, per-analysis lemma/POS frequency. Coverage records known morphology and frequency counts separately. Missing usable lemma leaves an empty analysis list and cannot create eligibility; no tier or level_ok decisions here.
6. Register annotate in the CLI; full default build stops preflight at tiers. Update only the existing test's first-unimplemented-stage expectation. CLI errors are clear when the optional dependency or pinned identity is unavailable, and no artifact is overwritten on failures.
7. After approved installation, run pinned real data through annotate, record coverage and repeat for byte-identical results in docs/qa/T-0122-annotate.md. NOTICE retains exact SGJP BSD copyright/disclaimer and KWJP CC BY attribution/modification statement. No runtime game dictionary, content, schema, validator, lock or tier changes.

## Tests
pipeline/tests/annotate/test_annotate.py:
- test_frequency_sources_and_nullable_joins: strict synthetic gzip CSVs, separate form/lemma metrics, finite values and duplicates, source bytes verified with injected fetcher.
- test_morphology_preserves_ambiguity_and_whole_word_identity: lemma/tag/inflection/metadata, homonyms, partial DAG and ign excluded, deterministic sorting.
- test_annotation_never_adds_valid_words_or_invents_eligibility: output membership exactly SJP input, missing lemma/frequency explicit, no tier assignment.
- test_stage_artifacts_and_identity_failures: injected analyzer, canonical repeat/resume, engine/dictionary mismatch before writes; old artifacts unchanged on bad sources.

## Acceptance
Required tests, pinned Godot 4.7.2 make check, task lint/scope and independent review pass. Real-data coverage/rebuild evidence only after dependency approval. One task/branch/PR; actual Codex provenance recorded.

## Escalation log
S7 resolved: Chris approved optional morfeusz2==1.99.15 (SGJP 2026.06.01) on 2026-10-09, replying "Rób" to the concrete dependency proposal. Native activation, verification and final merge may proceed within this scope.

S2/S5 resolved: native CLI registration makes the existing ingest CLI test’s
`annotate is not implemented` expectation obsolete. Proposed exact correction:
change its `--to annotate` and error expectation to `tiers` (two lines in
`pipeline/tests/ingest/test_ingest.py`). No ingest behavior changes. Chris approved adding this file to touch and the exact two-line correction on 2026-10-09.
