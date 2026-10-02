---
id: E01
title: Repo, tooling, CI and accounts
phase: 0
status: active
---

## Goal
One command of truth (`make check`), a CI that is Sol's test loop, scope enforcement on every PR, and
store accounts started early. Rows: `tasks/ROADMAP.md` E01.

## Player-facing outcome
None.

## Decisions
- D1: The repo stays public until Phase 2 content production (Chris, 2026-10-02): Actions minutes are
  free and branch protection works on GitHub Free. Before T-0296 Chris switches it to private, with
  GitHub Pro if branch protection must stay.
- D2: Repo work in Phase 0 is one serial lane `H`. Hotspot files (list under the ROADMAP.md column
  legend) change only in `infra` / `contract` tasks.
- D3: T-0013 pins the Godot 4.x.y version that decision 0001 names (T-0003); it never picks one itself.
- D4: The Docker image is the executor runtime and Sol's test loop (decision 0006): pinned Godot
  headless + Android export templates, Android SDK + JDK 17 + Gradle cache, gdtoolkit, Python + uv,
  make; published to GHCR.
- D5: Squash merge only; branch `t/NNNN-slug`; required checks and auto-delete set in T-0023 (Chris).
- D6: Scope is enforced by CI: changed files ⊆ `touch` ∪ the task's own file (T-0020); the test count
  never drops against `main` unless the PR carries the `test-count-exception` label (T-0021).
- D7: Store accounts start on day 1 (T-0012), because identity verification can take weeks.

## Contracts
- Make targets (T-0017): `check`, `test`, `lint`, `fmt`, `run`, `pipeline-test`, `content-validate`,
  `registries`, `context`, `review`, `board`, `plan`. A target whose inputs do not exist yet skips with
  a message, never silently.
- Task front-matter schema = `tasks/TEMPLATE.md`; `tools/tasks.py lint` validates it, areas come from
  `ARCHITECTURE.md#areas` (T-0019).
- Required CI checks after T-0022: format, lint, godot-import + log scan, unit + integration (GUT),
  pipeline pytest (when `pipeline/` changes), scope, tasks-lint, test-count.
- Labels (T-0023): risk, type, `test-count-exception`.

## Waves
### Wave 1
- T-0012 store accounts + reference devices (Chris, lane ADM; depends: T-0001)
- T-0013 repo layout + `game/project.godot` (depends: T-0003)
- T-0014 Docker image + devcontainer (depends: T-0013)
- T-0015 GUT + sample test (depends: T-0014)
- T-0016 Python toolchain (depends: T-0014)
### Wave 2
- T-0017 Makefile (depends: T-0015, T-0016)
- T-0018 CI v1 (depends: T-0017)
### Wave 3
- T-0019 `tools/tasks.py` (depends: T-0016, T-0007)
- T-0020 `tools/check_scope.py` (depends: T-0019)
- T-0021 `tools/count_tests.py` (depends: T-0020)
- T-0022 CI v2 (depends: T-0018, T-0021)
- T-0023 branch protection, Chris (depends: T-0022)
### Wave 4
- T-0024 `tools/context_pack.py` (depends: T-0019)
- T-0025 `tools/review_pack.py` (depends: T-0024)

## Open questions
- Q13: reference low-end Android model. Owner: Chris, in T-0012. Blocks T-0027 and T-0029.
- Play Console personal vs organization account (the closed-test rule for new personal accounts must be
  verified). Owner: Chris, in T-0012.
- EU trader status (DSA) and the public contact address. Owner: Chris, in T-0012.

## Exit criteria
- `make check` passes in the Docker image and in CI on `main`.
- CI v2 runs the scope, tasks-lint and test-count jobs; a PR that changes a file outside `touch` fails.
- Branch protection is on: squash only, required checks, no force push.
- `make context` and `tools/review_pack.py T-NNNN` produce packs Sol can paste into a chat.
- Play Console and Apple Developer accounts are verified, and the reference devices are in Chris's hands.
