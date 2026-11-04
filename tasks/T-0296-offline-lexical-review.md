---
id: T-0296
title: Produce an offline source-backed Polish lexical review queue
epic: E22
type: feat
area: pipeline.classify
risk: medium
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0123, T-0127]
touch:
  - pipeline/src/wordgame_pipeline/classify/**
  - pipeline/tests/classify/**
  - tasks/T-0296-offline-lexical-review.md
revision: 1
---

## Goal
Prepare a deterministic, reviewable queue of Polish level-word candidates using only already-pinned dictionary, morphology, frequency and current tier evidence. There is no AI model or paid/free remote API call. An editor, not the program, resolves uncertain familiarity and sensitivity.

## Context
- PRODUCT.md FR-CONT-05: word validity comes solely from the licensed source and overrides; a model cannot decide validity.
- CONTENT.md#word-tiers: tier order and owner overrides remain authoritative.
- Owner 2026-10-29: zero-cost, no AI API production path; the P2 roadmap is re-planned without waiving lexical review or launch gates.
- Source-backed P1 T-0123 and T-0127 are done. Historical T-0031 experiment stays unmerged and is not a production dependency. Missing T-0143 FUN gate remains an independent release prerequisite, not an automated content-classification prerequisite.

## Current state (preflight on fresh main)
- `pipeline/src/wordgame_pipeline/tiers/core.py`: `assign_tiers`, `rule_tier`, `analyses_for` and `arf` validate existing word evidence; their output records include `word`, `tier`, `tier_reason`, `analyses`, `frequency`, and `override`.
- `pipeline/src/wordgame_pipeline/tiers/__init__.py` requires pinned SJP and annotation sources before assigning P1 tiers.
- `pipeline/src/wordgame_pipeline/familiarity.py`: `load_catalog` reads explicit proposed/reviewed human familiarity decisions.
- `pipeline/src/wordgame_pipeline/stages.py` exposes P1 stages; stage `classify` exists in the catalog but is not selectable or wired into P1. No `classify/` package exists.
- Existing shipped content is 65 Polish slots. This task cannot imply that 200 are ready.

## Specification
1. Add a pure, typed, deterministic classification *review queue* builder under `pipeline.classify`; accept a source-provenance-bearing P1 tier payload and explicit human-review catalog input, without reading the network, invoking AI or changing the P1 stage runner.
2. Validate the payload envelope/provenance and records before producing output. Reject unpinned evidence, malformed/duplicate/unsorted records, invalid tiers, malformed review states, and unknown catalog words. Reuse strict tier and catalog validators rather than weaken them.
3. The review queue must include each candidate `level_ok` word that lacks an explicit reviewed human familiarity decision. Preserve the word, exact source tier/reason, frequency and lemma-evidence availability, evidence hash, and deterministic reason codes; flags for missing/ambiguous evidence are uncertainties, not semantic assertions of safety.
4. Include a deterministic second output for `bonus_ok` or ambiguous/banned-source records that would need manual escalation to become level words. Do not promote them, clear bans, rewrite overrides, or infer a safe classification from dictionary frequency alone.
5. Output canonical, sorted UTF-8 CSV or JSON through a pure serializer, with a SHA-256 digest over the exact source artifact and review catalog bytes, so reruns with identical inputs are byte-identical. No timestamps, machine paths, random sampling or generated human decisions.
6. No default publish/export activation; never modify `game/content/`, `pipeline/overrides/`, `pipeline/config/`, schema files, thresholds or released locks. T-0297 consumes human-approved outcomes with existing precedence; T-0304 remains the owner review gate.

## Out of scope
Model inference or prompting, token budgeting, paid or free APIs, account/privacy changes, native build/release claims, production content, new runtime dictionary, global CLI/stage handler changes, automatic word bans or promotions.

## Tests
File: `pipeline/tests/classify/test_offline_lexical_review.py`
- A pinned tier input with one unreviewed `level_ok`, one reviewed `level_ok`, one `bonus_ok`, one banned word yields a sorted queue containing only unresolved candidates plus separately flagged escalation, with preserved evidence.
- Same bytes in two runs produce byte-identical output and digest; shuffled, duplicate, unpinned or tampered input is rejected.
- Missing lemma/frequency and conflicting analyses produce explicit neutral uncertainty codes, never fabricated safety/familiarity labels.
- Existing approved override and reviewed human catalog cannot be overwritten by automatic output.
- Invalid review catalog status, missing source identity and unsupported language fail closed.
- Run `make pipeline-test`, `make check`, task/scope lint and exact-head CI.

## Acceptance
All specified tests and full checks pass, fresh independent review, exact-head CI success. Chris must separately review the queue in T-0304. Producing a queue alone does NOT complete T-0297, T-0306, content approval or the P2 exit gate.

## Rollback
Remove this optional offline package and task; no player saves, released slots or shipped content can be affected.
