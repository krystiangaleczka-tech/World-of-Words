---
id: T-0044
title: Boot smoke test from the boot scene to Level with Fakes
epic: E03
type: test
area: services.nav
risk: low
executor: human       # done in a Claude Code session Chris started
think: low
ui: none
status: done
depends_on: [T-0043]
touch:
  - game/tests/integration/test_boot_smoke.gd*
  - tasks/T-0044-boot-smoke.md
revision: 1
---

## Goal
CI catches any change that stops the game from booting: the real boot scene with the real autoloads
and headless platform Fakes must reach the Level screen with no error in the log.

## Context
- Roadmap row T-0044; dp08 §2; FR-PLAT-01 (Fakes on headless/desktop).
- ARCHITECTURE.md#boot-and-navigation boot steps 1–3.

## Current state
- `boot.tscn` exports `content_root`; `Nav.start` emits `boot_failed` on failure (T-0043).
- `game/tests/fixtures/content/pl/` has 3 levels (T-0041). `res://content` ships no packs until T-0127.
- GUT is configured with error tracking: an engine error or `push_error` fails the test.

## Specification
1. Instantiate `boot.tscn` with `content_root` set to the fixture content and add it to the tree.
2. Assert: no `boot_failed`; `Nav.current_screen()` is LEVEL; the slot is within content; Content
   language equals the saved language setting; Config registry is loaded; all eight Platform adapters
   are Fakes; the ads Fake recorded no calls.

## Out of scope
A separate `godot --headless` process run in CI (needs Makefile/CI changes, lane H infra);
switching `content_root` back to the default once T-0127 ships packs.

## Tests
`game/tests/integration/test_boot_smoke.gd::test_headless_boot_reaches_level_with_fakes`.

## Acceptance
`make check` green; test count rises by one.
