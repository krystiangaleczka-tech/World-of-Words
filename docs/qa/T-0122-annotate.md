# T-0122 — pinned Polish annotation

Implemented and verified by Codex on 2026-10-09. Chris approved the optional
`morfeusz2==1.99.15` dependency (AGENTS S7) by replying "Rób".

## Engine and source identity

The native engine reports version `1.99.15` and dictionary ID
`pl.sgjp.sgjp-2026.06.01`. The adapter checks both before fetching frequency
sources or writing artifacts. It loads SGJP with generation disabled and
case ignored. The pinned Linux wheel SHA-256 is
`089a83ab03a137a57e23d9d42028d80b8858d1a4de78f1db86a18ba504400a98`.
NOTICE includes the engine and SGJP BSD notices and KWJP attribution.

KWJP100 repository: `https://github.com/ipipan/kwjp100-varia`.
Pinned commit: `26d82bd8b906dfed1cfcf8f903b1650b56daeabf`.

| File | Bytes | SHA-256 | Parsed records |
|---|---:|---|---:|
| `kwjp100-slowa-orth_lc-all.csv.gz` | 5870924 | `20f71004b99ba9ebb158e68360aa88c627aa2e0f4ce43e18979187b0a2fa3949` | 360472 |
| `kwjp100-slowa-lemma-all.csv.gz` | 3133438 | `5206e80669a054ad4d3c9d39b7643d13e75435afa3612a15d2847f39f42bb5fc` | 184917 |

Verified cached gzip bytes are parsed strictly. ARF/IPM values must be finite
and nonnegative, with unique exact form or (lemma, POS) keys. Missing joins
remain null. Corpus-only forms never become valid words.

## Full-source verification

Input: T-0121's 450122 normalized SJP forms (snapshot 20260901, lengths 3–8).
With the existing ingest and normalize artifacts, execute from repository root:

```sh
uv run --all-packages --extra annotate wg build --lang pl --from annotate --to annotate
```

Two consecutive executions completed successfully and produced byte-identical
`pipeline/build/pl/03-annotate/artifact.json`:

- Size: 136320433 bytes.
- SHA-256: `880fc18ec5a81287028b7a7487c01d661b4c75c0f987efc0476e0e902727b47d`.
- Source forms: 450122; forms with usable lemma: 360250.
- Unique canonical lemmas: 67182; forms with exact form frequency: 109506.

All whole-form interpretations retain raw homonyms, full tags, names/labels,
canonical lemma, POS and inflection evidence. Partial DAG segments and `ign`
interpretations are excluded. Each input form has exactly one output record;
empty analyses and nullable frequency are explicit. Annotation assigns no
validity, eligibility or tier. The full default CLI build now stops preflight
at the unimplemented tiers stage.

## Automated verification

Five annotation behavior tests use authored gzip data and injected engines or
fetchers, without network access or the optional native package. They cover
strict parsing, nullable exact joins, ambiguity and whole-form identity, exact
source membership, repeat/resume, identity failures before downloads/writes,
and native loader/CLI registration. The existing contract test changes only
the first unimplemented stage expectation.

Final verification on 2026-10-09 after clean rebase onto main containing T-0118:
192 GUT tests, 149 pipeline tests and 81 tools tests pass; formatting/lint,
registries, task lint and scope pass. Full `make check` is green. Chris explicitly
approved the two-line ingest CLI expectation correction from annotate to tiers
and adding that test file to touch (S2/S5). The recorded full-source Linux runs
above are inherited evidence, not new native runs on macOS. A fresh independent
final review is required before merge. Raw corpora and artifacts remain ignored.
