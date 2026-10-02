# PRODUCT.md — Project WORD (working title "World of Words")

- Status: v1 for Chris's review (Chris decides; Opus second opinion once per phase)
- Owner: Chris. Maintainer: Sol (via `docs` PRs only; executors never edit this file).
- Sources: design pass `docs/design-pass/01`–`11` (wins on conflicts), decisions `0004`, `0005`, `0006`,
  market research files (input only).
- Canonical names: config keys, event names and IAP product IDs defined here are the contract.
  `DESIGN.md`, `GAME_DESIGN.md` and `tasks/ROADMAP.md` follow this file when they differ.
- Related docs: `GAME_DESIGN.md` (rules and economy intents; written in Phase 0 from this PRD),
  `ARCHITECTURE.md`, `CONTENT.md`, `DESIGN.md`, `TESTING.md`, `tasks/ROADMAP.md`.

How to read this file:
- This is the WHAT and WHY. Rules live in `GAME_DESIGN.md`, numbers live in `game/data/config/*.json`.
- `rules: GAME_DESIGN.md#<anchor>` marks where a detailed rule will live. Those anchors are a contract:
  `GAME_DESIGN.md` must create them.
- Config keys are written as `<file>.<key>` (example: `economy.price.hint` lives in
  `game/data/config/economy.json`). Values shown next to a key are intents, never hard numbers.
- Requirement IDs (`FR-<AREA>-NN`, `NFR-NN`) are stable. Tasks cite them. Do not renumber; retire an ID
  by marking it `(retired)`.
- Phase tags: `P1` Core Prototype, `P2` Vertical Slice, `P3` Production / soft launch, `Later`
  post-launch and data-gated. Phase 0 (Foundation) ships no player-facing features.

---

## Summary

Project WORD is an offline-first, portrait-only mobile word-connect puzzle game for Android and iOS:
the player swipes letters on a wheel to fill a small crossword grid, then immediately plays the next
level. The mechanic is proven by Words of Wonders, Wordscapes and dozens of clones; we do not compete on
mechanics or level count. We compete on four things players in this category repeatedly complain about:
a dictionary they can trust (a valid word is never rejected; weird words never appear in the grid),
Polish as a first-class language, fair monetization (no forced ads in the first levels, few
interstitials later, rewarded ads always optional, Remove Forced Ads that really removes them), and a
swipe that feels instant. A light meta layer (a journey through locations, postcards revealed with stars,
a daily puzzle with a monthly calendar and a forgiving streak) gives a second reason to play. The game
ships no dictionary and calls no LLM at runtime: a Python pipeline generates level packs offline. It is
built by one person (Chris) directing AI agents, so scope is deliberately small and every phase ends at
an explicit exit gate.

## Goals and non-goals

### Product goals
1. Core loop that people enjoy for 20+ minutes without instructions (Phase 1 "fun gate").
2. First 30 minutes at release quality on Android and iOS (Phase 2 vertical slice).
3. A trustworthy Polish dictionary experience: zero "my valid word was rejected" cases for words in the
   licensed source; no banned or obscure words as level words.
4. Monetization that never blocks campaign progress and stays measurably less aggressive than the
   category, while being configurable remotely so it can be tuned on data.
5. Retention benchmarks at soft launch in the range of category references (D1 ~30%, D7 ~13%,
   D30 ~8%; research benchmarks, to be validated). If D1 is far below, fix the first 10 minutes before
   adding content.
6. A content machine that produces 1000+ curated Polish levels, then English, then German, reproducibly.
7. Zero player progress or purchase loss caused by the game.

### Non-goals for v1 (explicitly out)
- No clans, guilds, multiplayer, leagues, tournaments, leaderboards, chat or social graph.
- No battle pass, season pass, event pass or piggy bank at launch (piggy bank / pass is `Later`,
  data-gated).
- No second soft or hard currency. Coins are the only currency; stars are progress, not currency.
- No large booster catalogue. Exactly three power-ups: Hint, Reveal, Shuffle (no rockets, multipliers,
  event-only boosters in v1).
- No backend, no accounts, no login, no server-side purchase validation until data proves the need.
- No cloud save in v1 (OS backup covers device change); real cloud save is `Later`.
- No LLM or any network-dependent logic at runtime. The game must be fully playable offline.
- No world-building scenes (changing location art by stage). Postcards replace them in v1.
- No landscape, no free rotation. Portrait only (tablet also portrait at start).
- No banner ads.
- No timers or fail states in levels. The game stays relaxing.
- No multiple content languages at once: one content language ships at a time (decision 0005).
- No live events in v1 (one event template is `Later`).

## Target players

Market order: Polish first, then English, then German (decision 0005). UI strings may run ahead of
content (PL + EN UI from P2). Audience: adults. Play target age group: 18 and over only, which keeps
the app outside the Play Families policy. The game is not designed for or targeted at children; ad
requests are never tagged child-directed or under the age of consent.

| Persona | Profile | What they want | What drives them away |
|---|---|---|---|
| Anna, 38, Poznań | Android mid-range phone, plays in short breaks and in the evening; plays Polish word and crossword apps today | Calm puzzles in proper Polish; one more level before sleep | An ad after every level; English-centric word lists; popups at launch |
| Marek, 57, Lublin | Crossword veteran, large text size, knows inflected forms and rare words | Every real word accepted; a daily puzzle; readable UI | "Not a word" for a valid inflected form; tiny tap targets; paywalls on hints |
| Kasia, 27, Kraków | iPhone, daily streaks in other apps, likes travel visuals and collecting | Streak, postcards, a reason to come back daily; would pay once to remove forced ads | Aggressive offers, fake "remove ads" that still shows ads, losing a streak to one missed day |

## Pillars and differentiators

Each pillar answers a market pain point found in the research (reviews of the top 30 competitors).

| Pillar | Market pain point | How we deliver it | Where |
|---|---|---|---|
| Instant, tactile swipe | Laggy or floaty input; game feel is the whole product in this genre | Letter wheel built and tuned on device first; line follows the finger every frame; haptic per letter; no loading screens between levels; fun gate before anything else | FR-WHEEL, NFR-01..03, Phase 1 exit |
| Trustworthy dictionary | "My valid word was not accepted"; weird, archaic or artificial words in grids | Word validity only from a licensed source + Chris's overrides (never an LLM); three tiers `level_ok` / `bonus_ok` / `banned`; every level ships the complete bonus list; `invalid_word_submitted` feeds a dictionary repair loop | FR-CORE, FR-CONT, FR-ANL, `CONTENT.md` |
| Polish first-class | Weak Polish localization, anglocentric dictionaries, missing diacritics | Polish content first; diacritics are separate tiles; inflected forms accepted as bonus words (decision 0004); fonts and UI tested with Polish text | FR-LOC, FR-CONT, NFR-12 |
| Fair monetization | Too many and too long ads, ads every level, fake "remove ads", hint paywalls | Ad policy as a pure, tested, remotely tunable function; no forced ads during onboarding; Remove Forced Ads removes all interstitials and own-offer interstitials; rewarded always opt-in with an alternative; progress never blocked by currency | FR-ADS, FR-IAP, FR-ECON, Monetization |
| Clean, calm UI | Popups and offers covering the game at launch and between levels | First action is gameplay; bottom sheets instead of modal popups; at most one non-gameplay prompt per session (config); minimal home screen | FR-ONB, FR-SET, `DESIGN.md` |
| Light but meaningful meta | "Level 728 → 729" monotony; collections that lose value | Journey through regions and locations; one postcard per location revealed piece by piece with stars; daily puzzle with a monthly calendar reward; forgiving streak with freezes | FR-META, FR-DAILY, FR-STREAK |
| Progress safety | Lost progress after phone change or crash; lost purchases; nerfing earned items | Atomic saves with backup and migrations; save in OS-backed-up location; idempotent purchase flow; rule: never take away earned items | FR-SAVE, FR-IAP, FR-ECON |

