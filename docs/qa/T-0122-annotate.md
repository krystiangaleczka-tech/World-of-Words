# T-0122 — annotation preparation, pending dependency approval

Status: blocked by AGENTS S7. Prepared by Codex on 2026-10-09.
No real morphology run, completed-task claim or cheap-executor evidence is asserted.

## Sources inspected read-only

Morfeusz PyPI metadata offers `morfeusz2==1.99.15`. The Linux wheel SHA-256 is
`089a83ab03a137a57e23d9d42028d80b8858d1a4de78f1db86a18ba504400a98`.
The archive contains the API wrapper and native libraries; static inspection of the embedded
dictionary string yields `sgjp-2026.06.01` and the SGJP BSD copyright/disclaimer.
The wheel has not been installed and native code has not been executed.
The loaded engine/dictionary identity still requires verification after approval.

KWJP100 repository: `https://github.com/ipipan/kwjp100-varia`.
Pinned commit: `26d82bd8b906dfed1cfcf8f903b1650b56daeabf`.

| File | Bytes | SHA-256 | Parsed records |
|---|---:|---|---:|
| `kwjp100-slowa-orth_lc-all.csv.gz` | 5870924 | `20f71004b99ba9ebb158e68360aa88c627aa2e0f4ce43e18979187b0a2fa3949` | 360472 |
| `kwjp100-slowa-lemma-all.csv.gz` | 3133438 | `5206e80669a054ad4d3c9d39b7643d13e75435afa3612a15d2847f39f42bb5fc` | 184917 |

Both downloaded files were parsed by the new strict parser; ARF/IPM values are finite and
nonnegative, and exact keys are unique. The first file keys forms; the second keys (lemma, POS).
No raw or derived corpus is committed. NOTICE records attribution and modification notices.

## Prepared implementation

- Strict, checksum-verified frequency cache/parser and nullable exact joins.
- An injected analyzer protocol and pure interpretation mapping. Whole-form SGJP interpretations
  preserve raw homonyms, tags, names/labels and inflection; partial DAG segments and `ign` are excluded.
- Annotation records exactly match the normalized source forms. Corpus-only words cannot enter
  gameplay validity; no tier or commonness decision is made.
- A stage handler supports canonical artifact repeat/resume and identity checks with offline fakes.

Four offline behavior tests pass, with fixed synthetic gzip inputs and injected byte fetchers/analyzer.
No tests perform network I/O or execute Morfeusz. Pure adapters do not require an additional package.

Prepared adapter tree: pinned Godot 4.7.2 `make check` passed (187 GUT, 148 pipeline,
81 tools tests). This validates the preparation, not the pending native backend or full-source stage.

## Remaining before completion

Approve optional `annotate = [morfeusz2==1.99.15]`; then update the dependency/lock, implement native
backend binding and register the CLI stage. Verify actual loaded engine/SGJP identity and BSD notice,
run all normalized SJP forms through the pinned sources, measure actual coverage and repeat for
byte-identical artifacts. Run final full checks and independent review before merging.
