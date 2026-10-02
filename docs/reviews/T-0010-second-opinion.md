# T-0010 — Second opinion on docs v1

- Scope: PRODUCT.md, ARCHITECTURE.md, CONTENT.md, GAME_DESIGN.md; focus on save format, LevelData
  schema, slot policy and IAP flow (ROADMAP T-0010). Date: 2026-10-02.
- Caveat: written in the same Claude Code session that drafted ARCHITECTURE, CONTENT and GAME_DESIGN,
  so it is less independent than a fresh session. Chris may still ask for a fresh review.
- Each finding: severity (high = would cost progress, money or a permanent decision; med = bug likely
  in a later task; low = clarity), proposal. Chris accepted all findings on 2026-10-02; applied in T-0011.

| # | Sev | Doc | Finding | Proposal | Chris |
|---|---|---|---|---|---|
| F1 | high | CONTENT `#slot-policy`, ROADMAP T-0318 | Closed testing starts early in P2 (14-day clock), so the current definition locks slots 1–200 before QA, the curve and onboarding are final. | Slots are released only by production or open-testing rollout. Closed-test and TestFlight builds may change any slot; their testers' progress is kept by slot number only (accepting odd levels). | accept |
| F2 | high | ARCHITECTURE `#save` | The atomic write renames `save.json` → `.bak` and then `.tmp` → `save.json`. A crash between the two renames leaves no `save.json`, and load falls back to the older `.bak`. | Load order: `save.json`; else `save.json.tmp` if it parses and its `schema_version` is valid; else `.bak`. Alternatively, write `.bak` as a copy before the single rename. Add an interruption test per step. | accept |
| F3 | med | ARCHITECTURE `#save`, GAME_DESIGN `#hints` | A hint spends coins and reveals a cell in two writes that may flush separately, so a kill in between can lose a paid hint. | Spend and reveal become one state change in `LevelController`, followed by one `Save.flush()` (synchronous, like IAP). | accept |
| F4 | med | ARCHITECTURE `#save` | The save shape has no place for an unfinished daily puzzle (only campaign `level_state`), yet FR-CORE-08 applies to daily too. | Add `daily.level_state` (day key + the same fields), cleared when the day key changes. | accept |
| F5 | med | GAME_DESIGN `#unlocks`, FR-CFG-02 | Remote config can override unlock and consent slots key by key and break the consent-before-ads constraint. | Validate the constraint on the merged config; if it fails, reject the whole remote payload and keep the defaults. Unlock and consent keys are not remote-tunable in v1. | accept |
| F6 | low | GAME_DESIGN `#ad-policy` | `levels_since_purchase` is null before the first purchase; rule 7 does not say how null is treated. | Null = no purchase yet = rule 7 passes. | accept |
| F7 | low | ARCHITECTURE `#save` | `processed_transactions` grows forever. | Keep it unbounded (a few hundred keys at most is small); state that explicitly so no one trims it. | accept |
| F8 | low | GAME_DESIGN `#economy-intents` | Progress is per language (FR-PROG-05), but it is not stated that coins, items and the bonus meter are shared across languages. | State it: the economy and the bonus meter are global; slots, stars and postcards are per language. | accept |
| F9 | low | CONTENT `#level-schema` | The shuffled tile order is not saved, so a resumed level shows the initial order. | Accept as intended (shuffle is free); write it into GAME_DESIGN `#power-ups`. | accept |
| F10 | low | PRODUCT FR-IAP-08 | Local verification only. With a public repo until P2 and no backend, Remove Forced Ads can be granted by editing the save on rooted devices. | Accept (single-player, low value); no change. | accept |

## Not found
- The IAP order grant → flush → finish with idempotent keys holds up, including restart after a crash
  at each step.
- The LevelData schema gives the game only what it needs; traceability fields stay out of runtime logic.
- No contradictions found between PRODUCT key names and the GAME_DESIGN registry (checked by script in
  T-0006/T-0007).
