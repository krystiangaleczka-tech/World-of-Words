# T-0223 board theme and layout geometry

GridCell generated palette and heavy font retain hinted dot/highlight inset/passive state.
BoardView.play_area_rects centralizes capped column, class ratios/gaps, wheel top/bottom padding,
minimum grid share and wheel-first shrink. Tiny impossible hosts compress structural overhead;
LevelScreen preserves existing zero-wheel guard and hides the wheel until a valid rect returns.
Preview minimum/class subscriptions relayout text wrapping and disconnect on exit. No motion,
gameplay, save, economy or HUD composition changes.

Pinned4.7.2 full make check: existing board-fit/intersection/centre and responsive scene tests plus
4new tests (404GUT) for generated theme/state and shared geometry. Native ignored builds/T-0223-preview
matrix3classes xPL/PSEUDO xdefault100/HC130 uses actual board gallery; rendered hinted fill pixel
checks fail a raw-palette regression. Font weight/state cues inspected visually. Single-CPU execution
affinity handles known clean-cache import engine instability; guards unchanged. Independent review
and13CI before merge. Physical devices/screen readers/taste/Opus remain open.

Full make check GREEN /tmp/wow-223-verified-check.log:404GUT,311pipeline,451tools,14outputs.
Native12matrix fill-pixel assertions pass; compact HC inspected. New scene regression mounts
existing gallery.gd fixture and exercises populated zero-room host then recovery.
