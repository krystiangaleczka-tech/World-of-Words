# T-0285 Settings native evidence

Actual SettingsScreen with an isolated, real Save owner under Godot4.7.2 GLES3 /
llvmpipe. Run `DISPLAY=:100 Godot --path game --audio-driver Dummy --script
../docs/qa/T-0285/capture.gd` using the pinned binary. The capture script uses a
synthetic install ID and no external provider, endpoint or system preference.

24 PNGs show top/bottom for COMPACT1080x1920, REGULAR1080x2340, TABLET1440x1920,
PL/PSEUDO, default100/HC130. The top/bottom pair demonstrates all sections and the
reachable version/install ID footer. Input target/scroll bounds are checked in the
12-case native layout test. Long copy wraps; no horizontal scrolling is enabled.

Compared with DESIGN.md#settings (the cited screen reference), TopBar, sound,
display, language, purchases, privacy and about retain their order. All controls
are existing catalog components. The short install ID uses ListRow's existing
trailing value plus the caption footer; ListRow has no opaque subtitle API. This
is an explicit bounded composition difference from the subtitle description.
No catalog component/theme was changed to imitate a mockup.

Seven integration tests use real Save and injected failing storage: owner validation,
copied committed vs dirty values, native intent without writes, owned removal,
explicit privacy availability, external-action/back intents, keyboard/reentry,
live native background theme change, plus the 12-case layout/scroll matrix. Programmatic refresh emits no setting intent.
Control gestures reset to committed state until a caller accepts/persists intent.

The opt-in scene is `settings_screen.tscn`: Home probes the conventional
`settings.tscn` path for availability, so creating that path would accidentally
enable a navigation button. The existing Home oracle is retained unchanged.

This task does not activate persistence, theme application, OS defaults, language
switching, navigation, sound, links, purchases, restore outcomes or consent. T-0286
owns apply and T-0287 language; T-0288 owns external rows. Device accessibility,
physical screenshots and Chris's taste gate remain open; desktop evidence does not
certify them. No SDK/store/account approval is inferred.
