# E04 dry-run release plan — 2026-10-06

Chris requested an audit of current tasks/commits and sequential continuation. This plan freezes
four implementation tasks against main after T-0044 (95fc151), without editing ROADMAP.md.
The scheduler proves disjoint work; execution in this session is one task and merge at a time.

## Completed-task audit

The four stale `review` statuses below are changed to `done`, with no change to their specifications.
Their merge commits are ancestors of the current main and their artifacts are exercised by the
existing checks. This is administrative reconciliation, not a new claim of model/device validation.

| Task | Main merge commit | Evidence |
|---|---|---|
| T-0025 | c024d99 | review_pack.py, existing review-pack tests |
| T-0026 | 9749479 | S1 plan and accepted decision 0007; subsequent device tasks and engine gate completed |
| T-0032 | 7d6c0ae / PR #15 | grid prototype and existing deterministic generator tests |
| T-0053 | d7f73a0 / PR #20 | reviewed swipe measurement, grouped immutable device logs, six measurement regressions |

The existing E03 PRs were independently inspected, tested on successive main revisions and merged:

| Task | PR | Main merge commit | Review outcome |
|---|---|---|---|
| T-0040 | #27 | e9f2e4e | content schemas integrated over device-measurement main |
| T-0041 | #28 | 106f068 | fixed mistyped JSON primitive comparisons; regression coverage |
| T-0042 | #29 | 74c41f5 | bot checks all fixture slots, words, bonus words and grid cells |
| T-0043 | #30 | 7d69fbf | fixed failed restart retaining LEVEL/old slot; retry regression |
| T-0044 | #31 | 95fc151 | real boot scene/autoload/Fake smoke test |

After T-0044: Godot 4.7.2 `make check` passes with GUT 75, pipeline pytest 136 and tools pytest 77.
Each PR had all nine GitHub CI jobs green before merge. Upstream synchronization commits were
preserved when updating existing PR branches; the published trees matched the locally tested trees.

## Preflight and scopes

- T-0046: HapticsAdapter.play and HapticsFake.calls exist. Preference is explicitly supplied by a
  service; no upward Save dependency or global binding is introduced. Existing tick-call compatibility
  remains. The injected debug logger makes diagnostics observable without a native SDK.
- T-0047: ConfigRegistry's append/read/definition/has_key APIs and both shipped documents exist.
  Tests use copies of all nine actual entries, not a second copy of generic toy-entry tests.
- T-0049: pure LevelData establishes original tile identity; built-in seeded RNG exists. Shuffle does
  not exist. The exact pure API and invalid-input contract are frozen, including repeated letters.
  New core logic is medium under TEMPLATE.md even though the roadmap row says low; use medium review.
- No implementation task changes a dependency, autoload, schema, balance value or export setting.

## T-0048 escalation — S1/S3/S4, R-UI-1

DESIGN.md says: "A screen task may not create a component. If a needed component or state is missing,
STOP (S4) and request a separate `ui.components` task." Every screen root must be ScreenScaffold;
new components also need gallery entries. No UI tokens, scaffold, button component or gallery exists.
Nav has DEBUG and its scene path but no public debug route. Save has no reset method. A screen task
cannot quietly invent those contracts. Token bootstrap T-0103 currently depends on Phase 0 exit;
using it as an undeclared Phase 0 dependency creates a gate problem.

T-0048 is blocked. Concrete prerequisite options for a revised plan:

1. Separate Phase 0 UI bootstrap/component/gallery work, plus scoped Save reset and Nav debug-route
   contracts. Freeze reset semantics, injected test storage and debug gating before implementing the screen.
2. Explicitly document a developer-tools exception to the screen/component requirement, still freezing
   the Save/Nav contracts in separate tasks and preserving release exclusion checks in T-0137/T-0138.

No preference between these architectural options is implemented here. No persistent player data is
deleted. The missing UI lane does not block the other three E04 tasks.

## Scheduler release

With T-0045 marked done, `uv run python tools/tasks.py plan` prints exactly:

```text
T-0046  platform.haptics  Respect the haptics preference and log named Fake patterns
T-0047  data.config       Exercise shipped hint and unlock registry type and range validation
T-0049  core.board        Permute tile indices deterministically and change the visible order when possible
```

T-0048 is intentionally absent. All three runnable tasks depend only on T-0045 and have disjoint
areas and touch globs. Execute T-0046, then T-0047, then T-0049; review and merge each on fresh main.

## Remaining gates

T-0031 / draft PR #14 still needs real classification outputs from two providers; no model results
are fabricated. T-0050 waits on T-0048 and actual Chris review minutes; T-0051 is Chris's explicit
Phase 0 exit and also depends on T-0031. Three runnable implementations do not prove cheap-model
participation when performed by Codex; preserve actual executor provenance for the retrospective.
No phase exit or Phase 1 release is claimed by this plan.
