---
id: T-0329
title: Add shared debug time and live runtime diagnostics
epic: E21
type: feat
area: features.debug
risk: high
executor: sol
think: med
ui: low
status: review
depends_on: [T-0294, T-0255, T-0251]
touch:
  - game/services/clock.gd
  - game/services/debug/clock.gd*
  - game/services/debug/diagnostics.gd*
  - game/services/debug/tools.gd
  - game/services/config.gd
  - game/services/config/config_registry.gd
  - game/services/analytics.gd
  - game/services/monetization.gd
  - game/services/nav/boot.gd
  - game/features/debug/p2_tools.gd
  - game/features/debug/diagnostics.gd*
  - game/locale/debug.csv*
  - game/tests/integration/test_debug_p2b.gd*
  - docs/qa/T-0329/**
  - tasks/T-0329-debug-p2b.md
revision: 1
---

## Goal
Implement FR-DEBUG-04: simulate calendar days/time zones using the shared injected Clock, inspect active configuration/buckets, and display a bounded live log of accepted analytics events.

## Context
- PRODUCT.md FR-DEBUG-04/06; FR-ANL-01: only registered events, no analytics schema changes.
- ARCHITECTURE.md: Clock is shared injection; monotonic time is for elapsed durations, calendar time is for day boundaries.
- docs/DESIGN.md#rules-quote-these-into-ui-tasks: existing catalog components, token visuals and translated labels.

## Current state
- Clock exposes unix_time_seconds/monotonic_msec/monotonic_usec. Boot creates one Clock and Nav.boot injects it into every service.
- Monetization._local_day combines injected Unix time with the system timezone bias directly; this is the one calendar consumer to adapt to the Clock seam.
- Config owns validated ConfigRegistry defaults and overrides. Analytics owns validated experiment buckets, registered-event acceptance and consent-gated delivery; track and _track_stub accept events before delivery.
- T-0294 exposes an optional debug facade through Nav and a scrollable P2 panel; services/debug and features/debug are excluded from Release and inspected in CI.

## Specification
- Add Clock.time_zone_bias_minutes() returning system bias. Replace only Monetization's direct bias lookup with this injected method. Existing clock behavior, ad rules/caps, save schema and frequency values remain unchanged.
- New services/debug/clock.gd extends Clock without a global class. Wrap an injected source; offset Unix time by whole days, override timezone in minutes, reset to source. Monotonic methods delegate unchanged. Guard mutations with OS.is_debug_build; validate bounds (100 years of offset, timezone -14h..+14h). No system clock/environment changes or persistence.
- Debug Boot wraps its normal Clock before Nav.boot; Release uses plain Clock and never loads developer scripts.
- Public copied read seams: ConfigRegistry.snapshot defaults; Config.active_values overlays validated active overrides; Analytics.experiment_buckets copied. No endpoint, install identity, cache metadata or writable internal references.
- Add Analytics.event_accepted(name,params) signal after successful stub acceptance/durable runtime enqueue, using independent parameter copies. No signal for denied, rejected, full or failed-persistence calls. No new event name/schema, no queue drain or consent bypass. Consumers cannot mutate the queued original.
- New injected debug diagnostics observer connects accepted events and consent changes. Keep at most 32 transient entries of canonical names plus at most 256 characters of serialized registered params; never common install/user context. Clear on denied consent and close; explicitly disconnect connections. No polling, SDK delivery, file/network I/O or global state.
- Observer snapshot includes offset/zone, active values, buckets and copied live entries. Refresh on open, accepted events and explicit Refresh; clock actions update immediately. Configure validates the same Clock for Save/Economy/Analytics; wrong or disabled bindings are refused.
- Debug facade exposes optional diagnostics reference; Boot owns and closes observer. Existing P2 panel composes a feature VBox from translated TextButtons/Labels: previous/next day, previous/next timezone hour, reset, refresh, active config/buckets and live log. Canonical config/event identifiers and their diagnostic values remain verbatim under translated headings; they are technical identifiers, not player copy.

## Tests
New test_debug_p2b.gd: fixed-source offset/day/zone/reset and unchanged monotonic clocks; invalid bounds leave state unchanged; real Monetization shop cap flips at the injected timezone/day boundary; copied active override/bucket snapshots; accepted log stays bounded and copies parameters, rejects unknown/full/failed/denied events, clears on consent denial/close and disconnects; actual catalog UI updates translated headings and clock controls without writes/delivery. Test stub and runtime acceptance paths with isolated memory queue.
Native debug matrix captures and full make check plus both Android checks.

## Acceptance
Full checks and independent review pass. Debug F3 exposes working shared time/config/log controls; actual Release archive excludes developer implementations.

## Wave refinement
Risk increased for the explicit shared calendar seam and analytics observation boundary. Several tiny generic read/signal seams support one debug feature without exposing private state or adding globals; no roadmap edit, new SDK or production balance behavior.

## Rollback
Squash revert; time/log state is transient and no migration is required.
