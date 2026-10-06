---
id: T-0057
title: Gate debug navigation and expose an F3 developer shortcut
epic: E04
type: contract
area: services.nav
risk: high
executor: sol
think: med
ui: none
status: ready
depends_on: [T-0055, T-0056]
touch:
  - game/services/nav.gd
  - game/services/nav/boot.gd
  - game/tests/integration/test_debug_navigation.gd*
  - tasks/T-0048-debug-shell.md
  - tasks/T-0057-debug-navigation.md
revision: 1
---

## Goal
Provide the missing debug route and wire an editor/desktop F3 entry, without allowing release routing.

## Context
- `docs/ARCHITECTURE.md#boot-and-navigation`: Nav owns screen switching.
- `docs/PRODUCT.md#fr-debug-debug-tools`: debug screens are debug-only.

## Current state
Nav.Screen.DEBUG, scene path and mounting exist; Save.is_loaded/debug_reset exist after T-0056.
No debug route exists. BOOT may be visible when shipped content is absent.

## Specification
Add go_debug() -> Error and configure_debug(enabled: bool) -> void. Routing requires both
OS.is_debug_build() and enabled (default true); tests may disable, never enable release routing.
Require a valid host and loaded Save; BOOT with missing Content may open Debug for diagnostics.
Rejected routes preserve state/mounted scene/slot. Screen changes retain existing signal behavior.
Boot handles non-echo pressed F3 only in debug builds, calling Nav.go_debug and consuming successful input.
Harden mounted cleanup against a host freed before later navigation; clear queued old scenes immediately
from their parent so two screens cannot receive input in the same frame. Existing public APIs unchanged.
Mark T-0048 ready only when all four prerequisites are done. No scene is introduced in Nav's task.

## Tests
`game/tests/integration/test_debug_navigation.gd`: test_debug_disabled_preserves_screen,
test_debug_requires_loaded_save_and_host, test_debug_route_after_boot_and_home,
test_debug_diagnostics_after_missing_content, test_freed_host_is_rejected. Use isolated Save storage,
Clock/services/hosts. Existing Nav tests unchanged.

## Acceptance
make check and fresh review pass. Release artifacts' physical exclusion stays T-0137/T-0138.

## Rollback
Revert removes routing/shortcut, preserving Save/content formats.
