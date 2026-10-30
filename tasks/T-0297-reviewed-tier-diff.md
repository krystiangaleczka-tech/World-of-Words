---
id: T-0297
title: Audit pinned tier changes and reviewed familiarity without automatic promotions
epic: E22
type: feat
area: pipeline.tiers
risk: high
executor: sol
think: high
ui: none
status: blocked
depends_on: [T-0296]
touch:
  - pipeline/src/wordgame_pipeline/tiers/review_diff.py
  - pipeline/tests/tiers/test_production_review.py
  - tasks/T-0297-reviewed-tier-diff.md
revision: 1
---

## Goal

Provide a deterministic, offline P2 tier-drift report. Reuse the T-0296
independently pinned source/tier validator. Only explicit existing
`overrides/pl.csv` decisions may authorize promotion into `level_ok`.
A familiarity rating alone is never word eligibility.

## Preflight and dependencies

- T-0296 classification queue exists in PR #288, not on main.
- Source tier rules and overrides are already implemented by the T-0123 stage.
- T-0355 scoring, T-0356 duplicate analysis and T-0359 allocation are
  independent offline helpers, not production acceptance.
- This is a **stacked implementation** from T-0296; until the source PR is
  reviewed and merged, this task remains blocked, not done.

## Specification

- Validate a canonical tier artifact against the source/annotation pins,
  config rules, exact override bytes, and familiarity CSV via T-0296.
- Reject missing/malformed or partial baseline tiers and noninteger thresholds.
- Compare every word's prior and current tier, emitting sorted, immutable
  source-backed transitions and before/after tier counts.
- Raise report alarms on changes beyond an explicit reviewed threshold and on
  any promotion to `level_ok` without an owner override.
- Track unresolved familiarity separately from native tier decisions.
- Report hashes of all relevant evidence, with no writes, timestamps, AI,
  network calls or runtime changes.

## Out of scope

No automatic tier change, approvals, content export, scoring thresholds,
calibration or 200-level acceptance. T-0304 editorial approval still required.
No P1 stage graph activation.

## Tests

`pipeline/tests/tiers/test_production_review.py` checks exact transition
counts, alarm behavior, owner precedence, canonical repeated output, invalid
baseline/thresholds, tampering and missing review evidence.

## Acceptance and blockers

- Full exact-head CI and fresh independent review required.
- T-0296 and its planning parent must merge first.
- Real baseline, thresholds, lexical review and T-0304 owner approval are
  external gates for a production decision.
