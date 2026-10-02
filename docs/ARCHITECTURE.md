# ARCHITECTURE.md — how the game is built

- Status: v1 draft (T-0007, 2026-10-02). Opus gives a second opinion (T-0010); Chris approves with docs v1
  (T-0011). Changing an invariant here needs a decision record or a second opinion.
- Sources: design pass `03-architektura-gry.md` §2–§5, `04-repo-i-dokumenty.md` §1; decisions 0001
  (Godot 4.7), 0002 (content in packs), 0003 (local date), 0006 (Sol has no runtime).
- Engine-specific parts assume Godot 4.7 (decision 0001). If the engine gate switches engines, this
  file is re-planned in T-0033.

## Layers

```
features/   screens: scenes + scripts per screen. Read state, call services, play animations.
ui/         design system: tokens, generated theme, components, gallery.
services/   autoloads with state and persistence (closed list, #autoloads).
core/       pure rules: RefCounted classes, no Node, no I/O, time and randomness injected.
platform/   SDK adapters (ads, iap, analytics, crash, consent, haptics, review, notifications) + Fakes.

data/       registries (JSON): config, analytics, audio.   content/  generated level packs.
```

### Dependency rules
1. `core/` imports only `core/`. It never uses `Node`, `FileAccess`, `Time`, `OS`, `randi()`/`randf()`,
   or any autoload. Dates and RNGs are parameters.
2. `services/` use `core/`, `platform/` (only through the `Platform` autoload) and `data/`. They know
   no scenes except `Nav`, which owns screen switching.
3. `features/` and `ui/` use `services/` and `core/` data types. They never call `platform/`.
4. `ui/components/` know nothing about game rules or services; they take parameters and emit signals.
5. `platform/` knows no game rules; it turns SDK callbacks into plain signals and calls.
6. Upward communication is by signals. The `Events` autoload carries side effects only (analytics, audio,
   haptics): logic calls, effects listen. No game rule may depend on an `Events` listener.
7. Adapter interfaces in `platform/` are the only abstractions in the project, because each has two real
   implementations (SDK and Fake). No other interface or base class "for later".

Review enforces these from P1; a script check is added when the first violation slips through.

## Areas

The closed list of areas. Every task names exactly one `area` (front-matter); `tools/tasks.py` reads
this table, and `touch` globs should stay inside the area's paths (plus exact registry or locale files the
task names). Two tasks in the same area never run at once. Adding an area is a `docs` change to this
table, made by the planner.

