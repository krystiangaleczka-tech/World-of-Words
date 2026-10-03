---
id: T-0017
title: Makefile with check, test, lint, fmt, run and tool targets
epic: E01
type: infra
area: infra
risk: med
executor: human       # done in a Claude Code session Chris started
think: med
ui: none
status: done
depends_on: [T-0015, T-0016]
touch:
  - Makefile
  - tasks/T-0017-*.md
revision: 1
---

## Acceptance
- Targets: check, test, lint, fmt (+ fmt-check), run, import, pipeline-test, tools-test,
  content-validate, registries, context, review (`T=T-NNNN`), board, plan.
- `import` fails on any ERROR / SCRIPT ERROR / WARNING line in the Godot import log.
- Targets whose inputs do not exist print `SKIP <target>: <reason>` and succeed.
- Verified: `make check` exit 0; a failing GUT assert makes `make test` exit non-zero.
