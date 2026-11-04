---
id: T-0359
title: Allocate unreleased slots deterministically with protected future reservations
epic: E22
type: feat
area: pipeline.sequence
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0358]
touch:
  - pipeline/src/wordgame_pipeline/sequence/allocate.py
  - pipeline/tests/sequence/test_allocate.py
  - docs/contracts/scoring.md
  - tasks/epics/E22-content.md
  - tasks/T-0359-sequence-allocation.md
revision: 1
---

## Goal
Implement T-0300's deterministic preview allocation against an explicit slot plan,
curve and duplicate policy, preserving every authored/released reservation.

## Current state
Preflight maine64556e: SlotPlan validates partition/reservation ownership, CurveTarget
is bounded/protected, dedupe.audit_duplicates validates analysis records and reports
immutable conflicts. No allocator or preview command exists. Scores must be supplied
by caller; T-0360 binds them to common explicit scoring config/source evidence.

## Interface
Frozen ScoredCandidate(id,letters:tuple,words:tuple,seed_word,difficulty:float,
authored:bool,landmark:bool), record(slot)->fresh dedupe record.
allocate(plan:SlotPlan,candidates:list|tuple,policy:DuplicatePolicy,language)
->frozen Allocation(assignments:tuple[Assignment],unused:tuple[str]). Assignment
contains requirement,candidate,mode,deviation,rejected:tuple[Rejection].
AllocationError(ValueError) exposes code,slot,blocked/conflicts immutable tuples;
never contains a partial assignment. Rejection records candidate ID/reason/conflicts.

## Specification
- Validate types, immutable candidate data, unique IDs, bounded scores and configured
  normalized/formable selected words using existing public dedupe API. Every
  candidate validates before selecting anything; authoritative seed is explicit.
- Require every fixed ID present. Authored proof must match requirement; landmark
  flag exactly matches slot kind, and landmark candidates must be authored.
  Validate all fixed pairs before greedy work; conflicts fail fixed_conflict.
- Reserve ALL fixed IDs before allocation, including future authored/released slots.
  Reject pool smaller than total before walking a huge plan. No content mutation.
- For each free slot ascending, rank unused nonreserved candidates by absolute score
  distance to target then ID. Unreserved authored candidates cannot be auto-moved.
  Check every trial against all fixed future and selected past records through
  existing duplicate policy (including every-word100-slot campaign spacing).
  Choose first eligible candidate; report earlier rejected candidates/conflicts.
- Modes released/authored/nearest; report absolute deviation except onboarding
  target=None gives deviation=None. Return all assignments in slot order and sorted
  unused IDs. Input order/permutations cannot affect results.
- If no greedy choice remains raise greedy_blocked with exact slot/rejections.
  No backtracking/global-unsatisfiable claim, partial plan or automatic relaxation.
  Input syntax errors remain ValueError; missing/incompatible fixed or insufficient
  pool use structured AllocationError. Caller owns comparable score/config proof,
  prior grid/tier/source validation and released geometry hashes.

## Tests
Nearest/tie/permutation/immutability; onboarding/released/future authored preserved;
future fixed duplicate blocks nearer candidate; unreserved authored excluded;
landmark compatibility; all-fixed conflict/missing candidate/pool-too-small/huge
plan fail fast; blocked greedy diagnostics and no input changes; invalid candidate/
score/tuple/ID/language/call shapes. Full check/fresh review/all exact-head CI.

## Rollback
Revert removes unused preview allocation; shipped content/handlers unchanged.


## Merged-task status reconciliation (2026-10-30)

Implementation was merged on main in [PR #242](https://github.com/krystiangaleczka-tech/World-of-Words/pull/242) with 16/16 exact-head CI success. Planner metadata corrected from stale `review` to `done`; executable code and released content were not changed.
