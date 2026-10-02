# 0005 — Content language order: PL → EN → DE

- Status: accepted (Chris, 2026-10-01)

## Decision
- Content (dictionary + levels) ships one language at a time: Polish first, then English, then German.
- The architecture, level schema and pipeline are language-agnostic from day one (`lang` everywhere,
  per-language pipeline config, per-language overrides).
- UI localization (strings) may run ahead of content: PL + EN UI from Phase 2.
- Each content language needs its own licensed source, morphology/frequency data, curation by a native
  speaker, and its own rules decision record (like 0004).

## German notes (for the future DE rules record)
- Umlauts `Ä Ö Ü` as separate tiles is the likely choice; `ß` needs a decision (own tile vs `SS`).
- Long compounds: cap word length per slot; level words should favour short, common words.
- Capitalised nouns are irrelevant (tiles are uppercase).

## Revisit if
- Soft-launch data argues for a different second market.
