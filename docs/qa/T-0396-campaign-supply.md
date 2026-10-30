# T-0396 — Polish campaign wheel capacity preflight

**Status:** evidence only, not a release authorization. Baseline: merged
`main` commit `e1da1ee51cbb167e1f34f81c471d0e662c044d63`.
Source: `pipeline/content-inputs/pl.json` (Git blob
`b879469e6985c55f402314ac7afb3106bf850349`). Existing level pack:
`game/content/pl/packs/c-0001-0065.json` (Git blob
`46319d1406e391fbc159526cb57fe946c9af1961`).

This inventory counts only *canonical sorted letter multisets* from
`level_ok` source words and already-shipped wheel signatures. It does
**not** establish that a source word was approved by a human, a crossword
was generated, or the score/bonus/geometry will pass validation.

| Current pinned evidence | Count |
|---|---:|
| Source `level_ok` words | 649 |
| Source `bonus_ok` words | 890 |
| Distinct source-backed wheel signatures | **486** |
| Existing shipped levels/signatures (P1) | **65** |
| Remaining distinct source wheel signatures | **421** |
| Strict theoretical campaign ceiling with no identical multisets | **486** |
| New unique source signatures needed for a 10,000-slot public release | **9,514** |
| New unique source signatures needed for the 30,000-slot long-term target | **29,514** |

The actual number of *publishable* crossword levels may be materially lower:
a word wheel must also yield a connected, valid crossword, sensible difficulty
and vocabulary, complete bonus sets, 100-slot selected-word spacing and quality
review. The current P1 `candidates.automatic` inventory of 189 is a **curated
subset**, not a replacement for the distinct tier-backed source count.

## Owner-approved 2026-10-29 production intent

- 200 levels: P2 review / testing milestone, not the public release.
- 500 levels: private/closed QA milestone, not the public release.
- **10,000 reviewed Polish levels**: prerequisite to first public rollout.
- **30,000 Polish levels**: subsequent expansion target.
- Exactly zero required paid LLM/API operations for word validity or
  classification. The licensed SJP source, locally pinned morphology/frequency
  evidence, and signed-off `overrides/pl.csv` are the validity source chain.

## Next necessary work

1. Expand the licensed, provenance-pinned lexical *input* well beyond the
   current compact P1 sample; inspect the full source and distinguish
   `level_ok` from mere technically valid bonus forms. No invented source.
2. Rebuild tier suggestions and a genuine human lexical review queue; do not
   automatically approve a new word merely because it appears in a dictionary.
3. Generate source-backed candidates and valid crossword geometries, then
   deduplicate signatures and word selections across 10,000 slots.
4. Benchmark deterministic generation/export, 100-slot spacing, app size,
   mobile load time, locked released slots and owner quality sampling.
5. Fail public release if the exact manifest and all QA conditions do not
   demonstrate 10,000 reviewed campaign slots.

## Reproduction

Run the no-network tests:

`uv run pytest pipeline/tests/candidates/test_campaign_capacity.py`

The task's `audit_campaign_capacity(index, existing_wheels, target_slots=10000)`
is a fast upper-bound checker, not an algorithm to create the missing levels.
