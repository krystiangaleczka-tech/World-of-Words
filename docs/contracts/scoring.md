# Offline difficulty analysis

## Raw features (T-0354)

`wordgame_pipeline.scoring.extract_features(level, frequencies, config)` returns
fresh finite floats in FEATURE_NAMES order. Inputs use exported level letters,
word placements and exact declared grid. Existing geometry validates normalized,
connected portrait crosswords; words must be normalized and formable from tiles.
This contract does not replace tier/bonus/source/slot validation.

| Feature | Definition |
|---|---|
| letter_count / distinct_letters | Wheel tile count / distinct configured characters; diacritics stay distinct |
| word_count | Selected crossword count; bonus words excluded |
| mean_word_length / max_word_length | Selected word lengths in Unicode code points after normalization validation |
| mean_log_arf | Mean log1p of known exact-form ARF, or0 when no form has evidence |
| frequency_coverage | Known ARF forms / selected forms; genuine ARF0 is known |
| anagram_pairs | Unordered selected pairs with identical letter multisets |
| grid_area / grid_fill | Bounding rectangle area / occupied-cell fraction |
| crossings / crossing_fraction | Sum of word lengths minus occupied cells / occupied-cell fraction |

Frequency mapping must contain exactly selected forms, with finite nonnegative
ARF or None. No lemma fallback, AI guess or bonus evidence. Stable selected-form
order and math.fsum make input permutations equivalent. Returned dictionaries do
not retain references to inputs. Invalid input raises ValueError before a result.
No default weights, filesystem/network/native analyzer or stage activation.

## Wave boundaries

T-0354 measures features; T-0355 supplies explicitly configured bounded scoring;
T-0356 audits duplicates/repetition. These pure offline contracts are split from
T-0298/T-0299 under Phase2 rolling-wave planning. T-0296 production classification
requires the private repository, API key/spend cap and human preflight; T-0297
classification suggestions, calibration, sequencing and production content remain
open. Existing P1 handlers/exports still write difficulty0.0. No published slots,
source words, config values, shipped content or save format change in this wave.

## Explicit bounded scoring (T-0355)

ScoringConfig.from_dict accepts only version1 JSON-compatible YAML with every raw
feature present exactly once. Each rule has finite nonnegative weight/minimum/
maximum, strict minimum<maximum and higher/lower difficulty direction. At least
one weight must be positive. Frozen rules/config validate direct constructors too.
`load_scoring(path)` reads only the explicitly supplied path; no defaults, production
weights, interpolation, network calls or config writes. Duplicate keys fail through
the existing strict parser. to_dict returns a fresh normalized configuration.

`score_features` requires exact finite nonnegative raw values. Clamp raw to each
rule range, normalize to[0,1], invert lower direction, and compute a weighted mean.
Weights are divided by their largest value before normalization to avoid overflow
from individually finite large weights. Immutable explanations contain raw,
normalized and weighted contributions in FEATURE_NAMES order. Stable fsum total
is bounded to[0,1] against floating rounding. SHA256 of canonical normalized config
bytes identifies provenance; input key order does not alter results.

Fixture weights prove mechanics only. Production configuration/calibration,
frequency coverage policy, stage integration and released-content scoring remain
open. This module neither mutates a level nor changes P1 difficulty0.0.

## Duplicate/repetition evidence (T-0356)

`wordgame_pipeline.dedupe.audit_duplicates(records, policy, config)` returns an
immutable tuple of DuplicateConflict(left_id,right_id,reasons,shared_words,jaccard).
Each explicit record has id,pool,slot,letters,words,seed_word: normalized formable
selected words, authoritative seed among them, unique identity and pool/position.
Caller owns prior tier/geometry/source validation. No seed is guessed from RNG or
word ordering. Bonus words are not analysis inputs. All records validate before
any pair result is constructed; no partial result or input mutation on failure.

Explicit immutable DuplicatePolicy requires threshold0..1 and seed_spacing>=100.
No production threshold defaults. Pairs are ordered by(pool,slot,id), independent
of input order. Reasons retain this order:

- letter_multiset: equal sorted tiles, preserving multiplicity and diacritics.
- word_jaccard: selected intersection/union strictly above configured threshold.
- word_spacing: any shared crossword word at campaign slot distance below100.
- seed_spacing: equal explicit seed words below configured campaign seed distance.

Exact minimum distance or threshold is allowed by that rule. Multiset/Jaccard
comparisons span campaign/daily. Campaign slots and daily positions do not share
a clock, so spacing compares campaign only; daily pacing is a future policy.
Shared words are sorted; multiple reasons for one pair remain visible.

This is pair evidence, not a greedy filter, sequence planner or replacement hard
validator. It never selects, deletes, reorders or exports levels. Production
threshold review, seed provenance wiring, classification, scoring calibration,
curve/sequence integration, production content and publishing remain open.
