---
id: T-0172
title: Safely handle destroyed haptics dependencies
epic: E08
type: fix
area: platform.haptics
risk: med
executor: sol
think: high
ui: none
status: ready
depends_on: [T-0171]
touch:
  - game/services/haptics_listener.gd
  - game/tests/integration/test_haptics_owner_lifetime.gd
  - game/tests/integration/test_haptics_owner_lifetime.gd.uid
  - tasks/T-0172-haptics-owner-lifetime.md
revision: 1
---

## Goal
Safely handle destroyed haptics dependencies. Owner requested another five pre-P2 technical tasks.

## Context
AGENTS.md requires owned signal cleanup and injected services; T-0165 diagnostics exclude background observations. Original Astra P2 ownership requirements and human gates remain separate.

## Current state
HapticsListener.configure(events: EVENTS_SCRIPT, save: SAVE_SCRIPT, platform: PLATFORM_SCRIPT), _connect_events, _disconnect_events and _play use null checks before event/settings/platform access; adapters are RefCounted.

## Specification
Implement T-0170 Haptics dependencies section. Edit only those guard expressions; preserve signals, current adapter lookup, preference and no hot-path allocation.

## Tests
In-memory Save +Events +HapticsFake: free Save or Platform then emit, silent/no errors; free Events before reconfiguration/tree reentry/teardown, safe; configure fresh owners reconnects exactly once and detaches old emitter. Null owners silent; live preference still suppresses effects. No real device/clock/sleep.

## Acceptance
All specified behavior/tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/phase approval inferred.
