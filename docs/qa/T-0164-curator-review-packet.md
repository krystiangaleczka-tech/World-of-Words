# Offline curator review packet

The packet presents the actual 65-slot campaign and its 103 required-word
judgments. It is curator QA, not the final game design or a player playtest.
HTML is standalone, responsive and offline: open the generated file in a browser,
use slot links to navigate, inspect wheel tiles, crossword letters and word rows.
Native sources/content are validated before generation. No runtime files change.

## Generate and inspect

Run from the repository root; shell redirection explicitly creates your chosen
local output. The Python commands themselves only read inputs and emit stdout.

```sh
uv run python -m wordgame_pipeline.review_packet > review.html
uv run python -m wordgame_pipeline.review_packet --format csv > candidate.csv
uv run python -m wordgame_pipeline.review_packet --format comparison --candidate candidate.csv > comparison.json
```

--root defaults to pipeline, --content-root to game/content, --catalog to
root/reviews/pl/familiarity.csv. --candidate is required for comparison and
rejected for HTML/CSV. An alternate catalog can supply annotated HTML too.
Validation errors return 1 with stderr/no partial output; malformed argument
syntax uses argparse's normal exit. Redirection may create/truncate an output
before validation fails, so keep draft filenames separate from committed inputs.

## Record actual decisions

Keep an untouched generated draft and edit a separate copy with a UTF-8 CSV/text
editor. In spreadsheet tools, import comma-separated columns as text to preserve
exact words and strings; export UTF-8 comma-separated CSV with the original five
headers. Do not alter/drop words, invent extra source forms or use localized
column names. CSV quoting handles commas, quotes and multiline rationale text.

For each word actually reviewed, enter band 1..5, status reviewed, your curator
attribution and a specific rationale. Keep unresolved words proposed, possibly
with a blank band. Existing judgments are retained on export; a missing annotation
becomes a blank-band proposed/unassigned row with Awaiting curator review.
The exporter never promotes a row. Review exact form, meaning, register and
familiarity rather than tile count; bonuses are outside this required-word queue.

Comparison validates native tiers and exactly all current required forms; it
rejects missing/extra/ineligible/malformed rows. Inspect Unicode-sorted changes,
candidate coverage and source hashes. Hashes identify file bytes, not your identity
or judgment quality. A valid comparison returns 0 even if early issues remain.
It neither applies changes nor completes any human/phase requirement. Applying
actual curator judgments to the repository needs a separately scoped content PR.

## Explicit readiness check

```sh
uv run python -m wordgame_pipeline.familiarity_report --catalog candidate.csv --check-early
```

This distinct check returns 0 only when the first 15 levels' required words are
reviewed with known band <=2. The current packet still contains 103 Codex proposals
and 24 early proposed issues: expected NOT READY, despite passing engineering CI.
Approved S26 evidence remains separate from per-word ratings. Outsider playtests
and FUN GATE remain human tasks; no P2 entry, production scoring or bonus ban is
inferred. No command writes the catalog, modifies source eligibility or game packs.
