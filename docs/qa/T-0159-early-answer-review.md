# Optional early required-answer familiarity check

Run from the repository root:

```sh
uv run python -m wordgame_pipeline.familiarity_report
uv run python -m wordgame_pipeline.familiarity_report --check-early
uv run python -m wordgame_pipeline.familiarity_report --check-early --early-slots 15 --max-band 2
```

The ordinary report validates/replays current content, emits canonical JSON and
returns 0 even when judgments are proposed or missing. It provides evidence for
review, not an editorial acceptance verdict. --check-early explicitly adds
`early_check: {slots, max_band, issues}` and returns 0 only with no issues;
otherwise it emits the report and returns 1. Validation errors return 1 with
stderr and no JSON; malformed command syntax uses argparse's normal error exit.
Threshold options without --check-early are rejected.

Slots default to 15 and maximum band to 2. Both must be integers: slots from
1 through the reported level count, band from 1 through 5. The pure helper also
rejects booleans as thresholds. Required answers retain level/word order;
reason priority is missing, proposed, unknown_band, above_max_band. Only an
explicitly reviewed, known band at or below the threshold passes. A proposed
band 1 remains unresolved. Later levels outside scope do not enter the verdict.

## Current result: NOT READY for editorial acceptance

The current version-2 campaign has 65 levels and 103 unique required words.
All catalog judgments are proposed/codex. The default first-15 check returns 1
with 24 issues, each reason proposed. This is expected and is covered by a
passing engineering test. Successful make check/CI therefore does not imply
that a curator has approved those 24 lexical judgments or that P2/FUN GATE
has passed. Existing S26 approval is retained as device evidence.

A curator should review exact forms/rationales as described in T-0157, record
actual per-word decisions with attribution, and rerun the report/check. These
commands never rewrite CSV statuses or game content to make a verdict pass.
Report file-byte hashes identify the reviewed inputs; they cannot authenticate
curator identity or quality. Alternate catalogs use --catalog PATH, and
--root/--content-root allow a copied offline workspace.

## Boundaries and verification

Only required words are checked. The report omits bonus words, so valid hard
optional bonuses remain eligible; a reviewed band-5 KUR fixture never blocks a
reviewed easy KOT answer. Runtime difficulty, source tiers, complete native
bonus pools, released content and player saves remain unchanged.

No integration into make check, p1 export/check, game JSON or phase gates is
introduced. Tests cover reviewed thresholds, proposed/missing/unknown reasons,
ordering, nonmutation, later-word and bonus exclusion, invalid types/bounds,
default CLI compatibility, passing/failing reviewed fixtures and the current
expected NOT READY catalog. Full engineering checks and an independent fresh
review are required before merge.
