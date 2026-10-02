---
id: E02
title: Spikes and engine gate
phase: 0
status: planning
---

## Goal
Evidence before production code: the engine and platform plugins work on real devices, the swipe feels
right, Polish word sources are licensed, and the generator is feasible. Rows: `tasks/ROADMAP.md` E02.

## Player-facing outcome
None.

## Decisions
- D1: S5 (can Sol work on the repo directly) is resolved by decision 0006 and has no task.
- D2: Spike code is throwaway and never merges to `main`, except `pipeline/spikes/s4/` (T-0032), which
  is the Phase 1 generator's starting point. Every spike merges a report under `docs/spikes/`:
  `S1-android.md`, `S1-ios.md`, `S2-swipe.md`, `S3a-pl-sources.md`, `S3b-classification.md`,
  `S4-generator.md`.
- D3: S1 runs as Opus + Chris in Claude Code on Chris's machine (Android plugin builds need a local
  SDK). Android first, then iOS in the same session family.
- D4: T-0026 fixes the final Android `applicationId` and iOS bundle ID (permanent after the first upload;
  neutral, without the working title). Throwaway apps use a separate `.spike` ID.
- D5: Plan B is Unity 6 LTS. Switching re-plans the Godot-specific E01 rows (T-0013, T-0014, T-0015,
  T-0018), E03 and E04 (T-0033).
- D6: Chris decides the PL word sources (T-0030 → decision `NNNN-pl-word-sources`). The classification
  trial compares two cheap models on the same 200 words (T-0031).

## Contracts
None. Spikes produce reports and decisions, not APIs.

## Waves
### Wave 1
- T-0026 S1 plan: plugin survey, test matrix, pass/fail criteria, app IDs (depends: T-0003)
- T-0030 S3a PL word sources and licences (depends: T-0002)
- T-0032 S4 generator prototype (depends: T-0016)
### Wave 2
- T-0027 S1 Android, Opus + Chris (depends: T-0026, T-0012)
- T-0029 S2 swipe on the low-end Android (depends: T-0012, T-0014)
- T-0031 S3b classification trial (depends: T-0030, T-0016)
### Wave 3
- T-0028 S1 iOS, Opus + Chris (depends: T-0027)
### Gate
- T-0033 ENGINE GATE (depends: T-0028, T-0029)

## Open questions
- Q8: analytics and crash providers. Owner: Sol, from S1; recorded in T-0033.
- Q9: minimum Android API and iOS versions. Owner: Sol, from S1; recorded in T-0033.
- Q11: PL dictionary and frequency sources and licences. Owner: Chris, in T-0030.
- Q13: reference low-end Android model (E01, T-0012). Blocks T-0027 and T-0029.
- Haptics and silent-switch approach, and screen-reader support on the pinned version (FR-A11Y-04).
  Owner: Sol, from S1; recorded in T-0033.

## Exit criteria
- Decision 0001 accepted with a pinned Godot version, or the switch to Unity 6 LTS recorded with the
  re-plan merged.
- Decision `NNNN-platform-providers` answers Q8, Q9, haptics, silent switch and FR-A11Y-04.
- Decision `NNNN-pl-word-sources` answers Q11.
- S2 report has Chris's latency rating and a recommended input approach.
- S4 produced 50 PL levels with quality notes; code kept in `pipeline/spikes/s4/`.
