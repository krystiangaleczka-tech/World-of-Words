# 0002 — Content ships in packs; the game has no dictionary

- Status: accepted (planner, 2026-10-02, T-0004). Records design pass 03 §1, which PRODUCT.md v1
  already requires. Chris confirms or overrides it when he approves docs v1 (T-0011).
- Context: design pass `03-architektura-gry.md` §1, `09-content-pipeline.md` §1, §4, §5; FR-CORE-02,
  FR-CORE-03, FR-CONT-01 … 09; decisions 0004 (Polish word rules) and 0005 (language order).

## Decision
1. **No dictionary at runtime.** The game contains no word list and no normalization logic. An attempt
   is validated by a set lookup against the current level's level words and bonus list (FR-CORE-02).
   Letters are tiles addressed by index, never typed text (FR-CORE-03).
2. **Complete bonus lists.** Each level's bonus list holds every `level_ok` or `bonus_ok` word that can
   be formed from its letter multiset, minus its level words. The pipeline rejects a level whose list is
   incomplete. A valid word missing from a list is a pipeline bug; the game never falls back to a
   dictionary.
   - Banned words appear in neither list, so they resolve as INVALID (FR-CORE-05).
   - Words shorter than 3 letters appear in neither list (decision 0004 §5).
3. **One source of word rules.** Word validity comes only from the licensed source plus Chris's
   overrides file (FR-CONT-05). All word rules live in the Python pipeline; the game only reads its output.
4. **Packs and a manifest.**
   - Levels ship as JSON packs of about 100 levels per language under `game/content/<lang>/`.
   - A manifest carries the content version, pipeline version and pack hashes, and maps slot → location
     → region.
   - Each level carries its letters, grid words with coordinates, complete bonus list, difficulty, seed
     and pipeline version (FR-CONT-01, FR-CONT-02).
   - Exact fields are owned by `CONTENT.md#level-schema` and `CONTENT.md#manifest` (T-0008). The JSON
     Schemas live in `pipeline/schema/` (T-0040) and are checked by both the pipeline and CI.
5. **Generated, never hand-edited.** `game/content/` is pipeline output.
   - Hand-made levels (onboarding, landmarks) are written as letters + words in YAML input. The
     pipeline builds their grids, validates them and exports them like any other level.
6. **Released slots.** A released slot never changes its letters, grid or level words; CI checks this
   against a lock file (FR-CONT-03). Its bonus list may change when the dictionary is repaired, and saves
   stay valid (FR-CONT-04; save details in `ARCHITECTURE.md#save`).
7. **Shipped with the app.** In v1 packs are bundled in the build, so play works offline (NFR-06).
   Downloading packs without an app update is Later (FR-CONT-09); the content version and hashes keep
   that option open.
8. **Daily pool.** The daily pool is a separate pack in the same level format, plus a date → puzzle
   calendar (FR-CONT-08).

## Why
- One place for word rules: the generator and the game cannot disagree.
- The app ships only the words its levels need, not a whole dictionary.
- No Unicode normalization or morphology in GDScript, which cheap models get wrong easily.
- A dictionary fix is new data, not new code. The runtime stays small, and the bot test (FR-CONT-07)
  can prove every shipped level is completable.

## Costs
- Size: a few MB of JSON per thousand levels per language, which compresses well. Polish bonus lists
  are long because inflected forms count (decision 0004), but they are per level. The total must fit
  the NFR-05 app-size budget.
- In v1 any dictionary repair needs an app release.
- The pipeline needs morphological data to build complete bonus lists (decision 0004, consequences).

## Consequences
- T-0008 writes `CONTENT.md#level-schema`, `#manifest` and `#slot-policy`. T-0040 turns them into
  JSON Schemas. T-0041 loads packs in the Content autoload. T-0042 is the bot test.
- Bonus-list completeness is a blocking pipeline validation (design pass 09 §4).
- A task that adds a word list, dictionary lookup or text normalization to `game/` contradicts this
  decision; the executor stops under STOP rule S4.

## Revisit if
- S3a (T-0030) finds that the licence does not allow shipping word lists derived from the source.
- Pack size threatens the NFR-05 budget.
- Live content updates (FR-CONT-09) are planned.
