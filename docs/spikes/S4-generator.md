# S4 generator spike — T-0032

## Result

The prototype is feasible. The command below deterministically generates 50 text-rendered Polish
word-connect crossword candidates from a deliberately small hand-curated spike list:

    uv run python pipeline/spikes/s4/generator.py --count 50 --seed 32032

The bundled input has 10 wheel pools and 69 unique words (77 entries including reuse). It is test data,
not a production dictionary and does not replace the licensed-source decision.

## Prototype behavior

- Every level starts from one wheel word and selects 3–5 additional words buildable from the same
  multiset of letters.
- The longest selected word is placed first. Remaining words are placed by matching crossings.
- Candidate placements reject conflicting letters, touching parallel words, occupied cells directly
  before or after a word, and any trial that would exceed 10x10.
- Placement uses bounded backtracking and deterministic pseudo-random tie breaking.
- Duplicate wheel + selected-word combinations are rejected.

With the committed seed, all 50 requested levels are produced. They contain 4–6 words (mean 5.14).
Observed grid width is 5–9, height 3–9, so every sample stays within the future 10x10 phone bound.
Mean bounding-box area is 35.00 cells.

Representative output:

    LEVEL 01 wheel=KARTA
    ....R
    KARTA
    A.A.K
    T.T..
    .TARA

    LEVEL 02 wheel=MIASTO
    S.O...
    A.S...
    MIASTO
    ....A.
    ..TOM.

    LEVEL 03 wheel=DROGA
    .G..D..
    DROGA..
    .A..ROG

## Quality notes

The layouts are technically connected and compact enough for the spike, but visual quality varies.
Some shapes are long or lopsided and the score currently optimizes crossings then area only. The sample
also reuses several short words across wheel pools, so it does not measure campaign diversity.

Before Phase 1 production use, T-0125 should keep the backtracking base but add explicit layout scoring
for portrait balance, stronger accidental-adjacency validation, multiple seeds with best-layout
selection, and property tests for connectivity/determinism. Candidate selection must come from the
licensed pipeline stages rather than this hand-curated file.

No production schema, validator, export format, released content, or game runtime code is changed.
