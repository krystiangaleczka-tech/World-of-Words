---
id: T-0031
title: Trial Polish AI classification on 200 words
epic: E02
type: spike
area: pipeline.classify
risk: medium
executor: cheap
think: med
ui: none
status: done
depends_on: [T-0030, T-0016]
touch:
  - docs/spikes/S3b-classification-trial.md
  - docs/spikes/S3b-classification-sample.json
  - tasks/T-0031-*.md
revision: 1
---

## Goal
Measure whether two cheap models agree enough on Polish word familiarity and sensitivity to justify
the Phase 2 batch-classification design, and establish a realistic cost per 1,000 words.

## Context
- docs/design-pass/09-content-pipeline.md#3-klasyfikacja-ai-koszt-i-kontrola — AI only classifies
  familiarity/sensitivity; it never decides word validity, results are cached, and disagreements go
  to human review.
- docs/decisions/0008-pl-word-sources.md — SJP.PL is the validity authority; morphology/frequency and
  AI classification cannot introduce validity.
- Roadmap row T-0031 — 200 PL words, two cheap models, agreement rate, cost per 1k, Chris reviews
  disagreements.

## Current state
- T-0016 is done and the Python toolchain exists.
- T-0030 is done; decision 0008 is accepted.
- No production classifier or API credentials are present in the repository.
- No T-0031 task file existed on main; Chris explicitly requested T-0031 execution.

## Specification
### Behavior
1. Use one fixed prompt and schema for both model runs so disagreement measures model behavior rather
   than prompt drift.
2. Classify exactly 200 Polish words, sampled to include common, obscure/legacy and
   sensitive/ambiguous cases. Feed only the word column to models; the sampling stratum is for
   analysis only.
3. For each word return:
   - familiarity: 0=unknown/very obscure, 1=uncommon, 2=widely known, 3=very common;
   - sensitivity: safe, review or block;
   - zero or more flags from archaic, vulgar, sexual, violence, alcohol_drugs, hate,
     proper_name, abbreviation, other.
4. Do not ask either model whether the token is a valid Polish word.
5. Measure exact familiarity agreement, familiarity agreement within one point, exact sensitivity
   agreement and actionable disagreement rate.
6. Queue for Chris every row where sensitivity differs, familiarity differs by at least two points,
   or flags differ in a way that changes review/block handling.
7. Record model IDs, date, request mode, token usage and paid-list-price cost. Report cost per 1,000
   words for each model and combined.
8. Do not commit API keys, account identifiers or other secrets.

### Edge cases
| Case | Expected |
|---|---|
| model rejects or omits a word | row is a disagreement/error and goes to review |
| malformed output | retry once with the same prompt; second failure is recorded, not silently fixed |
| word is vulgar but familiar | familiarity and sensitivity are independent fields |
| model claims a word is invalid | ignore validity claim; only requested classification fields count |
| one provider changes model alias | record the resolved/versioned model ID when available |

## Out of scope
- Production classify.py implementation, caching, provider SDKs, secrets, automatic tier assignment,
  ingest changes and generated game content.

## Tests
Documentation/data checks:
- sample JSON has exactly 200 unique words and every word is 3-7 characters;
- report contains the frozen prompt/schema and model/pricing sources;
- no agreement metric is claimed unless two actual model outputs were obtained;
- no secret or credential is committed.

## Acceptance
- Two distinct cheap models have classified all 200 words with the same prompt/schema.
- Agreement metrics and disagreement queue are reported.
- Chris can review the disagreement set without rereading all 200 rows.
- Actual or directly measured token usage yields cost per 1,000 words for each model and combined.
- Only files in touch changed and repository CI passes.

## Escalation log
- S1: ROADMAP defined T-0031 but no task file existed on main. Chris explicitly requested execution,
  so this branch freezes the ROADMAP scope without editing ROADMAP.
- S11: this Sol session has no callable second-model runtime and must not add/request API secrets in
  repository work. The 200-word sample, prompt, metrics and current public price basis are prepared,
  but the model-vs-model run itself remains blocked rather than fabricated.
