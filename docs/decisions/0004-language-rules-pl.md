# 0004 — Polish word rules

- Status: accepted (Chris, 2026-10-01: "jak uważasz" → design-pass recommendation adopted)
- Context: design pass `09-content-pipeline.md` §6. These rules shape the whole dictionary pipeline.

## Decision
1. Polish diacritics are separate letters/tiles: `Ą Ć Ę Ł Ń Ó Ś Ź Ż` are distinct from `A C E L N O S Z`.
2. Alphabet: the 32 Polish letters. Words containing `Q`, `V`, `X` are excluded.
3. Level words (in the crossword): base forms (lemmas) plus very frequent inflected forms, from tier `level_ok`.
4. Bonus words: every valid, non-banned form from the licensed source, including all inflected forms (tier `bonus_ok`).
5. Minimum word length: 3.
6. No proper nouns, no abbreviations, no acronyms.
7. Vulgar/offensive words are never level words and never accepted as bonus words; the player sees the
   same neutral feedback as for an invalid word (no punishment, no highlighting).

## Consequences
- Pipeline needs morphological data (lemma + inflection) for PL, not just a word list.
- Bonus lists per level can be long for Polish; packs stay small because they are per level.

## Revisit if
- Telemetry shows players confused by inflected forms being accepted, or invalid-word rate on common forms is high.
