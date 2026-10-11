---
id: T-0157
title: Propose lexical familiarity for current required words
epic: E08
type: content
area: content.pl
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0156, T-0152]
touch:
  - pipeline/reviews/pl/familiarity.csv
  - docs/qa/T-0157-familiarity-proposals.md
  - tasks/T-0157-familiarity-proposals.md
revision: 1
---

## Goal
Give the curator a source-backed, explicitly proposed review queue for every
current required answer, without another generated-content revision.

## Current state
- load_catalog from T-0156 validates the frozen CSV contract against native tiers.
- The version-2 shipped pack has 103 unique required words across 65 levels.
- Compact receipt records are validated through WordIndex(config).
- The new proposal CSV and QA note do not exist.

## Specification
Include exactly the 103 current required words, sorted once each, with an
editorial band proposal 1..5, status proposed, reviewer codex and concise English
rationale. Judge word familiarity rather than slot/tile count; explicit uncommon
forms/interjections/ambiguity deserve attention. These are agent proposals, not
measured frequency or Chris approval. Record assumptions and a curator workflow;
do not import unsupported words, change source tiers/bonuses, mark rows reviewed,
claim all-level manual QA or alter game data/p1 provenance.

## Tests
No mirrored permanent test for a data-only proposal. Validate all rows with the
parser and native WordIndex, exact required-word coverage and proposed-only status;
verify familiar long words are not rated by wheel size. Independently review every
proposal and rationale; full make check, scope/count, fresh review and green CI.

## Acceptance
The queue is complete, reviewable and accurately labeled; current game unchanged.

## Outcome
103/103 source-backed required forms proposed by Codex, with no extras:
69 band 1, 30 band 2, four band 3. Native parser and read-only replay pass.
Full make check: 247 GUT / 13049 assertions, 228 pipeline, 142 tools, 65 levels.
Scope three files; test count unchanged 402. Fresh independent row-by-row review
approved f54389a5ed85b0af0397fff594969d416c9e009b. Final-head green CI is
required before squash merge; this is not individual human lexical approval.
