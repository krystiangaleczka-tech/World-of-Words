---
id: T-0295
title: Present recoverable startup content and save failure states
epic: E21
type: feat
area: services.nav
risk: high
executor: sol
think: med
ui: med
status: review
depends_on: [T-0243, T-0217, T-0329]
touch:
  - game/services/nav.gd
  - game/services/nav/p2_navigation.gd
  - game/services/nav/startup_recovery.gd*
  - game/services/nav/boot.gd
  - game/features/recovery/startup.gd*
  - game/features/home/home.gd
  - game/locale/recovery.csv*
  - game/data/analytics/system.json
  - game/tests/integration/test_analytics_p2_registry.gd
  - game/tests/integration/test_nav_p2.gd
  - tools/tests/test_check_registries.py
  - tools/tests/test_analytics_p2_registry.py
  - game/tests/integration/test_startup_recovery.gd*
  - docs/PRODUCT.md
  - docs/qa/T-0295/**
  - tasks/T-0295-startup-recovery.md
revision: 6
---

## Goal
Implement DESIGN's startup failure flow: retryable content errors, backup-restored notification on the first eligible screen, and a one-time explanation when no save can be recovered.

## Context
- docs/DESIGN.md#flow-offline-and-errors: content failure uses StatePanel(error), Try again and Back to Home; backup recovery uses one Toast; lost save offers Restore purchases before normal first launch. No global offline banner.
- docs/PRODUCT.md#core-events-seed-of-the-registry, FR-SAVE-03, NFR-06; registered analytics only.
- docs/DESIGN.md#rules-quote-these-into-ui-tasks: R-UI-1/2 existing catalog composition only; R-UI-3 tokens/theme visuals; R-UI-4 translated copy; R-UI-5 generated themes untouched; R-UI-6 native screenshots.

## Current state
- Nav.start loads Save, Config and Content, stays on BOOT on load error and emits boot_failed. Home handles unavailable Content by disabling Play safely. go_home currently refuses BOOT.
- Save.last_load_report exposes corrupted:true for wholly lost saves. Save starts fresh in memory and ordinary flush persists recovery; backup_restored reports fallback. No save schema change is needed. Save.load is idempotent for already loaded instances and its report remains the current boot report; the presenter must latch a successful acknowledgement in transient state.
- P2Navigation.enqueue/its Home-only queue currently delay backup Toast until Home, including locked-home first launches.
- StatePanel.configure(kind,title,body,action) emits action_requested. TextButton/ScreenScaffold/Toast already exist. Monetization.restore_purchases returns initiation Error, not aggregate restore success.
- DESIGN asks for content-failure telemetry, but PRODUCT's canonical list/registry lacks it. This task explicitly adds the contract rather than inventing an unregistered call.

## Specification
- Add read-only Nav.boot_failure_stage (save/config/content/route or empty), maintained at existing startup boundaries. Add go_home(recovery:bool=false): existing callers unchanged; true allows safe unavailable Home only from BOOT after a content failure with valid loaded Save/Config and live host. No level unlock or progress advance.
- Optional first_screen:bool=false argument on Nav.enqueue_toast/P2Navigation.enqueue. Backup restoration uses true, prioritized before Home-only messages, delivered once on first Home or Level. Existing other toasts remain Home-only.
- New caller-owned startup recovery RefCounted orchestrator receives Nav, Save, Config, Content, Monetization and Analytics; Boot owns/closes it and listens to its started signal to finish audio/haptic/debug setup exactly once, including after an initial failed boot. It calls normal Nav.start and presents a catalog ScreenScaffold plus a feature-owned VBox on an overlay layer above normal screens on failure. No retry loop: only explicit presses retry.
- Content error: StatePanel(error), translated title/body/Try again and a TextButton Back to Home. Retry clears old presentation, calls Nav.start once and remounts state on failure. Back to Home calls guarded recovery Home and moves the same error controls into Home's body, hiding the redundant Back button; Retry remains available there. Home also checks that its next level can actually be loaded before enabling Play, so malformed packs remain safe too.
- Lost-save explanation after successful startup inspects the actual copied load report, not guessed file/network status. Show StatePanel(error) with Restore purchases and Continue. An existing non-dismissible Sheet traps focus and input above gameplay. Restore calls injected Monetization.restore_purchases exactly once per press, reports initiation only; on OK hide duplicate restore action and show requested status, never claim restored. An unavailable/error port shows retryable error. Continue flushes ordinary Save and closes only on OK; failures retain the explanation. A persisted fresh save does not show the explanation on next load.
- Signals and manual connections are disconnected; reparented controls reconnect their own handlers. Repeated/stale/reentrant presses cannot run duplicate startup or write after presentation closes. Locale refresh preserves current status; use themes and token spacings. No new catalog component.
- Explicit canonical telemetry contract: add content_load_failed {error_code:int} to PRODUCT system events and system.json. It reports the latest content startup error once the normal Analytics runtime becomes ready on a successful retry; coalesce failures to one transient pending code. No queue/consent/SDK bypass, paths, exception text or persistent identity. Use T-0329 event_accepted to clear the pending code on successful enqueue even if a later delivery-removal write fails, preventing a second enqueue. If Analytics is unavailable/full, keep pending for a later successful start; a process that never recovers cannot deliver this best-effort event. Non-content Save/Config failures do not fabricate the content event.
- Existing save_corrupted delivery remains unchanged. Update the existing exhaustive registry test's name/count from 47 to 48 while preserving all shape/type checks; new event validation is exercised too. Update both tools CLI and PRODUCT/registry parity regression counts from 47 to 48 as the same explicitly authorized canonical event addition; preserve the full command/result assertions. Update only the existing backup-restored Nav regression to assert immediate Level display and no repeated display on Home, replacing its obsolete Home-only expectation.

## Tests
New test_startup_recovery.gd with real injected memory Save/Content/Config/Nav: missing manifest and malformed level errors, explicit retry succeeds, Home recovery is safe and keeps inline retry; default go_home remains guarded; repeated/stale actions do not duplicate startup. Real corrupted primary plus backup emits exactly one Toast on Level before Home unlock, existing Home-only toasts remain queued. Wholly lost save explanation, restore unavailable/requested, no false success, failed Continue flush/retry, reload is one-time; fresh normal install has no explanation. Coalesced canonical content error is accepted only after normal analytics readiness with integer payload and no paths, survives queue rejection; no event for other stages. UI PL/EN/PSEUDO themes/layout matrix, no input fall-through, cleanup.
Full make check and both Android checks.

## Acceptance
Review/full checks pass, native failure/recovery matrix attached; no global offline banner or automatic retry loop.

## Wave refinement
Risk raised because the row requires a missing canonical telemetry event. The exact PRODUCT/registry and exhaustive-test edits above explicitly authorize that small contract addition; schema, balance, native SDK configuration and signing remain untouched. Restore UI truthfully depends on the already configured monetization service; it does not activate blocked native SDK setup.

## Rollback
Squash revert; no save migration. Already recovered fresh documents remain valid; transient error/observer state is discarded. A registry revert may discard queued diagnostic telemetry when the older registry no longer recognizes the new event.
