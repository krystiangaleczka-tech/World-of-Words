# T-0121 — pinned Polish source ingest evidence

Executed by Codex on 2026-10-08. No cheap-executor gate evidence is claimed.

## Source and reproducibility

Selected source: SJP.PL word-game list, snapshot `20260901`, CC BY 4.0
([source](https://sjp.pl/sl/growy/), [licence](https://creativecommons.org/licenses/by/4.0/)).
The upstream ZIP README confirms this licence option. The committed pin records:

- URL: `https://sjp.pl/sl/growy/sjp-20260901.zip`
- Archive bytes: `8515982`
- SHA-256: `43796ccf34a8ba9b6e965588b842721056b5a89cad4c8c38e057f838d4eaa6a5`
- UTF-8 member `slowa.txt`: `45650247` bytes, `3245600` nonempty entries.

Commands run against the full source, not synthetic fixtures:

```sh
uv run python -m wordgame_pipeline.ingest --root pipeline
uv run wg build --lang pl --to normalize
uv run wg build --lang pl --to normalize
```

The second full build reused the verified archive. Both artifacts were byte-identical:

| Artifact | SHA-256 |
|---|---|
| `01-ingest/artifact.json` | `012bb512be3baf2cccaac20bc1be77052335d337434f79587e2fe76645bdce27` |
| `02-normalize/artifact.json` | `73c777bf30536950e87e9f44a580237142ed200208c05995648fc89185bab514` |

Raw archive and derived word artifacts live only in ignored `pipeline/build/pl/`.
Repository NOTICE records attribution and modifications; no corpus is committed.

## Normalization counts

NFC, Polish upper/lower alphabet validation, uppercase, length 3..8, sorting/deduplication:

| Length | Unique normalized forms |
|---|---:|
| 3 | 1615 |
| 4 | 8222 |
| 5 | 28648 |
| 6 | 65258 |
| 7 | 130087 |
| 3–7 subtotal | 233830 |
| 8 | 216292 |
| 3–8 total | 450122 |

Rejections: alphabet `787`, over length `2794557`, under length `134`.
Accepted forms plus rejections account for all `3245600` source entries.
The earlier mirror's `234098` 3–7-letter estimate is not an assertion or a level-ready pool;
this report uses the downloaded pinned archive and the project's alphabet filter.

## Annotation boundary

The flat SJP list contains no lemma/POS/proper-name/abbreviation evidence.
Known metadata flags are rejected by the normalization API, but unknown source flags are
never invented from capitalization. These outputs remain pending T-0122 annotation and
T-0123 tiers; they are not approved level words or a shipped bonus dictionary.

Current **verified** lemma count: `0`. Current **verified** level-candidate count: `0`.
These measure evidence available in this stage, not the actual lemma pool size. The latter
cannot be calculated until the selected morphology source is pinned and joined in T-0122.
This preserves decision 0008: a form without usable lemma evidence cannot become `level_ok`.
No commonness, sensitivity or tier classification is performed here.

## Checks

Pinned Godot 4.7.2 `make check`: OK — 187 GUT, 144 pipeline, 81 tools tests.
Required offline cases cover verified cache reuse/failure, encoding/member/count validation,
Unicode and case-expansion boundaries, explicit metadata flags, deterministic normalization,
real stage integration through synthetic pinned ZIPs, CLI entrypoints and resume.
Tests use fixed ZIP metadata and injected fetchers or existing fixture cache, never network I/O.
