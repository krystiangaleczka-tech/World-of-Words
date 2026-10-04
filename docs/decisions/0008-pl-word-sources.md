# 0008 — Polish word, morphology and frequency sources

- Status: proposed — awaiting Chris
- Date proposed: 2026-10-04
- Context: T-0030 / Q11; decision 0004 already fixes Polish language rules.

## Decision

For Polish content pipeline inputs:

1. **Word validity:** SJP.PL game list under the **CC BY 4.0** option. Pin the exact archive URL/version
   and SHA-256 for every ingest release.
2. **Morphology:** Morfeusz 2 **SGJP variant** under **BSD 2-Clause** for lemma, POS and inflection
   metadata. PoliMorf may be used for diagnostics only; promoting it requires a separate provenance
   and licence review.
3. **Frequency:** IPI PAN **KWJP100** frequency lists under **CC BY 4.0**:
   `kwjp100-slowa-orth_lc-all.csv.gz` plus `kwjp100-slowa-lemma-all.csv.gz`.
   Store ARF and IPM; use ARF as the primary commonness signal.
4. **wordfreq is not a production dependency**. Its CC BY-SA data and attribution/redistribution
   constraints add avoidable share-alike complexity compared with KWJP100.
5. Authority is one-way: SJP validity → Morfeusz annotation → KWJP optional frequency.
   Missing frequency never makes a valid word invalid and annotation/frequency sources cannot
   introduce new valid words. **If an SJP-valid word has no usable lemma from the pinned morphology
   source, it is at most `bonus_ok`; it cannot be `level_ok` until reviewed lemma evidence exists.**
6. Attribution/licence notices for all selected sources ship in Settings > Licences. For CC BY 4.0
   inputs the notice must identify the source, link/licence and indicate modification, e.g. “words
   selected and processed based on …”. Morfeusz/SGJP keeps its BSD copyright notice/disclaimer.
7. Source versions remain traceable from content build metadata: SJP uses archive URL/version +
   SHA-256; KWJP100 uses repository commit + SHA-256 of each selected data file; Morfeusz/SGJP uses
   program version + SGJP dictionary release/date.

## Why

- SJP.PL publishes the game list directly for word-game admissibility and offers CC BY 4.0.
- Morfeusz SGJP provides a separately licensed, curated morphology source without allowing morphology
  coverage to redefine gameplay validity.
- KWJP100 is a balanced Polish corpus with form/lemma lists and ARF/IPM/dispersion metrics under
  CC BY 4.0, matching the pipeline's need without wordfreq's share-alike burden.
- Separate authority prevents corpus frequency or morphology coverage from silently redefining
  gameplay validity.

## Consequences

- The SJP game-list figure of 234,098 entries at 3–7 letters is an **inflected-form capacity check**,
  not the number of level-ready words.
- T-0121 owns deterministic SJP download, checksum, normalization and reporting of both admissible
  form counts and lemma/level-candidate counts.
- T-0122 annotates with Morfeusz SGJP and KWJP100; frequency is nullable; no-lemma entries remain
  `bonus_ok` at most.
- T-0122 records the full KWJP repository commit and full file SHA-256 values, and records Morfeusz
  version + SGJP dictionary date.
- If an implementation PR commits derived SJP/KWJP data to the public repository, it adds/updates a
  repository NOTICE with attribution and the CC BY modification statement.
- Source upgrades are reviewed data changes, not floating downloads.
- Decision 0004 still owns alphabet, minimum length, proper-name/abbreviation and offensive-word rules.

## Attribution sources

- https://sjp.pl/sl/growy/
- https://morfeusz.sgjp.pl/doc/license/
- https://kwjp.pl/lists/doc/about/
- https://github.com/ipipan/kwjp100-varia

## Revisit if

- an upstream licence changes;
- SGJP coverage is materially insufficient for SJP-valid 3–7-letter forms;
- KWJP frequency coverage is too low to separate common level words from obscure ones;
- legal review requires a different redistribution model.
