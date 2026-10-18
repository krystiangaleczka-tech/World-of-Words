---
id: T-0294
title: Add isolated debug wallet and fake monetization controls
epic: E21
type: feat
area: features.debug
risk: high
executor: sol
think: med
ui: low
status: review
depends_on: [T-0271, T-0233]
touch:
  - game/features/debug/debug.gd
  - game/features/debug/p2_tools.gd*
  - game/services/debug/tools.gd*
  - game/services/nav.gd
  - game/services/nav/boot.gd
  - game/locale/debug.csv*
  - game/export_presets.cfg
  - tools/check_release_export.py
  - tools/tests/test_release_export.py
  - game/tests/integration/test_debug_p2a.gd*
  - docs/qa/T-0294/**
  - tasks/T-0294-debug-p2a.md
revision: 2
---

## Goal
Expose FR-DEBUG-03 in debug builds using the injected durable wallet and current fake adapters, without bypassing ordinary gameplay owners.

## Context
- PRODUCT.md FR-DEBUG-03/06: grant/remove coins/items, toggle Remove Forced Ads, fake fill/no-fill/cancel/pending/crash-before-finish; developer code excluded from Release.
- ARCHITECTURE.md: only services call platform adapters; every balance change goes through Economy.
- docs/DESIGN.md#rules-quote-these-into-ui-tasks: catalog components, tokens and translated copy only.

## Current state
- Debug screen configure(save,content,nav) injects owners before mount, and existing controls have fixed paths used by regression tests.
- Economy.grant/spend, snapshot, atomic_save_matches and Save.committed_view/set_section/flush exist. Economy owns durable retry identity.
- AdsFake/IapFake.set_outcome validate closed per-operation controls. Platform holds current adapters; replacing them would invalidate existing service bindings.
- Boot initializes the shared Clock and starts Nav; P2 monetization runtime remains explicitly composed separately.
- Android Release excludes features/debug and ui/gallery; resource inspection verifies exclusions. No services/debug implementation exists.

## Specification
- New injected RefCounted service facade in services/debug (no global class/autoload), with runtime OS.is_debug_build guard and additional disable seam. All UI platform access goes through it.
- Explicit modify(item,positive_amount,remove) supports coins/hint/reveal only through Economy grant/spend with debug reason. No negative balances, overflow, unknown names, invalid counts or cross-Save bindings. Existing owner retry behavior stays authoritative.
- Explicit set_remove_forced_ads(bool) stages only monetization entitlement then flushes. Show committed state, retain failed target for identical retry, reject competing debug wallet/entitlement changes until retry. Do not overwrite dirty/conflicting monetization or wallet state. Do not fabricate purchase transactions or change save schema.
- Configure existing Fake adapters only; refuse real adapters, no SDK invocation, no adapter replacement, reward or purchase grant. UI presets: rewarded fill/no-fill and purchase success/cancel/pending/crash-before-finish. Outcomes apply to subsequent normal provider operations.
- Debug screen optional configure_p2_tools(port) is injected by optional fourth argument of Nav.configure(save,config,content,port) before mount. Actual debug Boot configures the existing Economy owner and port with Save/Config/Platform after successful boot; release never loads the facade.
- Compose a caller-owned feature panel from TextButtons and Labels. Coins step comes from economy.price.hint; items step is one item. Translate action/status labels. Scroll the entire debug body only when the extra panel is injected; unchanged paths/behavior otherwise. Existing reset and level actions remain intact.
- Explicitly extend Release exclusion and artifact inspector to services/debug; do not change project settings, SDKs, signing, endpoints, permissions or autoloads.

## Tests
New test_debug_p2a.gd: real memory Save/Economy grant/remove/reload, invalid and insufficient requests, failed wallet retry exactly once; failed entitlement target is hidden until durable success, competing changes refused; disabled and cross-owner guards; real adapters refused; fake selections produce normal callbacks only after explicit provider operations and never grant; actual mounted UI presets, scroll and Nav injection. Extend release inspector parametrization with service debug resources/remaps.
Native QA captures actual debug controls. Full make check and both Android checks.

## Acceptance
All tests pass, review and exact-head CI pass. Native tools available via debug F3; Release archive contains no developer facade.

## Wave refinement
Risk raised for explicit debug-only entitlement and export exclusions; executor Sol handles the service boundary. The small export/inspection changes are necessary to satisfy FR-DEBUG-06 rather than shipping developer mutation code. No native adapter or purchase setup is activated.

## Rollback
Squash revert restores prior Debug UI; no schema migration or balance/config change. Debug mutations already explicitly made by a developer remain in that local save.
