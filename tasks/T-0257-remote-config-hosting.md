---
id: T-0257
title: Validate and publish static remote config with GitHub Pages
epic: E17
type: infra
area: ci
risk: high
executor: sol
think: med
ui: none
status: review
depends_on: [T-0254]
touch:
  - remote/config.json
  - tools/validate_remote_config.py
  - tools/tests/test_validate_remote_config.py
  - .github/workflows/ci.yml
  - .github/workflows/remote-config-pages.yml
  - tasks/T-0257-remote-config-hosting.md
revision: 1
---

## Goal
Keep an auditable, strict JSON configuration in the repository and provide an
on-demand path to publish only this validated document as a public static asset.

## Context
- docs/PRODUCT.md#fr-cfg-configuration-remote-config-ab — FR-CFG-02 static JSON override.
- docs/ARCHITECTURE.md#autoloads — Config caches an offline remote JSON.
- tasks/ROADMAP.md T-0257 — remote/config.json, CI schema check and CDN workflow.
- T-0254 contract: JSON envelope version=1, values map, experiments with weighted variants.
- GitHub Pages custom workflows publish a static artifact from an authorized environment.

## Current state
- T-0254 contract (#182), T-0255 runtime (#183), and T-0256 timeline tests (#184)
  are merged on main.
- Only four ad cooldown/grace fields are remotely tunable; no consent/unlocks.
- CI is .github/workflows/ci.yml. There is no remote/config.json or Pages workflow.
- No deployed public URL is approved; T-0255 starts with an empty endpoint.

## Specification
1. The checked-in remote/config.json is a neutral baseline: version 1, empty values
   and empty experiments. It never changes gameplay balance by default.
2. The Python stdlib validator fails closed on missing/wrong envelope fields,
   malformed JSON, duplicate JSON keys, wrong type or range, unknown/nonremote
   keys, invalid experiment IDs/weights, duplicate experiment/variant IDs,
   more than 32 experiments or 100 variants, and files over 64 KiB.
3. Add a mandatory always-run remote-config-validation job to regular PR/main CI.
   Python unit tests run as part of existing tools pytest.
4. Add a manual-only GitHub Pages deployment workflow that runs on main only.
   Recheck validity before publication; publish only remote/config.json and a
   minimal entry page, never the repository contents or any secret.
5. No endpoint is assigned to Config.start_remote() until a human enables Pages,
   verifies the deployed URL, and approves it. No external cloud credentials.
6. No changes to the game or save data. Publisher verification is stricter than
   runtime behavior: unknown remote keys fail the publish check, while the game
   continues to ignore/log unknown keys from older cached documents.

## Tests
File: tools/tests/test_validate_remote_config.py
- Shipped baseline, valid override and experiment are accepted.
- Disallowed, unknown, mistyped and out-of-range overrides are rejected.
- Malformed/duplicated JSON, invalid experiment variants and duplicates fail.
- Oversized remote configuration cannot be published.
- CI validation job is independent of the Godot engine.

## Out of scope
- Enabling repository Pages settings, its public domain, or environment policy.
- Automatic deployment on PR or on unreviewed main commits.
- Any SDK, secrets, Firebase, R2 account or runtime endpoint change.

## Acceptance
- Validator and unit tests pass; CI reports the remote-config-validation job.
- No deployment from a PR; manual deploy restricted to main.
- Owner enables Pages > Source: GitHub Actions, restricts github-pages
  environment to main, reviews public URL and triggers manual publication.
- Branch is rebased onto current main and reviewed independently before merge.

## Escalation
S1 resolved: T-0254 is merged. The owner requested the next roadmap task;
the existing PR #185 was mechanically rebased onto current main without conflicts.
S11: Hosting choice is GitHub Pages for zero external infrastructure; no
network URL is activated or deployed. Owner must authorize final public
publication and Pages settings. S7: A new workflow is expressly required by
T-0257, so no changes to project.godot or existing plugins are needed.
