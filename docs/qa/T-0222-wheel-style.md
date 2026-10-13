# T-0222 final wheel styling

Generated palette/heavy TileLetter and Preview/Caption variations replace P1 raw colours/fonts.
Cached tile LOW surface and passive disabled outline preserve hit geometry. Selection/backtrack
motion uses scalar bookkeeping rather than allocating a tween in the swipe path. Reduction,
resize and exit settle transforms. Wheel lock/shuffle presentation restores; re-entry reconnects.
Preview bubble follows SURFACE/FULL and token padding, hides when empty; native translated shape
cues remain. Results motion unchanged for T-0225. Grid-cell hints remain as chosen by game design.

Pinned4.7.2 full make check, existing suite plus4behavior tests (400GUT), task/scope guards and independent
final-head review/13CI are merge gates. Native gallery captures in ignored builds/T-0222-preview
cover3classes xPL/PSEUDO xdefault100/HC130 with selected/building and result samples. Device,
screen-reader, Opus and taste checks remain open; no certification claim.

Full make check passed /tmp/wow-222-final-check.log under taskset -c0 after an engine
clean-cache import crash. No source guards changed. Caption starts after actual font line height,
wraps native minimum height; caption reshaping preserves fresh result tween.24native captures
cover wheel/building/result rows; COMPACT/PSEUDO/HC130 independently inspected.
