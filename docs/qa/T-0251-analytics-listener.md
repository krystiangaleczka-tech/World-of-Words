# T-0251 — Analytics listener P2a

Implementation: `game/services/analytics/analytics_listener.gd`, wired from successful
runtime Analytics startup before the initial Nav route.

## Registered mappings
- Boot/version/load status: `app_boot`, `content_version_loaded`,
  `save_corrupted`, `save_migrated`
- Lifecycle/navigation/settings: `app_background`, `app_foreground`,
  `nav_screen`, `settings_changed`
- Campaign: `level_start`, `level_complete`, `word_found`,
  `bonus_word_found`, `already_found_word`, `invalid_word_submitted`
- Successful shuffle: `shuffle_used`
- Durable domain effects: `economy_grant`, `economy_spend`,
  `stars_earned`, `postcard_piece_revealed`, `location_complete`,
  `feature_unlocked`

## Producer limitations
P1 `hint_used` carries no payment source: count it for completion, but do not
claim a paid hint event. Reveal, bonus chest, region, onboarding step, ad, IAP
and daily events await their independently owned producers. No registry changes,
new SDK, save schema modification, economics or consent policy changes.

## Verification
Focused integration: 17 tests / 749 assertions pass with pinned Godot 4.7.2.
Coverage includes the actual LevelController final-word/final-hint publication order,
failed persistence, committed Economy/Progress receipts, Save upgrades v1–v4,
backup recovery/v3 compatibility, failed boot, owner changes with pending completion,
consent FIFO/denial, full queue, lifecycle, settings write failure/retry and teardown.

Startup events and diagnostics are emitted only after the initial route succeeds.
Repeated setup in the same runtime does not invent another process boot. Completion
uses its original monotonic sample but waits until the current controller publication
turn ends; navigation flushes it before resetting visit counters. Changing runtime
owners flushes old completion while its original common context is still bound.

Full local make check passes: 674 Godot tests / 24,360 assertions, 329 pipeline
tests and 536 tools tests, plus registry, content, UI and clean-cache theme checks.
Independent exact-commit review and CI results are recorded in the PR.
Provider/device delivery remains T-0252; no SDK or live account is exercised here.
