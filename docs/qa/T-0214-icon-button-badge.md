# T-0214 icon actions and badges

Reviewed parent T-0213 d85cefe, PR139; stacked draft with prerequisite/human gates open.

IconButton reuses ActionButton's native input and bounded/reduced-motion lifecycle. Final
configure_icon atomically requires glyph, nonblank translated accessibility key and S/M size.
Both glyph sizes keep the minimum144px native target. Native icon_normal_color is explicitly
PRIMARY; glyph center uses symmetric content margins with no reserved blank sublabel. Direct
unlabelled export glyphs are removed; earlier labelled P1 callers/HintButton remain compatible.

Badge is passive, uses Caption and token pill/padding, official lock, PRIMARY/BONUS backgrounds.
Short captions/counts keep intrinsic width up to a token cap, while long copy wraps. Native
accessibility properties retain raw keys (Godot translates them independently); lock state and
count use separate name/description. LocaleCatalog copies belong to each Badge and release
on exit/re-entry. No production screen rewiring, tokens/themes or gameplay/platform changes.

Validation on Godot4.7.2-stable.ed1daf0bf: make check passes323 GUT,311 pipeline,451 Python tools,
registries and65 campaign levels; UI guards and14 generated outputs current. Existing expectations
unchanged. Six new tests cover required-label/atomic config/export rejection, sizes/centering,
HC130 and locale/pseudo/re-entry ownership, native activation/disabled/reduced motion, badge
counts/lock/new/passivity/atomic variants, caption wrapping and gallery inventory. Task lint147.

Native local Compatibility/llvmpipe capture matrix:12 previews, COMPACT/REGULAR/TABLET xPL/PSEUDO
xdefault100/HC130, fake insets/reduced motion. Ignored builds/T-0214-preview/icons_<CLASS>_<LANG>_<MODE>.png,
capture.gd and matrix.png. Visual inspection includes native glyph tint/centering, single-line
99999 count, official lock and translated new; all remain visible within the scaffold/scroll view.
Native startup smoke checked. T-0327 CI gallery job has not landed; these local captures do not
replace physical reference-device screenshots/taste/Opus acceptance or TalkBack/VoiceOver checks.

The shared implementation + fixture/tests exceeds approximate task-template line guidance, but
has one component area and four production script/scene files plus gallery wiring/copy. P1 text
compatibility remains explicitly provisional until final screen and HintButton migrations.

Independent review found whitespace exported keys bypassed the empty-key fallback. Canonicalize
keys with strip_edges, test empty/whitespace direct exports, and verify enabled native keyboard
activation as well as mouse and disabled suppression.

Pre-ready loading exports also sanitize the saved glyph when no accessible icon key exists,
so ending work cannot restore an unsafe glyph. Regression preserves the labelled P1 fallback.
