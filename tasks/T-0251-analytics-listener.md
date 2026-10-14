---
id: T-0251
title: Connect P2a side-effect signals to registered analytics
epic: E17
type: feat
area: services.analytics
risk: medium
executor: cheap
think: med
ui: none
status: ready
depends_on: [T-0250, T-0233, T-0242]
touch:
  - game/services/analytics.gd
  - game/services/analytics/analytics_listener.gd*
  - game/services/events.gd
  - game/services/nav.gd
  - game/services/save.gd
  - game/features/level/level.gd
  - game/tests/integration/test_analytics_listener.gd*
  - game/tests/integration/test_boot_smoke.gd
  - docs/qa/T-0251-analytics-listener.md
  - tasks/T-0250-analytics-service.md
  - tasks/T-0251-analytics-listener.md
revision: 1
---

## Goal
Connect truthful P2a gameplay, navigation, system, economy and postcard notifications to
the already-registered analytics names. Delivery remains exclusively the durable,
consent-gated `Analytics.track` boundary from T-0250; analytics must never decide or
block gameplay, persistence, rewards or navigation.

## Context
- `docs/ARCHITECTURE.md#analytics-audio-localization`: “Until consent resolves, events stay
  queued; after that they are sent or dropped per the outcome.”
- `AGENTS.md#code-rules`: “`Events` autoload is ONLY for side effects (analytics, audio,
  haptics), never for game logic.”
- `docs/PRODUCT.md#core-events-seed-of-the-registry` defines irreversible event names.
  `FR-ANL-04` requires `invalid_word_submitted` to include language, slot and exact letters.
- Roadmap T-0251; T-0250 implements validation, common context, durable FIFO and consent,
  not the listener. T-0252 owns real provider delivery.

## Current state — executor preflight
- `game/services/analytics.gd`: `start_runtime(save, config, content, event_bus, queue)`,
  `track(name, params)`, `runtime_ready()` and `pending_count()` exist. The service
  listens only to `Events.consent_changed`. It has no gameplay event listener.
- `game/services/events.gd`: existing side-effect signals `word_found(word)`,
  `bonus_found(word)`, `already_found(word)`, `invalid_word(word)`,
  `level_completed(slot)`, `hint_used`, `economy_changed(operation,reason,amounts,snapshot)`,
  `stars_earned(language,slot,stars)`, `postcard_piece_revealed(language,location_id,pieces)`,
  `location_complete(language,location_id)`, `feature_unlocked(language,feature,slot)` and
  `save_corrupted`. These signatures must remain backward-compatible.
- `game/features/level/level_controller.gd::_publish` emits word outcomes and
  `level_completed` only after successful persistence, but the latter has no duration or
  counters. `game/features/level/level.gd::_on_shuffle` has a successful-shuffle branch
  without a telemetry signal. P1 hints are free and must not be mislabeled paid.
- `game/services/nav.gd::start` loads Save, Config and Content, then calls
  `Analytics.start_runtime` *before* the initial `go_to_level`/Home route. It exposes
  `screen_changed(screen)`, `level_slot()` and its current screen.
- `game/services/save.gd::load` can recover, migrate or create a new document; existing
  `Events.save_corrupted` fires **before** Analytics is started. There is no public,
  copied load outcome giving accepted source schema version. `setting_changed(key)`
  fires only after a successful flush.
- `game/services/clock.gd` exposes injectable `monotonic_msec()`. `Content.level_for_slot`
  and `LevelData.get_id()/get_slot()/bonus_words()` provide campaign identity.
- Registries exist in `game/data/analytics/{lifecycle,level,tools,economy,meta,onboarding,system}.json`.
  All event parameters must match these files exactly; do not edit canonical registries.

## Specification

### Behavior
1. Add a non-autoload listener owned by `Analytics` and configured from `Nav.start` after
   successful `start_runtime`, before the first screen route. Use explicit injected
   Save, Content, Nav and Events references; do not depend on `Platform.analytics`
   from the listener. Repeating boot/listener setup with the same owners cannot create
   duplicate connections or duplicate a single transition event. Switching owners
   disconnects previous signals. Stub-only mode remains fully isolated.
2. Route events through `Analytics.track` only. Unknown consent leaves valid emissions in
   T-0250's durable FIFO; denial/revocation retains its existing behavior. Listener
   failures (queue full, invalid setup, invalid event) must never change a gameplay,
   Save, Economy or Nav return value, nor trigger a feedback loop.
