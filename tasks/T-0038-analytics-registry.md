---
id: T-0038
title: Add analytics registry validation and Fake queue stub
epic: E03
type: contract
area: services.analytics
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0035]
touch:
  - game/services/analytics.gd*
  - game/services/analytics/**
  - game/data/analytics/lifecycle.json
  - game/tests/integration/test_analytics_registry.gd*
  - tasks/T-0038-analytics-registry.md
revision: 1
---

## Goal
Implement the next roadmap contract: typed analytics registry validation and a deterministic queue stub.

## Context
- PRODUCT.md FR-ANL-01: debug builds fail loudly on unknown event names or parameters.
- PRODUCT.md#core-events-seed-of-the-registry: canonical lifecycle names.
- ARCHITECTURE.md#registries: event name, typed params and description per area JSON.
- ROADMAP T-0038; complete core registry T-0247 and production analytics T-0250 are later work.

## Current state
T-0035 is done/merged. Analytics is an inert ServiceStub. Platform.analytics is AnalyticsAdapter;
AnalyticsFake records log_event(name: String, params: Dictionary) calls. No analytics JSON exists.
T-0037 is open in PR #24 but is not a dependency; this branch starts from main.

## Specification
### Behavior
1. Seed lifecycle.json with canonical app_boot/app_foreground/app_background (no explicit params)
   and nav_screen (required screen: string). Do not automatically emit these events at boot or via Events.
2. Formal registry schema under services/analytics requires nonempty snake_case event dictionaries,
   each with exactly params and nonblank description. Param names are snake_case, types int/float/bool/string.
3. Pure registry validates definitions atomically and rejects duplicates. Payloads require exactly
   their registered keys and strict GDScript types; reject bool-as-int, fractional float-as-int,
   unsupported values, nonfinite floats and numbers beyond JSON-safe precision. No coercion.
4. Analytics.load atomically reads sorted root JSON files. Any error retains prior definitions;
   empty/missing directories fail, non-object JSON fails, non-JSON files are ignored.
5. track validates in all builds; invalid event emits push_error only in debug and returns ERR_INVALID_DATA.
   Explicit configure_stub(positive capacity) is required to enqueue; capacity is injected, not a guessed
   replacement for the future analytics.queue.max_events config. Overflow rejects newest, preserves FIFO.
6. Accepted events are copied, queued in memory and emitted only on explicit flush to Platform.analytics
   when it is AnalyticsFake. Real adapters are refused with pending data retained. No disk/network/SDK calls.
7. Reload with queued events is ERR_BUSY; shrinking below pending size fails without loss.
   Empty flush is a no-op. A second flush never repeats events. pending_count exposes no payloads.

### Interface
- Analytics.load(String = "res://data/analytics") -> Error; configure_stub(int) -> Error.
- Analytics.track(StringName, Dictionary = {}) -> Error; flush() -> Error; pending_count() -> int.
- AnalyticsRegistry.append_document(Dictionary) -> Error; definition(StringName) -> Dictionary;
  validate(StringName, Dictionary) -> bool. Definitions are copies.

### Edge cases
Validation failures do not queue or call adapters. Full queue never replaces accepted events.
No production consent or collection behavior is claimed. Common metadata is added by T-0250,
separate from this initial per-event payload contract. No changes to Platform, Save or Config.

## Out of scope
Full core registry (T-0247), real adapter (T-0252), Events listeners, production consent/durable queue
and common metadata (T-0250), automatic lifecycle emission, CI scanning (T-0039), user properties.

## Tests
File: game/tests/integration/test_analytics_registry.gd
- Shipped lifecycle definitions and all four primitive payload types.
- Unknown event/unknown or missing param/wrong type fail loudly, with no enqueue/calls.
- Atomic invalid registry append, duplicates, metadata/schema/name rejection and definition copies.
- FIFO, capacity/overflow, snapshotting, repeated flush and explicit configuration.
- Non-Fake adapter refusal retains data; load errors retain definitions; busy reload and shrink refusal.
Run pinned Godot 4.7.2 make check, schema validation, scope/metadata/test-count and boot smoke.

## Acceptance
Specified tests pass, canonical names preserved, no real collection enabled.

## Rollback
Squash revert removes the stub; no persistent queue or save migration exists.

## Deviations / concerns
Capacity is caller-injected for this stub; canonical production queue configuration is deferred to T-0250.
Four production files (two scripts, lifecycle registry and formal schema); full tests/contract exceed
~300 changed lines. This initial seed does not pretend to finish the P2 full core-event registry.
