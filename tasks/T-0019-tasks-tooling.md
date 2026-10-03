---
id: T-0019
title: Task metadata lint, board and parallel plan tooling
epic: E01
type: infra
area: tools
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0016, T-0007]
touch:
  - tools/tasks.py
  - tools/tests/test_tasks.py
  - tasks/T-0019-*.md
revision: 1
---

## Goal
Provide one deterministic CLI for validating task metadata, showing the task board and selecting
tasks that can start safely in parallel.

## Context
- `ARCHITECTURE.md#areas` — "The closed list of areas. Every task names exactly one `area`; `tools/tasks.py` reads this table."
- `docs/design-pass/05-workflow-ai.md` §4 — `tasks.py lint` validates metadata/dependencies, `board` renders statuses and `plan` releases runnable work.
- `docs/design-pass/06-standard-taskow.md` §6 — "One active task per area" and tasks with overlapping `touch` globs do not run together.
- Roadmap row: `tasks/ROADMAP.md` T-0019.

## Current state
- `Makefile` already calls `tools/tasks.py board` and `tools/tasks.py plan` when the script exists.
- `tools/tests/` is collected by pytest through the root Python toolchain.
- `docs/ARCHITECTURE.md#areas` contains the authoritative area table.
- `tools/tasks.py` and `tools/tests/test_tasks.py` do not exist yet.

## Specification
### Behavior
1. Read only top-level `tasks/T-*.md`; ignore ROADMAP, templates and `tasks/epics/`.
2. `lint` validates required front-matter fields, enums, task/epic IDs, filename/id match, revision,
   non-empty touch allowlist, areas from `ARCHITECTURE.md#areas`, known dependencies and an acyclic
   dependency graph. Existing legacy `risk: med` is accepted as the historical alias of `medium`.
3. Invalid input prints readable `ERROR:` lines and exits non-zero; valid lint prints the task count.
4. `board` prints all valid tasks in ID order with status, area and title.
5. `plan` considers only `ready` tasks whose dependencies are `done`; it excludes conflicts by area
   or overlapping `touch` globs against `in_progress` tasks and against earlier selected ready tasks.
6. Output order is deterministic by task ID.

### Edge cases
| Case | Expected |
|---|---|
| dependency references a task file that does not exist | lint error |
| dependency cycle | lint error with the cycle |
| two ready tasks overlap each other | only the earlier ID is released |
| `tools/**` vs `tools/tests/**` | conflict |
| `tasks/T-0019-*.md` vs `tasks/T-0020-*.md` | no conflict |

## Out of scope
- Do not edit ROADMAP, Makefile or CI in this task.
- Do not add a YAML dependency.
- Do not infer task metadata from epic files or ROADMAP.

## Tests
File: `tools/tests/test_tasks.py`
- valid task files lint while ROADMAP/templates/epics are ignored.
- schema and unknown areas fail lint.
- unknown dependencies and dependency cycles fail lint.
- the existing `risk: med` alias is accepted.
- board is sorted and includes status/area/title.
- plan requires `ready` plus all dependencies `done`.
- plan blocks same-area and overlapping-touch conflicts with `in_progress`.
- plan returns a mutually disjoint set of ready tasks.

## Acceptance
- `python tools/tasks.py lint`, `board` and `plan` work from repo root.
- `make tools-test`, formatting and lint checks pass in CI.

## Escalation log
