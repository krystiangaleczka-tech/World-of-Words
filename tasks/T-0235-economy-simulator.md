---
id: T-0235
title: Simulate three hypothetical P2 economy archetypes
epic: E15
type: feat
area: tools
risk: medium
executor: cheap
think: med
ui: none
status: done
depends_on: [T-0234]
touch:
  - tools/econ_sim.py
  - tools/tests/test_econ_sim.py
  - docs/qa/T-0235-economy-simulator.md
  - tasks/T-0234-p2-config.md
  - tasks/T-0235-economy-simulator.md
revision: 1
---

## Goal
Provide deterministic offline balances across 300 synthetic levels for saver, hinter and ad watcher.
Owner requested creating/executing this missing task and approved merging its prerequisite.

## Context
GAME_DESIGN.md economy intents: base income is separate from onboarding, bonuses, ads and IAP;
items are consumed before coins. Bonus surplus carries over; daily income remains P3.
Roadmap T-0235; FR-ECON-06; design-pass 03 section 6.2.

## Current state
T-0234 registries define documented defaults and ranges in game/data/config/*.json.
Config JSON definitions have default/type/range/description/owner/remote.
Python tools are directly importable as tools.*; uv/pytest/ruff already run in make check.
No econ_sim exists. Reconcile merged T-0234 status to done within this scope.

## Specification
1. tools/econ_sim.py reads and validates required defaults from supplied config directory, no network,
   timestamps, randomness, runtime calls or config edits. Strict integer/bool definitions and ranges;
   missing, malformed or invalid keys fail clearly. Default --levels 300, positive bounded input.
2. Simulate three deterministic policies: saver no tools/ads; hinter requests one Hint per eligible
   level and one Reveal each tenth eligible slot; ad_watcher requests the same tools, one rewarded
   Hint per eligible level, one Shop coin ad per synthetic day within configured cap, and enabled
   x2 base reward after unlock. All ads are assumed explicitly requested/available with permissions;
   this is not a native eligibility implementation. Insufficient tools are counted, never block levels.
3. CLI assumptions: --session-levels 10 (one synthetic session/day), --bonus-per-level 1,
   --no-onboarding, --iap-slot 0 (disabled; otherwise one small pack after Hint unlock).
   Apply onboarding once at Hint unlock; tools before completion; bonus credits after bonus unlock,
   settle whole chests at completion; base rewards at every completion per FR-ECON-05; the coins pill unlock does not gate income.
   x2 never doubles bonuses/IAP. Daily reward never paid. Inventory and coins start zero.
4. Emit deterministic JSON (--json path) with inputs, assumptions, source totals, spent coins/items,
   denied tools, remaining coins/items/carry-over and per-slot rows for all policies; Markdown
   (--markdown path or stdout) includes balances at session ends and intent ratios. Base-only mode:
   --no-onboarding --bonus-per-level 0; sources remain separately named in every report.
   Ratio with zero base reward is null, never divide by zero. Counts stay nonnegative safe integers.
5. Report limitations explicitly: synthetic policies, uncalibrated starting values, assumed sessions/
   ads/bonus discoveries, provisional IAP amount, no P3 daily and no proof of retention/affordability.

## Tests
New test_econ_sim.py: deterministic 300-level reports and all policy balances; explicit small
scenario arithmetic and gates; item-before-coins, Reveal shortage, base-only and source accounting;
bonus remainder/multi-chest, ad cap/disabled flags/x2 isolation, one-time optional IAP; injected
prices/rewards and zero reward; malformed config/input rejection; CLI JSON/Markdown and errors.
Full make check, scope and task metadata validation.

## Rollback
Offline unreferenced tool only; no live economy or content change.
