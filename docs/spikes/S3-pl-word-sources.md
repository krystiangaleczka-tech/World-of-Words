# S3a — Polish word sources and licences

Date: 2026-10-04. Task: T-0030. This is an engineering/licence spike, not legal advice.

## Recommendation

Use three independent authorities:

1. **Validity:** SJP.PL game list, pinned archive (currently `sjp-20260901.zip`), choose **CC BY 4.0**.
2. **Morphology:** **Morfeusz 2, SGJP variant**, inflection data under **BSD 2-Clause**.
3. **Frequency:** **KWJP100** lower-cased orthographic + lemma frequency lists, **CC BY 4.0**.
   Use ARF as the primary familiarity signal and IPM as a secondary diagnostic/tie-breaker.

Do not use `wordfreq` as the default production frequency source. Its code is Apache-2.0 but the
bundled data are CC BY-SA 4.0 and its own README says a CSV conversion is not compliant because
attribution/licence metadata would be lost. The project is also frozen, with bundled data ending
around 2021. KWJP100 provides the Polish metrics we need under the simpler CC BY 4.0 licence.

## Source comparison

| Purpose | Candidate | Licence / commercial fit | Result |
|---|---|---|---|
| validity | SJP.PL game list | GPL-2.0 **or CC BY 4.0**; select CC BY 4.0 | **SELECT** |
| validity/morphology | SJP.PL forms list | GPL-2.0, LGPL-2.1, CC BY 4.0 or Apache-2.0 | optional lemma fallback only; not a second validity authority |
| morphology | Morfeusz 2 SGJP | BSD 2-Clause; no separate commercial licence needed for the selected SGJP data | **SELECT** |
| morphology | PoliMorf | not selected; promotion would require its own provenance/licence review | diagnostic only |
| frequency | KWJP100 | CC BY 4.0 for repository resources | **SELECT** |
| frequency | wordfreq | code Apache-2.0; data CC BY-SA 4.0 + source-specific attribution | reject as default |

The Morfeusz documentation directly supports the SGJP choice and licence. It does **not** serve here
as evidence for PoliMorf's composition; this spike therefore does not infer PoliMorf provenance from
that page. Since validity is already owned by SJP.PL, SGJP is the cleaner dedicated annotation
authority. PoliMorf remains diagnostic only unless separately reviewed.

## Frequency fields

Use:
- `kwjp100-slowa-orth_lc-all.csv.gz` for exact lower-cased text forms;
- `kwjp100-slowa-lemma-all.csv.gz` for lemma-level support.

KWJP describes `F`, `IPM`, `ARF` and `1-DP`. ARF downweights words concentrated in only a few
texts, making it a better first ranking signal for “known to a normal player” than raw count alone.
KWJP includes only units seen at least five times; absence therefore means **unknown frequency**, not
invalidity.

## 3–7-letter scale check

The current SJP game archive advertised upstream is `sjp-20260901.zip`. A current public SJP/Literaki
mirror synchronized to that 2026-09-01 dataset reports:

| Length | SJP game-list forms |
|---:|---:|
| 3 | 1,626 |
| 4 | 8,252 |
| 5 | 28,701 |
| 6 | 65,331 |
| 7 | 130,188 |
| **3–7 total** | **234,098** |

**These 234,098 entries are inflected game-list forms, not the pool of words suitable for level
crosswords.** Under decision 0004, level words are lemmas plus only very frequent inflections; the
remaining admissible forms are bonus candidates. The mirror count is also not yet filtered for the
32-letter alphabet, Q/V/X exclusions or abbreviation/proper-name policy.

For scale only, an independent KWJP100 lemma estimate was computed with the 32-letter Polish alphabet,
lower-case forms and exclusion of particles, prepositions, abbreviations and similar non-level
categories. It was **not intersected with SJP.PL**, so it is not an authoritative gameplay count:

