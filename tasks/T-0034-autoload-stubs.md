---
id: T-0034
title: Register the closed autoload skeleton and injectable Clock
epic: E03
type: contract
area: infra
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0033, T-0011]
touch:
  - game/project.godot
  - game/services/*.gd*
  - game/services/nav/*
  - game/platform/platform.gd*
  - game/tests/integration/test_autoload_stubs.gd*
  - tasks/T-0033-engine-gate.md
  - tasks/T-0034-autoload-stubs.md
revision: 1
---

## Goal
Freeze the T-0034 roadmap scope as a runnable, inert autoload skeleton after the accepted engine gate.

## Context
- ARCHITECTURE.md#autoloads: "The closed list. No task adds, removes or renames one."
- ARCHITECTURE.md#autoloads: "Nav drives the boot sequence explicitly."
- ARCHITECTURE.md#areas: boot scene belongs to services.nav.
- tasks/ROADMAP.md: T-0034; E03 architecture skeleton.

## Current state
- T-0033 merged in PR #18; update its review status to done as merge bookkeeping.
- project.godot has no autoload registrations or main scene.
- services/ and platform/ have no service implementations.
- GUT discovers integration tests; typed declaration warnings are errors.

## Specification
### Behavior
1. Register Config, Save, Progress, Economy, Daily, Content, Monetization, Analytics,
   Audio, Nav, Events, Platform in exactly this order, at architecture-owned paths.
2. Each service inherits a typed, documented ServiceStub injection contract. No domain APIs
   are guessed ahead of T-0035 through T-0043; no file, SDK, signal or game-rule side effects.
3. Clock is RefCounted, never an autoload; wall and monotonic time are separate methods.
4. Boot scene under services/nav is the main scene and calls Nav.boot explicitly.
5. Nav.boot injects one Clock into every service. Repeating boot replaces the prior source.

### Interface
```gdscript
## @api Clock
func unix_time_seconds() -> int:
func monotonic_msec() -> int:
## @api ServiceStub (inherited by all twelve services)
func initialize(clock: Clock) -> void:
func get_clock() -> Clock:
## @api Nav
func boot(clock: Clock) -> void:
```

### Edge cases
- A freshly added service stays uninitialized until explicit boot.
- Fixed Clock subclasses work without sleeping or reading real time in tests.
- Clock must not be null on injection (programming assertion).

## Out of scope
Domain behavior, adapter interfaces/Fakes, persistence, registry APIs, screen routing and SDKs.

## Tests
File: game/tests/integration/test_autoload_stubs.gd
- test_closed_autoload_registration_and_order: exact list/order, live service nodes, no Clock autoload.
- test_boot_scene_initializes_every_service_with_one_clock: main scene creates and shares the source.
- test_fixed_clock_can_replace_previous_boot_source: reinjection and deterministic time on all services.
- test_service_is_inert_until_explicit_initialization: adding a node does not initialize it.
Run make check, task lint, scope check and headless main-scene smoke.

## Acceptance
All specified tests and CI checks pass; boot exits headless without errors or warnings.

## Rollback
Squash revert restores the previous project configuration; no save or content migration is needed.

## Deviations / concerns
- User explicitly requested T-0034 after merging T-0033. T-0023 is a human repository-settings
  task without a task file. Branch-protection inspection returns integration HTTP 403.
  It is retained as an unverified external prerequisite rather than fabricated as a done task
  or included as a missing dependency rejected by the task linter.
- Twelve mandated autoload scripts plus Clock/base/boot exceed the five-production-file guideline;
  the closed-list contract is intentionally atomic and each domain stub has two lines.
