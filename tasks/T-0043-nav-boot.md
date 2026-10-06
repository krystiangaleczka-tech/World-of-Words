---
id: T-0043
title: Nav screen state machine and boot sequence into Level
epic: E03
type: contract
area: services.nav
risk: high
executor: human       # done in a Claude Code session Chris started
think: med
ui: low
status: done
depends_on: [T-0036, T-0037, T-0041]
touch:
  - game/services/nav.gd
  - game/services/nav/**
  - game/tests/integration/test_nav.gd*
  - tasks/T-0043-nav-boot.md
revision: 1
---

## Goal
Starting the game runs the boot sequence (Save, Config, Content manifest) and enters the Level
screen for the saved slot. Nav is a screen state machine that later screens plug into by scene path.

## Context
- ARCHITECTURE.md#boot-and-navigation: boot steps 1–3 and "In P1 boot goes straight to Level, and Home
  exists empty, reachable from Debug." "An autoload does no work in `_ready()` ... `Nav` drives the boot
  sequence explicitly."
- DESIGN.md#screen-map: scene paths `features/level/`, `features/home/`, `features/debug/`.
- PRODUCT.md FR-ONB-01: first launch goes straight into level 1.
- Roadmap row T-0043.

## Current state
- `Nav.boot(clock)` injects the Clock into the 12 autoloads; `boot.tscn` is the main scene (T-0034).
- `Save.load()`, `get_setting(&"language")`, `get_section(&"progress")` with
  `by_lang.<lang>.current_slot` (T-0036); `Config.load()` (T-0037);
  `Content.load_manifest`, `slot_count`, `level_for_slot` (T-0041).
- No scene exists under `game/features/` yet.

## Specification
### Interface
`enum Screen { BOOT, LEVEL, HOME, JOURNEY, POSTCARD, SETTINGS, DAILY, COLLECTION, DEBUG }`,
`signal screen_changed(screen)`, `signal boot_failed(error)`,
`start(host: Node, content_root := "res://content") -> Error`, `configure(save, config, content)`
(tests/tools), `current_screen()`, `level_slot()`, `mounted_screen()`, `go_to_level(slot) -> Error`,
`go_home() -> Error`. `boot(clock)` is unchanged.

### Behavior
1. `start` runs `Save.load`, `Config.load`, `Content.load_manifest(<language setting>)`, then enters
   Level for the saved `current_slot`, clamped to `1..slot_count`.
2. Any failing step emits `boot_failed(error)`, returns it, and leaves Nav on BOOT.
3. Entering a screen frees the previously mounted scene, mounts the screen's scene under the host if
   the file exists, then emits `screen_changed`. Screens without a scene file are empty states.
4. `go_to_level` rejects slots Content cannot load; `go_home` is rejected before boot finished.
5. `boot.tscn` calls `Nav.boot` then `Nav.start(self, content_root)`; `content_root` is an exported
   property so tests can boot on fixture content. A failed start logs a warning, never an error.

## Out of scope
Level, Home and Debug scenes; Android back; Monetization step 4 (stub until E19); `nav_screen`
analytics (queue unconfigured until T-0250); Home routing for returning players (`unlocks.journey_slot`, P2).

## Tests
`game/tests/integration/test_nav.gd`: fresh install boots into Level 1 and creates the save; saved
slot is resumed; slot beyond content is clamped; missing content fails boot on BOOT; Home only after
boot and back to Level; unknown slots rejected; screens without scene files mount nothing.

## Acceptance
`make check` green; existing autoload tests unchanged and passing.

## Rollback
Revert the squash; boot returns to Clock injection only. No save format change.

## Deviations / concerns
- Nav reads the `progress` save section read-only for `current_slot` because Progress has no API until
  T-0111; T-0111 should switch this to `Progress`.
- Until T-0127 ships content, a real boot stops on BOOT with a warning (no manifest in
  `res://content`). The existing boot-scene test now runs the sequence against the real `user://save.json`
  of the test profile; it still passes unchanged.

## Integration review
A repeated `start` now clears the prior screen, slot and mounted scene before the boot sequence.
The regression test boots successfully, fails a restart on missing content, verifies BOOT and a
zero slot without `screen_changed`, then proves a subsequent valid retry reaches Level 1.
