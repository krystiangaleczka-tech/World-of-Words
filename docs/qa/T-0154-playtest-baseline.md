# Current P1 playtest baseline — 2026-10-11

This baseline supersedes the source/inventory instructions in the older local
T-0139..T-0143 forms, which pin `68d7ccd` and content version 1. Their old results
are not rewritten. The [original Astra audit](T-0142-architecture-preflight.md)
and [technical follow-up](T-0149-audit-followup.md) retain their original scope.

## Verified source and builds

| Task | Merged source | PR | Successful CI |
|---|---|---|---|
| T-0151 diagnostics | `8d2f666b2182111f9387d53c25a099e69c40048d` | [#89](https://github.com/krystiangaleczka-tech/World-of-Words/pull/89) | [38141118267](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38141118267) |
| T-0152 familiar words | `4c079bfad5944da2d50a338bcc4b5e3578c0d456` | [#90](https://github.com/krystiangaleczka-tech/World-of-Words/pull/90) | [38141853825](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38141853825) |
| T-0153 shipped screen/save tests | `8a2411ebcbb8949f778f9667182433da54f45e20` | [#91](https://github.com/krystiangaleczka-tech/World-of-Words/pull/91) | [38142456196](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38142456196) |

All three linked runs passed 12 jobs, including debug APK and unsigned Release
resource inspection. The current merged baseline has 247 GUT tests / 13049
assertions, 201 pipeline tests and 142 tooling tests. T-0153 swipes all 64
non-current slots through real screens with no campaign writes; the active slot
and final resume are tested separately. These are automated observations.

An available CI debug build is [world-of-words-android-debug](https://github.com/krystiangaleczka-tech/World-of-Words/actions/runs/38142456196/artifacts/11702723544),
from exact PR head `53b31d09780d001ff0112ca209684d47154092db`.
This contains the reviewed gameplay and content of the merged baseline; the
Squash merge has a different commit identity. Artifact availability was verified
on 2026-10-11; it expires on 2026-10-25 at 13:18:14 UTC. If expired, select a
later successful run and record its exact source and content identity again.

The artifact API's archive digest is
`sha256:c0adbe89b16086ac470e3d25169276e35ca8408bab7cfd9801a0ee5141f7f184`.
This is the **ZIP digest**, not the contained APK's SHA256. This task did not
download/install that APK or independently re-inspect its bytes; export checks
are the linked CI evidence. Keep the approved installed build for an ongoing
round. Existing [debug-build installation guidance](T-0137-android-debug.md)
applies: disposable debug certificates can differ, and uninstalling removes
the local save. Do not replace the personal test installation or reset its
progress just to obtain this baseline. Use an isolated test installation for
outsider reset-based sessions and retain its exact build throughout the round.

## Owner-approved S26 Ultra evidence

Chris explicitly confirmed on 2026-10-11: the reported tests were performed on
Samsung Galaxy S26 Ultra, he approves them, and work should continue. This
records his approval; it does not request it again. It supersedes pending owner
approval language in the earlier historical reports for these reported checks.

- [T-0151](T-0151-debug-level-playtest.md): non-current diagnostic BOA/ABO/OBA
  playback after shuffle and reopening preserved the campaign save. These were
  version-1 words; slot 21 is AUTO in the current revision.
- [T-0152](T-0152-curated-opening.md): content version 2 / 65 slots, final
  PARASOL/ROSA/PAS, and slot 7 KUR bonus followed by KURA completion after three
  shuffles and reopening; campaign bytes stayed unchanged.
- The reported device APK SHA256 is
  `cc1c971a37405bf28bf62744199fcb93be24c98c9cff2c44ea96d4935dbc9776`.
  It is the local integration APK described in T-0152, **not** the CI archive
  above. Its task/name/time helper T-0150 remains on Chris's computer; he will
  push it later. No code from that helper is claimed merged here.

No new phone run occurred in this cloud task. The approval is evidence for the
reported S26 Ultra scenarios; it is not a supplied timing measurement on A15,
65 recorded manual sessions, five outsider sessions, or a separate FUN GATE
decision. [Reference devices](../TESTING.md#reference-devices) retain their roles.

## Current content identity and inventory

- Content version: **2**; exactly **65 authored slots**, stable IDs 1–65.
- **103 unique required answers**, **1697 bonus entries** across levels.
- Wheel sizes: three to seven tiles; runtime difficulty remains the P1 `0.0`.
- Final required words: **PARASOL / ROSA / PAS**, grid **4 columns × 7 rows**.
- Pack SHA256:
  `140cf9b545370d3a7cf731eb1fd3344df0e88b6c378bb013e2852227c6282501`.
- Native generation and offline replay are verified in T-0152; familiarity
  bands are editorial choices, separate from source validity and bonus pools.

[Level inventory CSV](T-0154-level-inventory.csv) is derived from that committed
pack. Each row includes slot, ID, original tile order, grid dimensions, required
answers and bonus count. Empty `review_result` and `notes` fields mean no new
observation, not PASS. Answers are **reviewer-only**: do not show this inventory
or the debug answer view to outsider participants. It replaces the obsolete
version-1 inventory rather than changing source eligibility or generated packs.

## How to run further checks

Record date, exact APK/source/content version, device/Android, refresh rate,
power-saving mode and session duration with each result. Retain the same build
within a round; do not mix observations from old BOA slot 21 and current AUTO.

For content review (T-0140), play each intended slot and record unfamiliar words,
hint/answer use, time, grid problems and Continue behavior. Non-current debug
slots are session-only: words, bonuses, hints and completion work, but leaving
discards their board and never advances the saved campaign. The actual current
slot still persists normally. A fully completed campaign retains the locked
final-slot resume screen; open earlier slots to replay. Debug auto-completion
does not count as human solving, and diagnostic-only checks do not demonstrate
campaign persistence. Use an isolated test campaign for current-slot restart
and Continue checks; record which mode each observation used.

For feel/performance (T-0139), observe slow/fast drag, backtracking, repeated
letters, second pointer, cancellation/backgrounding, shuffle/hint gating,
feedback and the submission/save frame on larger wheels. Record actual overlay
sample counts, dropped samples and latency/FPS values if available; leave missing
measurements blank. The engine render-boundary estimate is not finger-to-photon
latency. Owner-approved S26 checks remain recorded; A15 results need their own
device evidence if used to satisfy the low-end reference requirement.

For T-0141, retain its T-0139/T-0140 prerequisites. Use five people outside the
project, each playing for at least 20 active minutes without instructions/help,
on the same recorded build. Start each on an isolated clean test campaign at
slot 1; hide answers/debug overlays and record actual time, first self-discovered
word, stalls, help, final slot and wish to continue. Early exit or assistance is
recorded as such, never filled in as a qualifying session. Do not reset Chris's
personal campaign to prepare these sessions.

T-0143 remains Chris's separate go / fix core / stop assessment of the recorded
evidence. This baseline updates working materials and approval history; it does
not mark the human task statuses done or change roadmap/P2 dependencies.