| Area | Paths | Notes |
|---|---|---|
| `core.board` | `game/core/board/` | `LevelData`, `BoardState`, `HintLogic`, `Shuffle` |
| `core.economy` | `game/core/economy/` | affordability, reward maths |
| `core.progress` | `game/core/progress/` | slot advance, unlock rules, stars, postcard pieces |
| `core.ads` | `game/core/ad_policy/` | `should_show_interstitial` |
| `core.daily` | `game/core/daily/` | day keys, daily pick (decision 0003) |
| `core.streak` | `game/core/streak/` | streak, freeze, repair |
| `services.config` | `game/services/config.gd`, `game/services/config/` | remote config, A/B buckets |
| `services.save` | `game/services/save.gd`, `game/services/save/` (migrations), `game/tests/fixtures/save/` | hotspot |
| `services.progress` | `game/services/progress.gd`, `game/services/progress/` | |
| `services.economy` | `game/services/economy.gd`, `game/services/economy/` | |
| `services.daily` | `game/services/daily.gd`, `game/services/daily/` | |
| `services.content` | `game/services/content.gd`, `game/services/content/`, `pipeline/schema/`, `game/tests/fixtures/content/` | schemas are a hotspot |
| `services.monetization` | `game/services/monetization.gd`, `game/services/monetization/` | ad flows, IAP flow, entitlements |
| `services.analytics` | `game/services/analytics.gd`, `game/services/analytics/` | queue, consent gating |
| `services.audio` | `game/services/audio.gd`, `game/services/audio/`, `game/data/audio/` | |
| `services.nav` | `game/services/nav.gd`, `game/services/nav/` | boot scene `game/services/nav/boot.tscn` |
| `platform.ads` | `game/platform/ads/` | each platform area holds interface, SDK adapter and Fake |
| `platform.iap` | `game/platform/iap/` | |
| `platform.analytics` | `game/platform/analytics/` | |
| `platform.crash` | `game/platform/crash/` | |
| `platform.consent` | `game/platform/consent/` | UMP + ATT |
| `platform.haptics` | `game/platform/haptics/` | |
| `platform.review` | `game/platform/review/` | |
| `platform.notifications` | `game/platform/notifications/` | Later |
| `level.flow` | `game/features/level/*.gd`, `game/features/level/*.tscn`, `game/features/level/complete/` | `LevelController`, level scene, Level complete layer |
| `level.wheel` | `game/features/level/wheel/` | `LetterWheelView`, input |
| `level.board` | `game/features/level/board/` | `BoardView` wiring, letter flight |
| `level.hud` | `game/features/level/hud/` | top bar, power-up buttons wiring |
| `features.home` | `game/features/home/` | |
| `features.journey` | `game/features/journey/` | includes postcard screen |
| `features.daily` | `game/features/daily/` | |
| `features.collection` | `game/features/collection/` | |
| `features.shop` | `game/features/shop/` | |
| `features.settings` | `game/features/settings/` | |
| `features.onboarding` | `game/features/onboarding/` | coach-mark and tutorial wiring |
| `features.debug` | `game/features/debug/` | debug builds only |
| `ui.tokens` | `game/ui/tokens.gd`, `game/ui/theme/`, `game/assets/fonts/` | theme is generated, never hand-edited |
| `ui.components` | `game/ui/components/` | catalog in `DESIGN.md#components` |
| `ui.gallery` | `game/ui/gallery/` | |
| `data.config` | `game/data/config/` | registry, one file per key prefix |
| `data.analytics` | `game/data/analytics/` | registry, one file per area |
| `locale` | `game/locale/` | one CSV per area |
| `assets.art` | `game/assets/art/`, `game/assets/icons/` | |
| `assets.audio` | `game/assets/audio/` | |
| `content.pl`, `content.en`, `content.de` | `game/content/<lang>/`, `pipeline/overrides/<lang>.csv`, `pipeline/config/<lang>.yaml`, `pipeline/handmade/<lang>/`, `pipeline/cache/<lang>/` | generated output changes only through the pipeline |
| `pipeline.ingest`, `pipeline.annotate`, `pipeline.classify`, `pipeline.tiers`, `pipeline.candidates`, `pipeline.grid`, `pipeline.scoring`, `pipeline.validate`, `pipeline.dedupe`, `pipeline.sequence`, `pipeline.qa`, `pipeline.export` | `pipeline/src/wordgame_pipeline/<stage>/`, `pipeline/tests/<stage>/` | one area per stage (`CONTENT.md`); `pipeline.validate` and `pipeline.export` are high risk |
| `tools` | `tools/` | |
| `infra` | `game/project.godot`, `game/export_presets.cfg`, `game/addons/`, `game/platform/platform.gd`, `game/services/events.gd`, `game/services/clock.gd`, `Makefile`, `pyproject.toml`, `docker/`, `.devcontainer/`, `.gitignore`, `README.md` | hotspots |
| `ci` | `.github/workflows/`, `.github/pull_request_template.md` | hotspot |
| `store` | `store/` (listing texts, screenshots, privacy policy source) | mostly work in store consoles |
| `docs` | `docs/`, `tasks/`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | |

Tests live with the area of the code they test:
- unit tests for `game/core/<domain>/x.gd` are `game/tests/unit/<domain>/test_x.gd` (`unit/` mirrors
  `core/`);
- integration tests are `game/tests/integration/<area>/`.

### Hotspots
Changed only by `infra` or `contract` tasks, one at a time, in lane `H`:
- `game/project.godot`, which includes the autoload list;
- `game/export_presets.cfg` and `game/addons/*`;
- the save schema: `game/services/save.gd`, migrations and golden files;
- the LevelData, manifest and daily-pack schemas in `pipeline/schema/`;
- `.github/workflows/*` and the `Makefile`.

## Autoloads

The closed list. No task adds, removes or renames one; that needs a decision record.

