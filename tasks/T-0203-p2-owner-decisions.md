---
id: T-0203
title: Apply the owner decisions after the P2 second opinion
epic: E11
type: docs
area: docs
risk: med
executor: sol
think: high
ui: low
status: ready
depends_on: [T-0202]
touch:
  - docs/GAME_DESIGN.md
  - docs/qa/T-0203-owner-decisions.md
  - tasks/T-0203-p2-owner-decisions.md
revision: 1
---

## Goal
Apply the owner decisions after the P2 second opinion; complete the owner-requested documentation/review work through T-0203.

## Context
Decision0010 is the owner-authorized ordering exception. PRODUCT owns keys/IDs/unlock defaults; GAME_DESIGN owns proposed intents. Original Astra Q1/Q4 requires durable economy/progress ownership before runtime monetization.

## Current state
T-0202 independent report and T-0200/T-0201 proposals exist; owner must explicitly choose Q2/Q7/Q15 and intents/onboarding. Existing config table contains canonical defaults and starting values.

## Specification
Record actual owner choices after review, apply them to GAME_DESIGN and list canonical/default/starting value disposition without editing runtime registries. Resolve all reviewer blockers before acceptance. Q7 is a development policy, not legal verification; provider/store evidence remains pending. If owner choices absent keep blocked, never assume a preselected answer was submitted.

## Tests
Verify explicit decision provenance, proposals vs approved rules, review findings disposed, config names/default ranges consistent, Q7 scope/content language separation, human evidence unchanged; full checks/fresh review/CI.

## Acceptance
Specified work, bounded touch scope, full make check, fresh independent review and final-head successful12jobCI before sequential squash merge. No human test or legal/SDK evidence fabricated.
