---
id: T-0039
title: Enforce registry schemas and literal service calls in CI
epic: E03
type: infra
area: ci
risk: high
executor: sol
think: med
ui: none
status: review
depends_on: [T-0037, T-0038]
touch:
  - tools/check_registries.py
  - tools/tests/test_check_registries.py
  - Makefile
  - .github/workflows/ci.yml
  - tasks/T-0039-registries-ci.md
revision: 1
---

## Goal
Fail CI for unregistered literal Config/Analytics calls or invalid shipped registries.

## Context
- ARCHITECTURE.md#registries: "fails CI when a literal key passed to Config.get_* or
  Analytics.track is not registered, or when a registry file breaks its schema."
- PRODUCT.md FR-CFG-01 and FR-ANL-01.
- ROADMAP T-0039 (HS), dp07 section 5.

## Current state
T-0037 and T-0038 are done on main. Config exposes get_int/get_float/get_bool/get_string;
Analytics exposes track. Their v1 schemas live under game/services/{config,analytics}/registry.schema.json.
Root registries are game/data/config/{hint,unlocks}.json and game/data/analytics/lifecycle.json.
Makefile check includes registries, but the target skips its nonexistent script.
CI has eight jobs; gdtoolkit/Lark are existing pinned development dependencies.

## Specification
### Behavior
1. CLI tools/check_registries.py [--root PATH] returns 0 on success, 1 on invalid data/source;
   deterministic diagnostics identify registry paths or source path and call line.
2. Read every root JSON file in config and analytics, validate against checked-in v1 schemas.
   Missing schemas/directories, empty registries, duplicate JSON keys, malformed/non-JSON values
   and duplicate names across files fail. No new dependencies.
3. Also enforce Config runtime invariants: filename prefix, nonblank owner/description,
   default within ordered inclusive range, and no remote unlocks/consent tuning.
4. Inspect production game/**/*.gd using the existing GDScript parser. Every literal first argument
   to Analytics.track and Config.get_int/get_float/get_bool/get_string must exist; typed getters
   must agree with the entry type. Support StringName literals, escapes and multiline calls.
5. Ignore comments, string contents and other receivers. Exclude game/tests, addons and .godot:
   negative tests and vendor/generated code are not shipped application calls. Dynamic expressions
   are reported as runtime-validated calls; no attempt to evaluate variables or composed strings.
   Syntax errors fail closed. Config.get means the typed APIs from ARCHITECTURE, not Object.get.
6. Implement the checked-in schema vocabulary without an external JSON-schema dependency;
   fail closed on unsupported assertion keywords, including nested schemas. No claim of a general
   Draft 2020-12 implementation. Schema changes using supported assertions take effect immediately.
7. make registries always invokes the checker. Add a registries CI job using the existing container
   and checkout pattern, on both PRs and main. Existing jobs remain intact.

## Out of scope
Registry/schema changes, analytics emission, dynamic argument evaluation, third-party linting,
new dependencies, gameplay, and validating literal analytics payloads (runtime handles these).

## Tests
File: tools/tests/test_check_registries.py
- Shipped registries pass; multiline StringName and escaped literals pass.
- Each unknown event/getter literal fails with path and line; wrong typed getter fails.
- Comments/strings/other receivers and negative-test/vendor/generated fixtures are ignored.
- Dynamic/composed arguments are reported; invalid GDScript fails.
- Config types, numeric bounds, ranges, required/extra metadata and remote/prefix invariants fail.
- Analytics invalid names, param types, extra metadata and blank descriptions fail.
- Empty/malformed/duplicate-key JSON, duplicate events and missing files fail.
- Changed schema assertions apply; unsupported nested vocabulary fails closed.
Run make check with pinned Godot 4.7.2, metadata/scope/test-count checks, and verify all CI jobs.

## Acceptance
Tests pass and CI contains an unconditional registries gate. No production registry changes.

## Rollback
Squash revert removes the gate and returns the Makefile target to its placeholder.

## Deviations / concerns
Schema evaluation intentionally supports only the current registry schema vocabulary and rejects
unknown assertions. The checker plus regression fixtures exceed the approximate 300-line guidance;
three production files change, within one CI task. An independent fresh-chat review is not claimed.