| Autoload | Responsibility | Persists through Save |
|---|---|---|
| `Config` | Registry defaults from `data/config/*.json`, remote overrides, type and range validation, A/B buckets | no (caches remote JSON in `user://config_cache.json`) |
| `Save` | The one save file: load, atomic write, backup, migrations, `install_id`; owns the `settings` and `meta` sections | owner of the file |
| `Progress` | Current and completed slots per language, stars, unlocks, postcard pieces, coach marks seen, in-level state | `progress` |
| `Economy` | Coins and items, `grant` / `spend`, journal | `economy` |
| `Daily` | Daily pick by day key, calendar, streak, freezes | `daily` |
| `Content` | Manifest, pack loading, level by slot, daily level by day key | no |
| `Monetization` | Ad policy calls, rewarded and interstitial flows, IAP flow, entitlements, consent sequencing | `monetization` |
| `Analytics` | `track(name, params)`, registry validation in debug, bounded queue, consent gating | no (queue in `user://analytics_queue.json`) |
| `Audio` | Sound cues from `data/audio/cues.json`, music, volumes; listens to `Events` | reads `settings` |
| `Nav` | Screen state machine, transitions, boot sequence, Android back | no |
| `Events` | Side-effect signals only (word found, bonus found, invalid word, level complete, purchase, …) | no |
| `Platform` | Adapter container: `Platform.ads`, `.iap`, `.analytics`, `.crash`, `.consent`, `.haptics`, `.review`, `.notifications`; selects SDK or Fake | no |

- **Settings** (the `settings` save section, FR-SET) are owned by `Save`, so no new autoload is needed.
  - `Save.get_setting(key)` and `Save.set_setting(key, value)` cover a closed key list: `sfx_volume`,
    `music_volume`, `haptics_enabled`, `reduced_motion`, `high_contrast`, `text_scale`, `language`.
  - `set_setting` persists immediately and emits `Save.setting_changed(key)`. Consumers re-read on that
    signal (FR-SET-04).
- **Clock.** `Clock` (`game/services/clock.gd`) is a plain injectable class, not an autoload. Services
  receive it at boot; tests pass a fixed clock.
- **Order.** Autoload order in `project.godot` is the order above. An autoload does no work in
  `_ready()` beyond wiring signals; `Nav` drives the boot sequence explicitly.

## Boot and navigation