3. After Analytics is runtime-ready, record `app_boot` once for each successful app boot,
   `content_version_loaded` once for the accepted Content version, and `nav_screen`
   on every real `Nav.screen_changed` transition, including the first visible screen.
   The screen value must be the canonical enum name, not localized copy. Record real
   application background/foreground transitions once each, without emitting artificial
   foreground for initial launch. Use Godot lifecycle notifications in the listener.
4. Capture startup Save load diagnostics without exposing the raw document or reading
   `user://save.json` separately. Add a read-only, copied `Save.last_load_report()`
   interface: `{corrupted: bool, from_version: int, to_version: int}` (zero versions
   when unknown / no upgrade). Report `save_corrupted {schema_version:0}` exactly
   once if a preexisting save could not be recovered. Report
   `save_migrated {from_version,to_version}` only if the accepted document truly
   upgraded from a **known lower version**; not on new install, backup promotion,
   unchanged v4 or preserved v3 compatibility. Snapshot diagnostics during Nav boot,
   then enqueue via Analytics after runtime setup; do not depend on the early
   `Events.save_corrupted` emission being replayed. Failed boot cannot fabricate either.
5. Listen for committed `Save.setting_changed` and track
   `settings_changed {setting: string}` with the setting key only; never its value.
6. On entering a real campaign level, track
   `level_start {slot:int,level_id:string}`, establish a fresh monotonic start
   sample and reset hint/reveal/bonus counters. On `word_found` and `bonus_found`,
   emit `word_found` and `bonus_word_found` with the active `slot,level_id,word`.
   On `already_found`, send `already_found_word` with `kind` determined from the
   current `LevelData.bonus_words()` (bonus versus level), never from a guess.
   On `invalid_word(word)`, send `invalid_word_submitted` with the actual active
   Content language, slot and unmodified submitted letter string. Do not trim, translate,
   hash, redact or replace the letters. Skip all these events when no matching active
   campaign level exists (e.g. boot, debug/unbound screen).
7. On `level_completed(slot)` emitted after successful Progress persistence, track
   `level_complete` once per committed active level with the required exact keys:
   `slot`, `level_id`, nonnegative `duration_ms` from injected monotonic Clock,
   `hints_used`, `reveals_used`, `bonus_words`, `stars`. Obtain stars from the
   corresponding committed `Events.stars_earned`, not a speculative award.
   Count distinct *committed* bonus discoveries once. Counters initialize to zero.
   Repeated, failed, stale or unrelated completion notifications are not attributed
   to a new level or counted twice. A resumed level starts a new measured visit;
   do not fabricate pre-resume attempts or durations.
8. From `Events.economy_changed`, emit exactly one `economy_grant` or
   `economy_spend` according to the **committed** operation, with canonical
   `reason,coins,hint,reveal` derived from actual `amounts`. Never send the wallet
   snapshot or balance; reject malformed/unknown operations instead of inventing
   zeros for invalid shapes. From `stars_earned`, `postcard_piece_revealed`,
   `location_complete` and `feature_unlocked`, map directly to the registered
   `meta` / `onboarding` events with the declared fields. These are receipt-based
   side effects; observer failure cannot replay a grant.
9. Add `Events.shuffle_performed(slot:int)` as a side-effect-only signal and emit
   it in the existing successful shuffle branch in `level.gd`; map it to
   `shuffle_used {slot}`. Preserve the existing audio `hint_used` signal.
   A free P1 hint must **not** be claimed to have `payment=item/coins/rewarded`.
   Only track `hint_used {slot,payment}` if a verified payment source is available
   from the later paid-hint flow (T-0278); do not invent a payer or change the
   established payment registry here. Similarly, never fabricate `reveal_used`,
   `bonus_chest_opened`, `region_complete`, `onboarding_step` or provider/ad/IAP
   events before their producers exist. Document these deliberate P2a omissions.
10. Signal handlers must have fixed typed arguments, bounded per-level counters and no
    retry loops. No new dependencies, autoloads, configuration, persistent save
    schema, analytics registry names, transaction protocol or consent rules.

