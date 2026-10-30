---
id: T-0304
title: Prepare explicit owner lexical review of first 200 Polish campaign candidates
epic: E22
type: content
area: content.pl
risk: medium
executor: human
think: none
ui: none
status: blocked
depends_on: [T-0297]
touch:
  - pipeline/reviews/pl/T-0304-owner-lexical-review.csv
  - docs/qa/T-0304-review-instructions.md
  - tasks/T-0304-lexical-owner-worksheet.md
revision: 1
---

## Goal
Create deterministic owner review inputs for all selected crossword answers
in the existing 65-slot prototype and the 135 T-0306 proposals, without
pretending editorial approval, modifying `overrides/pl.csv`, or publishing levels.

## Scope
Produce a CSV with exact word/slot/band/source cross-references and **empty**
human-decision fields. Review every proposed answer. Use the pinned compact
source for eligibility evidence and all T-0296 unresolved flags.

## Review gate / acceptance
A human editor must fill the actual word decisions, approve reasons, and
commit authorized overrides/catalog changes in a separately reviewed content
PR. The T-0297/0296 parents and production validators must be merged.
No automatic lexical safety, legitimacy or familiarity inference.
Do not mark `done` from this worksheet alone.

## Out of scope
No automatic promotions/word decisions, no API/model costs, no
game/content changes and no gameplay QA or release authorization.
