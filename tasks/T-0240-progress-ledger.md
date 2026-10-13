---
id: T-0240
title: Implement pure sequential progress and postcard ledger
epic: E16
type: feat
area: core.progress
risk: medium
executor: cheap
think: med
ui: none
status: review
depends_on: [T-0239]
touch:
  - game/core/progress/progress_ledger.gd*
  - game/tests/unit/core/progress/test_progress_ledger.gd*
  - tasks/T-0239-progress-contract.md
  - tasks/T-0240-progress-ledger.md
  - docs/qa/T-0240-progress-ledger.md
revision: 1
---

## Goal
Implement the pure mutable owner of per-language sequential progress for future service candidates.
Owner requested continuing through the next two tasks; no runtime integration in this task.

## Current state
T-0239 ProgressSnapshot and ProgressRules are merged with strict domain counts, JSON-only
canonicalization, fixed-one-star rule, exact piece thresholds and monotonic feature IDs.
No ProgressLedger exists; existing Progress service/Save/runtime are unchanged.
Reconcile merged T-0239 status to done within this scope.

## Specification
1. ProgressLedger.from_snapshot(source:Dictionary,rules:ProgressRules,metadata:Dictionary)
   ->ProgressLedger or null: validate/copy snapshot and canonical metadata {slots,regions,locations}.
   Regions require id/first/last; locations id/region/first/last. Ignore other fields and retain only
   required primitive metadata. IDs nonblank/trimmed, counts positive strict int; slots safe with
   room for end slot+1. Both lists partition 1..slots, IDs unique and locations within referenced
   region. Source current_slot <= slots+1; known location stars cannot exceed completed slots there;
   completed_locations cannot claim future known locations. Retired snapshot IDs/credits survive.
   Evaluate feature union at loaded current slot without changing source, stars or postcard credits.
2. snapshot()->Dictionary returns independent domain state; {} while unconfigured.
   complete(slot:int)->Dictionary accepts only current campaign slot, awards injected one star,
   advances current, increments this location's stars and reveals configured ordered piece credits.
   At location end fill remaining pieces and append completed location once. Region availability
   derives from current slot reaching each region's first; first region available from slot1.
3. Success returns {slot,stars,piece_delta:{id:new_count},completed_locations:Array[String],
   unlocked:Array[String],regions_unlocked:Array[String]}; arrays/maps include only newly earned
   changes. Duplicate/stale/skipped/outside/end/overflow/unconfigured returns {} without any mutation.
   Validate one candidate through ProgressSnapshot before assigning, including star safe-count limit.
4. location_status(id:StringName)->Dictionary returns {stars,pieces,complete} for known location,
   where complete is endpoint reached; unknown/unconfigured returns {}. unlocked_regions()
   ->PackedStringArray lists available regions in order. Queries do not award stars or fill old cards.
5. Snapshot/config/metadata/results isolated; previously credited pieces and features never removed.
   Exactly-once within the pure sequential state and after reloading its successful snapshot. No
   durable Save, reward, Events, language switch, paid-action, legacy backfill or UI guarantees.
   T-0241/T-0242 must adapt domain-only fields and define legacy history/persistence before integration.
   Pure rules use configured piece count; Content/owner validates asset capacity before rendering.

## Tests
New test_progress_ledger.gd: five-level/two-region/three-location exact star/card/unlock sequences,
short-location forced fill and multi-piece threshold, duplicates/stale/skips/end no mutation,
reload exactly once, prior/retired credits and config change monotonicity, copy isolation, overflow,
metadata shape/count/partition/reference failures and unconfigured queries. Full make check, scope
and task lint; fresh independent review and CI before merge.

## Rollback
Unused pure core class only; no live progress or saved data changed.
