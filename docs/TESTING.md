# TESTING.md — what we test, how, and on which devices

- Status: v1 (T-0009, 2026-10-02). Chris approves with docs v1 (T-0011).
- Principle (design pass 08): test hard what costs money, player progress or trust; check the rest by eye.
- Writing rules for tests are in `AGENTS.md#tests`; this file says what must be tested.

## Pyramid

```
          ▲  manual on device: game feel, ads, IAP sandbox, looks, performance
         ▲▲  headless integration: boot smoke, bot plays every level, save roundtrip
      ▲▲▲▲▲  unit (GUT): core/, migrations, IAP flow, ad policy, streak, registries
▲▲▲▲▲▲▲▲▲▲▲  pipeline (pytest + hypothesis) + content validation: the widest base
```

## Test matrix

### Blocking, automated (in `make check` and CI)

| Area | What exactly | Where |
|---|---|---|
| Pipeline grid and validators | Property-based: every word formable; grid connected; no accidental adjacency words; coordinates in bounds; same seed → same level | `pipeline/tests/` (hypothesis) |
| Content validation | Every pack matches the schema; no duplicates; no `banned` word; bonus completeness; released slots unchanged vs the lock file; byte-identical rebuild | `make content-validate`, `CONTENT.md#hard-validation` |
| Word matching (`BoardState`) | LEVEL / BONUS / ALREADY_FOUND / INVALID; repeated letters; intersections; under-3 ignored; completion fires once | `game/tests/unit/board/` |
| Hints and shuffle | Target cell and word order; disabled on complete level; cost charged exactly once; shuffle differs | `game/tests/unit/board/`, `services.economy` integration |
| Economy | grant/spend, never negative, journal bound, integer amounts, rewards from config | `game/tests/unit/economy/` |
| Save | Roundtrip; every migration on its golden file; corrupt file → backup → clean start; interrupted write (kill between temp write and rename) | `game/tests/integration/services.save/`, `game/tests/fixtures/save/` |
| IAP flow (Fake store) | Idempotent by transaction key; crash after grant / before flush / before finish; restore; pending; cancel | `game/tests/integration/services.monetization/` |
| Ad policy | Every condition of `GAME_DESIGN.md#ad-policy` alone and combined; Remove Forced Ads; first slot | `game/tests/unit/ad_policy/` |
| Daily and streak | Day boundary, time-zone change, DST, gap, freeze, weekly grant, repair window, clock rollback per decision 0003 | `game/tests/unit/daily/`, `unit/streak/` |
| Registries | Every `Analytics.track` and `Config.get_*` literal registered; registry files schema-valid; config constraint from `GAME_DESIGN.md#unlocks` | `tools/check_registries.py`, `game/tests/unit/` config tests |
| Remote config | Unknown key, wrong type, out of range → rejected, default kept | `services.config` integration |
| Tools CI depends on | `tasks.py`, `check_scope.py`, `count_tests.py`, `check_registries.py` | `tools/tests/` |

### Blocking, headless integration (Godot with Fakes)
- **Boot smoke** (T-0044): headless boot reaches the first screen with no errors or warnings in the log.
- **Bot test** (T-0042, FR-CONT-07): for every shipped level (fixtures + `game/content/`), load it
  through `Content`, submit each level word as tile indices, assert the level completes. Proves the
  runtime reads every level the pipeline wrote.
- **Save roundtrip through services**: play a few levels with Fakes, save, reload; state is identical.

