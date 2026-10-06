---
id: T-0025
title: Build deterministic review packs
epic: E01
type: infra
area: tools
risk: low
executor: sol
think: low
ui: none
status: done
depends_on: [T-0024]
touch:
  - tools/review_pack.py
  - tools/tests/test_review_pack.py
  - tasks/T-0025-*.md
revision: 1
---

## Goal
Add `tools/review_pack.py T-NNNN` so a reviewer can receive one deterministic Markdown bundle containing
the task contract, the branch diff, cited documentation sections and the canonical AI review checklist.

## Context
- `docs/design-pass/07-git-pr-merge.md#7-review-według-ryzyka` — medium/high reviews use
  `tools/review_pack.py`, and the eight-point AI reviewer checklist travels with the pack.
- T-0024 provides deterministic documentation-section extraction in `tools/context_pack.py`.
- Roadmap row: `tasks/ROADMAP.md` T-0025.

## Current state
- `Makefile` already invokes `tools/review_pack.py $(T)` from `make review T=T-NNNN` when it exists.
- `tools/context_pack.py` exposes deterministic `path#anchor` section extraction.
- `tools/review_pack.py` and `tools/tests/test_review_pack.py` do not exist.
- T-0024 is merged and marked `done`.

## Specification
### Behavior
1. Accept exactly one positional task ID in `T-NNNN` form and locate exactly one matching
   `tasks/T-NNNN-*.md` file.
2. Emit Markdown containing the complete task file.
3. Emit the Git diff from the merge base of `main` to `HEAD`; prefer `origin/main` when present
   and fall back to local `main`.
4. Find unique `docs/*.md#anchor` references in the task in first-seen order and include exactly
   those heading sections, including nested subsections, using the same extraction rules as
   `context_pack.py`.
5. Append the eight-point AI reviewer checklist from
   `docs/design-pass/07-git-pr-merge.md#7-review-według-ryzyka`.
6. Output ordering is deterministic. Failures print a readable `ERROR:` message and return non-zero.

### Edge cases
| Case | Expected |
|---|---|
| malformed or unknown task ID | fail readably |
| more than one matching task file | fail instead of guessing |
| cited documentation anchor is missing | fail readably |
| branch has no diff from main | emit `(no changes)` in the Diff section |
| duplicate doc ref in task | include the documentation section once |

## Out of scope
- Writing review packs to disk.
- Calling GitHub APIs or inspecting PR comments/checks.
- Changing `Makefile`, task tooling or context-pack behavior.

## Tests
File: `tools/tests/test_review_pack.py`
- task, merge-base diff, nested cited docs and all checklist items are emitted; unrelated doc sections are absent.
- unknown task ID fails readably.
- missing documentation anchor fails readably.

## Acceptance
- `make tools-test` and `make check` pass in CI.
- Only files in `touch` change.

## Escalation log
None.
