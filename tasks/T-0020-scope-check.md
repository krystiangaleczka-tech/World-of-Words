---
id: T-0020
title: Enforce task touch scope from branch
epic: E01
type: infra
area: tools
risk: medium
executor: sol
think: med
ui: none
status: done
depends_on: [T-0019]
touch:
  - tools/check_scope.py
  - tools/tests/test_check_scope.py
  - tasks/T-0020-*.md
revision: 1
---

## Goal
Reject task branches whose changed files escape the task's declared `touch` allowlist, while always
allowing the task's own metadata file.

## Context
- `docs/design-pass/07-git-pr-merge.md` §2 — task branches are named `t/NNNN-slug`; the task ID in
  the branch lets CI locate the task and enforce `touch`.
- `docs/design-pass/07-git-pr-merge.md` §5 — the required `scope` check enforces
  "changed files ⊆ `touch` + own task file".
- Roadmap row: `tasks/ROADMAP.md` T-0020.

## Current state
- `tools/tasks.py` validates task files and exposes each task's `id` and `touch` allowlist.
- `tools/tests/` is collected by pytest through the root Python toolchain.
- `tools/check_scope.py` and `tools/tests/test_check_scope.py` do not exist yet.
- T-0019 is merged and marked `done`.

## Specification
### Behavior
1. Resolve the task ID from a branch named exactly `t/NNNN-*`; in GitHub Actions prefer
   `GITHUB_HEAD_REF`, otherwise use the current Git branch.
2. Resolve exactly one top-level `tasks/T-NNNN-*.md` task file and read its validated `touch`
   allowlist via the existing task tooling.
3. Compare files changed from the base branch to `HEAD` using Git. The default base is
   `GITHUB_BASE_REF` when set, otherwise `main`; `--base` may override it.
4. Every changed path must match at least one `touch` glob or be the resolved task file itself.
5. Recursive `**` globs operate across path segments; ordinary `*` and `?` match only inside one
   path segment.
6. Success prints a concise `OK:` line and exits zero. Invalid branch/task metadata, Git failures and
   out-of-scope paths print readable `ERROR:` lines to stderr and exit non-zero.
7. Output ordering is deterministic.

### Edge cases
| Case | Expected |
|---|---|
| detached CI checkout with `GITHUB_HEAD_REF=t/0020-scope-check` | resolves T-0020 |
| branch does not match `t/NNNN-*` | fail before scope evaluation |
| no or multiple matching task files | fail clearly |
| changed own task file is not otherwise in `touch` | allowed |
| `tools/**` with `tools/tests/example.py` | allowed |
| `tools/*.py` with `tools/tests/example.py` | not allowed |
| deleted or renamed out-of-scope path appears in Git diff | rejected |

## Out of scope
- Do not edit CI or Makefile; T-0022 wires this check into CI.
- Do not change task schema or planning behavior in `tools/tasks.py`.
- Do not infer task IDs from ROADMAP or commit messages.

## Tests
File: `tools/tests/test_check_scope.py`
- resolves T-0020 from a normal `t/0020-*` branch and permits the own task file.
- accepts changed files covered by exact paths and recursive `**` touch globs.
- rejects an out-of-scope changed file and names it in stderr.
- rejects a non-task branch.
- uses `GITHUB_HEAD_REF` for detached/CI-style branch resolution.
- verifies `*` does not cross a path separator while `**` does.

## Acceptance
- `python tools/check_scope.py` works from repo root on a task branch.
- `make tools-test`, formatting and lint checks pass in CI.

## Escalation log
