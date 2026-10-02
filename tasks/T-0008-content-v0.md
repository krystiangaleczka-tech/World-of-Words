---
id: T-0008
title: Write CONTENT.md v0 from the design pass
epic: E00
type: docs
area: docs
risk: medium
executor: human       # done in a Claude Code session Chris started
think: high
ui: none
status: done
depends_on: [T-0002]
touch:
  - docs/CONTENT.md
  - docs/ARCHITECTURE.md
  - tasks/T-0008-*.md
revision: 1
---

<!-- Record only: done on `main` before the task tooling existed. -->

## Goal
The pipeline, word tiers, level / pack / manifest formats, slot policy and curve have one source that
the schemas (T-0040), the Content autoload (T-0041) and the pipeline epic build on.

## Acceptance
- `#level-schema`, `#manifest`, `#slot-policy`, `#curve` exist (all anchors cited elsewhere resolve).
- Stages and artifacts, tiers with precedence, overrides format, hand-made YAML, hard validation,
  QA sampling, determinism, daily pool, repair loop, sources pending S3a.
- ARCHITECTURE.md areas gain `pipeline/locks/`, `pipeline/sources/` and the curve/scoring configs.
