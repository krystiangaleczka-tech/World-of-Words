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
attribution/licence metadata would be lost. KWJP100 provides the Polish metrics we need under the
simpler CC BY 4.0 licence.

## Source comparison

| Purpose | Candidate | Licence / commercial fit | Result |
|---|---|---|---|
| validity | SJP.PL game list | GPL-2.0 **or CC BY 4.0**; select CC BY 4.0 | **SELECT** |
| validity/morphology | SJP.PL forms list | GPL-2.0, LGPL-2.1, CC BY 4.0 or Apache-2.0 | reference/fallback, not second validity authority |
| morphology | Morfeusz 2 SGJP | BSD 2-Clause; upstream says no separate commercial licence is needed | **SELECT** |
| morphology | Morfeusz 2 PoliMorf | BSD 2-Clause; broader merge of SGJP + community Morfologik/sjp.pl data | optional diagnostic fallback |
| frequency | KWJP100 | CC BY 4.0 for repository resources | **SELECT** |
| frequency | wordfreq | code Apache-2.0; data CC BY-SA 4.0 + source-specific attribution | reject as default |

Morfeusz documents SGJP as individually prepared and more precise, while PoliMorf merges SGJP with
community data. Since validity is already owned by SJP.PL, SGJP is the cleaner annotation authority;
a missing/ambiguous morphological result must never make an SJP-valid word invalid.

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

| Length | Words |
|---:|---:|
| 3 | 1,626 |
| 4 | 8,252 |
| 5 | 28,701 |
| 6 | 65,331 |
| 7 | 130,188 |
| **3–7 total** | **234,098** |

This is a **capacity sanity check, not a contractual fixture**. T-0121 must download the pinned
upstream archive itself, record SHA-256 and compute/assert its own per-length counts. The source
archive is authoritative; a mirror count is not.

## Authority rules for the pipeline

- SJP.PL membership is the only external validity authority; Chris overrides may further ban/allow.
- Decision 0004 still filters alphabet, proper nouns/abbreviations, offensive content and tiers.
- Morfeusz adds lemma/POS/inflection metadata only.
- KWJP adds optional frequency metadata only.
- Neither Morfeusz nor KWJP may introduce a word absent from the validity source.
- Upstream refreshes are explicit input-version changes: pin URL/version and SHA-256, compare counts,
  review tier/content deltas, then merge.

## Attribution / notices

Settings > Licences and repository notices for generated content should preserve:
- SJP.PL attribution + link + **CC BY 4.0** notice;
- Morfeusz 2 / IPI PAN and SGJP inflection-data copyright + **BSD 2-Clause** notice/disclaimer;
- KWJP100 / IPI PAN attribution + link + **CC BY 4.0** notice.

Keep source-version metadata in generated artifacts or their build manifest so a shipped content
version can be traced to exact upstream inputs.

## Sources checked 2026-10-04

- SJP.PL game list: https://sjp.pl/sl/growy/
- SJP.PL forms list: https://sjp.pl/sl/odmiany/
- Morfeusz 2 licence: https://morfeusz.sgjp.pl/doc/license/
- Morfeusz 2 variants: https://morfeusz.sgjp.pl/doc/about/
- KWJP frequency-list documentation: https://kwjp.pl/lists/doc/about/
- KWJP100 public data repository: https://github.com/ipipan/kwjp100-varia
- wordfreq README/licensing: https://github.com/rspeer/wordfreq/blob/master/README.md
- Count sanity-check mirror: https://poocoo.pl/slownik-literaki

## Chris decision

Recommended choice: **SJP.PL CC BY 4.0 + Morfeusz 2/SGJP BSD-2 + KWJP100 CC BY 4.0**.
Decision 0008 remains proposed until Chris explicitly accepts it.
