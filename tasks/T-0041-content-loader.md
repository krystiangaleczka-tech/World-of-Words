---
id: T-0041
title: Load the content manifest and packs into immutable LevelData
epic: E03
type: contract
area: services.content
risk: high
executor: human       # done in a Claude Code session Chris started
think: high
ui: none
status: review
depends_on: [T-0040, T-0034]
touch:
  - game/services/content.gd
  - game/services/content/**
  - game/core/board/level_data.gd*
  - game/tests/fixtures/content/**
  - game/tests/integration/test_content.gd*
  - game/tests/unit/board/test_level_data.gd*
  - pipeline/tests/test_content_fixtures.py
  - tasks/T-0041-content-loader.md
revision: 1
---

## Goal
The game can read `game/content/<lang>/manifest.json`, load campaign packs on demand and hand out an
immutable `LevelData` for a slot. A fixture pack with three levels gives later tests real content.

## Context
- ARCHITECTURE.md#content: "`Content` reads `game/content/<lang>/manifest.json` and loads packs on
  demand." "A level becomes an immutable `LevelData` (`game/core/board/level_data.gd`, tiles as indices)."
  "A pack that fails to load or validate ... never causes a crash loop."
- CONTENT.md#level-schema: "The game reads only `id`, `slot`, `letters`, `words`, `bonus` and `grid`."
- CONTENT.md#manifest: "The game checks pack hashes in debug builds and CI only."
- Roadmap row T-0041; FR-CONT-01, FR-CONT-02, FR-CORE-03, NFR-03.

## Current state
- `game/services/content.gd`: `extends ServiceStub`, no domain API (T-0034).
- `pipeline/schema/{level,pack,manifest}.schema.json` v1 (T-0040).
- `game/content/` holds only `.gitkeep`; no real packs until T-0127.

## Specification
### Interface
- `LevelData` (`class_name`, `RefCounted`, pure, no I/O):
  `static from_dict(Dictionary) -> LevelData` (null when invalid), `get_id() -> String`,
  `get_slot() -> int` (0 for daily), `tile_count() -> int`, `tile_letter(int) -> String`,
  `get_letters() -> PackedStringArray`, `word_count() -> int`, `word(int) -> String`,
  `word_cells(int) -> Array[Vector2i]`, `bonus_words() -> PackedStringArray`,
  `grid_size() -> Vector2i`, `spell(PackedInt32Array) -> String`.
- `Content`: `load_manifest(language: String, root: String = "res://content") -> Error`,
  `is_loaded() -> bool`, `get_language() -> String`, `content_version() -> int`,
  `slot_count() -> int`, `level_for_slot(slot: int) -> LevelData`,
  `signal pack_failed(file: String, error: Error)`.

### Behavior
1. `from_dict` reads only the six game fields and rejects: missing/mistyped fields, non-integral
   numbers, letters outside 3–8 single characters, empty `words`, `dir` other than `h`/`v`, grid outside
   1–10, a word leaving the grid, two words disagreeing on a shared cell. Getters return copies.
2. `spell(tiles)` returns the word formed by tile indices, or `""` if an index is out of range or used
   twice (FR-CORE-03: repeated letters are different tiles).
3. `load_manifest` validates `schema_version` 1, `lang` equal to the requested language, positive
   `content_version` and `slots`, and campaign packs whose `first..last` ranges cover `1..slots` in
   order with no gap. Any failure returns an Error and keeps the previously loaded manifest.
4. `level_for_slot` loads the pack holding the slot (one pack cached), checks its SHA-256 against the
   manifest in debug builds, checks the pack header and that its levels are exactly `first..last` in
   order, and returns the `LevelData`. Any failure emits `pack_failed` once per call and returns null.
5. Fixture `game/tests/fixtures/content/pl/` (manifest + `packs/c-0001-0003.json`, 3 handmade levels,
   one with a repeated letter) validates against the T-0040 schemas in pipeline CI.

### Edge cases
Slot 0, negative or above `slots` → null without `pack_failed`. Unknown language folder → ERR_FILE_NOT_FOUND.
Pack paths must match `packs/<name>.json`; anything else is rejected at manifest load.

## Out of scope
Daily levels, error UI and the analytics event for a failed pack (no event is registered yet),
export filters for JSON packs (T-0137), content validator (T-0126), Nav/boot wiring (T-0043).

## Tests
- `game/tests/unit/board/test_level_data.gd`: valid level getters, cells for h/v, repeated letters by
  index, spell rejects reuse/out of range, each rejection case in Behavior 1, getters return copies.
- `game/tests/integration/test_content.gd`: fixture manifest loads; slots 1–3 resolve with ids;
  out-of-range slots; wrong language, gap in pack ranges and bad path fail and keep prior state;
  hash mismatch and slot mismatch emit `pack_failed`.
- `pipeline/tests/test_content_fixtures.py`: fixture manifest and pack pass the schemas; manifest hash
  equals the pack bytes.

## Acceptance
`make check` green; fixture content passes the shared schemas; no autoload or project.godot change.

## Rollback
Revert the squash; nothing reads Content yet and no save data depends on it.

## Deviations / concerns
`LevelData` lives in `core.board` while the task's area is `services.content`, as the roadmap row names
it. The game-side checks duplicate a small part of the schema on purpose: a broken pack must fail
softly at runtime even though CI validates content.
