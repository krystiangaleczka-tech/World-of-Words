# T-0213 action buttons

Implementation parent: reviewed T-0212 b748d1e (stacked; merge parents first).

Primary/Secondary/Text retain native Button input, text, accessibility names and pressed signals.
Shared loading suppresses native activation, preserves initial disabled/icon and keeps copy visible.
Official video cue remains separate from the spinner. Theme/locale refresh and re-entry reconnect
only owned signals/translations. Sublabel wraps separately with measured bottom padding.

Two canonical values already specified in DESIGN are added to Tokens.Action and generated CSS:
PRESS_SCALE 0.96 and OUTLINE_WIDTH 3. Existing mirror enumeration is extended to cover them;
no previous assertion or generated theme/resource changes.

Validation: Godot 4.7.2-stable.ed1daf0bf. Full make check passes 317 GUT, 311 pipeline and 451
Python tools tests, registries and all 65 campaign levels; UI guards and 14 clean-cache generated
outputs match. Task lint 146 tasks. Eight new behavior tests cover native keyboard/mouse,
loading and initial disabled/icon restoration, locale/pseudo/accessibility, HC130, compact
wrapping/sublabel growth, atomic badges, pre-ready/re-entry and finite/reduced/disabled motion.

Local native Compatibility/llvmpipe gallery captures: 36 images (three component scroll anchors
x COMPACT/REGULAR/TABLET x PL/PSEUDO x default100/HC130, fake insets/reduced motion).
Ignored artifacts: builds/T-0213-preview/{primary,secondary,text}_<CLASS>_<LANG>_<MODE>.png,
matrix.png and capture.gd. Visually inspected full matrix and COMPACT/PSEUDO/HC130 primary:
main and caption copy stay separate, wrapped, legible; ad video remains in unavailable/loading
states; Text pressed underline visible. The scroll anchors can be clamped near the end, leaving
previous rows visible. Scrolling exposes all 15 states without shrinking hit areas.

T-0327 CI gallery rendering has not landed. These are native local screenshots, not CI gallery
artifacts or reference-device/taste acceptance. Opus/iPad/art and original device gates stay open.
The short rendering capture does not establish performance/battery or platform accessibility.

No production screen rewiring, service/economy/save/content/platform/export or ROADMAP change.

Independent review found caller disabled refresh could bypass loading and live reduced-motion
changes could leave a pulse active. Input dispatch now reasserts loading suppression without
consuming other controls' events; active motion reconciles the reduction flag on the next frame.
Both cases have regressions. Combined task scope exceeds the template approximate line/file
guidance: shared state implementation, three catalog buttons, gallery and contract/behavior tests.

Re-review extended live reduction reconciliation to ordinary press/release tweens as well;
a native-press regression covers switching reduced motion while the press tween is in flight.

T-0214 native accessibility probe exposed separate translation in Godot's accessibility getters,
which ignores Node auto_translate_mode for those fields. Keep raw label/sublabel keys there
while visible text remains explicitly translated; add pseudo name/description parity regressions.

Native Button glyph tint uses icon_normal_color, distinct from font_color; all normal/hover/pressed/
disabled glyph overrides use native property names, with a normal-glyph colour parity regression.
