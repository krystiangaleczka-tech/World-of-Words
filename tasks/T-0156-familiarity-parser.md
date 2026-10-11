---
id: T-0156
title: Validate source-backed familiarity review catalogs
epic: E08
type: feat
area: content.pl
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0155]
touch:
  - pipeline/src/wordgame_pipeline/familiarity.py
  - pipeline/tests/test_familiarity.py
  - tasks/T-0156-familiarity-parser.md
revision: 1
---

## Goal
Load deterministic offline review data without silently converting proposed or
missing judgments into approval or changing native source eligibility.

## Current state
- T-0155 defines the contract in docs/qa/T-0155-familiarity-contract.md.
- Native WordIndex exposes tiers mapping; non-banned tiers are level_ok/bonus_ok.
- The new familiarity module and tests do not exist.

## Specification
Add frozen typed WordReview(word: str, band: int | None, status: str,
reviewer: str, rationale: str) and load_catalog(path: Path,
tiers: Mapping[str, str]) -> dict[str, WordReview]. CSV header/order exactly
word,band,status,reviewer,rationale; UTF-8/NFC uppercase alphabetic words sorted
and unique. Reject extra/missing cells, malformed encoding/CSV, blank catalog,
unknown/banned native words, whitespace alterations, invalid bands/statuses or
empty curator/rationale. Band is empty or exactly 1..5; reviewed requires a band.
Proposed may have a band or remain unknown. Never normalize incorrect input,
infer approval, invent source records or perform I/O beyond reading the catalog.
Raise ValueError with useful row context; file I/O errors propagate normally.

## Tests
New test_familiarity.py: accept all five bands and unknown proposal; retain
Polish diacritics, quoted comma rationale and immutable typed records; reject
duplicates/unsorted, decomposed/lowercase/whitespace words, missing/extra
columns/cells, malformed UTF-8/CSV, invalid band/status, empty reviewer/rationale,
unknown/banned source word, reviewed unknown band, empty data. Verify read-only.

## Acceptance
Focused tests, full make check, scope/count and fresh review pass; remote CI
green before merge. Existing pipeline/build/runtime behavior is unchanged.

## Outcome
Frozen source-backed CSV loader and 27 focused cases pass. Full make check:
247 GUT / 13049 assertions, 228 pipeline, 142 tools, 65 levels. Scope three
files; test count 402 vs 397. Fresh independent review approved bd6e7e2
without blockers. Remote final-head CI is required before squash merge.
