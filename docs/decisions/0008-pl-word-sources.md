# 0008 — Polish word, morphology and frequency sources

- Status: proposed — awaiting Chris
- Date proposed: 2026-10-04
- Context: T-0030 / Q11; decision 0004 already fixes Polish language rules.

## Decision

For Polish content pipeline inputs:

1. **Word validity:** SJP.PL game list under the **CC BY 4.0** option. Pin the exact archive URL/version
   and SHA-256 for every ingest release.
2. **Morphology:** Morfeusz 2 **SGJP variant** under **BSD 2-Clause** for lemma, POS and inflection
   metadata. PoliMorf may be used for diagnostics, not as a second validity authority.
3. **Frequency:** IPI PAN **KWJP100** frequency lists under **CC BY 4.0**:
   `kwjp100-slowa-orth_lc-all.csv.gz` plus `kwjp100-slowa-lemma-all.csv.gz`.
   Store ARF and IPM; use ARF as the primary commonness signal.
4. **wordfreq is not a production dependency**. Its CC BY-SA data and attribution/redistribution
   constraints add avoidable share-alike complexity compared with KWJP100.
5. Authority is one-way: SJP validity → Morfeusz annotation → KWJP optional frequency.
   Missing morphology/frequency never makes a valid word invalid and those sources cannot introduce
   new valid words.
6. Attribution/licence notices for all selected sources ship in Settings > Licences; source versions
   remain traceable from content build metadata.

## Why

- SJP.PL publishes the game list directly for word-game admissibility and offers CC BY 4.0.
- Morfeusz explicitly uses the liberal BSD licence because morphological outputs can otherwise inherit
  restrictive dictionary terms; SGJP is the more precisely curated variant.
- KWJP100 is a balanced Polish corpus with form/lemma lists and ARF/IPM/dispersion metrics under
  CC BY 4.0, matching the pipeline's need without wordfreq's share-alike burden.
- Separate authority prevents corpus frequency or morphology coverage from silently redefining
  gameplay validity.

## Consequences

- T-0121 owns deterministic SJP download, checksum, normalization and count reporting.
- T-0122 annotates with Morfeusz SGJP and KWJP100; frequency is nullable.
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
