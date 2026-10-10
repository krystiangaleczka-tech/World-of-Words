---
id: T-0147
title: Preserve credited bonuses through bonus-only content updates
epic: E10
type: contract
area: core.board
risk: high
executor: sol
think: high
ui: none
status: done
depends_on: [T-0146]
touch:
  - game/core/board/board_state.gd
  - game/services/progress.gd
  - game/tests/unit/board/test_historical_bonus.gd
  - game/tests/unit/board/test_historical_bonus.gd.uid
  - game/tests/integration/test_progress_bonus_update.gd
  - game/tests/integration/test_progress_bonus_update.gd.uid
  - tasks/T-0147-historical-bonus.md
revision: 1
---

## Goal
Address Astra A1 for bonus-only updates: retain revealed cells, found required
words and already-credited bonus history when a bonus is removed or reintroduced.

## Context
- docs/qa/T-0142-architecture-preflight.md: A1 describes whole-board rejection.
- docs/ARCHITECTURE.md#save: content-specific state validation is BoardState's job.
- AGENTS.md: pure core has no dictionary, I/O or global state.
This explicitly extends the restoration API; no save v3, economic grant, content
schema, generated content, or phase-gate change is authorized.

## Current state
BoardState.from_dict(level, data) strictly rejects any bonus not in the current
LevelData.bonus_words list. Progress.restore_level uses that default and falls
back to a fresh board on rejection. BoardState._bonus is the credited ledger;
evaluate currently returns ALREADY_FOUND for every entry in that ledger.

## Specification
1. Add optional allow_historical_bonus: bool = false to BoardState.from_dict.
   Preserve strict default behavior for existing callers; Progress.restore_level
   explicitly opts in after its existing loaded-content compatibility checks.
2. Opt-in restores a retired bonus only if it is a unique String of length
   MIN_TILES..tile_count, formable using each original tile at most once, and not
   a required level word. Preserve all existing ID, cell and found-word checks.
3. Credited history remains in existing bonus_words snapshots/counts. Current
   LevelData.bonus_words alone determines eligibility for new attempts. A retired
   credited word evaluates INVALID without mutation; a reintroduced credited word
   evaluates ALREADY_FOUND without another credit.
4. Snapshot keys and save v2 format stay unchanged. This trusts bounded local
   historical records, not proof of old content membership. It cannot authenticate
   edited saves and is not economic grant authority. Future P2 transactions still
   require persisted operation identities and idempotency.
5. Scope is stable ID, letters, required words and geometry with changed bonus
   eligibility. Other malformed snapshots still reject/fall back normally.

## Tests
- Unit test strict default rejection, explicit history restore, retained cells
  and required-word progress, retired INVALID and reintroduced ALREADY_FOUND.
- Unit reject duplicate/non-string/short/too-long/nonformable/lowercase historical
  entries, required-word entries, foreign IDs and malformed cells/found words.
- Unit repeated-letter tile multiplicity bounds are enforced.
- Integration persist a partial board with bonus, reload changed content, retain
  progress/history, resave/reload and reintroduce without duplicate credits.
- Integration malformed historical records still fall back to a fresh board.
Run full make check, task lint, scope, count and independent review.

## Acceptance
The partial board survives real Save serialization and fresh service instances.
No restored record becomes a new eligible bonus or emits a fresh completion/grant.
Existing strict BoardState contracts pass unchanged.

## Rollback
No migration is needed; revert API/use/tests together. Strict resume then returns
with the known bonus-removal compatibility limitation.

## Outcome
Full make check passed: 236 GUT / 8744 assertions, 199 pipeline, 142 tools tests.
Fresh independent review approved 323bc593b122785566047b6b6d6350dfa9800bb8
without blockers. Strict defaults and existing tests remain unchanged. Scope:
seven files, two production files. Remote CI required before merge. Historical
records are bounded local history, not authenticated membership or grant authority.
