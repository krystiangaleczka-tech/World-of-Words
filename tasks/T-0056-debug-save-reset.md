---
id: T-0056
title: Add a durable debug-only reset of gameplay sections
epic: E04
type: contract
area: services.save
risk: high
executor: sol
think: med
ui: none
status: done
depends_on: [T-0054]
touch:
  - game/services/save.gd
  - game/tests/integration/test_debug_save_reset.gd*
  - tasks/T-0056-debug-save-reset.md
revision: 1
---

## Goal
An explicit developer action resets gameplay progress using Save-owned persistence, preserving identity,
settings and monetization records. Tests use isolated storage; never delete the real user save in tests.

## Context
- `docs/ARCHITECTURE.md#save`: atomic SaveStorage commit owns persistence.
- `docs/PRODUCT.md#fr-debug-debug-tools`: debug reset is requested by T-0048.

## Current state
Save.load/configure/get_section/flush exist; SaveSchema.fresh and SaveStorage.commit exist. No reset API.

## Specification
Add is_loaded() -> bool and debug_reset() -> Error. In release return ERR_UNAVAILABLE; before load
return ERR_UNCONFIGURED. Build fresh gameplay sections progress/economy/daily from SaveSchema,
preserving meta/settings/monetization exactly (including processed transactions and entitlements).
Commit using existing atomic storage BEFORE publishing candidate memory. On success loaded memory and
reload contain reset data; on failure retain prior in-memory data/dirty state, emit flush_failed(error),
and return the error. Existing storage recovery semantics apply after interrupted writes; no disk rollback
claim is made. No schema, balance, transaction grant, identity or settings changes. No reset on boot.

## Tests
`game/tests/integration/test_debug_save_reset.gd`: test_reset_preserves_identity_settings_and_transactions,
test_reset_is_durable_after_reload, test_failed_reset_keeps_memory_and_can_retry,
test_reset_before_load_is_rejected. Inject fixed Clock, identity and isolated SaveStorage; fault injection
at every existing storage checkpoint. Never call the real autoload reset.

## Acceptance
make check and unchanged existing Save tests pass. Fresh independent high-risk review before merge.

## Rollback
Revert removes the API; save schema is unchanged. Explicitly reset test progress is not restored by revert.
