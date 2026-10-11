---
id: T-0158
title: Report required-answer familiarity with reproducible evidence
epic: E08
type: feat
area: content.pl
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0157]
touch:
  - pipeline/src/wordgame_pipeline/familiarity_report.py
  - pipeline/tests/test_familiarity_report.py
  - tasks/T-0158-familiarity-report.md
revision: 1
---

## Goal
Produce a deterministic review report joining real required answers to lexical
annotations, with unknown/proposed/reviewed coverage visible.

## Current state
- p1.check(root, content) validates/replays shipped content read-only.
- T-0156 load_catalog and T-0157 proposal CSV exist.
- The new report module/test do not exist.

## Specification
Add build_report(root: Path, content: Path, catalog_path: Path) -> dict.
Call existing read-only p1.check before reporting; construct WordIndex from the
validated compact receipt/config and load_catalog. Read manifest-listed pack
levels; output schema_version 1, language pl, content_version, input hash receipts
(catalog SHA256, pack file SHA256 map, native tiers SHA256), and levels sorted by
slot with id and required words. Each word records word, band/null, status
(missing/proposed/reviewed), reviewer/rationale strings. Include unique-word
coverage counts for those statuses. Optional bonuses are not scored/rejected.
No clocks, network, pipeline caches or modifications. A valid incomplete catalog
must report missing answers, not silently invent ratings or approval.
Add python -m wordgame_pipeline.familiarity_report CLI --root (pipeline),
--content-root (game/content), --catalog (default root/reviews/pl/familiarity.csv).
Canonical JSON to stdout; concise validation errors on stderr and exit 1;
success 0. No existing wg/p1 CLI or production schemas change.

## Tests
New test_familiarity_report.py: deterministic actual campaign report (103
proposed/0 reviewed; exact slots/words/hashes), missing and reviewed fixture
annotations, catalog changes alter receipt, malformed/unknown catalog rejected,
tampered pack rejected by replay, read-only tree equality, CLI stdout/errors.

## Acceptance
Focused/full checks, scope/count, fresh review and green CI before merge.

## Outcome
Deterministic required-answer reporting, source/input hash receipts and canonical
CLI pass nine focused cases. Full make check: 247 GUT / 13049 assertions,
237 pipeline, 142 tools, 65 levels. Scope three files; test count 410 vs 402.
Fresh independent review approved 790348aa651a22dfc6279c3eafb3b6adff151362
without blockers. Final-head CI is required before squash merge.
