---
id: T-0358
title: Plan protected campaign slots with region and location ownership
epic: E22
type: contract
area: pipeline.sequence
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0357]
touch:
  - pipeline/src/wordgame_pipeline/sequence/slots.py
  - pipeline/tests/sequence/test_slots.py
  - docs/contracts/scoring.md
  - tasks/epics/E22-content.md
  - tasks/T-0358-sequence-slots.md
revision: 1
---

## Goal
Prepare T-0300 slot ownership before candidate selection: complete regional and
location partitions, explicit authored onboarding/landmarks and released IDs.
CONTENT.md#slot-policy forbids removing/reordering released slots; this reserves
identity only and does not replace export's locked geometry hashes.

## Current state
Preflight main5065e20: CurveConfig and target_for_slot calculate protected region-
local targets. No slot plan or allocation exists. Source rules require handmade
slots1–15 and landmarks; existing export owns lock-file geometry verification.

## Interface
Frozen Region(id,curve), Location(id,region,first,last), Reservation(slot,candidate_id),
SlotPlan(regions:tuple,locations:tuple,authored:tuple,released:tuple),
SlotPlan.requirement(slot)->frozen SlotRequirement(slot,region,location,curve,
fixed_id,authored,released). Plan.total is last regional slot. Constructors validate.

## Specification
- Nonempty canonical ordered region/location partitions cover1..total without
  gaps/overlaps; unique trimmed Unicode control/format-free IDs. Every location
  is wholly in its referenced region. Counts follow CurveConfig manifest-safe ints.
- Authored/released reservations are unique slots and candidate IDs within each
  tuple, ordered by slot, in range. Same slot in both must have same candidate ID;
  a candidate ID cannot occupy distinct slots across either collection. Released
  reservations form prefix1..R; no implicit release/content publication.
- Authored reservations cover every existing slot<=15 and every explicit regional
  landmark. Additional authored regular slots allowed. Released onboarding still
  needs matching authored proof; conflicting reservations fail before a plan exists.
- Single in-range query derives CurveTarget and returns exact region/location,
  fixed candidate ID and authored/released flags. No allocation of entire campaign,
  input mutation, weights/config defaults, hashes guessed or content reads/writes.
- Validate malformed direct constructor inputs too. Frozen tuple data and results
  remain immutable; no mapping/reference to mutable caller-owned state is retained.
- Bounded T-0300 wave: T-0358 slot plan; T-0359 deterministic protected allocation;
  T-0360 explicit preview/report. Real parameters, source/seed/tier proof, released
  lock hashes, production integration and publishing remain separate gates.

## Tests
Exact multi-region/location lookup; onboarding and landmark ownership; authored/
released agreement, prefix and cross-collection identity protection; gaps/overlaps/
invalid references; malformed types/counts/IDs/tuple order/duplicates; immutable
results, huge one-slot lookup with no full allocation. Full checks/review/all CI.

## Rollback
Revert removes unused plan contract; published slots/files remain unchanged.


## Merged-task status reconciliation (2026-10-30)

Implementation was merged on main in [PR #241](https://github.com/krystiangaleczka-tech/World-of-Words/pull/241) with 16/16 exact-head CI success. Planner metadata corrected from stale `review` to `done`; executable code and released content were not changed.
