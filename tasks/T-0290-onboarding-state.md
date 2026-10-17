---
id: T-0290
title: Persist monotonic onboarding and once-only coach state
epic: E21
type: contract
area: features.onboarding
risk: high
executor: sol
think: med
ui: low
status: review
depends_on: [T-0203, T-0242]
touch:
  - game/core/onboarding/onboarding_state.gd*
  - game/services/save.gd
  - game/services/events.gd
  - game/tests/unit/core/onboarding/test_onboarding_state.gd*
  - game/tests/integration/test_onboarding_save.gd*
  - docs/contracts/onboarding.md
  - tasks/T-0290-onboarding-state.md
revision: 1
---

## Goal
Provide the durable tutorial/coach owner and freeze a nonblocking presentation
protocol for T-0291/92 without activating a scene or changing the save format.

## Context
Roadmap T-0290; PRODUCT FR-ONB-03/05; docs/DESIGN.md#feature-unlock-gating;
GAME_DESIGN.md#onboarding: "animation visibility and durable completion are distinct
states." Save owns meta; Events is side effects only. Existing fields are sufficient.

## Current state
Save v4 meta already has onboarding_step and coach_marks_seen, both validated.
Save.set_section denies meta; set_setting owns immediate flush/committed publication.
Save.writes_blocked shares the atomic lease barrier. Events has no onboarding signal.
The analytics registry already defines onboarding_step with one int step parameter;
T-0328 owns its future listener. No tutorial/CoachMark component or state owner exists.

## Specification
- Pure immutable OnboardingState.from_dict({step:int,seen:Array[String]}) validates
  nonnegative JSON-safe step and unique nonempty trimmed seen IDs, preserving unknown
  historical IDs and higher steps. snapshot returns copies. tutorial_complete is step>=1.
- after_tutorial returns step max1, preserving flags. after_coach(feature) requires
  completed tutorial, accepts only shuffle/bonus/hint/journey/reveal, appends once,
  advances max step to their frozen IDs2/3/4/5/6. No money/unlock changes. No-op is stable.
- Save.configure_onboarding(events:Node)->Error explicitly binds real Events after
  load, without writing. No replacement while pending/dispatching. No boot activation.
  Save.onboarding_snapshot()->Dictionary reads copied committed {step,seen}.
  Save.complete_tutorial()->Error, mark_coach_seen(feature:StringName)->Error and
  retry_onboarding()->Error own metadata changes through existing full-document flush.
- Invalid/busy actions do not stage metadata. One pending exact action survives I/O
  failure, denies replacement and retries the same metadata while retaining unrelated
  owner fields. Snapshot hides dirty state. An unrelated successful Save.flush can
  commit it. Duplicate committed intent writes/emits nothing. Reentrant operations
  are busy, including during Save flush/error callbacks and event publication.
- On matching successful flush only, clear pending identity then emit existing-registry
  Events.onboarding_step(step:int), once per new committed teaching/coach action.
  The step is the action's stable ID (not historical maximum). Shared writes_blocked
  blocks all owner writes during this side-effect notification. No startup/replay event
  is invented after restart. Analytics transmission remains T-0328; no registry edit.
- Preserve other meta including install identity/atomic receipts and every other section.
  No new schema field, migration, balance or autoload. Default Save behavior unchanged.
- Freeze future CoachMark protocol in docs/contracts/onboarding.md: eligible visible
  target highlighted plus inline CAPTION key, any tap or TOAST_HOLD x2 dismissal
  without consuming input; serialize offers/legal/completion, persist before display,
  retry failures explicitly, exactly one presented coach per runtime. No UI code here.
  Tutorial first accepted player-solved LEVEL/BONUS only; hiding on touch never records
  completion. Future T-0291 must distinguish controller committed result from Hint/debug.

## Tests
Pure value validation/copy/monotonic/no-op/unknown-history/out-of-order coach behavior.
Actual Save/Events: opt-in, tutorial then each coach once, event payload IDs, no-op
revision stability, dirty failure/exact retry, unrelated flush, lifecycle/restart,
all five filesystem interruption checkpoints, reentrant commands and owner writers,
foreign/invalid input, metadata/other-section preservation and active atomic lease.
Existing tests unchanged. Full pinned make check, fresh independent review, all15 CI.

## Rollback
Disable explicit opt-in; retain existing fields/readers. No format migration.
