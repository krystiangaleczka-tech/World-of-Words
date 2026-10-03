---
id: T-0024
title: Build deterministic context packs
epic: E01
type: infra
area: tools
risk: low
executor: sol
think: med
ui: none
status: review
depends_on: [T-0019]
touch:
  - tools/context_pack.py
  - tools/tests/test_context_pack.py
  - tasks/T-0024-*.md
revision: 1
---

## Goal
Add `tools/context_pack.py` so agents can get a deterministic, pasteable snapshot of the repository
for one architecture area plus exact documentation sections cited by a task.

## Context
- `docs/design-pass/05-workflow-ai.md` §4 requires repo map, `@api` signatures and selected docs.
- `docs/decisions/0006-sol-as-repo-agent.md` keeps context packs for cheap executors and Opus.
- Roadmap row: `tasks/ROADMAP.md` T-0024.

## Current state
- `Makefile` already invokes `tools/context_pack.py` from `make context` when it exists.
- `tools/tasks.py` validates task metadata and exposes task state.
- `tools/context_pack.py` and its tests do not exist.

## Specification
1. Print Markdown containing repo map, `## @api` declarations, requested doc sections and non-`done` tasks.
2. `--area AREA` filters map/API files from `ARCHITECTURE.md#areas`; unknown areas fail.
3. Repeatable `--ref path#anchor` extracts that heading and nested subsections; bad refs fail readably.
4. Ignore repository/runtime caches such as `.git`, `.godot`, `.venv` and `__pycache__`.
5. With no arguments, `make context` still emits a whole-repository pack.

## Out of scope
- Writing pack files to disk or changing `Makefile`.
- Review/diff packaging; T-0025 owns `review_pack.py`.

## Tests
File: `tools/tests/test_context_pack.py`
- area map is sorted and includes API signatures, requested nested docs and only open tasks.
- unknown area fails.
- missing documentation anchor fails.

## Acceptance
- `make tools-test` and `make check` pass in CI.
- Only files in `touch` change.

## Escalation log
None.
