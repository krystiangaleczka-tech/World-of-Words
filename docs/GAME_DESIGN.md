# GAME_DESIGN.md — game rules and intents

- Status: v1 draft (T-0006, 2026-10-02). Chris approves it with docs v1 (T-0011) after the Opus second
  opinion (T-0010).
- Owns: the rules behind every `rules: GAME_DESIGN.md#…` reference in `PRODUCT.md`, and the default
  value, type and range of every config key.
- Does not own: requirement IDs, key **names**, event names, IAP product IDs (all canonical in
  `PRODUCT.md`); visuals and flows (`DESIGN.md`); level data and the difficulty curve (`CONTENT.md`);
  code structure (`ARCHITECTURE.md`).

## How to read this file

- **System / config / content** (design pass 03 §6): rules here become code in `core/` and
  `services/`; numbers live in `game/data/config/<file>.json`; levels come from the pipeline.
- A config key is written `<file>.<key>`: `economy.price.hint` lives in
  `game/data/config/economy.json`. The first segment is the file name.
- Defaults marked **canonical** are copied unchanged from `PRODUCT.md#first-10-minutes-timeline`.
  Every other number is a **starting value**: Chris owns the intent, Sol tunes the number with
  `tools/econ_sim.py` (FR-ECON-06) and soft-launch data. A rule never names a number; it names a key.
- Phases follow `PRODUCT.md`: P1 rules are built first; P2/P3 rules may be refined when their epic is
  planned, never silently.

## Word classes

An attempt is the ordered list of tile indices the player connected (FR-CORE-01 … 05). Its word is the
concatenation of those tiles' letters. Evaluation, in this order:

1. Fewer than 3 tiles: **ignored**. No class, no feedback, no analytics (FR-CORE-04, decision 0004).
2. Word is a level word of this level:
   - not yet found → **LEVEL**: the word is found, all its cells reveal (FR-CORE-07);
   - already found (by the player, or because hints revealed all its cells) → **ALREADY_FOUND**.
3. Word is in the level's bonus list:
   - not yet found in this level → **BONUS**: counts once toward the bonus chest (FR-BONUS-01);
   - already found in this level → **ALREADY_FOUND**.
4. Anything else, including banned words → **INVALID**: neutral feedback, no penalty, no counter
   (FR-CORE-05, FR-BOARD-06).

- Lookup is by set membership only (decision 0002). The same word built from different tiles with the
  same letters is the same word (FR-CORE-03).
- A word whose every cell is revealed counts as found at that moment, whatever revealed it.
- The level is complete exactly when every level word is found; completion fires once (FR-CORE-06).
- Found level words, revealed cells and found bonus words survive an app kill (FR-CORE-08).

## Letter wheel

- Touch down on a tile starts an attempt with that tile. Touch down outside every tile does nothing.
- While dragging, entering a tile's hit circle (radius = tile radius × `Touch.TILE_HIT_RATIO`,
  `DESIGN.md#touch-and-layout`) appends it, unless it is already in the attempt.
- Entering the **previous** tile removes the last tile (backtrack, FR-WHEEL-03). Re-entering any
  earlier tile does nothing.