## Scope by phase

Phase definitions and exit criteria come from design pass 11 §4 and are summarized in
`tasks/ROADMAP.md`. Phase 0 (Foundation) produces docs, spikes (S1 platform, S2 swipe, S3 dictionary,
S4 generator; S5 resolved by decision 0006), repo, CI and contracts; no player-facing features.

| Feature | P1 Core Prototype | P2 Vertical Slice | P3 Production | Later |
|---|---|---|---|---|
| Letter wheel (swipe, line, backtrack, haptics) | yes (raw visuals) | final game feel | — | — |
| Board from data, word matching (level/bonus/found/invalid) | yes | final animations | — | — |
| Shuffle | yes (free) | yes | — | — |
| Hint (letter) | yes (free, unlimited) | costs items/coins | — | — |
| Reveal (word) | no | yes | — | — |
| Progress save (slot) | yes | + economy, meta, settings sections | + daily, streak | cloud save |
| Debug screen | yes | + economy/ads/IAP/clock tools | + content review mode | — |
| Design system (tokens, components, gallery) | no (provisional tokens) | yes | extended | — |
| Home screen, journey | no | yes, 1 region, 3–4 locations | more regions | — |
| Stars, postcards | no | yes (per location) | postcard collection screen | world-building scenes |
| Landmark levels | no | no | yes | — |
| Economy (coins, items, rewards) | no | v1 + `econ_sim` | tuning on data | — |
| Bonus chest | no (bonus words recognized only) | yes | — | — |
| Onboarding | no | first 15 levels, config unlocks | tuned on funnel data | — |
| Daily puzzle + monthly calendar | no | no | yes | — |
| Streak + freeze | no | no | yes | — |
| Settings | no | yes | — | — |
| Analytics + registry | no (observe players in person) | yes, onboarding funnel | dictionary loop, calibration | — |
| Remote config + A/B buckets | defaults only | remote JSON + bucketing | experiments run | — |
| Ads (rewarded + interstitial) + UMP + ATT | no | yes | mediation decision | mediation |
| IAP | no | Remove Forced Ads, 1 coin pack, restore | more coin packs, starter pack | piggy bank / pass |
| Crash reporting | no | yes | — | — |
| UI localization | PL only | PL + EN | DE | more |
| Content language | PL (30–50 levels) | PL (150–200 production levels) | PL 1000+, then EN, then DE | more languages |
| In-app review prompt | no | no | yes | — |
| Local notifications | no | no | no | yes (opt-in) |
| Events | no | no | no | one template |
| Achievements | no | no | no | yes |
| Platforms | Android (iOS optional) | Android + iOS, closed testing / TestFlight | soft launch | — |

Explicitly OUT per phase:
- P1: economy, ads, IAP, meta (home, journey, stars, postcards), daily, design system, analytics,
  onboarding beyond hand-made first levels, settings screen.
- P2: daily, monthly calendar, streak, landmarks, postcard collection screen, more than one region,
  EN/DE content (EN UI only), A/B experiments in production, starter pack, mediation, review prompt.
- P3: events, local notifications, cloud save, achievements, piggy bank / pass, world-building scenes.
  Soft launch happens in P3 after daily + streak + ~500 PL levels.
- Later items start only when soft-launch data justifies them (see Hypotheses).

## Core experience

### Core loop
1. Level opens instantly (no loading screen).
2. Player swipes letters on the wheel; the current word previews above the wheel.
3. On release the attempt resolves to one of: level word (fills the grid), bonus word (counts toward the
   bonus chest), already found (the word is highlighted), invalid (neutral shake, no penalty).
4. Optional tools: Shuffle (free), Hint (one letter), Reveal (one word).
5. When all level words are found: completion sequence, reward (coins, stars), postcard progress.
6. Next level starts immediately; home and journey are one tap away but never forced.

Retention loops (design pass 03 §6.3): minutes = next level; session = bonus chest and postcard
progress; day = daily puzzle and streak; weeks = journey, postcard collection, monthly calendar.

### First 10 minutes (timeline)
Unlock slots below are config defaults in `game/data/config/unlocks.json` (and `consent.json`,
`ads.json`), not hard-coded numbers. Onboarding levels 1–15 are hand-made. Rules:
`GAME_DESIGN.md#onboarding`, `#unlocks`.

| Slot (default) | What happens | Config key |
|---|---|---|
| Launch | Splash → straight into level 1. No login, offers, daily, notification prompt, consent form or settings. | — |
| 1 | Tutorial swipe: 3 letters, 1–2 words, animated hand shows the gesture; only wheel and board on screen. | — |
| After 1 | On Level complete of slot 1: the UMP consent form, only where UMP reports it is required for the player's region. The ads SDK initializes only after UMP resolves. | `consent.ump_after_slot` (1) |
| 2 | 3 letters, several words; Shuffle button appears. | `unlocks.shuffle_slot` (2) |
| 3 | 4 letters; "already found" feedback likely seen naturally. | — |
| 5 | First bonus word: level contains an obvious extra word; first bonus feedback and BonusMeter appear. | `unlocks.bonus_meter_slot` (5) |
| After 6 (iOS) | On Level complete of slot 6: the system ATT prompt, preceded by UMP's IDFA explainer message; no custom pre-prompt screen. No ad request on iOS before ATT resolves. | `consent.att_after_slot` (6) |
| 7 | First hint: Hint button appears with free onboarding hints granted; one coach mark. Coins pill appears. Rewarded hint offers become possible. | `unlocks.hint_slot` (7), `economy.grant.onboarding_hints` |
| 10 | Home and journey unlock: after completion the player lands on Home for the first time and sees the first location and its postcard. | `unlocks.journey_slot` (10) |
| ~12 | First postcard piece revealed from stars. | `meta.postcard.piece_star_cost` |
| 12 | Reveal unlocks; the optional rewarded "x2 reward" button appears on Level complete. | `unlocks.reveal_slot` (12), `unlocks.double_reward_slot` (12) |
| 15 | Daily puzzle unlocks (P3; in P2 the slice ends onboarding here). | `unlocks.daily_slot` (15) |
| 16+ | First interstitial becomes eligible under the ad policy. | `ads.interstitial.first_slot` (16) |

Config constraint (validated by a unit test on the config registry):
`consent.ump_after_slot <= consent.att_after_slot < min(unlocks.hint_slot, unlocks.double_reward_slot,
ads.interstitial.first_slot)`. In other words, consent and ATT are resolved before the first moment an
ad could be offered.

## Functional requirements

Format: `ID | Phase | Requirement (one testable statement) | Rules / acceptance`. "Rules" points to the
future home of the detailed rule; numbers are config keys.

### FR-CORE: Word matching
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-CORE-01 | P1 | An attempt (sequence of tile indices) resolves to exactly one of LEVEL, BONUS, ALREADY_FOUND, INVALID. | rules: `GAME_DESIGN.md#word-classes`; unit tests in `core/board` |
| FR-CORE-02 | P1 | Validation is a set lookup against the level's word list and bonus list; the runtime contains no dictionary and no normalization logic. | design pass 03 §1 |
| FR-CORE-03 | P1 | Letters are tiles addressed by index, so repeated letters (two `A` tiles) work in any order. | test with repeated letters |
| FR-CORE-04 | P1 | Attempts shorter than the minimum length (3) are ignored without feedback or analytics. | decision 0004 §5 |
| FR-CORE-05 | P1 | A banned word gets the same neutral feedback as an invalid word (no highlight, no penalty). | decision 0004 §7 |
| FR-CORE-06 | P1 | A level is complete exactly when all level words are found; completion fires once. | |
| FR-CORE-07 | P1 | Finding a level word reveals all its cells; cells already revealed by intersections or hints stay revealed and are not counted twice. | |
| FR-CORE-08 | P1 | Level state (found words, revealed cells, found bonus words) survives app kill mid-level. | resume test |

