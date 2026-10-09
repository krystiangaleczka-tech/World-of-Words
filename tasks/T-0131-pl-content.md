---
id: T-0131
title: Build the first reviewed Polish campaign
epic: E08
type: content
area: content.pl
risk: med
executor: cheap
think: med
ui: none
status: done
depends_on: [T-0127, T-0128, T-0130, T-0119]
touch:
 - pipeline/src/wordgame_pipeline/p1.py
 - pipeline/config/p1-pl.json
 - pipeline/content-inputs/pl.json
 - pipeline/content-evidence/pl.json
 - pipeline/tests/test_p1_content.py
 - game/content/pl/**
 - game/content/NOTICE
 - docs/qa/T-0131-pl-content.md
 - tasks/T-0131-pl-content.md
revision: 1
---

## Goal
Ship 50 generated Polish levels plus 15 required handmade levels, with native
source provenance, byte-identical rebuild and complete runtime bot QA.

## Current state
Dependencies are done. Native current PL tiers exist locally; their SHA is recorded
in T-0129's audit. Registered candidates/grid/validate/export stages and publish()
exist; validate_content prepares compact CI tier evidence. Handmade slots 1–15
exist. No shipped PL campaign or compact export inputs exist yet. Root NOTICE
contains source attribution. Existing content bot already plays every shipped pack.

## Specification
1. Add a P1 build entry point `python -m wordgame_pipeline.p1` and a committed
   canonical selection plan (65 slots, content_version 1, reviewed_answers).
   Run unchanged native stages from candidates through export. Keep automatic
   candidates whose entire level_ok pool belongs to T-0129's kept answers or
   authored opening answers. Preserve complete source tier pools and bonuses;
   never promote a word or manufacture membership. Use unchanged exporter order,
   spacing, IDs, geometry and semantics. Author no game JSON by hand.
2. Generate packs/manifest using publish, tier evidence using validate_content,
   and compact source-input receipt from actual canonical native candidate/tiers
   artifacts. Record current config/source/annotation/review/override/handmade/
   plan/schema hashes and native full tiers SHA. CI receipt contains all eligible
   tier records for all retained candidate wheels, not only shipped levels.
3. --check reruns standard grid search, validates all retained grids, assembles
   the campaign and compares exact output bytes from committed compact inputs
   without dictionaries, native artifacts, writes or downloads. Invoke it in
   pipeline tests so existing CI checks enforce rebuilding. Use existing validators
   without changing them. Document compact extract's source trust boundary.
4. Generate game/content/NOTICE by copying root NOTICE; check byte equality.
   Record QA counts, hashes, source attribution, generated wheel sizes, dictionary
   review coverage and native/CI checks. P1 has no P2 scoring/curve; human playtest
   belongs to T-0140 and must remain unclaimed. No save/schema/economy changes.

## Tests
pipeline/tests/test_p1_content.py: rebuild actual campaign without native artifacts
and without writes; 15 handmade/50 generated and unique answers; a semantically
valid edited pack with repaired hashes still fails deterministic rebuild; changed
plan/review/schema invalidates inputs; source attribution and CLI failure behavior.
Existing GUT content bot plays every shipped level. Full make check.

## Acceptance
Native registered build, compact byte-identical grid/export replay, all 65 runtime
levels complete without hints, task/scope lint, fresh independent review, all CI.

## Rollback
Revert generated campaign and inputs as one task. These are internal P1 slots;
released-slot locks arrive later, and save contracts stay unchanged.
