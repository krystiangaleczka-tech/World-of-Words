---
id: T-0013
title: Repo layout and game/project.godot pinned to Godot 4.7.2
epic: E01
type: infra
area: infra
risk: high
executor: human       # done in a Claude Code session Chris started
think: med
ui: low
status: done
depends_on: [T-0003]
touch:
  - game/**
  - pipeline/.gitkeep
  - tools/.gitkeep
  - .gitignore
  - README.md
  - tasks/T-0013-*.md
revision: 1
---

## Acceptance
- `game/project.godot`: Godot 4.7.2, portrait, 1080×1920 `canvas_items` / `expand`, GL Compatibility
  renderer (widest low-end support), `untyped_declaration` and `inference_on_variant` as errors, unsafe
  access as warnings.
- Folder skeleton per `ARCHITECTURE.md#areas`; `.gitignore`; README run section.
- Verified: `godot --headless --path game --import --quit` exits 0 with no errors (4.7.2.stable.official.ed1daf0bf).
