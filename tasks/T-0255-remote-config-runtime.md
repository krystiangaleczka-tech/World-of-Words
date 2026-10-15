---
id: T-0255
title: Fetch and cache remote configuration without blocking startup
epic: E17
type: feat
area: services.config
risk: medium
executor: cheap
think: med
ui: none
status: blocked
depends_on: [T-0254, T-0250]
touch:
  - game/services/config.gd
  - game/services/analytics.gd
  - game/services/nav.gd
  - game/tests/integration/test_remote_config_service.gd*
  - tasks/T-0255-remote-config-runtime.md
revision: 1
---

## Goal
Load the last valid remote tuning and experiment assignments offline, fetch validated
updates asynchronously over HTTPS, and report assignment buckets to consent-gated analytics.

## Context
- docs/PRODUCT.md#fr-cfg-configuration-remote-config-ab — FR-CFG-02..04.
- docs/ARCHITECTURE.md#autoloads — Config caches user://config_cache.json.
- tasks/ROADMAP.md T-0255; T-0254 validates remote JSON and buckets.
- T-0250 Analytics provides set_experiment_buckets, track and consent gating.

## Current state
- Config.load() reads sorted local JSON into a ConfigRegistry and typed getters return defaults.
- RemoteConfigContract.validate() is on the T-0254 branch; not merged into main.
- Analytics.set_experiment_buckets() stores event context buckets but does not set SDK user properties.
- Nav.start() calls Analytics.start_runtime() after Save, Config and Content load.
- No remote fetch, HTTPRequest, cache or CDN URL is wired.

## Specification
1. Add Config.start_remote(install_id, analytics, endpoint="", cache_path=...) and
   accept_remote_document(document). It restores first valid primary/temp/backup JSON
   synchronously, exposing only contract-valid overrides and experiment buckets.
2. Valid HTTPS endpoint requests use HTTPRequest with config.remote.timeout_ms, in the
   background. Errors, timeouts, malformed content and non-200 status never block startup
   or replace the last valid configuration. Empty endpoint disables fetch without disabling cache.
3. Valid updates persist atomically via SaveStorage and apply runtime typed overrides.
   Normalize integral numbers from parsed Godot JSON at schema-defined integer fields.
   Unknown/unallowed values continue to follow T-0254 validation rules.
4. Emit registered experiment_assigned {experiment_id:string,bucket:int} events and
   remote_config_applied {config_version:string} for newly accepted responses.
5. Send a snapshot of experiment_buckets as one adapter user property ONLY after
   consent_changed(true); existing Analytics.set_experiment_buckets calls retain behavior
   unless explicitly marked remote. Never transmit properties on unknown/denied consent.
6. Nav initializes the optional cache/runtime after analytics initialization and before
   navigating to the first screen. The deployed HTTPS URL is supplied in T-0257.

## Out of scope
- Hosting, CDN deployment or choosing a network endpoint (T-0257).
- SDK implementation, analytics registry/schema changes, save schema and UI changes.

## Tests
File: game/tests/integration/test_remote_config_service.gd
- Valid values override permitted keys, leave protected keys alone and persist offline.
- Invalid candidate/network status/JSON retains active and cached valid values.
- HTTP JSON integer round-trip preserves valid assignments and typed overrides.
- Backup recovery returns the last valid document if primary is corrupt.
- Experiment assignments use the existing event schema and deterministic bucket.
- An empty endpoint supports cache-only boot; HTTP is not accepted.
- Buckets are transmitted as a user property only after explicit analytics consent.

## Acceptance
- Existing Analytics fake calls unaffected by legacy buckets.
- Consent-gated user-property delivery; no request or SDK call at boot without consent.
- Full CI and independent review required before merging.

## Escalation
S1 dependency exception: The owner explicitly requested T-0255 implementation despite
T-0254 being unmerged/draft. This PR is stacked on t/0254-remote-config-contract
and remains draft/blocked until T-0254 is green, reviewed and merged.
S11: No endpoint, secrets or network permissions are introduced here.
