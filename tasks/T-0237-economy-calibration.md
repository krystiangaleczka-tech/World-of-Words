---
id: T-0237
title: Calibrate documented economy defaults from synthetic reports
epic: E15
type: feat
area: data.config
risk: high
executor: sol
think: high
ui: none
status: blocked
depends_on: [T-0236]
touch:
  - game/data/config/bonus.json
  - docs/GAME_DESIGN.md
  - game/tests/integration/test_p2_config.gd
  - tools/tests/test_econ_sim.py
  - tasks/T-0236-economy-simulation-ci.md
  - tasks/T-0237-economy-calibration.md
  - docs/qa/T-0237-economy-calibration.md
revision: 1
---

## Goal
Record simulation-based calibration and apply only the owner's accepted threshold decision.
Owner requested drafting and implementing this missing task. Roadmap explicitly requires Chris approval.

## Current state
Merged T-0236 generates two synthetic 300-level reports from defaults. Bonus threshold is 10;
base reward25, Hint100, Reveal250, chest100. Default assumptions are 10 levels/session, one
bonus/eligible level, one session/day. There is no player/session evidence for these frequencies.
T-0236 status remains review after merge and is reconciled to done in this task.

## Specification
1. Compare chest thresholds 10/20 with all other config and scenario inputs identical. Show
   source totals, chest count, wallet, denied tools and whether intent ratios remain unchanged.
2. Owner chooses 20 to approximate two synthetic sessions/chest, or retains 10 pending observed
   data. Neither choice claims measured affordability or player behavior. No assumed consent/native
   outcome is evidence. Base/Hint/Reveal/rewarded proportions already fit documented intents.
3. Only after approval, if20: update bonus.chest.words_required default to20 within its existing
   range; update current GAME_DESIGN registry row and the two listed shipped-default assertions.
   Preserve all prices/rewards/inventory/save/content and historical T-0203 decision evidence.
   If10: retain defaults and record the explicit conservative disposition; no gratuitous code edits.
4. Future T-0280 bonus integration uses the approved threshold. Existing counters are never reset;
   no runtime Economy/bonus integration currently consumes this shipped default.

## Tests
Run existing test_p2_config and simulator tests, deterministic before/after reports, full make check,
scope/task metadata and CI simulation artifacts for any config change. No test weakening.

## Approval gate
Owner question pending: threshold20 versus retaining10 until actual session data. No balance
change is applied until answered. Reviewable comparison is docs/qa/T-0237-economy-calibration.md.

## Rollback
Config rollback only; no live wallet migration or credit deletion.
