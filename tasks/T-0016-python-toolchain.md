---
id: T-0016
title: Python toolchain - uv workspace for pipeline/ and tools/, ruff, pytest, hypothesis, gdtoolkit
epic: E01
type: infra
area: tools
risk: low
executor: human       # done in a Claude Code session Chris started
think: low
ui: none
status: done
depends_on: [T-0014]
touch:
  - pyproject.toml
  - uv.lock
  - pipeline/**
  - tools/**
  - README.md
  - tasks/T-0016-*.md
revision: 1
---

## Acceptance
- Root `pyproject.toml`: uv workspace (members `pipeline`, `tools`), pinned dev deps ruff 0.16.10,
  pytest 9.1.1, hypothesis 6.168.3, gdtoolkit 4.5.0; ruff and pytest config; `uv.lock` committed.
- Packages `wow_pipeline` and `wow_tools` (src layout) with sample tests (one hypothesis test).
- Verified: `uv sync`, `ruff check`, `ruff format --check`, `pytest` (3 passed) all green.
