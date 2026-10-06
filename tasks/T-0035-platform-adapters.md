---
id: T-0035
title: Add typed platform adapters and deterministic no-op Fakes
epic: E03
type: contract
area: infra
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0034]
touch:
  - game/platform/**
  - game/tests/integration/test_platform_adapters.gd*
  - tasks/T-0035-platform-adapters.md
revision: 1
---

## Goal
Implement the next roadmap contract: services can use eight typed adapters without native SDKs.

## Context
- ARCHITECTURE.md#platform: "Editor, headless and unit tests always get Fakes."
- ARCHITECTURE.md#platform: "Fakes are deterministic and scriptable from tests" and record calls.
- PRODUCT.md FR-PLAT-01; ROADMAP T-0035; E03 D3.

## Current state
- T-0034 exists in open PR #21, not merged. This is a dependent draft based on that branch.
- Platform extends ServiceStub, with inherited initialize(clock: Clock) and get_clock().
- Clock, Nav.boot and twelve autoloads exist on the dependency branch; no adapter implementations exist.

## Specification
### Behavior
1. Eight RefCounted interfaces and no-op Fakes live under platform/<service>/.
2. Typed Platform fields expose ads, iap, analytics, crash, consent, haptics, review, notifications.
3. initialize(clock) explicitly selects adapters; no SDK operation happens in _ready or selection.
4. Only Android/iOS device runtime with a registered factory and present plugin may select an SDK.
   Editor, headless, desktop, --fakes, missing plugins and wrong factory types fall back to Fake.
5. Debug/tests may force a Fake per service without replacing other services; selection preserves override.
6. Fakes record method/argument snapshots. No success, reward, purchase or consent decision is automatic.
   Tests script outcomes by emitting the typed inherited signals explicitly; no clocks or sleeps.
7. Transactions carry store_key, product_id and typed state; store_key means purchaseToken/Transaction.id.
8. Notifications stay Later with an empty interface/Fake. No scheduling API is guessed.

### Interface
Freeze the architecture sketch with these types:
- Ads: initialize(ConsentAdapter.State); load/show rewarded and interstitial; architecture signals,
  ad_failed(reason: String).
- IAP: query_products(PackedStringArray), purchase(String), finish(StoreTransaction), fetch_unfinished(),
  restore(); products_received(Array[Dictionary]), transaction_updated(StoreTransaction), purchase_failed(String).
- Consent: request_info(), show_form_if_required(), request_att(), show_privacy_options();
  consent_resolved(State), att_resolved(AttStatus). UNKNOWN defaults never imply authorization.
- Analytics: log_event(String, Dictionary), set_user_property(String, String).
- Crash: record(String), set_key(String, String). Haptics: play(String). Review: request_review().
- All operation returns are void. Each implementation documents its typed methods with ## @api.
- Platform register_sdk(StringName, StringName, Callable) -> bool, force_fake(StringName) -> bool;
  select_adapters(String, bool, bool, PackedStringArray, PackedStringArray) -> void.
- FakeCalls.entries: Array[Dictionary], record(String, Array) -> void; nested collection copies.

### Edge cases
Unknown registrations/overrides fail without changing adapters. Missing plugin never calls the factory.
Wrong factory output stays Fake. No plugin is installed by this task. SDK constructors must be inert.

## Out of scope
Production SDKs, consent policy, rewards/grants, durable processing, real events, notifications, signing,
project settings or changes to the autoload list.

## Tests
File: game/tests/integration/test_platform_adapters.gd
- test_headless_boot_has_eight_fakes_without_calls
- test_editor_headless_desktop_and_cli_never_invoke_sdk_factory
- test_device_requires_plugin_and_valid_adapter
- test_per_service_fake_override_preserves_other_adapter
- test_all_fake_operations_record_calls_without_signalling_success
- test_fake_outcomes_are_scriptable_without_real_time_or_grants
- test_recorded_arguments_are_snapshots
Run make check on pinned Godot 4.7.2, scope relative to dependency branch, task lint and headless smoke.

## Acceptance
All tests pass, eight adapters are typed and accessible, no provider initialization or external effects.

## Rollback
Revert this task after its dependents; no migration, save or native dependencies are introduced.

## Deviations / concerns
Dependent draft until T-0034 merges; review cannot treat its dependency as done yet. Mandatory eight
interface/Fake pairs exceed the file-count guideline; contract stays atomic for consistent consumers.
