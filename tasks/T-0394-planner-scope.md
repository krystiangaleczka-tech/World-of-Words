---
id: T-0394
title: Make planner-only documentation PRs pass bounded scope checks
epic: E22
type: infra
area: tools
risk: medium
executor: sol
think: high
ui: none
status: review
depends_on: [T-0018]
touch:
  - tools/check_scope.py
  - tools/tests/test_check_scope.py
  - tasks/T-0394-planner-scope.md
revision: 1
---

## Goal
Remove a tooling contradiction: ROADMAP.md's rolling-wave rule requires planning
PRs on `plan/ENN-waveN` branches, but `tools/check_scope.py` currently allows
only `t/NNNN-*`, so valid documentation planning PRs fail CI. Keep the task
branch allowlist strictly unchanged.

## Preflight
- Existing `_task_for_branch`, `_outside_scope`, and `main` enforce
  task file/touch scope for `t/NNNN-*` branches.
- ROADMAP.md says planner alone changes ROADMAP.md and commits in `plan/ENN-waveN`.
- PR #287 (offline content replan, documentation/task files only) is blocked by
  this contradiction; no code change is part of that PR.

## Scope
1. Add a narrow `plan/...` branch exception to the **scope tool only**.
   Planner PRs may edit `tasks/ROADMAP.md`, task markdown files under
   `tasks/T-NNNN-*.md`, `tasks/epics/ENN-*.md`, and named source-of-truth
   documents (PRODUCT, CONTENT, DESIGN, GAME_DESIGN, ARCHITECTURE, TESTING).
   Deny all Python, Godot, workflow, generated JSON, secrets, other paths.
2. Preserve task branches' existing per-task `touch` behavior and enforcement.
   Retain rename protection (both old and new paths are checked).
3. Reject invalid `plan/` names and non-task non-planner names, and enforce
   at least one real changed planning file.
4. Add end-to-end git-fixture tests for accepted planning change, rejected code,
   unknown docs, rename from forbidden to allowed and task rules unchanged.

## Non-goals
No bypass of tests or PR branch policy for executable files; independent fresh
review still required. No roadmap or source-of-truth edits are made in this task.

## Acceptance
All tools tests / scope / format / lint and exact-head CI green; external
independent review before merge.
