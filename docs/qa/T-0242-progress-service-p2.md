# T-0242 Progress P2 implementation

Base a5d2fdc / T-0333 PR169. Explicit real-port activation, copied committed reads, per-language
stars/persisted unlock/location/region views and atomic completion routing are implemented.
Private Save publication dispatch now calls Progress after Economy while its notification barrier
remains active. Progress receipt validation clears matching pending state and marks once before
completed/meta effects. Ordinary boot and unsuccessful initial activation retain P1; an activated
P2 route fails closed when later unavailable. Pause can resolve pending work after board unbind.
No Save public API, schema, economic rule/value, config/content or UI edits.

New integration suite: 21 public-behavior tests pass, including explicit/default/fake activation,
committed copy/no getter writes, effect order/reentrancy, five storage checkpoint/restart cases,
exact retry/unavailable reads, pause/screen unbind, history/journal trimming, receipt/reset invalidation,
independent active languages, endpoint versus card credit, P1 legacy fallback, later fail-closed
incompatibility, dirty board visibility and actual lost-Progress-publication recovery.
Clean baseline: 536/536 GUT. Final suite: 557/557 GUT, including all 21 new tests.

## Resolved S5 escalation
Chris explicitly approved adding `game/tests/integration/test_atomic_owner_port.gd` in revision3
and changing only the two obsolete post-activation expectations. Real bound configure_p2 now
returns OK and exposes the fresh committed ProgressSnapshot; all independent grant/spend,
pre-activation and default-port assertions remain unchanged. The initial 553/554 checkpoint was
caused solely by these deliberately inert T-0333-stage oracles.

## Verification
Full make check passed on the pinned Godot 4.7.2 build: 557 GUT, 329 pipeline and 500 tools tests;
formatting, lint, registries, content, UI literals and generated theme checks passed. Task lint passed
for 178 tasks. Scope is 11 files. Independent exact-head review and all 14 GitHub Actions checks
are required before merge; their final evidence belongs in PR164.
No automatic P2 boot/UI activation or device testing is claimed; T-0243 owns navigation activation.

## Independent review corrections
The first exact-head review rejected two uncovered public paths: a previously completed board
could be reused after Save reset, and an Economy callback could publish Progress halfway through
an Economy notification batch. Board binding now captures the committed lineage; atomic request
creation and P2 completion reject a board from another lineage. The private Save coordinator
enters a separate Progress dispatch gate only after Economy finishes; public accept_commit inside
that batch returns ERR_BUSY. Two new regression tests cover reset plus pause and reentrant receipt
publication with both base and onboarding Economy notifications. Lost-delivery subclass behavior
and later historical publication remain covered. The corrected head requires a fresh review.

A second independent review confirmed those fixes and found the related incomplete-board pause
path: save_level could persist a bound partial board from before reset. P2's shared board validator
now checks that binding lineage too, without changing P1 validation. A third regression checks
direct save_level and pause preserve the entire fresh reset state and exact primary bytes, then
verifies a freshly bound board can still be saved. Its initial empty-language assumption was
corrected to the actual reset default (fresh PL domain); the discarded level_state stays null.
