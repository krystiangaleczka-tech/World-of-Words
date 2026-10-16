---
id: T-0269
title: Integrate verified Play Billing and StoreKit 2 plugins
epic: E19
type: infra
area: infra
risk: high
executor: cheap
think: med
ui: none
status: blocked
depends_on: []
touch:
  - docs/qa/T-0269-billing-plugins.md
  - tasks/T-0269-billing-plugins.md
revision: 1
---

## Goal
Prepare the native billing transport without purchase settlement or product creation.

## Context
PRODUCT.md FR-IAP-08: local verification, no backend. Roadmap T-0269.
AGENTS.md S7/S11 apply to native plugins and platform settings.

## Current state
IapAdapter and IapFake exist; no real provider is activated.
T-0264 and its exact plugin/platform baseline are not delivered.

## Specification
Blocked planning record only. Before release to ready, inspect merged T-0264,
accepted S1 decisions, exact maintained plugin versions/APIs and Android/iOS build
loop evidence. Revise this task with the verified file/signature preflight,
smallest exact plugin/settings touch paths, license checks and device build tests.
No plugin/settings mutation is authorized by this blocked specification.
Purchase verification/settlement adapters remain T-0272/T-0273.

## Tests
After executable revision: pinned Android export and iOS build/device smoke tests,
with evidence that Fake selection still makes no provider calls.

## Acceptance
Remain blocked until precise integration scope and prerequisites are verified.
Do not mark ready from guessed plugin names or untested platform settings.

## Rollback
Before activation, revert the isolated plugin integration; no Save migration.

## Planning dependency gate
The roadmap prerequisite is described above but has no task file yet. Add that
ID to depends_on when materialized; status must remain blocked until it merges.
