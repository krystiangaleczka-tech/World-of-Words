---
id: T-0254
title: Define safe remote config and experiment contract
epic: E17
type: contract
area: services.config
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0203, T-0037]
touch:
  - game/services/config/remote_config_contract.gd*
  - game/data/config/config.json
  - game/data/config/ads.json
  - game/tests/integration/test_remote_config_contract.gd*
  - game/tests/integration/test_p2_config.gd
  - tools/tests/test_check_registries.py
  - tasks/T-0254-remote-config-contract.md
revision: 2
---

## Goal
Define and test bounded, fail-closed validation, deterministic experiment assignments,
and atomic last-valid selection before T-0255 implements nonblocking fetch and storage.

## Context
- PRODUCT.md FR-CFG-02..04: unknown keys ignored/logged, invalid overrides rejected,
  cached last-valid config offline, deterministic install/experiment buckets.
- GAME_DESIGN.md#config-key-registry: allow only explicitly remote=true tuning keys.
  Consent and unlock keys never remote, and first-slot 16 remains canonical.
- T-0037 ConfigRegistry owns validated metadata and typed local defaults.

## Current state
- ConfigRegistry.definition and has_key already exist, runtime reads only local defaults.
- No config.remote.timeout_ms registry or remote validator exists. T-0255 owns HTTP/cache I/O.

## Specification
1. Add canonical config.remote.timeout_ms = 3000, type int, range [500,10000],
   remote false. Enable remote tuning only for the four ad interstitial cooldown/grace keys;
   leave first_slot, consent and unlocks protected.
2. Contract v1 static JSON envelope: version=1, values dictionary, experiments array.
   Ignore and list unknown values; reject invalid, nonremote and out-of-range keys individually.
   Experiment entries {id, variants:[{id,weight}]} require unique nonempty IDs and weights
   totaling 100; reject malformed whole candidate.
3. Stable 0..99 bucket uses hash(install_id+experiment_id) % 100.
4. select_snapshot chooses validated remote, then last valid cache, then defaults.
   T-0255 fetches asynchronously with config.remote.timeout_ms, persists only accepted
   candidates, never blocks app start, and sends experiment assignments to Analytics.
   This task performs no network/cache I/O and defines no endpoint.
5. No registry renaming, save schema changes or analytics side effects.

## Tests
- Reconcile existing T-0234 metadata test with the four newly enabled remote flags;
  retain all other defaults and remote=false checks. Update registry count 36 -> 37.
- Integration tests cover accepted, unknown, protected, bad type/range, deterministic buckets,
  malformed experiments, and offline last-valid fallback.

## Acceptance
No SDK/endpoint, only allowed touch files, all CI checks green.

## Rollback
Revert contract and opt-in flags before T-0255 uses them.

## Escalation log
- S5 (revision 2): CI exposed two existing tests asserting obsolete registry counts and remote=false for every key. The revision explicitly permits the two targeted test updates; no production behavior beyond T-0254 is changed.
