# T-0287 — shipped content language selector

Reference: DESIGN.md#settings/#flow-first-launch and the preflight reload boundary
in docs/contracts/settings.md. T-0286 is merged asa716075 (#200); T-0242 metadata
is done. Actual Content's manifest/hash API and Save's before-load defaults hook
were verified before freezing the two-phase caller hook and implementing it.
No Content/Progress API, Boot/Nav mapping, save format or generated content changed.

## Native evidence

Pinned Godot4.7.2, native X11/Mesa compatibility renderer, actual file Save,
SettingsRuntime, SettingsLanguage, Content and SettingsScreen. Reproduce:
`DISPLAY=:100 <pinned Godot> --path game --audio-driver Dummy --script
../docs/qa/T-0287/capture.gd` under a native X server.

60 actual PNGs:36 production top/bottom/language-Sheet captures across COMPACT
1080x1920, REGULAR1080x2340, TABLET1440x1920, PL/PSEUDO, default100/HC130;
24 additional examples across all three sizes and both themes show the labelled debug choice, English UI top
and bottom with actual Save/Content still PL, and an unsafe-reload retry.

Production lists only Polish. The selected caption identifies the presented
language; focus on an alternative is not treated as selected. The debug-only EN
choice explicitly names preview and has a restore action. All sections remain
reachable; the modal fits compact PSEUDO HC130 and catalog controls retain native
focus, translation and touch geometry. No custom component/theme edits.

`fixture_unsafe_retry` deliberately uses the isolated test PL/EN catalog. Its hook
rejects prepare with ERR_BUSY, leaving Save/Content/UI PL, disabling alternatives
and modal dismissal while showing translated retry. It is not production EN
content and does not certify a real active-board reload integration.
Only the known native driver VSync warning is expected; no script errors/leaks.

## Owner behavior and tests

The actual Content validator discovers valid manifests; CSV translations do not
unlock content. The shipped catalog is immutable per request: explicit retry keeps
target/hash identity and rejects changed content. Normalized device locale chooses
its shipped base language or PL before the fresh-document Save defaults hook;
existing settings are preserved.

Tests use actual Save/Content, failing storage and caller hooks to cover PL-only
production, invalid manifest rejection, deep copied choices, transient preview and
restore/owner exit, initial locale/defaults, unsafe checkpoint, failed persistence,
an unrelated successful flush, pending reload without false success, reentrant
replacement, both campaign states, dishonest success without target Content,
changed manifest identity, native screen retry/reentry and twelve-case geometry.
A deferred resume is coalesced and never equates a committed setting with successful
Content/UI application. The caller must durably checkpoint and hold an active board
before permitting apply; no board is silently discarded.

## Open release gates

Production still ships PL only. Physical device locale/accessibility/taste gates
remain open. Real alternative-content publication and a concrete Nav/board reload
composition remain their caller's responsibility; this task exposes the explicit
boundary without activating it in Boot/Nav. No SDK or OS observation is fabricated.
Desktop native evidence does not certify physical-device behavior.

Verification: full make check PASS; after the final compact preview label/HC130
regression, final full runtime PASS794/794 tests,27,773 assertions. Twelve new
integration tests pass (focused358 assertions), with329 pipeline and536 tools
tests green, plus final format/lint and UI/theme/locale guards.
