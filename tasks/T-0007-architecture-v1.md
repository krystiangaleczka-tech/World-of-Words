---
id: T-0007
title: Write ARCHITECTURE.md v1 from the design pass
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
  - docs/ARCHITECTURE.md
  - docs/GAME_DESIGN.md
  - tasks/T-0007-*.md
revision: 1
---

<!-- Record only: done on `main` before the task tooling existed. -->

## Goal
Layers, dependency rules, the closed autoload and area lists, save, platform adapters, IAP flow and
registries are written down, so E01 tools and E03 contracts have one source.

## Acceptance
- `#areas` covers every area used in ROADMAP.md (checked by script); boot scene under `services.nav`.
- `#autoloads` (closed list of 12), `#save` (v1 shape), `#platform` (adapters + Fakes) exist.
- Settings section owned by `Save` (no new autoload).
- GAME_DESIGN.md registry gains `analytics.queue.max_events` (cited by PRODUCT.md FR-ANL-02).
