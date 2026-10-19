---
id: T-0351
title: Validate bilingual locale sources and formatting contracts
epic: E21
type: feat
area: locale
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0350]
touch:
  - tools/check_locale.py
  - tools/tests/test_check_locale.py
  - docs/contracts/localization.md
  - tasks/epics/E21-settings.md
  - tasks/T-0351-locale-source.md
revision: 1
---

## Goal
Implement the source-integrity portion of ROADMAP T-0289 (FR-LOC-03/04).
Catch missing PL/EN copy and incompatible format arguments before import.

## Context
ARCHITECTURE.md#localization uses one CSV per area and area.screen.element keys.
DESIGN.md#copy-and-tone requires PL first, EN second, no plural-dependent sentences;
Chris approves Polish prose. Automated integrity does not certify editorial quality.

## Current state
Fresh main e639d19 has 12 area CSVs, existing literal-copy guards and a Godot test
checking nonempty cells/key shape. No standalone strict CSV/format parity guard.
Existing tools pytest runs in make check/CI, without Makefile changes.

## Specification
- Add standard-library tools/check_locale.py with load_catalog(root:Path) returning
  key -> {pl,en} and raising ValueError with path/physical-line diagnostics on
  invalid input. Require nonempty catalog, exact keys,pl,en header, three cells,
  unique area.screen.element keys matching filename, trimmed nonempty copy in both
  languages, no C0 controls except newline/tab. Strict UTF-8/CSV parsing; reject
  malformed quoting and duplicate keys. Blank physical records may be ignored.
- Compare ordered Godot percent-format argument signatures (s,d,o,x,X,f,v,c),
  including dynamic width/precision arguments; allow different literal wording or
  numeric widths but reject type/count/order changes, broken/unsupported tokens.
  %% consumes no argument. Standalone numeric percentage labels (100%) are valid;
  raw percentage mixed with a formatted sentence requires %%.
- CLI --root defaults to repository regardless of cwd; deterministic sorted
  diagnostics and nonzero failure; read only, no rewriting/import/content changes.
  Repository test invokes validator, so existing tools CI enforces it.
- Document contract and bounded three-task T-0289 wave: T-0351 source validation,
  T-0352 actual imported PL/EN parity, T-0353 static references + shipped metadata.
  Keep editorial/native/location-content approval open. Do not invent location copy.

## Tests
Valid quoted commas/newlines/Unicode/escaped percent/numeric percentages; invalid
header/row/key/duplicate/empty/control/encoding/quoting; placeholder missing/type/
order/dynamic arity/broken token; deterministic errors; actual repository source;
CLI from another cwd, fail nonzero and no writes. Full check/fresh review/all CI.

## Out of scope
Runtime UI/resource changes, translation wording approval, plural heuristics,
EN campaign activation, generated content, external destinations and project config.