### FR-WHEEL: Letter wheel
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-WHEEL-01 | P1 | Touch down on a tile starts a word; dragging over further tiles appends them; release submits. | rules: `GAME_DESIGN.md#letter-wheel` |
| FR-WHEEL-02 | P1 | The connecting line follows the finger every frame with no per-frame allocations. | NFR-01, NFR-02 |
| FR-WHEEL-03 | P1 | Moving back onto the previous tile removes the last tile (backtrack). | |
| FR-WHEEL-04 | P1 | Tile hit radius is larger than the tile art; a tile cannot be selected twice in one word. | token `Touch.TILE_HIT_RATIO` (`DESIGN.md#touch-and-layout`) |
| FR-WHEEL-05 | P1 | A second finger is ignored while a word is in progress. | manual + unit |
| FR-WHEEL-06 | P1 | The current word previews above the wheel while dragging. | |
| FR-WHEEL-07 | P1 | Each newly selected tile triggers haptic `tick` (if haptics enabled) and a visual selected state. | FR-AUDIO |
| FR-WHEEL-08 | P1 | Shuffle permutes tile positions only; the visible order differs from the current one whenever at least two letters differ; ignored during a drag. | rules: `GAME_DESIGN.md#power-ups`; free, unlimited |
| FR-WHEEL-09 | P1 | The wheel supports the letter counts the content uses (intent 3–7, landmarks up to 8) without overlap. | `CONTENT.md#level-schema` |

### FR-BOARD: Crossword board
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-BOARD-01 | P1 | The grid renders from level data coordinates (`x`, `y`, `dir`) with no layout logic in the client beyond scaling. | `CONTENT.md#level-schema` |
| FR-BOARD-02 | P1 | The grid scales to fit the available rectangle without scrolling for every grid up to the content limit (intent 10×10). | tested across layout classes |
| FR-BOARD-03 | P1 | A found level word animates its letters into the cells. | P2: final motion per `DESIGN.md#level-motion` |
| FR-BOARD-04 | P1 | ALREADY_FOUND highlights the existing word on the board. | |
| FR-BOARD-05 | P1 | BONUS feedback is distinct from LEVEL feedback by colour plus icon/text (never colour alone). | NFR-11 |
| FR-BOARD-06 | P1 | INVALID feedback is a short neutral shake of the preview; no sound punishment, no counter. | |
| FR-BOARD-07 | P1 | On completion the next level is preloaded during the completion sequence and becomes interactive with no loading screen. | NFR-03 |

### FR-HINT: Hint, Reveal, Shuffle
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-HINT-01 | P1 | Hint reveals exactly one unrevealed cell, chosen deterministically by `HintLogic`. | rules: `GAME_DESIGN.md#hints` (selection order, e.g. intersections first) |
| FR-HINT-02 | P1 | Hint is unavailable (button disabled) on a complete level and does nothing when no unrevealed cell exists. | |
| FR-HINT-03 | P2 | Hint consumes one Hint item if owned, otherwise `economy.price.hint` coins; the cost is charged exactly once per use. | test: double tap, kill during use |
| FR-HINT-04 | P2 | Reveal reveals one whole unfound level word (deterministic choice) and costs one Reveal item or `economy.price.reveal` coins. | rules: `GAME_DESIGN.md#hints` |
| FR-HINT-05 | P2 | When the player cannot afford a hint, the button offers a rewarded ad (if available) or the shop; it is never a dead button. | FR-ADS-04 |
| FR-HINT-06 | P1 | Shuffle is free, unlimited and never changes board, economy or progress state. | FR-WHEEL-08 |
| FR-HINT-07 | P2 | Contextual "stuck" offer: after `hint.offer_idle_seconds` (default 45) without a found word, or after `hint.offer_invalid_streak` (default 5) INVALID attempts in a row, the Hint button pulses with an inline label, at most once per level; no popup. | rules: `GAME_DESIGN.md#hints` |

