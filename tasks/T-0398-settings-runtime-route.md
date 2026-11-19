---
id: T-0398
title: Connect Settings and offline licences to normal navigation
epic: E21
type: feat
area: services.nav
risk: medium
executor: sol
think: high
ui: high
status: review
depends_on: [T-0397, T-0286, T-0287, T-0348]
touch:
  - game/services/nav.gd
  - game/services/nav/boot.gd
  - game/services/nav/offline_campaign.gd*
  - game/services/nav/settings_session.gd*
  - game/features/home/home.gd
  - game/tests/integration/test_boot_smoke.gd
  - game/tests/integration/test_settings_navigation.gd*
revision: 1
---

## Goal

Open Settings from Home and Level. Apply the saved preferences across screens and navigate to offline licences and back to the original screen.

## Context

- `DESIGN.md#settings` and `#accessibility` specify the screen and immediate application. R-UI-1/2 use approved components, R-UI-3 uses tokens, R-UI-4 uses translated copy, R-UI-5 keeps generated themes intact and R-UI-6 requires screenshots of the runtime surface.
- `ARCHITECTURE.md#boot-and-navigation` assigns screen routing to Nav and preference persistence to Save.

## Current state

- Home checks for `features/settings/settings.tscn`. The implemented scene is `settings_screen.tscn`.
- `SettingsScreen` accepts Save, SettingsRuntime and SettingsLanguage, plus optional service bindings. `LicencesRoute` preserves the existing screen while showing licences.
- `SettingsRuntime.configure` requires loaded Save and a Control root. Existing audio and haptic owners observe committed Save settings.

## Specification

- Route the existing Settings scene with loaded owners, track the actual return destination and checkpoint an active level before leaving. The Settings Back action and OS Back share the same route and handle licences first. Pressing Back to a Level must restore the same committed board.
- Configure a boot-owned root and apply committed text size, contrast and reduced motion to routed screens. Change preferences through the existing owner, including failed-write retry. Use only shipped languages in the regular selector. Keep the existing debug EN UI preview behavior and a safe reload route for a real language change.
- Open offline licences using the existing `LicencesRoute`. Optional provider actions remain unavailable until configured by their respective integration tasks.

## Tests

- Through normal navigation, enter Settings from Level and Home. Apply and persist a display change, open a licence and return through Settings to the source screen. Check restored Level progress, applied theme and Back behavior.
- Verify Home and Level expose Settings only when the route is bound and that provider actions do not initiate requests in the offline configuration.
- Verify the actual Boot installs the Settings session and that a switch to a second shipped fixture language returns to its own saved slot.

## Acceptance

`make check` and scope check pass. Verify the existing Settings screen in the pinned Godot runtime. Record any physical-device checks still needed.
