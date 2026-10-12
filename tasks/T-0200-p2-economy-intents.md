---
id: T-0200
title: Define P2 economy and monetization intents
epic: E11
type: docs
area: docs
risk: med
executor: sol
think: high
ui: low
status: ready
depends_on: [T-0185]
touch:
  - docs/GAME_DESIGN.md
  - docs/qa/T-0200-economy-intents.md
  - tasks/T-0200-p2-economy-intents.md
revision: 1
---

## Goal
Define P2 economy and monetization intents; complete the owner-requested documentation/review work through T-0203.

## Context
Decision0010 is the owner-authorized ordering exception. PRODUCT owns keys/IDs/unlock defaults; GAME_DESIGN owns proposed intents. Original Astra Q1/Q4 requires durable economy/progress ownership before runtime monetization.

## Current state
GAME_DESIGN has economy intents, stars, bonus chest, ad policy and config registry; PRODUCT has canonical keys/IDs and fixed unlock/consent timeline. No T-0200 note exists.

## Specification
Under decision0010, document P2 intent scope and state proposed Q2 rule; preserve key names/defaults and distinguish P2/P3 sources/IDs. Record grants/spends/reward callbacks only after durable atomic ownership contracts from Astra Q1/Q4, explicit SDK/consent boundaries and pending owner choices. No new balance/runtime/schema/SDK implementation.

## Tests
Review canonical key/ID/default consistency, P2 vs P3 exclusions, proposed choices distinct from accepted, links/anchors, durable grant/spend/native callback conditions, full checks/fresh review/CI.

## Acceptance
Specified work, bounded touch scope, full make check, fresh independent review and final-head successful12jobCI before sequential squash merge. No human test or legal/SDK evidence fabricated.
