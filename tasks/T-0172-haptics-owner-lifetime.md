---
id: T-0172
title: Cover existing Audio and Haptics owner lifetime safety
epic: E08
type: test
area: platform.haptics
risk: med
executor: sol
think: high
ui: none
status: done
depends_on: [T-0171]
touch:
  - game/tests/integration/test_audio_owner_lifetime.gd
  - game/tests/integration/test_audio_owner_lifetime.gd.uid
  - game/tests/integration/test_haptics_owner_lifetime.gd
  - game/tests/integration/test_haptics_owner_lifetime.gd.uid
  - tasks/T-0172-haptics-owner-lifetime.md
revision: 2
---

## Goal
Protect existing Audio/Haptics behavior from future lifetime regressions, not repair a newly demonstrated bug.

## Context
AGENTS.md requires owned signal cleanup and injected services; T-0165 diagnostics exclude background observations. Original Astra P2 ownership requirements and human gates remain separate.

## Current state
HapticsListener.configure(events: EVENTS_SCRIPT, save: SAVE_SCRIPT, platform: PLATFORM_SCRIPT), _connect_events, _disconnect_events and _play use null checks before event/settings/platform access; adapters are RefCounted.

## Specification
Implement T-0170 Existing Audio/Haptics owner-lifetime safety section. Add only two new integration test files and generated UIDs. No production changes. Existing null guards already reject freed Nodes on Godot4.7.2; passing baseline is expected. Use public effects/connections, memory storage and injected clocks.

## Tests
Audio: freed Save makes play false without sink call/errors; replacement after free restores play/preferences, configure(null) and teardown safe, bounded real voices. Haptics: in-memory Save +Events +HapticsFake: free Save or Platform then emit, silent/no errors; free Events before reconfiguration/tree reentry/teardown, safe; configure fresh owners reconnects exactly once and detaches old emitter. Null owners silent; live preference still suppresses effects. No real device/clock/sleep. Confirm a missing guard mutation or equivalent stale dependency regression is detected; temporary local mutations must be restored before full checks and commit.

## Acceptance
All specified behavior/tests; full make check, scope/count, fresh independent review and final-head green CI before sequential squash merge. No human/phase approval inferred.

## Outcome
Fresh review approved eed150e26e38680b8aef6fba69864da981a58883.
Fullcheck:267GUT/13247assertions,311pipeline,183tools,65levels.
Focused7tests/76assertions pass; isolated missing-disconnect copy triggers
one test/five failed assertions, no script errors. Production unchanged.
Scope5files,count468vs461. Final-head12jobCI required beforemerge.
