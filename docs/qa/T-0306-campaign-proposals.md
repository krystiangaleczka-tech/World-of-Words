# T-0306 — Polish 200-slot candidate selection (editorial draft)

Date: 2026-10-29. **Status: proposed / blocked for production.**

## Grounded inventory

- Existing committed P1 campaign: **65 levels**, 1–65. No `game/content/` files altered.
- New candidate arrangements: **135 levels**, contiguous slots 66–200.
- Total target inventory: **200**; only the original 65 are presently shipped.
- New proposed selected crossword answers: **331 placements**; every selected
  word has `level_ok` tier in the pinned `pipeline/content-inputs/pl.json`.
- Each new proposed grid has **at least two** crossword words. Grid and letters
  are explicit inputs, to be checked through the repository's native `make_level`,
  `WordIndex`, and full geometry constraints before accepting this PR.
- New wheel size: five letters for 66–90, six for 91–150,
  seven for 151–200. These are **editorial bands**, not a calibrated
  difficulty measurement; no fake score is written to gameplay packs.
- Unique letter multisets across 200 planned slots and 100-slot spacing
  between selected crossword words are asserted by new tests.
- Only **two** proposed levels (194 and 199) use a selected word outside
  the seed/partner familiarity shortlist, and have `manual_review_priority: true`.
  **This is not a claim that the other 133 are human-approved**; every
  proposed word still requires lexical/UX review.

## Difficulty and coverage summary

| Slots | Provisional band | Wheel letters | New levels | Crossword answer placements | Source-derived bonus candidates |
|---|---:|---:|---:|---:|---:|
| 1–30 | 1 — tutorial/easy | existing | 30 | existing | existing |
| 31–65 | 2 — easy | existing | 35 | existing | existing |
| 66–90 | 2 — medium transition | 5 | 25 | 50 | 313 |
| 91–120 | 3 — medium | 6 | 30 | 60 | 728 |
| 121–150 | 3 — medium-plus | 6 | 30 | 73 | 877 |
| 151–175 | 4 — hard candidate | 7 | 25 | 69 | 1843 |
| 176–200 | 5 — harder candidate | 7 | 25 | 79 | 1307 |

The large number of source-formable bonus candidates is a **QA warning**.
They must be reviewed for clarity, sensitivity and expected player behavior.
The compact source is not a complete production dictionary, and a high number
of bonus candidates is not itself a sign of a good level.

## Example proposed levels

| Slot | Wheel | Crossword words | Band |
|---:|---|---|---:|
| 66 | ACMOS | MOC, SAMO | 2 |
| 75 | CEHIK | CIEK, ICH | 2 |
| 90 | AGRUZ | GRUZ, RAZ | 2 |
| 100 | ADHMRU | DAM, HURA | 3 |
| 120 | AADHOW | AHA, OWAD | 3 |
| 140 | AANOTW | TONA, WATA | 3 |
| 155 | ABKLNOR | BAL, BOA, KONAR | 4 |
| 175 | ACEKLPR | CEP, KRA, PLACEK | 4 |
| 180 | AAKMOTŁ | ATAK, MAŁO, TAM | 5 |
| 190 | GORSUZŁ | GRUZ, SZŁO | 5 |
| 200 | AHKORUZ | HURA, KOZA, RAZ | 5 |

Every row in the complete 135-slot data file includes wheel letters,
selected answer words, exact crossword grid placements, editorial band,
review status and priority flag.

## Source provenance and zero-cost constraints

The candidate JSON pins the exact Git blob identity for:
`pipeline/content-inputs/pl.json`, the existing
`game/content/pl/packs/c-0001-0065.json`, and
`pipeline/reviews/pl/T-0129-words.csv`. The checker rejects changes
to these files without rebuilding/reviewing the candidate batch.

No API key, LLM batch, network inference, paid classifier, new source
word or player progression change is introduced. All placements are
authoring proposals, not hand-edits to generated game JSON.

## Mandatory gates before this can be called T-0306 done

1. Pass exact-head CI and independent content/technical review.
2. Complete the still-missing production stages T-0297–T-0303 and
   owner-reviewed onboarding T-0305, with approved difficulty weights.
3. Rebuild all 200 through the actual P2 generator, source QA and
   manifest v1.1 region/location metadata; never manually edit packs.
4. Have Chris review source words and bonus lists, then play the first
   ~100 levels and all key difficulty transitions. Fix awkward puzzles.
5. Conduct mobile UI/geometry testing; confirm all generated grids fit
   the COMPACT layout and reward/coach flow on actual devices.

**The PR is preparatory; not merged to production, not a completed 200-level
campaign and not certification of calibrated difficulty.**
