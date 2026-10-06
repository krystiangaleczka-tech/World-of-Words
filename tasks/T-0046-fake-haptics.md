---
id: T-0046
title: Respect the haptics preference and log named Fake patterns
epic: E04
type: feat
area: platform.haptics
risk: low
executor: cheap
think: low
ui: none
status: done
depends_on: [T-0045]
touch:
  - game/platform/haptics/haptics_fake.gd
  - game/tests/unit/platform/test_haptics_fake.gd*
  - tasks/T-0046-fake-haptics.md
revision: 1
---

## Goal
The SDK-free HapticsFake records enabled named patterns, suppresses them when haptics are disabled,
and produces deterministic debug diagnostics. It remains usable in headless/editor tests.

## Context
- `docs/PRODUCT.md#fr-audio-audio-and-haptics` FR-AUDIO-02: "Named haptic patterns `tick`, `soft`, `success`, `error` via the platform adapter; no-op where unsupported."
- `docs/ARCHITECTURE.md#autoloads`: settings belong to Save; only services call platform adapters.
- ROADMAP T-0046 and FR-PLAT-01; Events/settings wiring and device adapter belong to T-0109.

## Current state
- `HapticsAdapter.play(pattern: String) -> void` exists.
- `HapticsFake` extends it, exposes `calls: FakeCalls` and records `play` with `[pattern]`.
- `Save.get_setting(&"haptics_enabled")` exists; the adapter must not import or access Save.

## Specification
### Interface
```gdscript
func configure(haptics_enabled: bool, debug_logger: Callable = Callable()) -> void
func play(pattern: String) -> void # existing signature unchanged
```
The optional logger takes one String. A service supplies the current preference to configure;
this task does not connect global services or settings signals.

### Behavior
1. A new Fake defaults to enabled; `tick`, `soft`, `success`, `error` record exactly one call each,
   in order, using the existing `FakeCalls` format. Repeated patterns are separate calls.
2. Disabled and unknown patterns are no-ops: no record, log, SDK call or gameplay effect.
3. Configure may toggle preference repeatedly and preserves existing call history.
4. On enabled supported calls in debug builds, emit `HapticsFake.play: <pattern>` to the injected
   logger, or `print` when no logger is supplied. Release builds never log.

## Out of scope
Save reads/writes, Events binding, native haptics, changes to HapticsAdapter or Platform selection.

## Tests
File `game/tests/unit/platform/test_haptics_fake.gd`:
- `test_named_patterns_record_in_order`: all four patterns plus a repeated tick retain exact arguments.
- `test_disabled_and_reenabled`: disabled calls do nothing; reenable records only the next call and keeps history.
- `test_unknown_patterns_are_noops`: empty string and `unsupported` produce no record or log.
- `test_debug_logger_receives_enabled_patterns`: injected logger captures exact lines in debug and none in release;
  default no-logger path still records one call without errors.

## Acceptance
All cases pass headlessly; existing adapter tests pass unchanged. No SDK or global state is added.

## Execution evidence
Implemented in the Codex session, not a cheap-model run. Fresh independent review and CI are
required before merge; this completion alone does not satisfy the Phase 0 cheap-executor gate.