Boot (`services.nav`, `DESIGN.md#screen-map`):
1. `Save.load()`: migrate if needed; corrupt file → backup → clean start (see [Save](#save)).
2. `Config.load()`: registry defaults, then the cached remote JSON. A fresh fetch starts in the background
   and never blocks (FR-CFG-03).
3. `Content.load_manifest(language)`.
4. `Monetization.process_unfinished_transactions()` starts in the background (FR-IAP-05).
5. The first screen: Level for the current slot. From `unlocks.journey_slot` on, a returning player
   goes to Home instead.

- `Nav` is a state machine over screens: Boot, Level, Home, Journey, Postcard, Settings, Daily,
  Collection, Debug. Sheets (Shop, hint options) are overlays owned by the screen that opens them,
  not Nav states.
- The Level complete layer belongs to the Level screen, so the next level preloads behind it
  (FR-BOARD-07).
- In P1 boot goes straight to Level, and Home exists empty, reachable from Debug.

## Level flow

```
LetterWheelView ── word_attempted(tiles: PackedInt32Array) ──► LevelController (level.flow)
LevelController ── BoardState.evaluate(tiles) ──► AttemptResult { kind, word, cells }
                 ── BoardView.reveal_word(cells) / preview feedback
                 ── Events.word_found | bonus_found | already_found | invalid_word
                 ── Progress.save_level_state(...)            (FR-CORE-08)
BoardState.is_complete() ──► Progress.complete_level(slot) ──► Economy.grant(level_complete)
                          ──► Level complete layer ──► Monetization (consent step, interstitial?) ──► next level
```
- `BoardState`, `HintLogic` and `Shuffle` are pure classes in `core/board`. Rules:
  `GAME_DESIGN.md#word-classes`, `#hints`, `#power-ups`.
- `LevelController` is the only writer of level state during a level; the views only render it.

## Save

One JSON file, `user://save.json` (FR-SAVE-01 … 09).

- **Atomic write** (FR-SAVE-02): write to `save.json.tmp` → flush → rename the current `save.json` to
  `save.json.bak` → rename the temp file to `save.json`.
- **Load** (FR-SAVE-03):
  1. Read `save.json`. If it is unreadable, invalid JSON, or `schema_version` is missing or newer
     than the build knows, try `save.json.bak`.
  2. If the backup fails too, start a clean save and emit `Events.save_corrupted` (analytics from P2).
  3. A save restored from backup shows the "Progress restored from backup" Toast once.
- **Migrations** (FR-SAVE-04) are a chain of pure functions `migrate_vN_to_vN1(data: Dictionary) ->
  Dictionary` in `game/services/save/`. Each has a golden-file test:
  `game/tests/fixtures/save/vN.json` → expected `vN+1`. Migration runs before any section is handed out.
- **When** (FR-SAVE-05): `Save.request_flush()` after a word found, level complete, any economy
  transaction, settings change and going to background. Never per frame. The IAP flow uses a synchronous
  `Save.flush()`.
- **Where** (FR-SAVE-06): the user data directory, which is covered by Android Auto Backup and the iOS
  backed-up directory. Cache files (`config_cache.json`, `analytics_queue.json`) are excluded from
  backup.
- **Ownership**: each section is read and written only by its owner (table in [Autoloads](#autoloads)).
  Other code asks the owner, never reads raw save data.

Save v1 shape (T-0036 fixes exact field names; this is the contract it starts from):

```json
{
  "schema_version": 1,
  "meta": { "install_id": "uuid-v4", "created_at": "2026-10-02T12:00:00Z", "app_version": "0.1.0" },
  "settings": { "sfx_volume": 1.0, "music_volume": 0.8, "haptics_enabled": true, "reduced_motion": false,
                "high_contrast": false, "text_scale": 0, "language": "pl" },
  "progress": { "by_lang": { "pl": { "current_slot": 1, "completed_slot": 0, "stars": 0,
                "level_state": null, "location_pieces": {} } },
                "unlocked": [], "coach_marks_seen": [], "bonus_meter": 0 },
  "economy": { "coins": 0, "items": { "hint": 0, "reveal": 0 }, "journal": [] },
  "daily": { "completed_days": [], "last_seen_day": null, "freezes": 0, "last_freeze_week": null,
             "streak": 0, "streak_broken_at": null },
  "monetization": { "remove_forced_ads": false, "processed_transactions": [], "last_interstitial": null,
                    "levels_since_interstitial": 0, "levels_since_purchase": null, "shop_coins_ads": {} }
}
```
- `level_state` holds the slot, found level words, revealed cells and found bonus words of the
  unfinished level (FR-CORE-08). It is cleared on completion.
- Sections are independent, so a future cloud sync can merge them separately: max for progress, union
  for transactions (FR-SAVE-09).

## Platform

Every platform service sits behind an adapter interface with a Fake (FR-PLAT-01). The game runs in the
editor, in headless CI and in tests with Fakes only.

- **Layout:** `game/platform/<service>/<service>_adapter.gd` (the interface: methods and signals, no
  logic), `<service>_fake.gd`, and the SDK adapter, e.g. `<service>_admob.gd`.
- **Selection:** `Platform` picks the SDK adapter only on a device build with the plugin present (Android
  or iOS), unless the `--fakes` command-line argument is given. Editor, headless and unit tests always
  get Fakes. Debug builds can force a Fake per service from the Debug screen.
- **Behaviour:** Fakes are deterministic and scriptable from tests (succeed, fail, no fill, cancel,
  pending). They record calls for assertions.

Interface sketch (T-0035 writes the real `## @api`):

| Service | Calls | Signals |
|---|---|---|
| ads | `initialize(consent)`, `load_rewarded()`, `show_rewarded()`, `load_interstitial()`, `show_interstitial()` | `rewarded_loaded`, `reward_earned`, `ad_closed`, `ad_failed(reason)` |
| iap | `query_products(ids)`, `purchase(id)`, `finish(transaction)`, `fetch_unfinished()`, `restore()` | `products_received`, `transaction_updated(transaction)`, `purchase_failed(reason)` |
| consent | `request_info()`, `show_form_if_required()`, `request_att()` (iOS), `show_privacy_options()` | `consent_resolved(state)`, `att_resolved(status)` |
| analytics | `log_event(name, params)`, `set_user_property(key, value)` | — |
| crash | `record(message)`, `set_key(key, value)` | — |
| haptics | `play(pattern)` with patterns `tick`, `soft`, `success`, `error` | — |
| review | `request_review()` | — |
| notifications | Later | — |

- A transaction carries the store key (`purchaseToken` on Android, StoreKit 2 `Transaction.id` on iOS),
  product ID and state; never `orderId` (FR-IAP-03).
- Plugins are chosen at the engine gate (T-0033, decision `NNNN-platform-providers`). Adding one is a
  `game/addons/*` hotspot change.

## Monetization flows

**IAP** (FR-IAP-03 … 08):
```
purchase(id) ─► store transaction (key, product, state)
  key ∈ Save.monetization.processed_transactions ─► finish only, grant nothing
  else ─► Economy.grant(...) or set entitlement ─► add key ─► Save.flush() ─► finish / consume / acknowledge
boot: fetch_unfinished() ─► same flow (idempotent)
restore: non-consumables only (Remove Forced Ads); never revoked locally (FR-IAP-11)
```
- Purchases are verified locally (StoreKit 2 signed transactions, Play Billing signature); there is no
  backend.
- A crash between any two steps must neither lose nor double a grant; the integration test covers each
  gap.

**Rewarded**: the reward is granted only on `reward_earned` (FR-ADS-04). The flow states follow
`DESIGN.md#flow-rewarded`.

**Interstitial**:
- `Monetization` builds the state for `core/ad_policy` `should_show_interstitial(state, config, now)` and
  shows the ad only when it returns true (`GAME_DESIGN.md#ad-policy`).
- The ads SDK is initialized only after consent resolves; on iOS, after ATT too (FR-ADS-06).

**Consent**: `Monetization` triggers the UMP and ATT steps on the Level complete of
`consent.ump_after_slot` and `consent.att_after_slot`. An unresolved step retries at the next Level
complete (`DESIGN.md#flow-consent-and-att`).

## Registries

Registries are directories with one file per key prefix or area, so parallel tasks do not conflict.

- **Config** `game/data/config/<prefix>.json` (FR-CFG-01). The key prefix is the file name, so
  `economy.price.hint` lives in `economy.json`.
  - Each entry: `default`, `type` (`int` | `float` | `bool` | `string`), `range` (`[min, max]` for
    numbers), `description`, `owner`, `remote` (bool).
  - Values come from `GAME_DESIGN.md#config-key-registry`.
  - `Config.get_int(key)`, `get_float`, `get_bool` and `get_string` fail loudly in debug builds on an
    unknown key or a wrong type.
- **Analytics** `game/data/analytics/<area>.json` (FR-ANL-01). Each event has a name, typed params and a
  description; the names are canonical in `PRODUCT.md`. `Analytics.track` validates against the
  registry in debug builds.
- **Audio** `game/data/audio/cues.json`: cue name → files, volume, pitch variation.
- **Check:** `tools/check_registries.py` (T-0039) fails CI when a literal key passed to `Config.get_*` or
  `Analytics.track` is not registered, or when a registry file breaks its schema.

## Content

Decision 0002: the game holds no dictionary.

- `Content` reads `game/content/<lang>/manifest.json` and loads packs on demand.
- A level becomes an immutable `LevelData` (`game/core/board/level_data.gd`, tiles as indices).
- Schemas, slot policy and manifest fields are owned by `CONTENT.md#level-schema`, `#manifest` and
  `#slot-policy`.
- A pack that fails to load or validate shows `StatePanel(error)` and emits an analytics event; it never
  causes a crash loop (`DESIGN.md#flow-offline-and-errors`).
- Level data loads in 100 ms or less (NFR-03).

## Analytics, audio, localization

- **Analytics.** `Analytics` queues events in a bounded file queue (`analytics.queue.max_events`,
  FR-ANL-02).
  - Until consent resolves, events stay queued; after that they are sent or dropped per the outcome
    (FR-CONSENT-02).
  - Every event carries `install_id`, app version, content version, language and A/B buckets
    (FR-ANL-03).
- **Audio and haptics.** Both listen to `Events` and respect the settings. Features never call them
  for logic.
- **Localization.** One language setting covers content and UI (FR-LOC). UI strings are Godot
  translation CSVs, one per area (`game/locale/<area>.csv`), with English keys `area.screen.element`.

## Testing hooks

- Pure `core/` → unit tests run headless in seconds.
- Services take a `Clock`, an RNG seed and `Platform` Fakes, so integration tests run headless in CI with
  no SDK.
- The boot smoke test (T-0044) and the bot test (T-0042) run every CI build. Details: `TESTING.md`.
