---
id: T-0052
title: Fix pipeline change detection in CI containers
epic: E04
type: infra
area: ci
risk: high
executor: sol
think: med
ui: none
status: done
depends_on: [T-0018]
touch:
  - .github/workflows/ci.yml
  - tasks/T-0052-*.md
revision: 1
---

## Goal
Make the conditional pipeline test job reliable inside the CI toolchain container so changes under
`pipeline/**` always run `make pipeline-test` and Git failures cannot be misreported as "no changes".

## Context
- T-0018 requires `make pipeline-test` when the change set contains a path under `pipeline/**`.
- T-0032 CI evidence: `git diff` logs `Not a git repository`, then the detector incorrectly emits
  `changed=false` and skips the required test step.
- `scope` and `test-count` already configure `$GITHUB_WORKSPACE` as a Git safe directory.

## Current state
- `.github/workflows/ci.yml`
  - `pipeline-test` performs Git operations without the explicit safe-directory setup used elsewhere.
  - Git commands rely on the step's implicit current working directory.
  - `git diff ... | grep -q .` is inside an `if`, so a Git failure falls through to the same branch
    as a legitimate empty diff.

## Specification
### Behavior
1. Configure `$GITHUB_WORKSPACE` as a Git safe directory before pipeline change detection.
2. Run detector Git commands explicitly against `$GITHUB_WORKSPACE`.
3. A failing `git diff` must fail the detector step instead of producing `changed=false`.
4. Preserve comparison semantics and the explicit SKIP message when no `pipeline/**` path changed.
5. Do not alter any other CI job or trigger.

### Edge cases
| Case | Expected |
|---|---|
| Git metadata is unusable | detector step fails |
| no `pipeline/**` path changed | `changed=false`, explicit SKIP |
| at least one `pipeline/**` path changed | `changed=true`, `make pipeline-test` runs |

## Out of scope
- Changes to pipeline code or tests.
- Changes to branch protection, Makefile, toolchain image, or other workflows.
- Editing planner-owned `tasks/ROADMAP.md`.

## Tests
CI evidence:
- T-0052 PR: detector completes without a Git repository error.
- T-0032 rerun after merge: `Run pipeline tests` executes because that PR changes `pipeline/**`.

## Acceptance
- Detector cannot convert a Git failure into `changed=false`.
- T-0032 CI executes `make pipeline-test` and passes.

## Rollback
- Squash-revert T-0052; no persisted data or schema is changed.

## Escalation log
- S1: T-0052 is an unplanned Phase 0 hotfix created at Chris's explicit request to unblock T-0032.
  The planner-owned ROADMAP is intentionally unchanged.
- Evidence: CI run 58 on T-0052 completed the detector without a Git repository error; CI run 60 on
  T-0032 detected pipeline changes, executed `make pipeline-test`, and passed.
