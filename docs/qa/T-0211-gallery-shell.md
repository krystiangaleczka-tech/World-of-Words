# T-0211 gallery shell

Run `godot --path game res://ui/gallery/gallery.tscn` on desktop, or run that scene
from the editor for a device preview. Production navigation stays unchanged and the
existing Android release excludes ui/gallery/*; this task changes no export preset.

The shell fits the display of a separate native SubViewport while preserving exact
COMPACT1080x1920, REGULAR1080x2340 or TABLET1440x1920 coordinates. The toolbar switches
PL/EN/PSEUDO, default/HC,100/115/130 text, reduced motion and token-derived fake insets.
No real desktop safe-area calculation leaks into the preview. Theme applies locally;
locale/pseudo settings and reduced-motion flags are temporarily process-wide because
existing components use TranslationServer/Tokens. Only one shell runs per process.
Exit restores previous values, including absent pseudo settings, and owned translations
are released independently of other owners. No save, economy or service action is run.

Samples contains PL pangram/restore copy, EN baseline, tabular Numeric samples, eight
letter identities and a labelled sparse10x10 synthetic grid reaching both opposite
corners. These are diagnostic geometry fixtures, not generated levels. Samples and
translated shell captions disable a second automatic text translation after explicit
translation, so PSEUDO accents/35% expansion are applied exactly once.

Controls/Wheel/Board/Debug reuse P1 galleries. Their existing explicit palette/font
size overrides are provisional: switching the preview theme does not certify final
HC/text scaling for those components. Final states, all motion rows and DE samples
arrive in subsequent tasks. The shell clearly labels this limit; no taste/device/
Opus or phase-exit gate is claimed.

Validation: five new GUT tests cover54 switch combinations, all pages, invalid atomic
configuration, pre-ready configuration/native toggle, resizing, max geometry and exit
restoration/foreign translation ownership. Native Compatibility screenshots cover12
Samples variants:3 classes ×PL/PSEUDO ×default100/HC130 with fake insets, under ignored
builds/T-0211-preview/gallery_<CLASS>_<LANG>_<MODE>_<SIZE>.png. Caption/diacritics, wheel
and both extreme grid corners are visible. Capture harness/logs are ignored fixtures;
T-0327 will supply the actual CI gallery rendering job. PR records full checks/review/CI.