### Manual on device
See [Device checklist](#device-checklist). Runs before every release and for every `risk: high` task
that touches platform, ads, IAP or save.

### Deliberately not automated
- UI layout, colours, spacing (gallery screenshots and review cover them; `DESIGN.md#gallery-and-review`).
- Animation and effect code, audio.
- Navigation beyond boot smoke.
- Thin SDK adapters (covered by spike S1 and the device checklist; Fakes are tested indirectly).

### Later (non-blocking first)
- Gallery screenshots rendered headless in CI and attached to UI PRs (T-0327); visual diff once the design
  system is stable.
- Performance proxy: level load time and frame time in the level scene on a desktop build (P3).

## Test layout and CI

- GUT tests in `game/tests/`: `unit/<domain>/` mirrors `game/core/<domain>/`; `integration/<area>/`;
  `fixtures/` (small level pack, save golden files). New fixtures only when a task lists them.
- pytest in `pipeline/tests/<stage>/` and `tools/tests/`.
- `make check` = format, lint, Godot import with log scan, GUT unit + integration, pytest, registries,
  content validation. Green before every PR (`AGENTS.md`).
- CI also runs scope, tasks-lint and test-count; the test count never drops against `main` without the
  `test-count-exception` label.
- No sleeps, no real clock, no unseeded randomness. Inject `Clock` and seeded RNGs.

## Reference devices

Chosen by Chris in T-0012 (Q13). Store accounts are still to be created.

| Device | Layout class | Purpose | Model |
|---|---|---|---|
| Low-end Android (Q13) | REGULAR (20:9) | performance, swipe latency (NFR-01) | Samsung Galaxy A15 (Chris, 2026-10-02) |
| High-end Android, 120 Hz | REGULAR | high refresh rate, gesture inset | Samsung Galaxy S26 Ultra |
| iPhone with notch | REGULAR | safe areas, iOS haptics, ATT, StoreKit | iPhone 13 Pro Max |
| iPad | TABLET | content column, wheel cap | none yet: simulator until bought (before P2 device checklist) |
| COMPACT (16:9, 720p) | COMPACT | smallest layout | none: Android emulator profile; buy a cheap 16:9 phone only if P2 layout tests show problems |
| Mac for iOS builds | — | Xcode, signing | MacBook Air M3 |

Layout classes: `DESIGN.md#reference-devices`.

## Device checklist

Run on all reference devices with a release-configured build. Record results in
`docs/qa/<version>-device-checklist.md` (pass / fail / note per row).

**Game feel and performance**
- [ ] The line follows the finger with no perceivable lag on the low-end Android (NFR-01).
- [ ] Level scene holds 60 fps; no frame over 33 ms during a swipe (NFR-02); 120 Hz where supported.
- [ ] No loading screen between levels; next level interactive when the completion sequence ends (NFR-03).
- [ ] Cold start ≤ 3 s low-end Android, ≤ 2 s iPhone, excluding consent (NFR-04).
- [ ] Haptic tick per letter; haptics off in Settings silences everything.
- [ ] iOS silent switch mutes sound effects (FR-AUDIO-04).

**First 10 minutes (clean install)**
- [ ] Straight into level 1; no prompt before the first level (FR-ONB-01).
- [ ] Unlocks appear at the timeline slots, each with at most one coach mark (`GAME_DESIGN.md#unlocks`).
- [ ] UMP form after slot 1 where required; ATT after slot 6 on iOS; no ad before they resolve.

**Ads (test units)**
- [ ] Rewarded grants only after the full view; early close grants nothing (FR-ADS-04).
- [ ] No fill / offline: button explains and offers the alternative (FR-ADS-05).
- [ ] Interstitials never before `ads.interstitial.first_slot`, never mid-level or after a daily.
- [ ] Backgrounding during an ad leaves a consistent state; audio pauses and resumes (FR-ADS-08).

**IAP (sandbox / internal track)**
- [ ] Purchase consumable and Remove Forced Ads; cancel; restore after reinstall.
- [ ] Kill the app during a purchase; on restart the purchase completes once, never twice (FR-IAP-04/05).
- [ ] Pending / Ask to Buy shows pending and completes later (FR-IAP-07).

**Interruptions and offline**
- [ ] Airplane mode: campaign, daily, settings and save work; ads and shop degrade with a message (NFR-06).
- [ ] Incoming call, notification shade, app switch mid-swipe and mid-level: state resumes (FR-PLAT-05).
- [ ] Kill the app at any moment: at most the current unfinished attempt is lost (NFR-13).
- [ ] Low storage: save failure does not corrupt the previous save.

**Platform**
- [ ] Safe areas respected on every screen (FR-PLAT-03); Android back behaves per FR-PLAT-04.
- [ ] Backup restore to a new device keeps progress and purchases (FR-SAVE-06).
- [ ] 30-minute session: no thermal throttling, menus idle without redrawing (NFR-08).
- [ ] Text scaling and reduced motion work; Polish diacritics render everywhere (NFR-11, NFR-12).

## Release checklist

Before every build that releases slots (`CONTENT.md#slot-policy`) or goes to a store track:
- [ ] `make check` green on the release commit; CI Android build green (iOS build for iOS releases).
- [ ] Version bumped in `game/version.json`; content version in the manifest; changelog and release notes.
- [ ] Device checklist passed for this version on all reference devices (link the `docs/qa/` file).
- [ ] Content: QA sampling done for new slots; lock file updated for slots this release releases.
- [ ] Registries: no unregistered events; new events listed in the release notes for the analytics dashboard.
- [ ] Store: data-safety / privacy labels still match what the build collects; privacy policy current.
- [ ] Crash-free rate of the previous release meets NFR-07 (from P3 soft launch).
- [ ] Chris signs off in the release PR.
