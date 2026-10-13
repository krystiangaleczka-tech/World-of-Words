---
id: T-0232
title: Define the durable Economy service contract
epic: E15
type: contract
area: services.economy
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0231, T-0229]
touch:
  - game/services/economy.gd
  - game/services/events.gd
  - game/tests/integration/test_economy_contract.gd*
  - docs/qa/T-0232-economy-service-contract.md
  - tasks/T-0232-economy-service-contract.md
  - tasks/T-0229-save-v3.md
  - tasks/T-0231-economy-ledger.md
revision: 2
---

## Goal
Define the injected Economy service interface and durable transaction semantics for T-0233.
This contract adds fail-closed stubs, not runtime grants or persistence.

## Context
- GAME_DESIGN.md economy rules: "Every change goes through `grant(source, items)` or
  `spend(sink, items) -> bool` with a reason. Balances never go negative."
- ARCHITECTURE.md autoloads: Economy owns coins, items and the economy save section.
- Roadmap T-0232; FR-ECON-02, FR-ECON-03. Owner authorized creating this missing task file.

## Current state
- `game/services/economy.gd` extends ServiceStub with no domain methods.
- ServiceStub.initialize(clock: Clock) injects the boot-owned Clock.
- Save exposes get_section, set_section and flush; SaveSchema v3 economy contains
  coins, hint/reveal items, bonus_counter and an array of journal dictionaries.
- WalletSnapshot validates flat int amounts (coins/hint/reveal); EconomyLedger owns pure arithmetic.
- Events extends ServiceStub; economy_changed does not exist yet.

## Specification
1. Add typed configure(save, config, events)->void, is_ready()->bool,
   snapshot()->Dictionary, journal()->Array[Dictionary], can_afford(items)->bool,
   grant(source:StringName, items:Dictionary)->Error and spend(sink:StringName,items:Dictionary)->bool.
   Inject concrete Save, Config and Events script types; preserve inherited Clock initialization.
2. This task's stubs stay inert even after configure: false readiness/affordability/spend,
   ERR_UNCONFIGURED grant, empty isolated snapshot/journal. No Save calls, signals or mutations.
   No boot wiring or gameplay callers until implementation tasks.
3. T-0233 semantics: configure performs no I/O; readiness requires loaded dependencies and Clock.
   snapshot exposes coins/items/bonus_counter; journal returns an isolated ordered array.
   Amounts follow WalletSnapshot.valid_amounts; reasons must be nonempty and trimmed.
   Invalid, insufficient and overflowing operations fail atomically. grant reports Error;
   spend returns true only after durable success. Reject reentrant mutations during publication.
4. T-0233 records one entry per accepted operation:
   {timestamp:int, operation:String (grant/spend), reason:String, amounts:Dictionary}.
   Timestamp uses injected Clock.unix_time_seconds. Amounts are copied flat positive/zero ints.
   Append then trim oldest entries to injected economy.journal.max_entries (positive int).
   Preserve bonus_counter and unknown owner extensions. Do not alter Save schema or balances here.
5. Define Events.economy_changed(operation:StringName, reason:StringName,
   amounts:Dictionary, snapshot:Dictionary). It is a side-effect notification, not a transaction
   controller or analytics event. T-0233 publishes once after durable success, with copied payloads.
   Failed persistence must not publish or report success; retry must not double-apply or double-journal.
   Exactly-once retry implementation and persistence tests belong to T-0233; callers must serialize
   operations and retry the same unresolved request before issuing another.

## Out of scope
Persistence implementation, journal trimming execution, analytics listener, config registry,
bonus settlement orchestration, gameplay integration, save migrations and platform code.

## Tests
`game/tests/integration/test_economy_contract.gd`:
- Typed interface can be called before initialization and returns fail-closed defaults.
- Initialization and repeated configure with concrete isolated dependencies cause no writes/events.
- Mutating returned empty collections or request payloads cannot change subsequent reads.
- Events signal has exactly the four typed parameters specified above.
- Full make check and task/scope validation.

## Rollback
Revert unused stubs and signal; no runtime wallet or persisted data changed.

## Escalation log
S2 resolved by owner: allowlisted the two status-only dependency files in revision 2.
