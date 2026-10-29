---
id: T-0388
title: Support 10k public launch and 30k campaign pack boundaries
epic: E22
type: infra
area: pipeline.export
risk: high
executor: sol
think: high
ui: none
status: review
depends_on: [T-0127, T-0131]
touch:
  - pipeline/src/wordgame_pipeline/content_limits.py
  - pipeline/src/wordgame_pipeline/export/__init__.py
  - pipeline/src/wordgame_pipeline/content.py
  - pipeline/schema/manifest.schema.json
  - pipeline/tests/export/test_export.py
  - pipeline/tests/export/test_campaign_capacity.py
  - tasks/T-0388-campaign-capacity.md
revision: 1
---

## Goal

Remove the 9,999-slot hard stop and four-digit pack filename schema boundary so
the existing exporter and validation paths can represent at least **10,000**
Polish campaign levels at public launch, with capacity for up to **30,000**
post-launch levels. This does NOT generate, review, or ship 10,000 levels.

## Owner decision and preflight (2026-10-29)

Owner requires 10,000 Polish levels on first public release and targets 30,000
post-launch. Existing exporter `assemble` rejects slots >9,999 and
`content.bundle` rejects pack ranges ending >9,999; the manifest schema pack
filename pattern is exactly four digits. Godot Content service resolves file
names from manifest, without a four-digit filename constraint. Existing pack
names remain unchanged. T-0127 and T-0131 are done on main.

## Scope

1. Introduce one shared `MAX_CAMPAIGN_SLOTS = 30_000` in pipeline for export
   and validation limits. Only positive integer slots in 15..30,000 export.
   Validate pack ranges against the same maximum; do not change released slots.
2. Support zero-padded four-digit filenames up to 9,999 and automatically
   widened five-digit filenames from slot 10,000 onward. Keep all prior filenames
   and bytes stable and reject malformed/unsafe manifest paths.
3. Add schema and content/pack boundary regression tests including 9,999,
   10,000, 10,001, 30,000, and 30,001; no oversized 10,000-level fixture should
   be required for simple name checks.
4. Adjust the old `assemble(... slots=10_000)` rejection expectation to
   30,001, without weakening bool/negative/version validation.

## Non-goals and risks

- No source dictionary expansion or cost-bearing AI, no generator
  performance guarantee, no calibrated scoring, no campaign publication.
- This patch does not solve the quadratic P1 greedy selector; T-0408 must
  implement/prove full 10k deterministic, CI-budget generation.
- No game/content JSON, save formats, IAP, monetization or released-slot changes.
- Actual release remains gated on source word review, 100-slot spacing,
  geometry, pack validation, all CI and independent fresh review.

## Tests

`pipeline/tests/export/test_campaign_capacity.py`: manifest schema supports
4/5-digit transitions, rejects malformed paths and 30001 via direct limit helper;
legacy manifest schema still validates, and pack validator enforces upper range.
Existing `pipeline/tests/export/test_export.py` still exercises exporter
invalid type/version bounds and real low-slot determinism.

## Acceptance

Scope + task lint, ruff, pipeline pytest and all required CI green. The task
may merge only after independent review, never solely from this author chat.
