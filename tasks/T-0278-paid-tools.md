---
id: T-0278
title: Integrate durable paid Hint and Reveal with fallback offers
epic: E20
type: feat
area: level.hud
risk: high
executor: cheap
think: high
ui: high
status: blocked
depends_on: [T-0276, T-0277, T-0263, T-0274, T-0336]
touch:
  - tasks/T-0278-paid-tools.md
  - docs/qa/T-0278-paid-tools-preflight.md
revision: 1
---

## Goal
Atomically debit item/coins and publish Hint/Reveal with retry-safe identity.

## Context
GAME_DESIGN.md#hints: a shared dirty Save followed by flush is not sufficient proof
for paid tools. T-0274 supplies the explicit Shop Sheet; activation remains blocked on this preflight.

## Specification
Blocked preflight only. On merged T-0274/T-0276/T-0277 inspect exact durable candidate
and recovery contracts before releasing code scope. Item first, else canonical coin
price; double taps/restart cannot debit twice. Unaffordable opens catalog Sheet with
rewarded or shop alternatives. No UI/free mutation can bypass durable debit proof.
Revise with exact touched contracts/tests; no implementation is authorized here.

## Tests
Executable revision must test each debit/reveal crash gap, idempotence, insufficiency,
reentry and full UI/accessibility matrix. No store/device gates inferred complete.

## Acceptance
Remain blocked until every dependency and durable paid-tool preflight is verified.

## Preflight disposition (2026-10-17)
T-0336 supplies the missing joint paid-tool transaction and durable receipt namespace.
Keep presentation blocked until that prerequisite merges; executable UI scope follows
in revision 2 under Chris's explicit instruction to complete T-0278.
