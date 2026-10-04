---
id: T-0030
title: Select Polish word and frequency sources
epic: E02
type: spike
area: pipeline.ingest
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0002]
touch:
  - docs/spikes/S3-pl-word-sources.md
  - docs/decisions/0008-pl-word-sources.md
  - tasks/T-0030-*.md
revision: 1
---

## Goal
Choose a commercially usable, reproducible source stack for Polish word validity, morphology and
frequency so the Phase 1 content pipeline can ingest real data without licensing ambiguity.

## Context
- `docs/design-pass/09-content-pipeline.md#8-źródła-danych-do-weryfikacji-licencji-w-spikeu-s3`
  — validity must come from a licensed source; SJP.PL, Morfeusz/PoliMorf and frequency data need review.
- `docs/decisions/0004-language-rules-pl.md` — 32-letter alphabet, min length 3, morphology required.
- `docs/PRODUCT.md#compliance-and-store-requirements` — dictionary/frequency licences must permit
  commercial derived data and required attribution must ship in Settings > Licences.
- Roadmap row T-0030; Q11.

## Current state
- Decision 0004 fixes Polish language rules but does not select data sources.
- The pipeline design names SJP.PL, Morfeusz/PoliMorf and wordfreq/corpus options.
- No PL source decision exists; decision numbers currently end at 0007.
- No T-0030 task file existed on main; Chris explicitly requested T-0030 execution.

## Specification
### Behavior
1. Compare the current SJP.PL game/inflection downloads and their licence choices.
2. Compare Morfeusz 2 SGJP/PoliMorf for morphological annotation and commercial redistribution.
3. Compare wordfreq with a Polish corpus frequency source, including downstream/derived-data burden.
4. Record a current 3–7-letter vocabulary-size sanity check that distinguishes inflected-form capacity
   from lemma/level-candidate scale.
5. Recommend one deterministic source stack and exact attribution obligations.
6. Create decision 0008 as proposed; only Chris may change it to accepted.

### Edge cases
| Case | Expected |
|---|---|
| validity source contains rare/objectionable words | source membership means valid input only; tiers/overrides still enforce decision 0004 |
| SJP-valid word has no usable Morfeusz lemma | word stays valid input but is at most `bonus_ok`; it cannot become `level_ok` without lemma evidence |
| morphology disagrees with SJP validity | SJP validity wins; morphology may be missing/ambiguous |
| frequency row is missing | keep word valid; frequency is nullable and cannot create validity |
| upstream archive changes | ingest pins source-specific version identifiers + SHA-256; source update is an explicit reviewed change |
| share-alike source complicates exported artifacts | do not select it when a CC BY/BSD alternative meets the need |

## Out of scope
- Download/ingest implementation, schemas, thresholds for `level_ok`, AI classification and content generation.
- Legal advice beyond documenting upstream licence terms and conservative engineering consequences.

## Tests
Documentation review:
- each selected source has an upstream URL, licence and attribution rule;
- validity, morphology and frequency have separate authority/fallback rules;
- the report distinguishes 3–7-letter inflected-form counts from lemma/level-candidate estimates;
- version pinning covers SJP, KWJP100 and Morfeusz/SGJP;
- decision 0008 does not silently claim Chris approval.

## Acceptance
- Only files in `touch` change and repository CI passes.
- T-0120/T-0121/T-0122 can implement the source stack without another source-selection decision.
- Chris can accept or reject decision 0008 from one concise recommendation.

## Rollback
Docs-only spike. Revert the squash commit before implementation; after generated content depends on
these sources, replace the decision explicitly and rebuild unpublished content.

## Escalation log
- S1: ROADMAP defined T-0030 but no task file existed on main. Chris explicitly requested execution,
  so this PR records the frozen ROADMAP scope without editing ROADMAP or production code.
