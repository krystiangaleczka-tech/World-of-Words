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
The PR CI is the authoritative `make check` result; local Godot and Python
runtimes are not attached to the GitHub connector session.
