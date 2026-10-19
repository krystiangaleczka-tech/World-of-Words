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
