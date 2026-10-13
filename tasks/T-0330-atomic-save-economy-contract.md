---
id: T-0330
title: Specify atomic owner commit and lossless P2 adaptation
epic: E16
type: contract
area: services.save
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0241, T-0233, T-0229]
touch:
  - docs/qa/T-0330-atomic-save-economy-contract.md
  - tasks/T-0330-atomic-save-economy-contract.md
  - tasks/T-0241-progress-service-contract.md
  - tasks/T-0233-economy-service.md
revision: 1
---

## Goal
Define the missing prerequisite contract for T-0242 without activating or changing persistence.
Owner explicitly approved a separate Save/Economy and migration contract after PR #164 escalation.
T-0330 is the next free Phase 2 ID after T-0329; ROADMAP remains untouched.

## Context
T-0241 specification 6 and acceptance boundary; T-0203 D2; ARCHITECTURE.md Save ownership;
GAME_DESIGN.md P2 owners and Q2 one-star rule. Economy owns all wallet validation and balance
changes. Preparation produces values only, never another service-owned balance change.

## Current state
Save v3 set_section mutates the dirty document before flush. SaveStorage commit has five interruption
checkpoints and load selects primary, temp, backup. Economy has one pending request, masks its own
candidate and trims its diagnostic journal. ProgressCommitPort is unavailable. SaveSchema language
state lacks location_stars; SaveMigrations default chain ends at v3. No runtime coordinator exists.

## Specification
Write docs/qa/T-0330-atomic-save-economy-contract.md with exact proposed typed APIs, response shapes,
owner serialization and committed/pending visibility, validated candidate/recovery rules, durable
processed identities/reset lineage, lossless v3-to-v4 adaptation, replay policy, activation gates,
implementation split and named failure tests. Reconcile merged T-0241/T-0233 statuses to done.
No executable API, Save schema, migration, balance, Events, dependency or boot change in this task.
The future implementation must be separately scoped and must preserve existing public call behavior.

## Tests
- Verify every Current state assertion against source and every referenced requirement against docs.
- Inspect contract against T-0203 D2 and T-0241 requirements with fresh independent Sol review.
- Full make check, task lint, committed scope check and CI.
Runtime crash/migration tests are specified for later implementation, not claimed to run here.

## Acceptance
Contract includes executable signatures, exact candidate/receipt shapes, failure/restart semantics,
legacy conflict policy and all named future tests. No unresolved policy disguised as implementation.
T-0242 remains blocked until separately implemented and verified prerequisites exist.

## Rollback
Documentation only; revert does not alter runtime or on-disk state.
