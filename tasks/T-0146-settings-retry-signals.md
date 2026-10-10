---
id: T-0146
title: Publish settings changes after any successful retry
epic: E10
type: contract
area: services.save
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0145]
touch:
  - game/services/save.gd
  - game/tests/integration/test_settings_retry.gd
  - game/tests/integration/test_settings_retry.gd.uid
  - tasks/T-0146-settings-retry-signals.md
revision: 1
---

## Goal
Close the settings notification gap identified while following Astra Q4: a dirty
setting committed by a later flush must notify its consumers after persistence.

## Context
- docs/ARCHITECTURE.md#save: Save owns settings and structural persistence.
- docs/qa/T-0142-architecture-preflight.md: Q4 requires a settings retry policy.
- AGENTS.md: Events carries effects, never transaction authority.
This changes notification behavior, not save v2 format or failed dirty reads.

## Current state
Save.set_setting validates, updates memory and flushes; it emits setting_changed
only if that direct call succeeds. Save.flush/request_flush, application pause
and debug_reset may persist dirty settings without the signal. debug_reset
preserves settings. SaveSchema.SETTINGS is the closed key list.

## Specification
1. Track validated dirty setting keys in Save. A failed write emits no settings
   signal and retains keys for any subsequent successful flush or debug reset.
2. On success notify once per pending key, coalescing repeated failed edits to
   the latest stored value. Invalid keys/values never queue notifications.
3. Clear a snapshot of pending keys before synchronous callbacks; changes made
   by callbacks start a new pending generation and must survive failed retries.
   Signals identify a committed setting change, not an atomic read transaction
   across arbitrary callbacks. Existing memory remains dirty/readable on failure.
4. Plain flush, request_flush, application pause and another owner's section
   flush all release notifications. A clean no-op flush must not duplicate them.
5. A successful debug reset publishes preserved pending settings after updating
   memory. Failed reset retains them. No reward/transaction/SDK changes.

## Tests
File: game/tests/integration/test_settings_retry.gd
- Failed direct edit, plain retry and reload show no premature signal and one
  notification after durable storage; clean retry emits nothing further.
- Repeated failed key edits coalesce; separate keys each notify; invalid edits
  do not create notifications.
- Another owner's section write/flush also publishes pending settings.
- request_flush and application pause publish pending settings.
- Failed then successful debug reset publishes preserved settings exactly once.
- A synchronous callback's failed new edit stays pending for a later retry.
Run full make check, metadata lint, scope, count and independent fresh review.

## Acceptance
Callbacks in the ordinary retry read persisted settings from storage. Existing
settings, audio, haptics, save and progress tests remain unchanged and green.

## Rollback
Revert the task; document format remains v2. The missed retry notification returns.

## Outcome
Full make check passed: 230 GUT tests / 8674 assertions, 199 pipeline and
142 tools tests. Independent review approved 24d1e4257985c21e064f2eefd734f9ce0362d70a
without blockers. Scope: four files; all existing tests unchanged. Remote CI is
required before merge. Human gates and P2 transaction work remain open.
