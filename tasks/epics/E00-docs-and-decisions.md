---
id: E00
title: Docs and decisions
phase: 0
status: active
---

## Goal
The source-of-truth docs v1 and the Phase 0 decisions are in the repo, so every later task can cite
an anchor instead of making a product or architecture decision. Rows: `tasks/ROADMAP.md` E00.

## Player-facing outcome
None.

## Decisions
- D1: Agent-facing files are English. Chris writes Polish. The design pass (`docs/design-pass/`) stays
  Polish and read-only, and loses every conflict with `docs/` (see its README).
- D2: `docs/PRODUCT.md` is canonical for config key names and defaults, analytics event names and IAP
  product IDs. `GAME_DESIGN.md` (T-0006) copies the key list from `PRODUCT.md#first-10-minutes-timeline`
  and never renames a key.
- D3: Accepted decisions: `docs/decisions/0004-language-rules-pl.md`,
  `0005-content-language-order.md`, `0006-sol-as-repo-agent.md`. Numbers 0001–0003 are reserved for
  T-0003 … T-0005. Later decisions take the next free number (rows write it as `NNNN`).
- D4: A new decision never edits an old one; it supersedes it.
- D5: Docs v1 get exactly one Opus second opinion (T-0010, findings list). Chris approves docs v1 in
  T-0011. After that, doc changes go through `docs/*` PRs.
- D6: Lane DOC is one queue. It also carries T-0033, T-0045, T-0050 and T-0051 from other epics.

## Contracts
No code. These anchors are cited by `PRODUCT.md`, `DESIGN.md`, `ROADMAP.md` or `AGENTS.md` and must
exist when their file merges (missing anchor = S1 for the citing task):
- `GAME_DESIGN.md` (T-0006): `#ad-policy`, `#bonus-chest`, `#daily`, `#economy-intents`, `#hints`,
  `#landmarks`, `#letter-wheel`, `#monthly-calendar`, `#onboarding`, `#postcards`, `#power-ups`,
  `#progression`, `#stars`, `#streak`, `#unlocks`, `#word-classes`
- `ARCHITECTURE.md` (T-0007): `#areas`, `#autoloads`, `#platform`, `#save`
- `CONTENT.md` (T-0008): `#curve`, `#level-schema`, `#manifest`, `#slot-policy`
- `TESTING.md` (T-0009): no anchors cited yet; reference devices live in `DESIGN.md#reference-devices`

## Waves
### Wave 1
- T-0001 repo + import (done, Chris)
- T-0002 adopt seed, epics E00–E04 (depends: T-0001)
### Wave 2
- T-0003 decision 0001 engine, status proposed (depends: T-0002)
- T-0004 decision 0002 content in packs (depends: T-0002)
- T-0005 decision 0003 local device date (depends: T-0002)
### Wave 3
- T-0006 GAME_DESIGN.md v1 (depends: T-0002)
- T-0007 ARCHITECTURE.md v1 (depends: T-0002)
- T-0008 CONTENT.md v0 (depends: T-0002)
- T-0009 TESTING.md v1 (depends: T-0002)
### Wave 4
- T-0010 Opus second opinion, Chris starts the session (depends: T-0006, T-0007, T-0008)
- T-0011 apply accepted findings; Chris approves docs v1 (depends: T-0009, T-0010, T-0004, T-0005)

## Open questions
- None for waves 2–4. T-0006 drafts Q2 (stars per level) as options; Chris decides it in Phase 2
  (`PRODUCT.md#open-questions`).

## Exit criteria
- Decisions 0001 (proposed), 0002 and 0003 merged in `docs/decisions/`.
- `GAME_DESIGN.md`, `ARCHITECTURE.md`, `CONTENT.md`, `TESTING.md` merged, and every anchor listed under
  Contracts resolves.
- The Opus findings list exists and each finding is marked accepted or rejected.
- Chris approved docs v1 in T-0011.
