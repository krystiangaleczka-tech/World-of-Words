---
id: T-0164
title: Expose offline review packet commands and usage
epic: E08
type: feat
area: content.pl
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0163]
touch:
  - pipeline/src/wordgame_pipeline/review_packet.py
  - pipeline/tests/test_review_packet.py
  - docs/qa/T-0164-curator-review-packet.md
  - tasks/T-0164-curator-review-packet.md
revision: 1
---

## Goal
Expose offline review packet commands and usage. Owner requested five more tasks before the pending P2 human gate.

## Current state
render_review, export_worksheet and compare_reviews exist; no packet CLI/test/QA note exists.

## Specification
Add python -m wordgame_pipeline.review_packet and main(argv: list[str] | None = None) -> int. --root pipeline, --content-root game/content, --catalog defaults root/reviews/pl/familiarity.csv; --format html(default)/csv/comparison. Comparison requires --candidate; reject candidate for other formats. HTML/CSV build validated report, HTML loads manifest-listed packs. Emit UTF-8 HTML/CSV or canonical comparison JSON to stdout; valid reports0 even unresolved proposals, validation errors stderr1; argparse syntax errors normal. No writes, new deps, existing CLI/build changes. Document safe explicit curator editing, read-only comparison, candidate source hashes, separate early readiness/phase gates. Generate local HTML/CSV artifacts from merged current main for user preview, do not commit generated artifacts or false approval.

## Tests
Test actual HTML/CSV and comparison CLI stdout/default/explicit paths, invalid option pairing/files/data/content, module entrypoint and no writes. Full checks/fresh review/CI. Inspect generated actual65/103 packet and verify displayed proposals.

## Acceptance
Only authorized touch files; full make check, scope/count, independent fresh review
and final-head green CI before squash merge. No human review or phase result invented.
