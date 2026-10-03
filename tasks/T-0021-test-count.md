---
id: T-0021
title: Prevent test-count regressions
epic: E01
type: infra
area: tools
risk: low
executor: sol
think: low
ui: none
status: done
depends_on: [T-0020]
touch:
  - tools/count_tests.py
  - tools/tests/test_count_tests.py
  - tasks/T-0021-*.md
revision: 1
---

## Goal
Reject task branches whose committed automated-test count is lower than the base branch, unless Chris
has explicitly approved the reduction with the `test-count-exception` pull-request label.

## Context
- `docs/design-pass/07-git-pr-merge.md` §5 — every PR has a blocking `test-count` check and the
  count may drop only with Chris's exception label.
- Roadmap row: `tasks/ROADMAP.md` T-0021.
- T-0020 is merged and marked `done`.

## Current state
- Python tests live under `pipeline/tests/` and `tools/tests/` and use pytest-style
  `def test_*` functions.
- Godot tests live under `game/tests/` and GUT test methods use `func test_*`.
- CI wiring for this check does not exist yet; T-0022 owns that hotspot change.
- `tools/count_tests.py` and `tools/tests/test_count_tests.py` do not exist yet.

## Specification
### Behavior
1. Count committed Python pytest test functions under `pipeline/tests/` and `tools/tests/`.
2. Count committed GUT test functions under `game/tests/`.
3. Compare `HEAD` with the base branch. The default base is `GITHUB_BASE_REF` when set, otherwise
   `main`; `--base` may override it.
4. Resolve a requested base locally first, then under `origin/` so a CI checkout can use
   `origin/main`.
5. If the HEAD count is equal to or greater than the base count, print a concise `OK:` line and exit
   zero.
6. If the count drops, print a readable `ERROR:` with old count, new count and delta, then exit
   non-zero.
7. A drop is allowed only when the GitHub event payload named by `GITHUB_EVENT_PATH` contains the
   exact PR label `test-count-exception`; the success output must say that the exception was used.
8. Git/read/parse failures print readable `ERROR:` lines and exit non-zero.
9. Counting and output are deterministic.

### Edge cases
| Case | Expected |
|---|---|
| pytest function plus method in a `Test*` class | both count |
| async pytest `test_*` function | counts |
| GUT `func test_*` | counts |
| helper function that does not start with `test_` | ignored |
| local `main` is absent but `origin/main` exists | compare against `origin/main` |
| unrelated PR label is present | a count drop still fails |
| malformed `GITHUB_EVENT_PATH` payload | fail clearly |

## Out of scope
- Do not edit CI or Makefile; T-0022 wires this check into CI.
- Do not create or manage repository labels; T-0023 owns repository policy and labels.
- Do not execute either test framework to discover parameterized case expansion; this guard counts
  committed test definitions.

## Tests
File: `tools/tests/test_count_tests.py`
- accepts an equal/increased count and proves pytest + GUT definitions are both counted.
- rejects a lower count and reports the before/after counts and delta.
- accepts an intentional drop with the exact `test-count-exception` PR label.
- rejects a drop when only an unrelated label is present.
- falls back to `origin/main` when the local base branch is absent.
- reports malformed GitHub event JSON as an error.

## Acceptance
- `python tools/count_tests.py --base main` works from repo root on a committed task branch.
- `make tools-test`, formatting and lint checks pass in CI.

## Escalation log
