---
id: T-0397
title: Connect the offline P2 campaign to normal boot
epic: E20
type: feat
area: services.nav
risk: high
executor: sol
think: high
ui: high
status: review
depends_on: [T-0242, T-0243, T-0278, T-0281, T-0291, T-0292, T-0333]
touch:
  - game/services/nav.gd
  - game/services/nav/boot.gd
  - game/services/nav/offline_campaign.gd*
  - game/features/level/level.gd
  - game/ui/components/ScreenScaffold.gd
  - game/tests/integration/test_boot_smoke.gd
  - game/tests/integration/test_offline_campaign.gd*
revision: 3
---

## Goal

Players reach the existing P2 campaign HUD and earn durable rewards through a normal launch. The first level teaches the swipe, and the campaign continues through the existing navigation and unlock rules.

## Context

- `ARCHITECTURE.md#boot-and-navigation` assigns startup and transitions to Nav. Save, Progress and Economy retain their existing ownership.
- `DESIGN.md#level-p2-final` and `#feature-unlock-gating` define the UI and unlocks. Use the existing catalog and translations. R-UI-1/2 use approved components, R-UI-3 uses tokens, R-UI-4 uses translated copy, R-UI-5 keeps generated themes intact and R-UI-6 requires screenshots of the runtime surface.
- T-0143 remains a release gate. This work prepares the real route for playtesting.

## Current state

- `boot.gd` calls `Nav.configure_p2()` and `StartupRecovery.start`. `Nav.start` loads Save, Config and Content before it picks a scene.
- `AtomicProgressPort.configure(save, progress, economy)` binds concrete owners before Save loads. `Progress.configure_atomic` reads loaded config, and `Progress.configure_p2` certifies the committed save against the loaded content.
- Level already exposes setup for HUD, wallet-backed tools, bonus meter, completion, tutorial and coaches. Home can take a coach guard before mounting. The existing components require explicit composition.

## Specification

- Boot enables an offline campaign composition for its actual service owners. Bind the same Save/Progress/Economy pair once before the first load. After Config and Content load, certify progression and enable atomically persisted checkpoints and rewards. Keep content-recovery retries and pre-existing Save compatibility. A save that cannot be adapted plays through the existing compatible route. A failed persistence operation keeps its existing retry or recovery behavior.
- Compose the currently playable campaign slot before it mounts. Keep diagnostic replays isolated from the live wallet, preserve terminal campaign behavior and run the existing tutorial only at slot 1. Route Home from the Level action, attach the existing coaches and pause their presentation while a sheet is active. Disable the Settings control until its route is connected.
- Preserve offline play and use the existing unavailable-store presentation when a player opens the shop. Provider activation, SDK calls, consent prompts, reward ads and purchases are separate tasks. Reuse the current Continue and postcard flow for offline play.
- At the final shipped slot, enable Continue through the campaign's navigation. Show a newly earned postcard when applicable. When there is no postcard to reveal, return to the existing completed campaign state on Home.
- Run the debug diagnostics on the composed screen. Avoid redundant chrome moves when the diagnostic readout joins the existing layout.

## Tests

- Extend the real Boot smoke case to assert the normal first level has the activated HUD, tutorial, bonus and completion composition. No test-supplied screen composition is accepted for this assertion.
- Exercise the regular Nav path with isolated saves and shipped content. Complete levels, verify one wallet grant and one star per newly completed level, verify persistence before Continue, and exercise Home and a non-current debug replay. Cover retry after missing content, a legacy progress save and Continue from the last shipped slot with a fully revealed postcard.

## Acceptance

`make check`, scope check and the normal game route pass. The existing Level screen is checked under the pinned Godot runtime. Device sign-off remains part of the roadmap.

## Rollback

Disable composition by reverting this task. The existing Save schema and committed wallet/progress data remain readable by prior builds.
