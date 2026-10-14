# T-0244 Home screen

Base aac79fa / merged T-0243. Home composes existing scaffold, TopBar, coin pill, settings icon,
postcard, StatePanel, PrimaryButton and Journey tab. Nav passes its injected Save/Content/Config
owners before Home mounts; no screen-owned progress/economy initialization or gameplay activation.

Each refresh reads one independent committed Save view. The displayed coin amount, actual next slot,
location and saved postcard pieces never read dirty staging. A saved completed-postcard marker keeps
the earned postcard complete after rebalancing without changing saved counts. Play rereads the actual
committed next slot and delegates to Nav, blocks repeat input on success, and permits retry on error.
Terminal/unavailable content disables Play rather than replaying the last level. Missing art uses the
existing empty StatePanel plus a pieces count while valid campaign play remains available.

Unbuilt tabs are hidden. Settings remains disabled until its scene exists; the coin pill is passive.
Slot text uses per-screen owned translations from raw PL/EN templates, so pseudo applies once and
independent Home instances do not overwrite each other. Exit removes translations and connections.
The existing Nav Toast owns pending results and inherits the mounted Home theme/safe bounds.

The fixed-height header configures the native CurrencyPill for an unwrapped number and a reserved
glyph width through public Button properties. No catalog code, new components, tokens, generated
themes, save format, economy/config values, content packs or analytics changed. T-0220's stale status
is reconciled to done because its implementation was already merged (a7e222a).

## Verification
14 new Home cases cover committed versus staged values, preserved earned postcards, actual-slot
routing and duplicate suppression, failed/busy retry, terminal/missing content, legacy/missing art,
navigation availability, independent PL/EN/PSEUDO copy, owner errors, real Nav/Level/Toast integration
and all three official layout classes at HC130/PSEUDO with safe insets. Header checks cover visible
balance, space for both number and glyph, translation changes and fixed-height containment.
Full make check PASS on the pinned engine: 593/593 GUT, 329 pipeline and 500 tools tests; formatting,
lint, registry/content validation, UI guards and generated-theme verification pass. Existing tests
remain unchanged. Task lint accepts 180 tasks.

[Native screenshots and reproducible capture](T-0244/README.md) cover all three layouts, PL/default100
and PSEUDO/HC130, each with synthetic fixture art and missing-art states. Fixture image/name are
explicitly QA-only; production art remains its own task. Device/taste/PL review remains pending.