### Interface
```gdscript
## @api — Save read-only last completed load outcome; independent copied values.
func last_load_report() -> Dictionary

## @api — Events side effect only; emitted after successful shuffle.
signal shuffle_performed(slot: int)
```
The listener setup method may be internal to the Analytics implementation; no unrelated
public APIs or existing signal signatures may change.

### Edge cases
| Case | Expected |
|---|---|
| Save diagnostics happen before Analytics startup | Reconstructed once from the accepted Save result, with no raw document leaked |
| First boot with no prior save | `app_boot`, not `save_corrupted` or `save_migrated` |
| v3 file blocked in compatibility mode | No misleading `save_migrated` |
| Failed Save/Economy/Progress persistence | No "successful" transactional analytics event |
| Navigation to Home, Debug or Postcard | Clear active level attribution; never attach stale slot/ID |
| Replay/restart or repeated signal connection | No duplicate tracking from duplicate listeners |
| Invalid word with Polish diacritics or repeated letters | Preserve exact Unicode letters and correct language |
| Full/denied analytics queue | Gameplay continues; existing consent policy handles the event |
| Earlier star signal for different language/slot | Do not carry it into current level completion |
| Failed or unavailable shuffle | No `shuffle_used` event |

## Out of scope
- Adding or renaming event definitions or changing their parameter schemas.
- Ads/consent UI, analytics SDK delivery, crash provider, remote config experiments.
- Paid Hint/Reveal payment source (T-0278), daily, bonus-chest settlement and multi-region
  completion. Do not silently report placeholders as genuine paid actions.
- Changing the LevelController's persistence contract or Economy's grant/spend semantics.
- Introducing new autoloads, player-facing copy, Save migrations or queue format changes.

## Tests
File: `game/tests/integration/test_analytics_listener.gd`
- Given an isolated loaded Save/Content and fake `Events` + `AnalyticsFake`, when boot
  connects the listener before the first screen, then `app_boot`, accepted version and
  initial `nav_screen` have the registered payloads, without duplicate connections.
- Given unresolved consent, when events occur, then they remain in FIFO; denial removes
  them and an allowed decision sends in order. A queue error does not fail game actions.
- Given a campaign level, when committed required/bonus/invalid/already-found notifications
  occur, then exact registry event names, slot, ID, Unicode letters and bonus/level kind
  are present; after leaving the level no stale attribution is emitted.
- Given a deterministic monotonic Clock and committed stars, when a single completion
  fires twice, then one `level_complete` contains exact nonnegative elapsed time and
  counts; replay, failed persistence, fresh level and resume keep separate counters.
- Given actual committed Economy and Progress signals, when grant/spend, stars, postcard,
  location and unlock notifications fire, then exact parameter dictionaries are tracked
  once, with no speculative balance or duplicate awards.
- Given `shuffle_performed`, only successful shuffles produce `shuffle_used`; free
  P1 hints do not impersonate paid hints.
- Given fresh, v4, successful v1/v2/v3 upgrades, rejected corrupt saves, backup
  recovery and preserved v3 compatibility, then startup diagnostics produce only the
  truthful `save_corrupted`/`save_migrated` records, even across repeated Nav start.
- Given settings, app background/foreground and different listener/owner lifetimes,
  then only committed changes and real transitions are reported, and stale listeners
  are disconnected.

File: `game/tests/integration/test_boot_smoke.gd`
- Real Nav boot leaves Analytics runtime-ready with the listener installed and
  telemetry not sent to real providers without consent.

## Acceptance
- The complete supported P2a mapping above is implemented and checked against the
  canonical JSON registry; unsupported future producers are explicitly accounted for,
  not spoofed.
- All named tests pass, plus `make check`, tasks lint, scope check and CI.
- `docs/qa/T-0251-analytics-listener.md` records event matrix, deliberate producer
  omissions and focused test evidence.
- Reconcile the already-merged T-0250 file status to `done` in this PR.
- No UI screenshots required.

## Implementation notes
- Keep Analytics/Events as observers only; use injected `Clock.monotonic_msec()` for
  visit duration. The listener must not mutate Core, Save, Progress or Economy.
- Do not change the canonical Analytics event registry to fit an implementation;
  adapt emitted payloads to the registry.
- If actual implementation cannot fit the prescribed narrow scope/size, escalate
  before broadening the `touch` list or weakening a required mapping.

## Escalation log
<!-- rule id -> question -> answer (revision N) -->