### FR-PROG: Progression and campaign slots
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-PROG-01 | P1 | The campaign is a fixed sequence of numbered slots; the save stores the highest completed slot and the current slot. | rules: `GAME_DESIGN.md#progression` |
| FR-PROG-02 | P1 | Completing a level advances to the next slot immediately. | |
| FR-PROG-03 | P2 | Slot → location → region mapping comes from the content manifest, never from code. | `CONTENT.md#manifest` |
| FR-PROG-04 | P2 | Feature unlocks (shuffle, bonus meter, hint, journey/home, reveal, double reward, daily) are driven only by `unlocks.*_slot` config keys and persist once unlocked. | `GAME_DESIGN.md#unlocks`; constraint in [First 10 minutes](#first-10-minutes-timeline) |
| FR-PROG-05 | P2 | Progress is kept per content language; switching language never loses progress in another language. | |
| FR-PROG-06 | P2 | Completed campaign levels cannot be replayed in v1; the journey shows them as complete only. | rules: `GAME_DESIGN.md#progression` (confirm) |
| FR-PROG-07 | P3 | The player reaching the last shipped slot sees a "more levels coming" state with daily still available; never a crash or empty screen. | |

### FR-META: Stars, journey, postcards, landmarks
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-META-01 | P2 | Each completed level awards stars per `meta.stars.per_level` (intent: 1; extra stars for no hints is an open question). | rules: `GAME_DESIGN.md#stars` |
| FR-META-02 | P2 | Each location has one postcard split into `meta.postcard.pieces` pieces; pieces reveal in order each time the location's star total reaches the next threshold (`meta.postcard.piece_star_cost` stars per piece); stars are not spent. | rules: `GAME_DESIGN.md#postcards` |
| FR-META-03 | P2 | Completing all levels of a location completes its postcard and unlocks the next location; completing a region's locations unlocks the next region. | |
| FR-META-04 | P2 | Journey screen shows regions and locations with locked / in progress / complete states. | `DESIGN.md#journey-1-region` |
| FR-META-05 | P2 | Home shows the current location, its postcard progress, the next level number and one primary Play action. | `DESIGN.md#home` |
| FR-META-06 | P3 | Postcard collection screen lists all earned postcards, including monthly calendar postcards. | |
| FR-META-07 | P3 | Landmark levels (larger, hand-made) appear at manifest-defined slots, followed by an easier "breather" level. | rules: `GAME_DESIGN.md#landmarks`, `CONTENT.md#curve` |
| FR-META-08 | P2 | Earned stars, pieces and postcards are never removed by any update or rebalance. | rule: never take away earned items |

### FR-ECON: Economy
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-ECON-01 | P2 | One currency (coins, integer) plus an inventory of items (Hint, Reveal). Stars are not currency. | rules: `GAME_DESIGN.md#economy-intents` |
| FR-ECON-02 | P2 | Every balance change goes through `grant(source, items)` / `spend(sink, items) -> bool` with a reason; balances never go negative. | unit tests |
| FR-ECON-03 | P2 | Every transaction is appended to a bounded journal in the save (`economy.journal.max_entries`) and tracked in analytics. | |
| FR-ECON-04 | P2 | All prices and rewards come from config keys (`economy.price.*`, `economy.reward.*`), never from code. | CI `registries` check |
| FR-ECON-05 | P2 | Level completion grants `economy.reward.level_complete`; rewarded "double reward" multiplies it by `economy.reward.double_multiplier`. | |
| FR-ECON-06 | P2 | `tools/econ_sim.py` simulates player archetypes (saver, hinter, ad watcher) over 300 levels and reports balance over time; run on every economy config change. | intents in `GAME_DESIGN.md#economy-intents` |
| FR-ECON-07 | P2 | No currency is ever required to progress in the campaign: every level is completable without hints. | |

### FR-BONUS: Bonus words and bonus chest
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-BONUS-01 | P1 | Bonus words are recognized and give positive feedback; each bonus word counts once per level. | |
| FR-BONUS-02 | P2 | Each new bonus word adds 1 to the BonusMeter; at `bonus.chest.words_required` the chest opens and grants `economy.reward.bonus_chest`; surplus carries over. | rules: `GAME_DESIGN.md#bonus-chest` |
| FR-BONUS-03 | P2 | The bonus counter persists across levels and sessions. | save roundtrip |
| FR-BONUS-04 | P3 | Bonus list changes from dictionary repairs apply to released levels without affecting saved progress. | FR-CONT-04 |

### FR-DAILY: Daily puzzle and monthly calendar
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-DAILY-01 | P3 | Every day has one daily puzzle, the same for all players of a language, chosen from the daily pool by the device's local date. | rules: `GAME_DESIGN.md#daily`; decision `0003-local-date` |
| FR-DAILY-02 | P3 | Daily unlocks at `unlocks.daily_slot`. | |
| FR-DAILY-03 | P3 | Completing the daily grants `economy.reward.daily` and marks the day on the monthly calendar. | |
| FR-DAILY-04 | P3 | Completing every day of a calendar month grants that month's exclusive postcard. | rules: `GAME_DESIGN.md#monthly-calendar` (catch-up of missed days is an open question) |
| FR-DAILY-05 | P3 | Daily works offline: pool and calendar ship in the app. | NFR-06 |
| FR-DAILY-06 | P3 | Day boundaries, time-zone changes and DST are handled by pure logic with an injected date; clock rollback has defined (not "safe") behaviour. | unit tests per `TESTING.md` |

### FR-STREAK: Streak and freeze
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-STREAK-01 | P3 | The streak counts consecutive local days with a completed daily puzzle. | rules: `GAME_DESIGN.md#streak` |
| FR-STREAK-02 | P3 | A missed day consumes one held freeze automatically instead of breaking the streak. | |
| FR-STREAK-03 | P3 | The player receives `streak.freeze.weekly_grant` freezes per week, capped at `streak.freeze.max_held`. | |
| FR-STREAK-04 | P3 | A broken streak can be repaired once via a rewarded ad within `streak.repair.window_hours`. | FR-ADS-04 |
| FR-STREAK-05 | P3 | Streak state, freezes and history survive reinstall via OS backup and app updates via migrations. | FR-SAVE |

### FR-ONB: Onboarding
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-ONB-01 | P2 | First launch goes straight into level 1: no login, offer, daily, notification or rating prompt. | |
| FR-ONB-02 | P2 | Levels 1–15 are hand-made and follow the timeline in [First 10 minutes](#first-10-minutes-timeline). | rules: `GAME_DESIGN.md#onboarding`; Opus second opinion |
| FR-ONB-03 | P2 | Each new feature is introduced at most once with one coach mark that can be dismissed with any tap. A coach mark is the target component's highlighted state plus one inline caption beside it: no overlay, no popup. | `DESIGN.md#feature-unlock-gating` |
| FR-ONB-04 | P2 | Apart from consent/ATT and coach marks, at most `onboarding.max_prompts_per_session` (intent 1) non-gameplay prompts (offers, rating, notices) appear per session. | |
| FR-ONB-05 | P2 | Every onboarding step emits `onboarding_step` so the funnel is measurable per step. | FR-ANL |

### FR-ADS: Ads
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-ADS-01 | P2 | Interstitial decisions come only from the pure function `should_show_interstitial(state, config, now)`. | rules: `GAME_DESIGN.md#ad-policy` |
| FR-ADS-02 | P2 | No interstitial before `ads.interstitial.first_slot`, more often than `ads.interstitial.min_levels_between` levels and `ads.interstitial.min_seconds_between`, within `ads.interstitial.session_grace_seconds` of session start, or within `ads.interstitial.purchase_grace_levels` after any purchase. | unit tests per condition |
| FR-ADS-03 | P2 | Interstitials appear only between campaign levels: never during a level or a daily puzzle, never on app open. | |
| FR-ADS-04 | P2 | Rewarded rewards are granted only in the "reward earned" callback; closing early grants nothing. | |
| FR-ADS-05 | P2 | When a rewarded ad is unavailable (no fill, offline, consent), the UI says so and offers the alternative; no spinner without end. | |
| FR-ADS-06 | P2 | Ad SDK initializes only after the UMP flow resolves; on iOS no ad is requested before ATT resolves; personalization follows consent. | FR-CONSENT |
| FR-ADS-07 | P2 | With Remove Forced Ads owned, no interstitials and no full-screen own-offer interstitials appear; rewarded stays available. | FR-IAP-02 |
| FR-ADS-08 | P2 | Game audio pauses during ads and resumes after; backgrounding during an ad leaves a consistent state. | device checklist |
| FR-ADS-09 | P3 | Ad frequency keys are remotely tunable and A/B-testable without a build. | FR-CFG |
| FR-ADS-10 | Later | Mediation adapters are added only if fill rate or eCPM data requires it. | |

### FR-IAP: In-app purchases
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-IAP-01 | P2 | The shop sells the P2 catalog (see [Monetization](#monetization)) with store-localized prices. | |
| FR-IAP-02 | P2 | Remove Forced Ads is a non-consumable entitlement that disables interstitials permanently. | |
| FR-IAP-03 | P2 | Purchase processing is idempotent by the store transaction key (iOS StoreKit 2 `Transaction.id`, Android `purchaseToken`; never `orderId`): an already-processed key grants nothing and is only finished. | unit tests with fake store |
| FR-IAP-04 | P2 | Order is fixed: grant (or set entitlement) → atomic save flush → finish/consume/acknowledge in the store. | crash between steps must not lose or double grant |
| FR-IAP-05 | P2 | Unfinished transactions are fetched and processed through the same flow on every app start. | |
| FR-IAP-06 | P2 | Restore Purchases is in Settings on iOS and Android, and additionally in the Shop sheet on iOS; it restores non-consumables only. | |
| FR-IAP-07 | P2 | Pending and deferred purchases (Play pending, Ask to Buy) show a pending state and complete later through FR-IAP-05. | |
| FR-IAP-08 | P2 | Purchases are verified locally (StoreKit 2 signed transactions, Play Billing signature); no backend. | accepted fraud risk (design pass 03 §4.4) |
| FR-IAP-09 | P3 | Additional coin packs and a one-time starter pack are added. | open question on contents |
| FR-IAP-10 | Later | Piggy bank or pass, only if data supports it. | |
| FR-IAP-11 | P2 | Once granted, Remove Forced Ads is never revoked locally; refunds and revocations are not tracked. | accepted loss, consistent with local verification and no backend; principle 7 |

### FR-CONSENT: Privacy consent
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-CONSENT-01 | P2 | Google UMP consent info is requested on every launch; the form is shown when required, on Level complete of `consent.ump_after_slot` for a new player, and always before ad SDK initialization. | [First 10 minutes](#first-10-minutes-timeline) |
| FR-CONSENT-02 | P2 | Analytics collection respects consent; events before a consent decision are queued locally and sent or dropped per the outcome. Crash reporting starts at first launch without advertising identifiers and is listed under legitimate interest in the privacy policy; if the provider chosen in Q8 cannot run that way, or Q7 rules otherwise, it starts only after the consent decision. | verify current provider consent-mode rules (Q7, Q8) |
| FR-CONSENT-03 | P2 | Settings contains a Privacy options entry that reopens the UMP privacy options form when required. | |
| FR-CONSENT-04 | P2 | iOS ATT is requested on Level complete of `consent.att_after_slot`, preceded by UMP's IDFA explainer message, never at first launch and before the first ad-capable unlock; no custom pre-prompt screen; denial still allows non-personalized ads. | constraint in [First 10 minutes](#first-10-minutes-timeline) |

### FR-SET: Settings
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-SET-01 | P2 | Sound-effects and music volume sliders; toggles for haptics, reduced motion and high contrast; text size (2 steps above default). | `DESIGN.md#accessibility` |
| FR-SET-02 | P2 | Language selector listing only languages whose content ships (from the manifest); EN UI before EN content is reachable in debug builds only. | FR-LOC-01 |
| FR-SET-03 | P2 | Restore Purchases, Privacy options, Privacy policy link, support contact (opens mail with `install_id` prefilled), licenses/credits screen including the Godot engine licence and third-party notices (`Engine.get_license_text()`, `Engine.get_copyright_info()`) plus SDK, font, icon, audio and dictionary/frequency attributions. | FR-IAP-06, compliance |
| FR-SET-04 | P2 | Every setting persists and applies immediately without restart. | |

### FR-LOC: Localization
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-LOC-01 | P2 | One language setting drives UI and content together; default is the device language if its content ships, else Polish. A release build never shows UI in a language whose content does not ship. | design pass 03 §4.9; decision 0005 |
| FR-LOC-02 | P1 | All UI strings come from per-area CSV files with English keys; no literal player-facing strings in code or scenes. | CI check (P2) |
| FR-LOC-03 | P2 | UI strings complete in PL and EN; DE in P3. | |
| FR-LOC-04 | P2 | No player-facing sentence depends on a plural form: counts are shown as number + icon or "Label: N" (Godot CSV translations have no plural forms; Polish has three). | `DESIGN.md#copy-and-tone`; string review in CI |
| FR-LOC-05 | P2 | Store listings, privacy policy and consent texts exist in each shipped language. | |

### FR-A11Y: Accessibility
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-A11Y-01 | P2 | All interactive elements meet `Touch.MIN_TARGET`. | gallery review |
| FR-A11Y-02 | P2 | Reduced motion maps motion tokens to `Motion.INSTANT` in one place. | |
| FR-A11Y-03 | P2 | High-contrast palette variant and two larger text steps keep every screen usable in all layout classes. | |
| FR-A11Y-04 | P2 | Every IconButton, NavTab, Toggle, Slider, HintButton and CurrencyPill has an accessibility label key. Labels are exposed to TalkBack/VoiceOver only if the pinned Godot version supports mobile screen readers (checked in spike S1); otherwise exposure moves to Later. Full gameplay support for blind players is not promised. | |

### FR-AUDIO: Audio and haptics
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-AUDIO-01 | P1 | Code plays named cues from the registry (`data/audio/cues.json`); placeholder sounds in P1. | |
| FR-AUDIO-02 | P1 | Named haptic patterns `tick`, `soft`, `success`, `error` via the platform adapter; no-op where unsupported. | iOS native generators if S1 confirms |
| FR-AUDIO-03 | P2 | Final cue set for letter select, word found, bonus, invalid, level complete, chest, UI tap; pitch variation per registry. | |
| FR-AUDIO-04 | P2 | Separate volumes for sound and music; respects the device silent switch on iOS for sound effects. | verify Godot behaviour in S1 |

### FR-ANL: Analytics
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-ANL-01 | P2 | Code tracks only events defined in the registry (`data/analytics/*.json`); debug builds fail loudly on unknown names or parameters. | CI `registries` |
| FR-ANL-02 | P2 | Events are queued offline and sent when possible; the queue is bounded. | `analytics.queue.max_events` |
| FR-ANL-03 | P2 | Events carry `install_id`, app version, content version, language and A/B buckets; no personal data. | NFR-10 |
| FR-ANL-04 | P2 | `invalid_word_submitted` records language, slot and the letter string for dictionary repair. | design pass 09 §7 |
| FR-ANL-05 | P2 | Crash reports with app and content version reach the crash provider chosen in S1. | |
| FR-ANL-06 | P3 | Per-slot telemetry (time, hints, abandon) feeds difficulty calibration of `scoring.yaml`. | |

### FR-CFG: Configuration, remote config, A/B
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-CFG-01 | P1 | Every balance number has a registry entry in `data/config/*.json`: default, type, range, description, owner. | CI `registries` |
| FR-CFG-02 | P2 | A static remote JSON (CDN) overrides a subset of keys; unknown keys are ignored and logged; wrong types or out-of-range values are rejected keeping defaults. | unit tests |
| FR-CFG-03 | P2 | Remote config fetch never blocks start; the last valid remote config is cached and used offline. | `config.remote.timeout_ms` |
| FR-CFG-04 | P2 | A/B bucket = `hash(install_id + experiment_id) % 100`; experiments defined in remote JSON; buckets sent as analytics user properties. | |
| FR-CFG-05 | P3 | At least one experiment (ad frequency) runs in soft launch. | Hypotheses H1 |

### FR-SAVE: Save
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-SAVE-01 | P1 | One JSON save file with `schema_version`, sections per service (`progress`, `economy`, `daily`, `monetization`, `settings`, `meta`). | `ARCHITECTURE.md#save` |
| FR-SAVE-02 | P1 | Writes are atomic (temp file + rename) and keep the previous version as backup. | interruption test |
| FR-SAVE-03 | P1 | A corrupt save falls back to the backup; if both fail the game starts clean and emits `save_corrupted` (P2+). | |
| FR-SAVE-04 | P1 | Migrations are a chain `migrate_vN_to_vN+1`, each with a golden-file test. | |
| FR-SAVE-05 | P1 | Saves happen on meaningful events (word found, level complete, transaction, settings change, background), never per frame. | |
| FR-SAVE-06 | P2 | The save lives in a location covered by OS backup (Android Auto Backup rules, iOS backed-up directory). | device test: restore to new device |
| FR-SAVE-07 | P1 | A random `install_id` is created once and stored in the save; no accounts. | |
| FR-SAVE-08 | P2 | Processed store transaction keys (per FR-IAP-03) are stored in the save. | FR-IAP-03 |
| FR-SAVE-09 | Later | Cloud save via a platform adapter merges sections (max for progress, union for transactions). | format ready from P1 |

### FR-CONT: Content
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-CONT-01 | P1 | Levels ship as JSON packs (~100 levels each) plus a manifest with content version and hashes, validated by JSON Schema in the pipeline and in CI. | `CONTENT.md#level-schema` |
| FR-CONT-02 | P1 | Each level contains letters, grid words with coordinates, the complete bonus list, difficulty, seed and pipeline version. | |
| FR-CONT-03 | P2 | Released slots are immutable (letters, grid, level words); CI blocks changes against the lock file. | `CONTENT.md#slot-policy` |
| FR-CONT-04 | P2 | Bonus lists of released slots may change (dictionary repairs) without breaking saves. | |
| FR-CONT-05 | P1 | Word validity comes only from the licensed source and `overrides/<lang>.csv`; an LLM may classify, never decide validity. | design pass 09 §1 |
| FR-CONT-06 | P1 | Pipeline output is deterministic: same inputs and pipeline version produce byte-identical packs. | pipeline tests |
| FR-CONT-07 | P1 | CI bot test loads every shipped level through the runtime and completes it with its level words. | `TESTING.md` |
| FR-CONT-08 | P3 | Daily pool is a separate pack plus a date → puzzle calendar; no duplicates against the campaign. | |
| FR-CONT-09 | Later | Content packs downloadable without an app update. | |

### FR-PLAT: Platform services
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-PLAT-01 | P1 | Every platform service (ads, IAP, analytics, crash, consent, haptics, review, notifications) sits behind an adapter with a Fake implementation; the game runs in editor and CI with Fakes only. | `ARCHITECTURE.md#platform` |
| FR-PLAT-02 | P1 | Android release-candidate builds come from CI (APK/AAB); iOS builds nightly and before release. | |
| FR-PLAT-03 | P2 | Safe areas (notch, Dynamic Island, gesture bar) are respected on every screen via `ScreenScaffold`. | |
| FR-PLAT-04 | P2 | Android back closes an open Sheet; on Level it goes to Home once Home is unlocked, otherwise it moves the app to the background; on Home it moves the app to the background; elsewhere it goes back one screen. No exit-confirmation dialog; the game saves before backgrounding. | FR-PLAT-05 |
| FR-PLAT-05 | P1 | The game saves on going to background and resumes state on return. | |
| FR-PLAT-06 | P3 | In-app review prompt via the native API, once, at a positive moment after `review.prompt_after_slot`, never right after an ad or a broken streak. | |
| FR-PLAT-07 | Later | Opt-in local notification reminding of the daily puzzle. | |
| FR-PLAT-08 | Later | Achievements; Play Games / Game Center only on demand. | |

### FR-DEBUG: Debug tools
| ID | Ph | Requirement | Rules / acceptance |
|---|---|---|---|
| FR-DEBUG-01 | P1 | Debug screen (debug builds only): jump to any slot, show answers, complete level, reset save. | |
| FR-DEBUG-02 | P1 | Debug overlay shows FPS and input-to-line latency estimate on device. | NFR-01 |
| FR-DEBUG-03 | P2 | Grant/remove coins and items, toggle Remove Forced Ads, force fake ad/IAP outcomes (fill, no fill, cancel, pending, crash-before-finish). | |
| FR-DEBUG-04 | P2 | Clock offset (simulate days, time zones), view active config and buckets, live analytics event log. | |
| FR-DEBUG-05 | P3 | Content review mode: play any campaign or daily level by id and flag it to a local report for the pipeline. | design pass 09 §2 stage 12 |
| FR-DEBUG-06 | P1 | Debug code and screens are excluded from release builds (verified on the release artifact). | |

## Non-functional requirements

Reference devices (chosen in Phase 0, recorded in `TESTING.md`): one low-end Android (e.g. 720p,
2–3 GB RAM, Android 10+), one iPhone with notch or Dynamic Island, one iPad.

| ID | Requirement | Target | Measured by |
|---|---|---|---|
| NFR-01 | Input latency | Line and tile selection update on the next rendered frame after the touch event; no perceivable lag judged by Chris on the low-end Android | FR-DEBUG-02 overlay, device review, fun gate |
| NFR-02 | Frame rate | Level scene 60 fps sustained on low-end Android; 120 Hz on high-refresh devices where the engine allows; no frame > 33 ms during a swipe | on-device profiling, P3 desktop proxy test |
| NFR-03 | Level transitions | No loading screen between levels; next level interactive when the completion sequence ends; level data load ≤ 100 ms | instrumented timer in debug builds |
| NFR-04 | Cold start | ≤ 3 s to first interactive screen on low-end Android, ≤ 2 s on iPhone (excluding consent form) | stopwatch on release build |
| NFR-05 | App size | Download ≤ 80 MB at P3 with one content language; warn in CI at 90% of budget | CI artifact size check |
| NFR-06 | Offline play | Campaign, daily, settings and save work fully offline; ads/IAP degrade with a clear message; config and analytics cached/queued | airplane-mode checklist |
| NFR-07 | Stability | Crash-free users ≥ 99.5%; ANR and crash rates below Google Play bad-behaviour thresholds (verify current values) | crash provider, Play Console vitals |
| NFR-08 | Battery and thermal | Menus use low-processor mode; idle level scene does not redraw continuously; no thermal throttling in a 30-minute session on reference devices | device checklist |
| NFR-09 | Device support | Min Android API and iOS version decided after S1 (meet store target-API rules); phones and tablets, portrait | release checklist |
| NFR-10 | Data and privacy | No accounts and no personal data; random `install_id`; data minimization; no data sale; analytics data deletable on request by `install_id` | privacy policy, store forms |
| NFR-11 | Accessibility baseline | Touch targets ≥ `Touch.MIN_TARGET`; information never by colour alone; reduced motion; haptics off; separate volumes; text scaling; high contrast | gallery screenshots, checklist |
| NFR-12 | Localization readiness | Fonts cover PL (`ĄĆĘŁŃÓŚŹŻ`), EN, DE (`ÄÖÜß`) upper and lower case; UI tolerates +35% text length without truncation; no string concatenation | gallery in PL, EN and a pseudo-locale (Godot pseudolocalization, +35% expansion, accents on); DE from P3 |
| NFR-13 | Progress durability | Killing the app at any moment loses at most the current unfinished word attempt | interruption tests, FR-SAVE |
| NFR-14 | Reproducibility | Content builds are deterministic; every shipped pack is traceable to pipeline version and inputs | pipeline tests, manifest hashes |
| NFR-15 | Testability | All rules in `core/` are pure and unit-tested; `make check` is green before every PR | CI |

## Monetization

### Principles
1. Monetization never blocks campaign progress. Every level is solvable without spending.
2. No forced ads during onboarding: no interstitial before `ads.interstitial.first_slot`
   (default 16, i.e. after onboarding level 15).
3. Interstitials are rare, only between levels, and fully governed by the ad policy and remote config.
4. Remove Forced Ads removes interstitials only (and any full-screen own-offer prompts). Rewarded ads
   stay available because they are the player's choice.
5. Rewarded ads are always optional, always explained before playing, and always have an alternative.
6. No banners, no ads disguised as game UI, no popups at launch, no offers right after a purchase.
7. What the player earned or bought is never taken away or nerfed.
8. All prices, rewards and frequencies are config; intents are decided by Chris with an Opus second
   opinion; numbers are tuned by Sol with `econ_sim` and soft-launch data.

### Ad placements
| Placement | Format | Phase | Trigger | Config keys |
|---|---|---|---|---|
| Between levels | Interstitial | P2 | Ad policy allows after level complete | `ads.interstitial.*` |
| Hint when stuck / cannot afford | Rewarded | P2 | Player taps Hint without items or coins | `ads.rewarded.hint.enabled`, `economy.reward.rewarded_hint` |
| Double level reward | Rewarded | P2 | Optional button on level complete | `ads.rewarded.double.enabled`, `economy.reward.double_multiplier` |
| Free coins in shop | Rewarded | P2 | Shop row, daily cap | `ads.rewarded.shop_coins.daily_cap`, `economy.reward.rewarded_coins` |
| Streak repair | Rewarded | P3 | Broken streak within the window | `streak.repair.window_hours` |

### IAP catalog
Product ID convention (proposal, Chris approves): `<type>.<item>.v<N>`, lowercase letters, digits,
underscores and periods only; `nc` = non-consumable, `c` = consumable. No app name in IDs (the store
name is not final). A changed product (content or price tier strategy) gets a new `v<N>` id.

Product IDs are irreversible: once created in Google Play Console or App Store Connect they cannot be
reused after deletion. Create them only after Chris approves this table (verify current store ID
rules at creation time).

| Product ID | Type | Phase | Content |
|---|---|---|---|
| `nc.remove_forced_ads.v1` | non-consumable | P2 | Disables interstitials permanently; restorable |
| `c.coins_s.v1` | consumable | P2 | `iap.coins_s.amount` coins |
| `c.coins_m.v1` | consumable | P3 | `iap.coins_m.amount` coins |
| `c.coins_l.v1` | consumable | P3 | `iap.coins_l.amount` coins |
| `c.starter_pack.v1` | consumable, one purchase per install enforced in game | P3 | coins + Hint + Reveal items only (no entitlements, so restore is not needed) |

Price points are Chris's decision per store. Research reference for Poland: Remove Forced Ads around
24.99 PLN (Words of Wonders charges about 49.99 PLN), small coin pack 4.99 PLN, starter pack 9.99 PLN.

## Analytics and KPIs

### KPIs
| KPI | Definition / how measured | Reference |
|---|---|---|
| D1 / D7 / D30 retention | Share of installs with an `app_boot` or `app_foreground` on day N (install cohort, local day) | ~30% / ~13% / ~8% (research benchmark) |
| Onboarding completion | Share of installs completing level 15 | funnel F1 |
| Levels per session, sessions per day, session length | From `level_complete` and `app_boot` / `app_foreground` / `app_background` timestamps | |
| Per-slot abandon rate | Sessions ending inside a level without completion, per slot | difficulty spikes |
| Hints per level | `hint_used` + `reveal_used` per `level_complete`, per slot | economy intents |
| Invalid-word rate | `invalid_word_submitted` per level; top strings per week | dictionary quality |
| Bonus words per level | `bonus_word_found` per `level_complete` | |
| Rewarded opt-in | `ad_reward_earned` / rewarded offers shown | |
| Interstitials per DAU | `ad_shown` (interstitial) / DAU | below category; target set after soft launch |
| IAP conversion, ARPPU | Payers / installs; revenue / payers | |
| ARPDAU | (ad revenue estimate + IAP revenue) / DAU | ad revenue from ad network reporting |
| Daily participation, streak length | `daily_complete` / DAU; distribution of `streak_updated.length` | P3 |
| Crash-free users, ANR rate | Crash provider, Play Console vitals | NFR-07 |
| Store listing conversion | Store consoles | |

### Core events (seed of the registry)
Names are snake_case, stable, and become `data/analytics/*.json`. Renaming breaks history: treat names
as irreversible (Opus second opinion before the first production release). Avoid names reserved by the
provider chosen in S1 (for example Firebase reserves `first_open`, `session_start`, `screen_view`).

| Area | Events |
|---|---|
| Lifecycle | `app_boot`, `app_foreground`, `app_background`, `nav_screen` |
| Consent | `consent_result`, `att_result` |
| Onboarding | `onboarding_step`, `feature_unlocked` |
| Level | `level_start`, `level_complete`, `word_found`, `bonus_word_found`, `invalid_word_submitted`, `already_found_word` |
| Tools | `hint_used`, `reveal_used`, `shuffle_used`, `hint_stuck_offer_shown` |
| Economy | `economy_grant`, `economy_spend`, `bonus_chest_opened` |
| Meta | `stars_earned`, `postcard_piece_revealed`, `location_complete`, `region_complete` |
| Daily | `daily_start`, `daily_complete`, `calendar_month_complete`, `streak_updated`, `streak_freeze_used`, `streak_broken`, `streak_repaired` |
| Ads | `ad_offer_shown`, `ad_shown`, `ad_reward_earned`, `ad_failed` |
| IAP | `shop_opened`, `iap_purchase_started`, `iap_purchase_completed`, `iap_purchase_failed`, `iap_restore_completed` |
| System | `settings_changed`, `save_corrupted`, `save_migrated`, `remote_config_applied`, `experiment_assigned`, `content_version_loaded` |

### Funnels
- F1 Onboarding: `app_boot` (first) → `level_complete` slot 1 → `consent_result` → `level_complete`
  slot 3 → 5 → 7 → 10 → 15 → `app_boot` on day 1. In the EEA, events before the consent decision are
  queued (FR-CONSENT-02), which is why consent comes after slot 1 and not later.
- F2 Hint: `hint_stuck_offer_shown` → `hint_used` or `ad_offer_shown` → `ad_reward_earned` → `hint_used`.
- F3 IAP: `shop_opened` → `iap_purchase_started` → `iap_purchase_completed`.
- F4 Daily (P3): `feature_unlocked` (daily) → `daily_start` → `daily_complete` → `daily_complete` next day.
- F5 Dictionary loop (P3): weekly top `invalid_word_submitted` strings → source check → override →
  new bonus lists shipped.

## Compliance and store requirements

| Topic | Requirement | Phase | Owner |
|---|---|---|---|
| GDPR / EEA consent | Google-certified CMP (UMP) runs before ad SDK init; privacy options re-accessible from Settings | P2 | Chris (legal), Sol (impl) |
| ATT (iOS) | Prompt at a controlled moment after an explainer; no tracking without authorization | P2 | Chris, Sol |
| Privacy policy | Public URL, linked in stores and Settings; lists data collected (install_id, gameplay events, invalid letter strings, ad identifiers per consent), processors, retention, deletion contact | P2 | Chris |
| Google Play Data safety | Form matches actual SDK behaviour (ads, analytics, crash) | P2 | Chris |
| Apple privacy labels | App Privacy details match SDK behaviour; SDK privacy manifests included | P2 | Chris |
| Target audience | Play target age group 18 and over only (outside the Families policy); not designed for children; ad requests not tagged child-directed or under age of consent | P2 | Chris |
| Content / age rating | IARC questionnaire in Play Console; App Store age-rating questionnaire (ads and IAP disclosed) | P2, before closed test | Chris |
| EU trader status (DSA) | Declare trader status in App Store Connect (required for IAP distribution in the EU); Play shows developer contact details for monetized apps. The address, phone and email become public: choose a business or virtual address before entering them | Phase 0, with accounts | Chris |
| app-ads.txt | AdMob `app-ads.txt` at the root of the developer website listed in both stores; host it on the same domain as the privacy policy (custom domain or a `<user>.github.io` user-site root, not a project subpath) | P2, before closed test | Chris |
| Engine and SDK notices | Godot MIT licence, its third-party notices and SDK licences shown in Settings > Licences (FR-SET-03) | P2 | Sol |
| Google Play testing | New personal developer accounts must run a closed test before production access (recently 12 testers for 14 days; verify current rules) | start in P2 | Chris |
| Store accounts | Google Play Console and Apple Developer accounts created early (identity verification can be slow) | Phase 0 | Chris |
| Dictionary licence | PL source (e.g. SJP.pl word list for games, PoliMorf) licence permits commercial use of derived data; attribution shown in licenses screen | Phase 0 (S3) | Chris |
| Frequency data licence | e.g. `wordfreq` data is CC BY-SA: confirm whether embedding derived results is allowed, or count on a corpus with a clear licence | Phase 0 (S3) | Chris |
| Fonts | Licence allows app embedding (e.g. OFL) | P2 | Chris |
| AI-generated art | Image tool terms allow commercial use; keep prompt/style record | P2/P3 | Chris |
| Icons, audio | Open licences (e.g. Lucide, Material Symbols) with attribution where required | P2 | Sol |
| Trademark | "World of Words" is close to "Words of Wonders": search EUIPO/USPTO and stores before choosing the store name | before P2 store listing | Chris |
| Store policies | No ads disguised as UI, close buttons visible, accurate store screenshots (real gameplay) | P2 | Chris |

## Content requirements

| Phase | Campaign content | Other content |
|---|---|---|
| P1 | 30–50 PL levels from pipeline v0 (spike S4) + ~10 hand-made | — |
| P2 | 150–200 production PL levels (tiers, AI classification, Chris's review); levels 1–15 hand-made; 1 region with 3–4 locations and their postcards | — |
| P3 | ~500 PL levels before soft launch, 1000+ after; landmarks hand-made; more regions | Daily pool; monthly postcards; EN content after PL works, then DE |

Language rules: Polish rules are fixed by decision `0004-language-rules-pl` (diacritics as separate
tiles, 32-letter alphabet, base forms + very frequent inflections as level words, all valid forms as
bonus words, min length 3, no proper nouns or abbreviations, vulgar words never accepted). EN and DE
each need their own rules decision record before their pipeline runs (decision 0005).

Quality bars:
- No `banned` word appears as a level or bonus word; banned words resolve as INVALID.
- Every level word is `level_ok`; every bonus list is complete for its letters.
- 100% of the first ~100 levels and all landmarks are human-played in the debug review mode; ~5% of
  the rest plus every flagged level are sampled.
- Onboarding levels and landmarks are hand-made (letters + words in YAML); the pipeline only builds
  grids, validates and exports them.
- Difficulty follows the target curve (rising trend per region, saw-tooth wave, landmark spikes,
  breather after landmarks); parameters in `pipeline/config/curve.yaml`.
- No duplicate letter multisets or near-duplicate word sets across campaign and daily pool.
- Locations hold roughly 20–50 levels each (intent, manifest-defined); region 1 covers every P2 slot,
  so no slot is ever outside a location (FR-PROG-03).
- Daily pool size intent: at least 90 days of puzzles exist before daily launches, with a rolling buffer
  of at least 60 days ahead after launch; holiday-themed puzzles optional.

## Hypotheses to validate

| ID | Hypothesis | Metric | Decision it drives | When |
|---|---|---|---|---|
| H1 | Fair ads (no forced ads in onboarding, rare interstitials) monetize acceptably while retaining better | ARPDAU and D7 across A/B buckets of `ads.interstitial.min_levels_between` | Default ad frequency; whether to add mediation | P3 soft launch |
| H2 | Postcards are enough meta; world-building scenes are not needed | D7/D30 of players past level 10 vs before; journey/collection screen visits; qualitative playtests | Invest in world-building scenes or not | P3 + Later |
| H3 | Poland is a viable first market | CPI, D1, ARPDAU in PL soft launch vs targets | Soft-launch market choice; timing of EN content | P3 |
| H4 | The pipeline difficulty curve matches real difficulty | Per-slot abandon rate, hints per level, time per level vs predicted difficulty | Recalibrate `scoring.yaml` weights and curve | P3 |
| H5 | Accepting inflected forms as bonus words is welcome, not confusing | Invalid-word rate on common forms, bonus words per level, review mentions | Revisit decision 0004 | P3 |
| H6 | Players change devices often enough to need real cloud save | `save_corrupted`, restore-from-backup rates, support requests | Build cloud save (Later) | after soft launch |

## Open questions

| # | Question | Owner | Needed by |
|---|---|---|---|
| Q1 | Store name and trademark clearance vs "Words of Wonders" | Chris | before P2 store listing |
| Q2 | Stars per level: always 1, or extra for no hints? | Sol drafts in `GAME_DESIGN.md`, Chris decides | P2 meta epic |
| Q3 | Daily calendar: can missed days of the current month be played later (catch-up), and at what cost? | Sol drafts, Opus second opinion, Chris decides | P3 daily epic |
| Q4 | Does the streak count daily completions only, or any level played that day? | Sol, Chris | P3 |
| Q5 | Starter pack: include it at all, contents, and placement without becoming a popup | Chris, Opus second opinion | P3 |
| Q6 | Price points per store and the coin amounts per pack | Chris | P2 store setup |
| Q7 | Legal basis for analytics and crash reporting before the consent decision (consent moment itself is fixed: UMP after slot 1, ATT after slot 6) | Chris (verify with current Google/legal guidance) | P2 |
| Q8 | Analytics and crash providers (Firebase vs HTTP-based) | Sol, from S1 result | end of Phase 0 |
| Q9 | Minimum Android API and iOS versions | Sol, from S1 | end of Phase 0 |
| Q10 | iPad: portrait only acceptable under current Apple multitasking/orientation rules? | Opus checks, Chris decides | P2 |
| Q11 | PL dictionary and frequency sources and licences | Chris, from S3 | end of Phase 0 |
| Q12 | Soft-launch market: PL vs an English tier-2 market | Chris, Sol prepares data | P3 |
| Q13 | Reference low-end Android device model | Chris | Phase 0 |
| Q14 | Image-generation tool and art style document | Opus (style), Chris (tool, licence) | P2 |
| Q15 | Language selection before EN content: is "debug-only EN UI" acceptable for closed testers? | Chris | P2 |

## Glossary

| Term | Meaning |
|---|---|
| Slot | Fixed campaign position number (1, 2, 3...). Released slots never change their level words or grid. |
| Level word | Word placed in the crossword grid; must be tier `level_ok`. |
| Bonus word | Valid word formable from the letters but not in the grid; counts toward the bonus chest. |
| Invalid | Anything else, including banned words; neutral feedback, no penalty. |
| Tier | Pipeline classification of a word: `level_ok`, `bonus_ok`, `banned`. |
| Override | Chris's manual word decision in `pipeline/overrides/<lang>.csv`; highest priority. |
| Pack / manifest | JSON file with ~100 levels / index of packs with content version, hashes and slot → location → region map. |
| Lock file | Record of released slots that CI uses to block changes to them. |
| Region / location | Journey chapter / place inside it; each location has one postcard. |
| Postcard | One illustration per location revealed piece by piece with stars; replaces world-building in v1. |
| Star | Progress unit earned per level; not a currency. |
| Landmark | Larger hand-made level at manifest-defined slots, followed by a breather. |
| Coins | The only currency. |
| Hint / Reveal / Shuffle | Reveal one cell / reveal one word / rearrange the wheel (free). |
| Bonus chest | Reward granted after a configured number of bonus words. |
| Daily | One puzzle per local date, the same for all players of a language. |
| Monthly calendar | Month view of completed dailies; completing the month grants an exclusive postcard. |
| Streak / freeze | Consecutive days with a completed daily / item that covers one missed day automatically. |
| Interstitial | Full-screen ad between levels, governed by the ad policy. |
| Rewarded | Opt-in ad that grants a reward only after it is watched. |
| Remove Forced Ads | Non-consumable purchase that disables interstitials; rewarded stays. |
| Entitlement | Permanent right from a non-consumable purchase; restorable. |
| UMP / ATT | Google User Messaging Platform (EEA consent) / Apple App Tracking Transparency. |
| install_id | Random UUID created on first launch; used for analytics and A/B buckets. |
| Bucket | Stable A/B group: `hash(install_id + experiment_id) % 100`. |
| Config key / intent | Named balance value in `data/config` / the product goal a number must satisfy. |
| `econ_sim` | Script simulating player archetypes to check economy intents. |
| Fun gate | Phase 1 exit: 5 outsiders play 20+ minutes unprompted; swipe feels instant on low-end Android. |
| Vertical slice | Phase 2: first 30 minutes at release quality on Android and iOS. |
| Soft launch | Limited public release in P3 to collect retention and monetization data. |
| Fake adapter | Platform adapter implementation without an SDK, used in editor and CI. |
