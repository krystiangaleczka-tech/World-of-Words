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

## Regional targets (T-0357)

`wordgame_pipeline.sequence.CurveConfig` accepts explicit version1 JSON-compatible
YAML only: first,last,base,trend,period,amplitude,landmark_spike,breather_drop and
landmarks. Integer region bounds/period are manifest-safe; unit parameters are
finite0..1, spike/drop positive. Landmarks are unique ordered slots above15 inside
the region, with a following in-region nonlandmark slot. No production curve file
or default numbers are supplied. Constructors/loaders validate; to_dict is fresh.

`target_for_slot` computes one in-region slot without allocating a region or
assigning content. Slots1–15 always return onboarding with no target/baseline.
For other slots offset=slot-first and saw=(offset%period)/(period-1); the ordinary
baseline is clamped base+trend*offset+amplitude*saw. Landmark adds a bounded spike.
Its next slot takes the smaller of baseline-drop and previous landmark target-drop,
bounded at0. nextafter toward0 preserves strictly easier recovery when a tiny
positive drop would round away. Output explains ordinary baseline and final target.

This is a region-local calculation. Caller owns reviewed parameters, actual region/
location mapping, landmark authorship, released-slot protection and assignment.
Classification, calibration, whole-campaign scheduling and stage activation remain
open; P1 exports, shipped slots and production configuration are unchanged.

## Protected slot ownership (T-0358)

`sequence.slots.SlotPlan` holds immutable Region/Location partitions and authored/
released Reservation tuples. Regions and locations cover1..total in canonical
order, without gaps/overlap or duplicate IDs. Locations stay wholly in their
referenced region. IDs reject Unicode control/format characters. Counts remain
manifest-safe. Construction validates all nested types and ownership invariants.

Authored reservations cover existing slots1–15 and every regional landmark;
additional authored regular slots are allowed. Released IDs form prefix1..R and
must agree with authored IDs on overlap. No candidate may reserve distinct slots
across either collection. This reserves identity, not released geometry hashes;
existing export lock validation remains authoritative.

`plan.requirement(slot)` computes one CurveTarget and returns exact region/location,
fixed ID and authored/released flags. Huge explicit regions do not allocate their
slots. No candidate selection/content write is performed. T-0359 will allocate
against this plan; T-0360 will compose explicit preview/report. Actual parameters,
source/seed/tier proof, released hashes and publishing remain separate gates.

## Deterministic protected allocation (T-0359)

`sequence.allocate.allocate(plan,candidates,policy,language)` validates every
immutable ScoredCandidate and normalized/formable record before choosing content.
Comparable0..1 scores and authoritative seeds are caller-owned; T-0360 will bind
fresh scores to common explicit configuration. Authored/landmark flags must match
fixed requirements. Every fixed candidate must exist and fixed pairs must pass
current duplicate policy. Released identity is never moved to improve difficulty.

All future fixed IDs are reserved before greedy work. Free slots ascend; candidates
rank by absolute target distance then ID. Unreserved authored candidates cannot
be moved automatically. Each trial is checked against ALL fixed future and chosen
past records, including canonical every-word100-slot spacing. Rejections preserve
exact duplicate evidence. Output assignments explain mode/deviation/rejections;
unused IDs are sorted. Inputs and previously returned frozen records stay intact.

AllocationError reports fixed_missing, fixed_incompatible, pool_too_small,
fixed_conflict or greedy_blocked with slot/conflict/rejection tuples. No partial
assignment is returned on failure. Greedy failure is not proof that no global
solution exists; no backtracking or automatic constraint relaxation is attempted.
This remains preview allocation, not publication or replacement export lock proof.
