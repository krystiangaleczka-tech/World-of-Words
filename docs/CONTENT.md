# CONTENT.md — content pipeline and level data

- Status: v0 (T-0008, 2026-10-02). Opus second opinion on the schema and slot policy in T-0010; Chris
  approves with docs v1 (T-0011). Sections marked *(P2)* or *(P3)* are direction, refined when their
  epic is planned.
- Owns: pipeline stages and artifacts, word tiers and overrides, the level, pack and manifest formats,
  the released-slot policy, the difficulty curve, validation, QA sampling, determinism.
- Sources: design pass `09-content-pipeline.md`; decisions 0002 (content in packs, no runtime
  dictionary), 0004 (Polish word rules), 0005 (PL → EN → DE).

## Principles

1. **Word validity comes only from the licensed source plus Chris's overrides** (FR-CONT-05). An LLM
   never decides whether something is a word.
2. **An LLM only classifies** (sensitivity, familiarity, topic). Its output is a cached suggestion, never a
   verdict.
3. **Deterministic** (FR-CONT-06, NFR-14): the same inputs and pipeline version produce byte-identical
   packs.
4. **Stages with artifacts.** Each stage reads the previous stage's artifact and writes its own; a build
   can start from any stage.
5. **Released slots are immutable** in letters, grid and level words. Bonus lists may change
   ([Slot policy](#slot-policy)).
6. **The game only reads the output** (decision 0002). Every word rule lives here and in the pipeline.

## Repository layout

```
pipeline/
  src/wordgame_pipeline/<stage>/   one package per stage (ARCHITECTURE.md#areas: pipeline.<stage>)
  tests/<stage>/
  schema/                          level, pack, manifest, daily calendar JSON Schemas (hotspot)
  config/<lang>.yaml               alphabet, length limits, tier rules per language
  config/curve.yaml                difficulty curve; config/scoring.yaml  feature weights
  overrides/<lang>.csv             Chris's word decisions (highest priority)
  handmade/<lang>/*.yaml           hand-made levels (onboarding, landmarks)
  cache/<lang>/                    AI classification cache (committed)
  locks/<lang>.lock.json           released-slot lock file (committed)
  sources/                         download scripts + checksums (raw data is not committed)
  build/<lang>/<NN-stage>/         intermediate artifacts (git-ignored)
game/content/<lang>/               final output: manifest.json, packs/*.json (committed, generated)
```

- Command line: `wg build --lang pl [--from <stage>] [--to <stage>]` (T-0120).
- `make content-validate` validates `game/content/` against the schemas and the lock file.

## Stages and artifacts

| # | Stage (area) | Does | Automatic check | Human |
|---|---|---|---|---|
| 1 | ingest (`pipeline.ingest`) | Download sources, verify checksum | checksum, entry count | licence, once per source |
| 2 | normalize (`pipeline.ingest`) | NFC, uppercase, language alphabet, length 3..N, drop proper nouns and abbreviations | per-language rule tests | — |
| 3 | annotate (`pipeline.annotate`) | Lemma, part of speech, inflection flag, frequency | coverage (share with frequency) | — |
| 4 | classify (`pipeline.classify`) *(P2)* | AI suggestions: sensitivity, familiarity, topic; two runs | agreement rate; disagreements → queue | disagreements and flagged level-word candidates only |
| 5 | tiers (`pipeline.tiers`) | `level_ok` / `bonus_ok` / `banned` from rules + overrides (+ suggestions from P2) | tier distribution diff vs previous build | `overrides/<lang>.csv` |
| 6 | candidates (`pipeline.candidates`) | Seed word → letter multiset → every formable word (anagram index); hand-made YAML input | ≥ minimum `level_ok` words | — |
| 7 | grid (`pipeline.grid`) | Crossword layout: greedy with backtracking, many seeds, best layout | grid invariants (below) | — |
| 8 | scoring (`pipeline.scoring`) *(P2)* | Difficulty from features × weights | score distribution | calibration with telemetry (P3) |
| 9 | validate (`pipeline.validate`) | [Hard validation](#hard-validation); a failure rejects the level | — | — |
| 10 | dedupe (`pipeline.dedupe`) *(P2)* | Same multiset; word-set Jaccard; seed-word spacing K | thresholds in config | — |
| 11 | sequence (`pipeline.sequence`) *(P2)* | Fit levels to the [curve](#curve); landmarks, breathers, onboarding, locations | deviation from curve | curve chart review |
| 12 | qa (`pipeline.qa`) *(P2)* | Report: stats, histograms, weirdest level words, AI "odd for this slot" flags | — | [QA sampling](#qa-sampling) |
| 13 | export (`pipeline.export`) | Packs + manifest into `game/content/<lang>/`; lock check | schema, lock file, byte-identical rebuild | `content` PR review |

In P1 the pipeline runs stages 1–3, 5–7, 9 and 13. Levels are ordered by letter count, with no scoring,
dedupe or AI (T-0120 … T-0131).

## P1 repetition spacing

Chris requested on 2026-10-09 that crossword words may recur only at a slot
distance of at least 100 (for example, slots 1 and 101). Recurrence is optional;
a word need never return. This applies to every crossword word, not only the
seed word. Bonus lists do not count as crossword occurrences. Subsequent P1
sequencing and export work must enforce this policy before shipping packs.

## Word tiers

Every normalized word gets exactly one tier:

| Tier | Meaning | Allowed as |
|---|---|---|
| `level_ok` | Common, inoffensive, known to an average adult; base form or very frequent inflection | level word or bonus word |
| `bonus_ok` | Valid form from the source, not offensive, not `level_ok` (rarer words, inflected forms) | bonus word only |
| `banned` | Vulgar, offensive, proper noun, abbreviation, outside the alphabet, or banned by Chris | nothing: the game treats it as INVALID |

- **Precedence:** `overrides/<lang>.csv` > rules in `config/<lang>.yaml` > AI suggestion. The AI
  suggestion can only move a word toward a stricter tier (`level_ok` → `bonus_ok` → `banned`), or flag
  it for review; it never makes a word valid.
- **Polish rules** (decision 0004):
  - 32-letter alphabet, with diacritics as separate letters;
  - words with Q, V or X are excluded;
  - minimum length 3;
  - level words are base forms plus very frequent inflections;
  - every valid, non-banned form is a bonus word;
  - no proper nouns or abbreviations;
  - vulgar words are `banned`.
- EN and DE need their own rules decision before their pipeline runs (decision 0005).

### Overrides
`pipeline/overrides/<lang>.csv`, one row per decision, in UTF-8. The pipeline sorts it by `word` on
read, so the order of rows does not matter.

```csv
word,tier,reason,date,by
KOT,level_ok,common animal,2026-10-20,chris
GÓWNO,banned,vulgar,2026-10-20,chris
```
- `tier` is one of the three tiers.
- `reason` is required.
- Overrides are the history of dictionary decisions and are never deleted. A newer row for the same word
  wins.

### Classification *(P2)*
- Batch calls of a cheap model, cached in `pipeline/cache/<lang>/` keyed by
  `(word, prompt_version, model)`. The cache is committed, so a rebuild costs nothing and is
  reproducible.
- Two runs (two models or two prompts); disagreements go to `pipeline/build/<lang>/review_queue.csv`
  for Chris. His answers land in `overrides/<lang>.csv`.
- The repo turns private before the first production classification run (T-0296).

## Hand-made levels

Onboarding levels and landmarks are written by hand and processed like any other level, skipping the
candidates stage. The pipeline builds the grid, validates and exports.

```yaml
# pipeline/handmade/pl/onboarding.yaml
- slot: 1
  letters: [K, O, T]
  words: [KOT]              # level words; the grid is built by the pipeline
- slot: 5
  letters: [D, O, M, A]
  words: [DOM, MODA]
  expect_bonus: [ODA]       # validation fails if this word is not in the generated bonus list
```
- Letters must form every listed word. The bonus list is always generated from the tiers, never typed
  by hand.
- `grid:` with explicit coordinates is optional, for a landmark whose layout matters.

### P1 candidate artifact

The candidates stage imports handmade YAML while bypassing automatic seed discovery for
those entries. `automatic` contains one wheel per canonical sorted letter multiset,
its stable `pl-auto-<signature>` candidate ID, sorted seeds, and complete `level_ok` /
`bonus_ok` pools. The grid stage selects crossword words; remaining eligible words
become bonus words. These are intermediate IDs, not exported level IDs.

`handmade` contains slot, letters, selected words, complete bonus, expected bonus and
optional `grid` placements (`[{w: KOT, x: 0, y: 0, dir: h}]`). Geometry is checked by
subsequent grid/validation stages. Import rejects duplicate keys/slots, aliases,
custom tags and multiple YAML documents. Source pins, rule/override hashes and a
hash of sorted handmade paths plus exact bytes are carried into the artifact.
Candidate pools can overlap; sequencing/export enforces the 100-slot repetition policy.

## Level schema

One level is a JSON object. The schema lives in `pipeline/schema/level.schema.json` (T-0040) and is
checked by the pipeline and by CI. `schema_version` sits on the pack, not on each level.

```json
{
  "id": "pl-c-000128",
  "slot": 128,
  "letters": ["D", "O", "M", "A", "K"],
  "words": [
    { "w": "DOM",  "x": 0, "y": 0, "dir": "h" },
    { "w": "MODA", "x": 2, "y": 0, "dir": "v" }
  ],
  "bonus": ["DAM", "KOD", "ODA"],
  "grid": { "w": 3, "h": 4 },
  "difficulty": 18.4,
  "landmark": false,
  "source": "generated",
  "seed": 9137442,
  "pipeline": "0.7.0"
}
```

| Field | Type | Rule |
|---|---|---|
| `id` | string | `<lang>-<kind>-<NNNNNN>`; kind `c` campaign, `d` daily. Unique per language, never reused. |
| `slot` | int ≥ 1 | Campaign slot. Absent in daily levels. |
| `letters` | array of 1-character strings | Wheel tiles in their initial order; 3–7 letters, landmarks up to 8 (FR-WHEEL-09). Uppercase, from the language alphabet. Repeats are allowed (tiles are addressed by index, FR-CORE-03). |
| `words` | array of `{w, x, y, dir}` | Level words. `x`, `y` are the zero-based cell of the first letter; `dir` is `h` (right) or `v` (down). Order = the tie-break order used by `GAME_DESIGN.md#hints`. |
| `bonus` | array of strings, sorted | Complete bonus list: every `level_ok`/`bonus_ok` word of length ≥ 3 formable from `letters`, minus `words` (decision 0002). May be empty. |
| `grid` | `{w, h}` | Bounding box; at most 10 × 10; portrait-friendly aspect (see [Hard validation](#hard-validation)). |
| `difficulty` | number | Score from stage 8; `0` in P1. |
| `landmark` | bool | Hand-made larger level ([curve](#curve)). |
| `source` | `generated` \| `handmade` | Where the letters and words came from. |
| `seed` | int | Seed that produced the grid (and letters, for generated levels). |
| `pipeline` | string | Pipeline version (semver) that built the level. |

The game reads only `id`, `slot`, `letters`, `words`, `bonus` and `grid`. All other fields are for
traceability and QA (NFR-14).

### Packs
- `game/content/<lang>/packs/c-0001-0100.json`: campaign slots 1–100. Daily packs are
  `d-0001-0100.json`.
- File shape: `{ "schema_version": 1, "lang": "pl", "kind": "campaign", "levels": [ ... ] }`, levels
  sorted by slot.
- About 100 levels per pack (FR-CONT-01).

## Manifest

`game/content/<lang>/manifest.json`, schema `pipeline/schema/manifest.schema.json`.

```json
{
  "schema_version": 1,
  "lang": "pl",
  "content_version": 3,
  "pipeline": "0.7.0",
  "slots": 200,
  "packs": [
    { "file": "packs/c-0001-0100.json", "kind": "campaign", "first": 1, "last": 100, "sha256": "…" },
    { "file": "packs/c-0101-0200.json", "kind": "campaign", "first": 101, "last": 200, "sha256": "…" }
  ],
  "regions":   [ { "id": "r01", "name_key": "journey.region.r01", "first": 1, "last": 200 } ],
  "locations": [ { "id": "r01-l01", "region": "r01", "name_key": "journey.location.r01_l01",
                   "first": 1, "last": 48, "postcard": "postcards/r01-l01.webp" } ],
  "landmarks": [],
  "daily": null
}
```
- `content_version` is an int that rises by 1 on every content export of that language. It goes into
  analytics events and crash reports (FR-ANL-03).
- `regions`, `locations` and `landmarks` arrive with manifest 1.1 (T-0302, P2). In P1 they are absent,
  and the game treats the whole campaign as one location.
- Locations cover every slot from 1 to `slots` with no gaps and no overlaps (FR-PROG-03). Each holds about
  20–50 levels.
- `daily` *(P3)* points to the daily packs and the calendar file `daily/calendar.json` (day key → daily
  level id).
- The game checks pack hashes in debug builds and CI only. A mismatch is a build error, never a runtime
  decision.

## Slot policy

- A slot is **released** when a build containing it reaches a Play open-testing or production track, or
  the App Store. Internal, closed-testing and TestFlight builds do not release slots: their testers keep
  progress by slot number only and may meet changed levels (T-0010 F1, Chris 2026-10-02).
- The **lock file** `pipeline/locks/<lang>.lock.json` maps each released slot to a hash of its
  `letters`, `words` (with coordinates) and `grid`. The export command updates it when a release is cut
  (T-0302).
- Hard validation fails if a released slot's locked fields differ from the lock file (FR-CONT-03).
- **Allowed for a released slot:**
  - a changed `bonus` list, after a dictionary repair (FR-CONT-04);
  - changed `difficulty`, `seed` and `pipeline` metadata.
- **Not allowed:** removing, renumbering or reordering released slots. New content only appends slots.
- A released level found to be broken is fixed in place only in its bonus list. Anything else needs an
  override with Chris's explicit approval in the `content` PR.
- Saves stay valid across bonus-list changes: progress refers to slots and found level words, and counted
  bonus words stay counted (`GAME_DESIGN.md#bonus-chest`).

## Curve

The difficulty curve exists only in the pipeline. The game plays slot after slot (design pass 03 §6).

- **P1:** levels are ordered by letter count only.
- **Score** *(P2)*: features × weights from `config/scoring.yaml`. The features are letter count, word
  count and lengths, word frequency, anagram count, grid topology and intersections.
- **Target curve** (`config/curve.yaml`, P2):
  - a rising base trend per region;
  - a saw-tooth wave (period about 5);
  - spikes on landmark slots;
  - an easier breather slot right after each landmark.
- **Onboarding:** slots 1–15 are hand-made and outside the curve (`GAME_DESIGN.md#onboarding`).
- **Landmarks** *(P3)*: hand-made and up to 8 letters, at slots the sequence stage assigns and the
  manifest lists (FR-META-07).
- **Calibration** *(P3)*: per-slot telemetry (time, hints, abandons, FR-ANL-06) fits the
  `scoring.yaml` weights (T-0453). Unreleased slots are re-sequenced; released slots never move.

## Hard validation

A level that breaks any rule is rejected. Design pass 09 §4, `pipeline.validate`, `risk: high`.

1. Every level word and bonus word can be formed from `letters` (each tile used at most once).
2. Every level word is `level_ok`; every bonus word is `bonus_ok` or `level_ok`; no word is `banned`.
3. **Bonus completeness:** `bonus` = all `level_ok`/`bonus_ok` words of length ≥ 3 formable from `letters`,
   minus `words`.
4. The grid:
   - is connected;
   - holds each level word exactly once;
   - is at most 10 × 10;
   - fits `Layout.CELL_MIN` on the COMPACT layout with `Layout.GRID_MIN_RATIO`
     (`DESIGN.md#level-screen-geometry`) from P2.
5. No accidental strings: side-by-side letters form only intended words.
6. Letter count and word count are in range for the slot; from P2, difficulty is within the target
   window.
7. The schema is valid; only characters of the language alphabet appear.
8. No duplicates across the campaign and the daily pool: no identical letter multiset, and no word set
   above the Jaccard threshold *(P2)*.
9. Released slots are unchanged per the lock file ([Slot policy](#slot-policy)).

Hand-made levels go through the same rules; a hand-made level that fails is fixed by hand, not
overridden.

## QA sampling

| Content | Played in the debug review mode by Chris |
|---|---|
| P1 levels (30–50) | 100 % (T-0140) |
| First ~100 campaign levels, all landmarks, onboarding | 100 % |
| Everything else | ~5 % random sample + every level the QA report flags |
| Daily pool | the QA report + ~5 % sample; all holiday-themed puzzles |

Flags become overrides or hand-made fixes, then a rebuild. The QA report goes into the `content` PR.

## Determinism

- Seed of a generated level = `hash(lang, pipeline_version, candidate_index)`. No other randomness;
  every random choice uses an RNG seeded from it.
- Output JSON uses UTF-8, sorted keys, no whitespace variance and fixed float formatting
  (one decimal for `difficulty`). It carries no timestamps, absolute paths or machine names.
- Inputs are pinned by checksum (sources), committed files (overrides, cache, handmade, configs) and the
  pipeline version.
- CI rebuilds the content from the committed inputs and fails if the output differs by one byte
  (T-0127). The heavy production build may run only on `content` PRs (T-0408).

## Daily pool *(P3)*

- Generated as a separate pool in the same level format. It has no duplicates against the campaign or
  itself (FR-CONT-08).
- `daily/calendar.json` maps each day key (decision 0003) to a level id. At least 90 days exist before
  daily launches. After launch a rolling buffer of at least 60 days ahead is kept (T-0422).
- Days past the calendar end are picked deterministically from the pool by day key (decision 0003).

## Dictionary repair loop *(P3)*

```
invalid_word_submitted (aggregated) ─► frequent strings ─► check against the source
   ├─ in the source but banned or filtered ─► review queue ─► override ─► new bonus lists
   └─ not in the source ─► candidate for addition (Chris decides) ─► override
level_complete / hint_used / time per slot ─► real difficulty ─► scoring.yaml calibration
```
A repair changes only bonus lists of released slots, so saves stay valid (T-0454).

## Sources and licences

Pending spike S3a (T-0030), decided by Chris in decision `NNNN-pl-word-sources` (Q11).
- **PL candidates:** the SJP.pl word-game list (several licences to choose from), PoliMorf and Morfeusz
  for morphology, and frequency from a corpus whose licence allows derived data.
- **Frequency:** `wordfreq` is CC BY-SA. S3a checks whether shipping derived results in the game is
  allowed.
- **EN and DE:** decided before their pipelines run (T-0461, T-0470).

Every source's licence and attribution go into the in-game licences screen (FR-SET-03) and
`pipeline/sources/README.md`.
