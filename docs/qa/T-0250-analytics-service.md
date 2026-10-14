# T-0250 analytics service evidence

## Runtime contract

`Analytics.start_runtime` is called by Nav only after Save, Config and the selected content manifest
load. It loads the frozen 47-event registry, reads the non-remote
`analytics.queue.max_events` value and restores `user://analytics_queue.json`. A telemetry setup
error is nonfatal to navigation; `track` remains unavailable unless setup completed.

Each durable queue entry contains the registered event name, its exact event-specific parameter
snapshot and this common context captured when the event was accepted:

| Field | Source | Stored/provider type |
|---|---|---|
| `install_id` | Save `meta.install_id` | string |
| `app_version` | `application/config/version` | string |
| `content_version` | accepted Content manifest | integer |
| `language` | accepted Content manifest, required to match Save | string |
| `experiment_buckets` | `set_experiment_buckets` snapshot | canonical sorted JSON string |

Experiment IDs are lower snake case, at most 40 characters, and bucket values are integers 0..99.
The empty object is the P2 default. T-0255 owns deterministic assignment and provider user
properties; T-0250 only supplies the event context boundary.

Event-specific registry validation happens before capacity or consent handling. Denial therefore
does not turn invalid producer calls into accepted calls. If an event-specific `language` or
`content_version` field exists, it must equal the common context; the provider receives one value.
No exception text, receipt, transaction token, advertising identifier or provider identifier is
added by this service.

## Consent state and collection inventory

The service starts in `unknown` on each launch and listens only to its configured
`Events.consent_changed(analytics_allowed: bool)` bus. T-0261 will map the purpose-specific consent
result: granted or legally/provider-verified not-required becomes `true`; denied, unresolved and
revoked do not authorize transmission. Unresolved has no emission and keeps the state unknown.

| State/action | Local queue | Adapter/network boundary |
|---|---|---|
| unknown + valid event | append durably | no adapter call |
| first/updated `true` | drain FIFO | one `log_event` handoff per entry |
| allowed + valid event | append durably, then remove after handoff | immediate `log_event` handoff |
| first/updated `false` | publish empty primary and purge recovery copies | no adapter call |
| denied + valid event | discard | no adapter call |
| denied then later `true` | deleted history remains deleted | future events may be handed off |

Before the decision, this task performs file I/O only. It makes no consent-information, config,
ads, purchase, analytics or crash network request. The platform Fake records calls in headless and
editor runs. T-0249/T-0252 own native SDK installation and actual analytics network behavior;
T-0254/T-0255 own remote-config traffic; T-0261 owns consent-information and ads ordering; purchase
and crash traffic remain with their respective adapter tasks. Crash collection remains disabled
pending its separate legal/provider gate.

## Durability and delivery semantics

The queue document has schema version 1 and an ordered `events` array. It uses the existing
`SaveStorage` temp/flush/backup/primary write boundaries but remains independent of `save.json`.
Startup checks primary, temp and backup in that order. A valid temp is promoted without rewriting it;
a valid backup remains untouched until a new primary is durably published. If recovery itself is
interrupted, that accepted source remains available to the next attempt. If every candidate is
malformed, analytics-only data is discarded and an empty document is written so gameplay can continue.

Capacity counts restored entries. Overflow rejects the newest event and leaves the accepted FIFO
unchanged. Every append is published before it appears in memory. Adapter `log_event` has no result,
so its call is the handoff boundary. The service then publishes removal of that head entry. If the
removal write fails, the entry stays pending and may be handed off again: delivery is intentionally
at least once rather than silently lossy. Provider-side offline retry after a successful handoff
belongs to T-0252.

Denial uses a stricter cleanup path: it writes an empty primary and removes temp/backup copies. If
that write fails, it deletes every queue candidate as a privacy-preserving fallback and clears the
in-memory queue. Already handed-off events cannot be recalled.

JSON represents numbers without preserving the in-memory integer/float variant. Recovery restores
integer fields only where the frozen event definition or common-context schema requires an integer;
nonintegral and unsafe values remain invalid. Runtime producer validation remains strictly typed.

## Verification

- Isolated integration coverage exercises unknown/granted/denied/revoked states, restart FIFO and
  capacity, payload snapshots, common context, strict buckets, type restoration, temp recovery,
  corrupt reset, write/removal interruption, at-least-once retry, mode isolation and signal teardown.
- The real boot smoke verifies that the shipped config key loads and Analytics becomes runtime-ready
  without an adapter call.
- The legacy registry suite remains unchanged and covers the explicit Fake-only stub mode.
- Full `make check` passed locally on Godot 4.7.2: 624 Godot tests / 23,200 assertions, 329
  pipeline tests and 500 tools tests, followed by registry, content, UI-string/token and
  generated-theme checks. Scope, exact-head independent review and all required CI checks are
  recorded in the PR.
