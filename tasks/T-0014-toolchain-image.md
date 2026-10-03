---
id: T-0014
title: Toolchain Docker image, devcontainer and GHCR publish workflow
epic: E01
type: infra
area: infra
risk: high
executor: human       # done in a Claude Code session Chris started
think: med
ui: none
status: done
depends_on: [T-0013]
touch:
  - docker/**
  - .devcontainer/**
  - .github/workflows/toolchain-image.yml
  - README.md
  - tasks/T-0014-*.md
revision: 1
---

## Acceptance
- `docker/Dockerfile` pins Godot 4.7.2 headless + export templates, Android SDK (platform 36,
  build-tools 36.0.0, NDK r28), JDK 17, Gradle cache dir, uv, gdtoolkit, make.
- `.devcontainer/devcontainer.json` uses the published image (Codespaces / VS Code).
- `.github/workflows/toolchain-image.yml` builds on PR, smoke-tests (Godot import of `game/`, tools
  present) and pushes `latest` + `sha-*` to GHCR from `main`.
- Verified: first run on `main` green (Actions run 37111762837): build, smoke test and GHCR push passed.

## Notes
- Chris's Mac never needs the image: CI, cloud agents and Codespaces run it.
- After the first push, set the GHCR package visibility to public so the devcontainer can pull it.
