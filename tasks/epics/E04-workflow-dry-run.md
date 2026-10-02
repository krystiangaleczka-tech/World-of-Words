---
id: E04
title: Workflow dry run
phase: 0
status: planning
---

## Goal
Prove the loop plan → parallel cheap executors → CI → review → merge on four small tasks, and fix the
template and `AGENTS.md` with what it teaches. Closes Phase 0. Rows: `tasks/ROADMAP.md` E04.

## Player-facing outcome
None. A debug screen exists in debug builds only.

## Decisions
- D1: Four tasks in disjoint areas and lanes, all `cheap`, all `risk: low`: `platform.haptics`,
  `data.config`, `features.debug`, `core.board` (ROADMAP lanes `D1` … `D4`). They run at the same time.
- D2: Sol writes the four task files in one `plan/E04-wave1` PR (T-0045) and releases them with
  `tools/tasks.py plan`. `docs/design-pass/06-standard-taskow.md` §4 (Shuffle) is the model task for
  T-0049.
- D3: The retrospective counts escalations, red CI runs and Chris's review minutes per task (T-0050).
- D4: Fixes go into `tasks/TEMPLATE.md` and `AGENTS.md`, never into the merged tasks.

## Contracts
None new. The tasks build on E03: the haptics adapter interface and Fake, the Config registry, Nav and
`core/board/`.

## Waves
### Wave 1
- T-0045 write and release the dry-run wave (depends: T-0044, T-0039, T-0042, T-0025)
### Wave 2 (parallel)
- T-0046 Fake haptics (depends: T-0045)
- T-0047 Config registry tests (depends: T-0045)
- T-0048 debug screen shell (depends: T-0045)
- T-0049 `Shuffle.permute` + tests (depends: T-0045)
### Wave 3
- T-0050 dry-run retrospective (depends: T-0046, T-0047, T-0048, T-0049)
- T-0051 PHASE 0 EXIT, Chris (depends: T-0050, T-0030, T-0031, T-0032, T-0033)

## Open questions
- None.

## Exit criteria
- At least three of the four tasks merged without Chris fixing code.
- The retrospective is merged, and its fixes to `tasks/TEMPLATE.md` and `AGENTS.md` are merged.
- Chris signs the Phase 0 exit (T-0051): S1 passed or engine switched, `make check` green in CI, docs
  v1 merged, language and source decisions recorded.