| KWJP100 lemmas, 3–7 letters | Total | 3 | 4 | 5 | 6 | 7 |
|---|---:|---:|---:|---:|---:|---:|
| all observed (≥ 5 occurrences) | 23,097 | — | — | — | — | — |
| IPM ≥ 1 | 9,554 | 325 | 944 | 1,978 | 2,833 | 3,474 |
| IPM ≥ 10 | 3,252 | 131 | 391 | 749 | 948 | 1,033 |
| IPM ≥ 100 | 663 | 42 | 109 | 177 | 187 | 148 |

For comparison, lower-cased orthographic **forms** (`orth_lc`) of length 3–7 with IPM ≥ 10 number
5,805: 264 / 679 / 1,359 / 1,766 / 1,737 by length. This suggests that short level content will need
carefully selected frequent inflections as decision 0004 already allows; T-0123/T-0124 must set the
actual `level_ok` thresholds.

The SJP figure is a **capacity sanity check, not a contractual fixture**. T-0121 must download the
pinned upstream archive itself, record SHA-256 and compute/assert both:
1. admissible 3–7-letter form counts; and
2. a lemma/level-candidate count after the agreed normalization and morphology rules.

The source archive is authoritative; a mirror count is not.

## Authority rules for the pipeline

- SJP.PL membership is the only external validity authority; Chris overrides may further ban/allow.
- Decision 0004 still filters alphabet, proper nouns/abbreviations, offensive content and tiers.
- Morfeusz adds lemma/POS/inflection metadata only.
- **An SJP-valid word with no usable Morfeusz lemma is at most `bonus_ok`; it cannot be
  `level_ok` until a pinned, reviewed lemma source resolves it.** Missing morphology does not make
  the word invalid.
- The SJP.PL forms list may later be pinned as a lemma fallback under its compatible licence, but it
  must not become a second validity authority.
- KWJP adds optional frequency metadata only.
- Neither Morfeusz nor KWJP may introduce a word absent from the validity source.

## Version pinning

Every ingest release records source-specific immutable identifiers:
- **SJP.PL:** exact archive URL/filename/version and archive SHA-256.
- **KWJP100:** exact repository commit plus SHA-256 for each selected compressed file. The research
  snapshot used here observed repository commit `26d82bd`; implementation must persist the full
  commit SHA and full file hashes rather than rely on this short reference.
- **Morfeusz/SGJP:** Morfeusz program version and the SGJP dictionary release/date used for annotation.

Upstream refreshes are explicit reviewed input-version changes: compare counts and tier/content deltas
before merging.

## Attribution / notices

Settings > Licences and repository notices for generated content should preserve:
- SJP.PL attribution + link + **CC BY 4.0** notice;
- Morfeusz 2 / IPI PAN and SGJP inflection-data copyright + **BSD 2-Clause** notice/disclaimer;
- KWJP100 / IPI PAN attribution + link + **CC BY 4.0** notice.

For CC BY sources the notice must also state that the material was modified, for example:
**“Words selected and processed based on SJP.PL / KWJP100 data licensed under CC BY 4.0.”**

If derived KWJP/SJP data are committed while the repository is public, the implementation PR must add
or update a repository NOTICE carrying the required attribution and modification statement. Keep
source-version metadata in generated artifacts or their build manifest so a shipped content version
can be traced to exact upstream inputs.

## Sources checked 2026-10-04

- SJP.PL game list: https://sjp.pl/sl/growy/
- SJP.PL forms list: https://sjp.pl/sl/odmiany/
- Morfeusz 2 licence: https://morfeusz.sgjp.pl/doc/license/
- Morfeusz 2 SGJP information: https://morfeusz.sgjp.pl/doc/about/
- KWJP frequency-list documentation: https://kwjp.pl/lists/doc/about/
- KWJP100 public data repository: https://github.com/ipipan/kwjp100-varia
- wordfreq README/licensing: https://github.com/rspeer/wordfreq/blob/master/README.md
- Count sanity-check mirror: https://poocoo.pl/slownik-literaki

## Chris decision

Recommended choice: **SJP.PL CC BY 4.0 + Morfeusz 2/SGJP BSD-2 + KWJP100 CC BY 4.0**.
Decision 0008 remains proposed until Chris explicitly accepts it.
