# Offline lexical familiarity review contract

Chris requested five further tasks after the current prototype merges. This
T-0155..T-0159 wave prepares a small offline review workflow before P2. It does
not run the deferred paid/model classification experiment or claim its cost
evidence, generate more levels, change eligibility or start a phase.

## Separate judgments

Native tiers answer whether a form is source-backed and eligible. A required
word's familiarity is a separate editorial judgment. Wheel size, intersection
count and slot position describe puzzle complexity and cannot supply lexical
ratings. The game's P1 difficulty stays 0.0. Complete valid optional bonus pools
remain independent: a difficult bonus is not a required obstacle to completion.

| Band | Editorial meaning | Review questions |
|---|---|---|
| 1 | Very familiar | Ordinary basic vocabulary; recognizable without explanation |
| 2 | Familiar | Everyday concrete/action words, some normal ambiguity |
| 3 | Less familiar | Narrower meanings, uncommon forms or interjections needing review |
| 4 | Difficult | Niche, literary, regional or obscure forms for many players |
| 5 | Very difficult | Specialist or especially unfamiliar forms requiring strong evidence |
| Empty | Unknown | No defensible proposal or judgment yet |

These are editorial categories, not corpus-frequency quantiles, measured player
success rates or a numerical runtime classifier. Consider the exact form and
meaning, lemma/inflection, literary/regional register and ambiguity; do not infer
them solely from length. A proposed easy rating can still be wrong.

## CSV contract and source boundary

The UTF-8 CSV header is exactly `word,band,status,reviewer,rationale`.
Words use uppercase NFC alphabetic source forms, in strictly increasing Python
Unicode order, without duplicates or whitespace normalization. Every word must
exist in the supplied native tier mapping as level_ok or bonus_ok; banned or
unavailable words are rejected. This does not establish new dictionary authority:
the report obtains the mapping from the existing validated compact P1 receipt
and WordIndex. Its bundled/offline provenance boundary remains as documented.

`band` is empty or a canonical single digit 1..5. `status` is proposed or reviewed.
Reviewer and rationale are nonempty, trimmed strings. Extra/missing columns or
cells, malformed CSV/UTF-8, a blank catalog and invalid fields fail validation.
Quoted CSV rationale text may contain commas. Input is rejected rather than
silently normalized or repaired.

`proposed` records an agent/curator suggestion, including an unknown band.
`reviewed` records a curator decision with an explicit band and attribution.
File validation cannot authenticate that person or the quality of the judgment.
No process changes proposed into reviewed automatically. The initial 103-word
catalog contains only Codex proposals: Chris's S26 approval is not relabeled as
103 individual lexical ratings, and no corpus frequencies are invented.

## Typed parser

T-0156 adds frozen WordReview records with typed fields word: str, band: int |
None, status: str, reviewer: str, rationale: str. The public helper
`load_catalog(path: Path, tiers: Mapping[str, str]) -> dict[str, WordReview]`
reads only that CSV and raises ValueError for invalid data (row context where
available). It does not mutate tiers or input files; ordinary I/O errors propagate.

## Reproducible report

T-0158 adds `build_report(root: Path, content: Path, catalog_path: Path) -> dict`.
It first calls read-only p1.check; only then joins manifest-listed level required
answers with the catalog. JSON shape:

```
schema_version: 1
language: pl
content_version: manifest content version
inputs: {catalog_sha256, tiers_sha256, packs: {manifest pack filename: SHA256}}
coverage: {missing: unique-word count, proposed: count, reviewed: count}
levels: [{slot, id, required: [{word, band, status, reviewer, rationale}]}]
```

Levels are sorted by slot; required entries preserve committed word order.
Absent annotations have band null, status missing and empty reviewer/rationale.
Catalog rows outside required words do not enter coverage. File-byte hashes identify
the inspected inputs; they do not prove human approval. No timestamps, network,
new caches or file changes are introduced. CSV changes alter the catalog receipt.

`python -m wordgame_pipeline.familiarity_report` accepts --root (pipeline),
--content-root (game/content), --catalog (default root/reviews/pl/familiarity.csv).
It emits canonical JSON to stdout and returns 0 for a valid report, including
unreviewed/missing annotations; concise invalid-input errors use stderr and exit 1.
This successful engineering report is not a familiarity acceptance verdict.

## Opt-in early-answer check

T-0159 adds `early_issues(report: dict, slots: int = 15, max_band: int = 2)`.
For required words in the first slots, it returns ordered `{slot,id,word,reason}`
records; reason priority is missing, proposed, unknown_band, above_max_band.
Only reviewed words with a known band at/below the threshold pass. A proposed
band 1 still fails. Bonus words are outside the check. Slots must be an integer
1..level count and maximum band an integer 1..5; bool is not an integer option.

CLI --check-early enables this explicit check; --early-slots (15) and --max-band
(2) configure it. Threshold options without the check are rejected. Output adds
`early_check: {slots, max_band, issues}`; exit 0 means no issues, otherwise 1.
Without the check, T-0158 behavior is retained. The current proposal-only catalog
is expected NOT READY; it must never be relabeled to make the check green.

The optional check is not wired into existing builds, make check, game JSON or
FUN GATE. Future production authoring integration needs its own approved task,
source evidence, curator decisions and phase dependencies. All five tasks require
full engineering checks, fresh independent review and green CI before merging.
