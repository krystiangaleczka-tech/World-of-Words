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
status: ready
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
- `tasks/ROADMAP.md` — T-0052 is a hotspot CI repair in lane H.
- T-0018 requires `make pipeline-test` when the change set contains a path under `pipeline/**`.
- Current CI evidence from T-0032: `git diff` logs `Not a git repository`, yet the detector emits
  `changed=false` and skips the required test step.

## Current state
- `.github/workflows/ci.yml`
  - `scope` and `test-count` configure `$GITHUB_WORKSPACE` as a Git safe directory.
  - `pipeline-test` performs Git operations without that setup.
  - `git diff ... | grep -q .` is inside an `if`, so a Git failure falls through to the same branch
    as a legitimate empty diff.

## Specification
### Behavior
1. Configure `$GITHUB_WORKSPACE` as a Git safe directory before pipeline change detection.
2. A failing `git diff` must fail the detector step instead of producing `changed=false`.
3. Preserve current behavior: pull requests compare against the PR base SHA; main pushes compare against
   `github.event.before`; no `pipeline/**` change prints the explicit SKIP reason.
4. Do not alter any other CI job or trigger.

### Edge cases
| Case | Expected |
|---|---|
| Git metadata is unusable | detector step fails |
| no `pipeline/**` path changed | `changed=false`, explicit SKIP |
| at least one `pipeline/**` path changed | `changed=true`, `make pipeline-test` runs |

## Out of scope
- Changes to pipeline code or tests.
- Changes to branch protection, Makefile, toolchain image, or other workflows.

## Tests
CI evidence:
- T-0052 PR: existing CI remains green and the detector no longer logs a Git repository error.
- T-0032 rerun after merge: `Run pipeline tests` executes because that PR changes `pipeline/**`.

## Acceptance
- Detector cannot convert a Git failure into `changed=false`.
- T-0032 CI executes `make pipeline-test` and passes.

## Rollback
- Squash-revert T-0052; no persisted data or schema is changed.

## Escalation log
