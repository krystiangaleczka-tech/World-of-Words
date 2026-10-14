---
id: T-0250
title: Add durable consent-gated analytics delivery
epic: E17
type: feat
area: services.analytics
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0247]
touch:
  - game/data/config/analytics.json
  - game/services/analytics.gd
  - game/services/analytics/analytics_queue.gd*
  - game/services/events.gd
  - game/services/nav.gd
  - game/tests/integration/test_analytics_service.gd*
  - game/tests/integration/test_boot_smoke.gd
  - tools/tests/test_check_registries.py
  - docs/qa/T-0250-analytics-service.md
  - tasks/T-0250-analytics-service.md
revision: 1
---

## Goal
Give the P2 analytics service a bounded durable FIFO, required common context and an explicit
consent gate. Events survive restart while consent is unresolved, then are handed to the selected
adapter in order or deleted without transmission.

## Context
- `docs/ARCHITECTURE.md#analytics-audio-localization` — "Until consent resolves, events stay queued;
  after that they are sent or dropped per the outcome."
- `docs/GAME_DESIGN.md#p2-consent-and-collection-policy` — remote transmission stays disabled until
  the appropriate consent; denial and revocation disable the affected telemetry path.
- Roadmap row: `tasks/ROADMAP.md` T-0250; refs FR-ANL-02, FR-ANL-03, FR-CONSENT-02, NFR-10.
- `docs/qa/T-0248-name-review.md` N2/N5 — enforce the consent boundary, exclude sensitive provider
  data and register `analytics.queue.max_events` in this task.

## Current state
- `game/services/analytics.gd`
  - `load`, `configure_stub`, `track`, `flush`, `pending_count` implement registry validation and an
    explicitly configured in-memory Fake-only FIFO. No persistence, common context or consent state.
- `game/services/events.gd` has side-effect signals but no consent signal.
- `game/services/nav.gd::start` loads Save, Config and Content before entering the first screen.
- `game/platform/analytics/analytics_adapter.gd::log_event` accepts a name and Dictionary and has no
  delivery result; provider-side retry belongs to T-0252.
- `analytics.queue.max_events` is documented with default 500 and range 50..5000 but is not shipped.

## Specification
### Behavior
1. Add non-remote config key `analytics.queue.max_events` with documented default/range/owner. Runtime
   setup requires loaded Save/Config/Content, loads the canonical registry, restores a validated FIFO
   from `user://analytics_queue.json`, and never blocks navigation when analytics storage is damaged.
2. Validate event-specific parameters against the canonical registry before consent handling. Accepted
   entries snapshot their values and add `install_id`, current app version, loaded content version,
   language and a canonical JSON `experiment_buckets` string. No raw errors, receipts, ad IDs or other
   provider identifiers are added.
3. Before the first `Events.consent_changed` emission, accepted events are durably queued. `true`
   drains the FIFO in order and hands later events immediately to `Platform.analytics`; `false` drops
   the queue and later valid events. A later `false` is revocation and clears anything not handed off.
4. Capacity includes restored entries. A full queue rejects the newest event with
   `ERR_OUT_OF_MEMORY` and preserves accepted FIFO entries. Every accepted queue mutation is committed
   with primary/temp/backup recovery; a wholly invalid analytics queue is discarded and recreated.
5. `set_experiment_buckets` accepts only lower-snake experiment IDs and integer buckets 0..99, takes
   an independent snapshot, and affects newly tracked events. Empty buckets are valid until T-0255
   supplies assignments and provider user properties.
6. Preserve the existing explicit stub mode and its tests. Runtime setup and stub setup cannot be
   mixed. Repeated runtime setup is idempotent for the same dependencies and does not reset the first
   consent decision of the launch.
7. Nav starts Analytics after Save, Config and Content load. Analytics setup failure is nonfatal to
   gameplay; the service rejects runtime tracking until a later successful setup.

### Interface
```gdscript
## @api
signal consent_changed(analytics_allowed: bool)
func start_runtime(save: Save, config: Config, content: Content,
    event_bus: Events = Events, queue: AnalyticsQueue = AnalyticsQueue.new()) -> Error
func set_experiment_buckets(buckets: Dictionary) -> Error
func runtime_ready() -> bool
```

### States
| State | Event | Next state | Side effects |
|---|---|---|---|
| unknown | valid track | unknown | persist at FIFO tail |
| unknown | consent true | allowed | hand off and remove FIFO entries in order |
| unknown | consent false | denied | delete FIFO without adapter calls |
| allowed | valid track | allowed | persist, hand off, then remove |
| allowed | consent false | denied | delete any unhanded entries; later valid tracks drop |
| denied | consent true | allowed | later valid tracks may be handed off; deleted history stays deleted |

### Edge cases
| Case | Expected |
|---|---|
| Invalid event or payload while denied | `ERR_INVALID_DATA`; validation is never bypassed |
| Persistence fails while accepting an event | Return the I/O error and do not expose it as pending |
| Persistence fails after adapter handoff | Keep the entry for at-least-once retry; duplicates are possible |
| Primary invalid, temp/backup valid | Recover the first valid candidate and canonicalize it |
| Every recovery file invalid | Drop analytics-only data and start with an empty durable queue |
| Consent emitted by unrelated event bus | No state change |

## Out of scope
- Firebase/Sentry installation, provider projects, credentials, endpoints or native configuration
  (T-0249/T-0252).
- Mapping gameplay signals to analytics events (T-0251), consent UI/orchestration (T-0261), remote
  config bucket computation and analytics user properties (T-0254/T-0255).
- Save schema changes or claiming legal/provider consent certification.

## Tests
File: `game/tests/integration/test_analytics_service.gd`
- Unknown consent persists snapshots/common context; restart restores FIFO and capacity rejects newest.
- Grant drains restored/current events in order and sends later events immediately.
- Denial and revocation clear pending entries and suppress later valid events while preserving validation.
- Bucket validation/canonicalization and per-event snapshots are exact.
- Primary/temp/backup recovery, wholly corrupt reset and injected write failures have explicit outcomes.
- Runtime preconditions, mode exclusivity, idempotence and signal disconnect behavior are enforced.

File: `game/tests/integration/test_boot_smoke.gd`
- Real boot loads the new config key and leaves Analytics runtime-ready without provider calls.

## Acceptance
- All tests above exist and pass.
- Existing analytics registry/stub behavior remains green.

## Implementation notes
- Adapter `log_event` is a void handoff boundary. Durable retry after an adapter accepts the call is the
  provider adapter's responsibility; failure to persist the removal intentionally permits at-least-once
  delivery rather than silent loss.
- The queue contains analytics events only and is independent from `save.json`.

## Rollback
A squash revert removes the queue file producer, config key, signal and startup wiring. Existing
`analytics_queue.json*` files are inert if the service is reverted; no Save migration is required.

## Escalation log
<!-- rule id -> question -> answer (revision N) -->
