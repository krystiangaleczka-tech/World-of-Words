# 0003 — Day = device local date; no clock-rollback protection

- Status: accepted (planner, 2026-10-02, T-0005). Records design pass 03 §4.5, which PRODUCT.md v1
  already requires. Chris confirms or overrides it when he approves docs v1 (T-0011).
- Context: design pass `03-architektura-gry.md` §4.5; FR-DAILY-01 … 06, FR-STREAK-01 … 05; NFR-06
  (offline). Single-player game, no backend, no leaderboards.

## Decision
1. **Day key = local calendar date of the device** (`YYYY-MM-DD`), read from the injected `Clock` at the
   moment of the action. No server time, no NTP check.
2. **Daily puzzle** for day key D = the calendar entry for D (same for all players of a language,
   FR-DAILY-01). If D lies outside the shipped calendar, the puzzle is picked deterministically from the
   daily pool by D (the pipeline keeps a buffer so this is rare).
3. **One completion per day key.** Rewards and calendar marks are granted at most once per day key.
4. **Streak** = consecutive day keys with a completed daily (FR-STREAK-01), evaluated from the stored
   completed day keys and the latest day key ever seen (`last_seen_day`, stored in the save).
5. **Defined edge behaviour (FR-DAILY-06):**
   | Case | Behaviour |
   |---|---|
   | Midnight passes during a daily | The puzzle that was opened finishes and counts for the day key it was opened on. |
   | Time-zone travel or DST makes a day repeat | Already completed → nothing new. |
   | Time-zone travel skips a day | Treated as a missed day (freeze rules apply). |
   | Clock moved forward | Treated as real time: missed days consume freezes or break the streak. |
   | Clock moved back (D < `last_seen_day`) | The daily for D is playable; its coins are granted only if D was never completed; streak and calendar do **not** change. `last_seen_day` never decreases. |
   | Weekly freeze grant | Once per ISO week key of the local date. |
   | Repair window (`streak.repair.window_hours`) | Measured on the device clock; a rollback can extend it. Accepted. |
6. All of this is pure logic in `core/` with the date as a parameter; services read `Clock` (dp03 §4.5).

## Why
- Offline-first with no backend: there is no trustworthy time source, and asking for one breaks offline
  play (NFR-06).
- Cheating the clock only harms the cheater's own single-player experience; there is no leaderboard or
  trade to protect. Rule 5 still stops rollback from farming coins or rebuilding a streak.

## Consequences
- `GAME_DESIGN.md#daily` and `#streak` (T-0006) cite this decision; TESTING.md (T-0009) lists the
  edge-case tests from the table above.
- Save stores completed day keys and `last_seen_day` (ARCHITECTURE.md#save).

## Revisit if
- Leaderboards, events with shared rewards or any server-validated reward are added.