- Release submits the attempt (see [Word classes](#word-classes)).
- A second finger is ignored while an attempt is in progress (FR-WHEEL-05).
- An interrupted drag (app backgrounded, system gesture, touch cancel) discards the attempt with no
  feedback.
- Each appended tile plays haptic `tick` when haptics are on; backtrack plays nothing (FR-WHEEL-07).
- Shuffle, Hint and Reveal are ignored during a drag.

## Power-ups

| Power-up | Effect | Cost | Unlock |
|---|---|---|---|
| Shuffle | Permutes the tile positions on the wheel | Free, unlimited (FR-HINT-06) | `unlocks.shuffle_slot` |
| Hint | Reveals one cell ([Hints](#hints)) | 1 Hint item, else `economy.price.hint` coins | `unlocks.hint_slot` |
| Reveal | Reveals one whole unfound level word ([Hints](#hints)) | 1 Reveal item, else `economy.price.reveal` coins | `unlocks.reveal_slot` |

Shuffle rules (FR-WHEEL-08, design pass 06 §4):
- Uses an injected, seeded RNG; never `randi()`.
- If the tiles contain at least two different letters, the new visible order differs from the current
  one: retry the permutation up to 10 times, then rotate by one position.
- If all letters are equal, the order may stay the same.
- Changes nothing but tile positions: board, economy and progress are untouched.
- The shuffled order is not saved; a resumed level shows the initial order (T-0010 F9).

Placement on screen (one power-up per wheel corner) is owned by `DESIGN.md`.

## Hints

**Hint** (FR-HINT-01 … 03):
1. Target word: the shortest unfound level word; ties go to the word listed first in the level data.
2. Revealed cell: the first unrevealed cell of the target word, reading from its start.
3. If that cell was the target word's last unrevealed cell, the word counts as found (and may complete
   the level). The same holds for any crossing word that becomes fully revealed.
4. Hint is disabled on a complete level, and does nothing when no unrevealed cell exists.

**Reveal** (FR-HINT-04): reveals every cell of the longest unfound level word (ties: first in the
level data); the word counts as found.

**Paying** (P2, FR-HINT-03, FR-HINT-05):
- An owned item is used first; otherwise coins are spent. The cost is charged exactly once per use,
  through `Economy.spend`, before the cell is revealed. A failed spend reveals nothing. Spend and reveal
  are one state change followed by one synchronous `Save.flush()`, so a kill never loses a paid hint
  (T-0010 F3).
- Cannot pay: the button opens the hint options (rewarded ad for `economy.reward.rewarded_hint` Hint
  items if available, or the Shop); never a dead button (`DESIGN.md#flow-stuck-player`).
- In P1, Hint is free and unlimited, and Reveal does not exist yet.

**Stuck offer** (P2, FR-HINT-07): the Hint button pulses with an inline label when either
- `hint.offer_idle_seconds` pass with no newly found level or bonus word, or
- `hint.offer_invalid_streak` INVALID attempts happen in a row.

At most once per level. Ignored attempts (under 3 tiles) do not count toward the streak; any LEVEL,
BONUS or ALREADY_FOUND resets it. No popup.

## Progression

- The campaign is a fixed sequence of slots 1, 2, 3, … per content language (FR-PROG-01, FR-PROG-05).
- The save stores, per language, the current slot and the highest completed slot.
- Completing a level advances the current slot by one immediately (FR-PROG-02). There is no level
  select.
- Completed levels cannot be replayed in v1 (FR-PROG-06). The journey shows them as complete.
  Proposed for Chris to confirm in T-0011.
- Slot → location → region comes from the content manifest (FR-PROG-03).
- Last shipped slot completed: a "more levels coming" state, daily still available (FR-PROG-07, P3).

## Unlocks

A gated feature is absent until its slot, then appears with at most one coach mark
(`DESIGN.md#feature-unlock-gating`, FR-ONB-03).

- "At slot N" means the feature is available from the moment slot N becomes the current slot.
- "After slot N" means on the Level complete of slot N.
- Once unlocked, a feature stays unlocked even if a later config lowers or raises its key (FR-PROG-04);
  the save records it.
- Gating is driven only by these keys, never by code constants.

| Key | Default (canonical) | Unlocks |
|---|---|---|
| `consent.ump_after_slot` | 1 | UMP consent form where required (after slot) |
| `unlocks.shuffle_slot` | 2 | Shuffle |
| `unlocks.bonus_meter_slot` | 5 | Bonus meter and chest |
| `consent.att_after_slot` | 6 | iOS ATT prompt with the UMP IDFA explainer (after slot) |
| `unlocks.hint_slot` | 7 | Hint, coins pill, Shop; grants `economy.grant.onboarding_hints` |
| `unlocks.journey_slot` | 10 | Home, journey, postcards |
| `unlocks.reveal_slot` | 12 | Reveal |
| `unlocks.double_reward_slot` | 12 | Rewarded x2 on Level complete |
| `unlocks.daily_slot` | 15 | Daily puzzle and streak (P3) |
| `ads.interstitial.first_slot` | 16 | Interstitials become eligible ([Ad policy](#ad-policy)) |

**Constraint**, checked by a unit test on the config registry:
`consent.ump_after_slot <= consent.att_after_slot < min(unlocks.hint_slot, unlocks.double_reward_slot, ads.interstitial.first_slot)`.
Consent and ATT are resolved before any ad can be offered.

## Stars

- Each completed campaign level awards `meta.stars.per_level` stars (starting value 1), whatever hints
  or items were used (FR-META-01).
- Stars are progress, not currency: never spent, never removed (FR-META-08).
- The daily puzzle awards no stars.
- Q2 (extra star for no hints) is open; see [Open questions](#open-questions).

## Postcards

- Each location has one postcard of `meta.postcard.pieces` pieces (starting value 4) (FR-META-02).
- Each time the location's star total reaches the next multiple of `meta.postcard.piece_star_cost`
  (starting value 12), the next piece reveals, in order. With one star per level, the first piece
  reveals around slot 12, as the timeline intends.
- Completing every level of the location completes its postcard (FR-META-03). Pieces not yet revealed
  reveal together at that moment. The next location then unlocks; the last location of a region also
  unlocks the next region.
- Locations hold roughly 20–50 levels (`PRODUCT.md#content-requirements`). A short location therefore
  completes its postcard on completion rather than through stars; that is intended.
- Revealed pieces and completed postcards are never taken away (FR-META-08).

## Landmarks

- Landmark levels sit at slots the manifest defines (FR-META-07). They are hand-made, larger
  (up to 8 letters, FR-WHEEL-09) and harder; the next slot is an easier breather level
  (`CONTENT.md#curve`).
- Rules are identical to any other level: same word classes, power-ups, rewards and stars. A landmark
  is special in content and presentation only.

## Economy intents

Design in intent units first, numbers second (design pass 03 §6.2). Intents are Chris's decision with
an Opus second opinion; the numbers below are starting values that `econ_sim` checks.

**Intents** (proposed for Chris in T-0011):
1. A player who never watches ads or pays can afford a Hint about once every 4 levels.
2. One rewarded ad is worth about one Hint.
3. The bonus chest opens about every two sessions and is worth about one Hint.
4. A daily puzzle is worth about one Hint.
5. Reveal costs about 2.5 Hints.
6. Coins are never required to progress (FR-ECON-07): every level is solvable without power-ups.

**Rules** (FR-ECON-01 … 05):
- One currency, coins (`int`). Inventory items: Hint, Reveal. Stars are not currency.
- Coins, items and the bonus meter are global across content languages; slots, stars and postcards are
  per language (T-0010 F8).
- Every change goes through `grant(source, items)` or `spend(sink, items) -> bool` with a reason.
  Balances never go negative.
- Every transaction goes to the save journal (bounded by `economy.journal.max_entries`) and to analytics.

| Source | Key | Starting value |
|---|---|---|
| Level complete | `economy.reward.level_complete` | 25 coins |
| Rewarded x2 on Level complete | `economy.reward.double_multiplier` | 2 (applies to the level reward only) |
| Bonus chest | `economy.reward.bonus_chest` | 100 coins |
| Rewarded hint | `economy.reward.rewarded_hint` | 1 Hint item |
| Rewarded free coins in Shop | `economy.reward.rewarded_coins` | 100 coins, at most `ads.rewarded.shop_coins.daily_cap` per local day |
| Daily puzzle | `economy.reward.daily` | 100 coins |
| Onboarding grant at `unlocks.hint_slot` | `economy.grant.onboarding_hints` | 3 Hint items |
| IAP coin packs | `iap.coins_s.amount`, `iap.coins_m.amount`, `iap.coins_l.amount` | 1000 / 2750 / 6000 coins (Q6, Chris) |

| Sink | Key | Starting value |
|---|---|---|
| Hint without item | `economy.price.hint` | 100 coins |
| Reveal without item | `economy.price.reveal` | 250 coins |

## Bonus chest

- From `unlocks.bonus_meter_slot`, each new BONUS adds 1 to the bonus meter (FR-BONUS-02).
- Bonus words found before the unlock are still recognized and get feedback, but do not fill the meter.
- When the meter reaches `bonus.chest.words_required` (starting value 10), the chest opens on the next
  Level complete layer, never mid-level, and grants `economy.reward.bonus_chest`. Surplus words carry
  over.
- The meter persists across levels, sessions and app updates (FR-BONUS-03).
- Daily puzzle bonus words fill the same meter.
- If a dictionary repair removes a word from a bonus list, words already counted stay counted
  (FR-BONUS-04).

## Daily

Day boundaries follow decision 0003 (device local date; defined behaviour on clock changes).

- From `unlocks.daily_slot` (P3), one daily puzzle per day key, the same for all players of a language
  (FR-DAILY-01, FR-DAILY-02).
- A daily puzzle is an ordinary level from the daily pool: same word classes, power-ups and prices.
- Completing it grants `economy.reward.daily` once per day key and marks the day on the monthly
  calendar (FR-DAILY-03).
- It does not change the campaign slot and awards no stars. No interstitial follows a daily puzzle
  (FR-ADS-03).
- An unfinished daily keeps its state until its day key is no longer today; then it is gone unless Q3
  allows catch-up.
- Works offline (FR-DAILY-05).

## Monthly calendar

- Shows the days of the current local month with states future / today / done / missed / frozen
  (`DESIGN.md` `CalendarDay`).
- Completing the daily on every day of a calendar month grants that month's exclusive postcard
  (FR-DAILY-04).
- A day covered by a streak freeze is **not** a completed day for the calendar.
- Catch-up of missed days is open (Q3); see [Open questions](#open-questions).

## Streak

Day boundaries follow decision 0003.

- The streak counts consecutive day keys with a completed daily puzzle (FR-STREAK-01). Campaign levels
  do not count (Q4 draft, below).
- A missed day automatically consumes one held freeze instead of breaking the streak; the day shows
  as frozen (FR-STREAK-02).
- `streak.freeze.weekly_grant` freezes (starting value 1) are granted once per ISO week of the local
  date, up to `streak.freeze.max_held` (starting value 2) (FR-STREAK-03).
- With no freeze left, a missed day breaks the streak. Within `streak.repair.window_hours` (starting
  value 24) after the break is detected, it can be repaired once by a rewarded ad (FR-STREAK-04).
- Streak, freezes and history survive reinstall via OS backup and updates via migrations (FR-STREAK-05).

## Onboarding

- Levels 1–15 are hand-made (letters + words in YAML, `CONTENT.md`) and follow
  `PRODUCT.md#first-10-minutes-timeline`. Opus gives a second opinion on them (FR-ONB-02).

| Slots | Content intent |
|---|---|
| 1 | 3 letters, 1–2 short common words; the tutorial hand shows the gesture |
| 2 | 3 letters, several words |
| 3–4 | 4 letters; repeats likely, so ALREADY_FOUND is seen naturally |
| 5 | Contains one obvious bonus word (first BONUS feedback, meter appears) |
| 6–15 | Gradual growth to 5 letters; no landmark |

- First launch goes straight into level 1: no login, offer, daily, notification or rating prompt
  (FR-ONB-01).
- Each feature is introduced once, by one coach mark that any tap dismisses (FR-ONB-03).
- Apart from consent/ATT and coach marks, at most `onboarding.max_prompts_per_session` (starting value 1)
  non-gameplay prompts per session (FR-ONB-04).
- Each step emits `onboarding_step` (FR-ONB-05).

## Ad policy

**Interstitials** come only from the pure function `should_show_interstitial(state, config, now)`
(FR-ADS-01). It is evaluated after Continue on a campaign Level complete, and returns true only if all
of these hold:
1. The player does not own Remove Forced Ads (FR-ADS-07).
2. The ads SDK is initialized (UMP resolved; on iOS, ATT resolved) (FR-ADS-06).
3. The level just completed is at or after `ads.interstitial.first_slot` (canonical 16).
4. At least `ads.interstitial.min_levels_between` campaign levels (starting value 4) have been completed
   since the last interstitial.
5. At least `ads.interstitial.min_seconds_between` seconds (starting value 180) have passed since the
   last interstitial.
6. At least `ads.interstitial.session_grace_seconds` seconds (starting value 120) have passed since the
   session started.
7. At least `ads.interstitial.purchase_grace_levels` levels (starting value 10) have been completed since
   the last purchase. Before the first purchase this rule passes (T-0010 F6).

- Never during a level or a daily puzzle, never on app open (FR-ADS-03).
- Not loaded or failed: skip silently and go to the next level.

**Rewarded ads** are always opt-in, explained before playing, and have a non-ad alternative
(Monetization principle 5):
- Placements: hint when the player cannot pay (`ads.rewarded.hint.enabled`), x2 on Level complete
  (`ads.rewarded.double.enabled`), free coins in the Shop (daily cap), streak repair (P3).
- The reward is granted only in the reward-earned callback (FR-ADS-04).
- Remove Forced Ads does not remove rewarded ads.

**Never:** banners, ads disguised as game UI, popups at launch, offers right after a purchase
(Monetization principle 6).

## Config key registry

Every key the docs name, with its v1 default. Type `int` unless noted. Range is inclusive. Owner: who
decides a change (Chris = intent; Sol = tuning within the intent). T-0037 and later tasks copy these
into `game/data/config/*.json` (FR-CFG-01).

| Key | Default | Range | Owner | Phase |
|---|---|---|---|---|
| `unlocks.shuffle_slot` | 2 (canonical) | 1–50 | Chris | P2 |
| `unlocks.bonus_meter_slot` | 5 (canonical) | 1–50 | Chris | P2 |
| `unlocks.hint_slot` | 7 (canonical) | 1–50 | Chris | P2 |
| `unlocks.journey_slot` | 10 (canonical) | 1–50 | Chris | P2 |
| `unlocks.reveal_slot` | 12 (canonical) | 1–50 | Chris | P2 |
| `unlocks.double_reward_slot` | 12 (canonical) | 1–50 | Chris | P2 |
| `unlocks.daily_slot` | 15 (canonical) | 1–100 | Chris | P3 |
| `consent.ump_after_slot` | 1 (canonical) | 1–20 | Chris | P2 |
| `consent.att_after_slot` | 6 (canonical) | 1–20 | Chris | P2 |
| `hint.offer_idle_seconds` | 45 (canonical) | 10–600 | Sol | P2 |
| `hint.offer_invalid_streak` | 5 (canonical) | 2–50 | Sol | P2 |
| `ads.interstitial.first_slot` | 16 (canonical) | 1–200 | Chris | P2 |
| `ads.interstitial.min_levels_between` | 4 | 1–20 | Sol | P2 |
| `ads.interstitial.min_seconds_between` | 180 | 30–1800 | Sol | P2 |
| `ads.interstitial.session_grace_seconds` | 120 | 0–1800 | Sol | P2 |
| `ads.interstitial.purchase_grace_levels` | 10 | 0–100 | Sol | P2 |
| `ads.rewarded.hint.enabled` | true (bool) | — | Chris | P2 |
| `ads.rewarded.double.enabled` | true (bool) | — | Chris | P2 |
| `ads.rewarded.shop_coins.daily_cap` | 3 | 0–20 | Sol | P2 |
| `economy.reward.level_complete` | 25 | 0–1000 | Sol | P2 |
| `economy.reward.double_multiplier` | 2 | 1–5 | Sol | P2 |
| `economy.reward.bonus_chest` | 100 | 0–5000 | Sol | P2 |
| `economy.reward.rewarded_hint` | 1 | 1–5 | Sol | P2 |
| `economy.reward.rewarded_coins` | 100 | 0–5000 | Sol | P2 |
| `economy.reward.daily` | 100 | 0–5000 | Sol | P3 |
| `economy.grant.onboarding_hints` | 3 | 0–20 | Chris | P2 |
| `economy.price.hint` | 100 | 1–10000 | Sol | P2 |
| `economy.price.reveal` | 250 | 1–10000 | Sol | P2 |
| `economy.journal.max_entries` | 200 | 50–2000 | Sol | P2 |
| `bonus.chest.words_required` | 10 | 1–100 | Sol | P2 |
| `meta.stars.per_level` | 1 | 1–3 | Chris | P2 |
| `meta.postcard.pieces` | 4 | 1–16 | Chris | P2 |
| `meta.postcard.piece_star_cost` | 12 | 1–100 | Sol | P2 |
| `onboarding.max_prompts_per_session` | 1 | 0–5 | Chris | P2 |
| `iap.coins_s.amount` | 1000 | 1–100000 | Chris (Q6) | P2 |
| `iap.coins_m.amount` | 2750 | 1–100000 | Chris (Q6) | P3 |
| `iap.coins_l.amount` | 6000 | 1–100000 | Chris (Q6) | P3 |
| `streak.freeze.weekly_grant` | 1 | 0–7 | Chris | P3 |
| `streak.freeze.max_held` | 2 | 0–14 | Chris | P3 |
| `streak.repair.window_hours` | 24 | 1–168 | Sol | P3 |
| `review.prompt_after_slot` | 30 | 15–500 | Chris | P3 |
| `config.remote.timeout_ms` | 3000 | 500–10000 | Sol | P2 |
| `analytics.queue.max_events` | 500 | 50–5000 | Sol | P2 |

Ranges protect against typos and bad remote values (FR-CFG-02): a value outside its range is rejected
and the default stays. Remote config may override only keys marked remote-tunable in the registry
file; which ones is decided when FR-CFG-02 is built (P2), starting with `ads.interstitial.*` (FR-ADS-09).
`unlocks.*` and `consent.*` are never remote-tunable in v1. The [Unlocks](#unlocks) constraint is checked
on the merged config; if it fails, the whole remote payload is rejected and defaults stay (T-0010 F5).

## Open questions

Drafts for Chris. Each needs his decision before the epic that uses it is planned
(`PRODUCT.md#open-questions`).

- **Q2 Stars per level.**
  - A: always `meta.stars.per_level` (1).
  - B: +1 star for a level finished without Hint or Reveal.
  - Recommendation: A. B makes paid hints feel like a penalty and pushes players to grind instead of
    using a hint. Needed by the P2 meta epic.
- **Q3 Monthly calendar catch-up.**
  - A: none; a missed day loses the month's postcard.
  - B: missed days of the current month stay playable until the month ends, each unlocked by a
    rewarded ad (or coins when ads are unavailable).
  - Recommendation: B. A makes the monthly postcard fragile after the first missed day, which removes the
    reason to keep playing that month. Opus second opinion, then Chris. Needed by the P3 daily epic.
- **Q4 What the streak counts.**
  - A: daily completions only.
  - B: any played level that day.
  - Recommendation: A, as FR-STREAK-01 already states. It gives the daily a reason to exist and keeps
    the streak one tap from Home. Needed in P3.
- **Q5 Starter pack.** Draft:
  - one purchase per install;
  - shown only as a Shop row from `unlocks.hint_slot`, never as a popup or after a purchase;
  - contents coins + Hint + Reveal items only.

  Chris decides with an Opus second opinion; P3.
