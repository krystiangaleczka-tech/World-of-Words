# T-0243 native gallery evidence

Godot 4.7.2 ed1daf0bf, X11/Xvfb and Mesa llvmpipe. Existing Overlays gallery + Toast, with the new
navigation copy; these captures are not implementations of Home/Journey screens. Default100 shows
backup restoration, HC130 shows purchase restoration. PL and PSEUDO (0.35 expansion/accents),
fake safe insets, reduced motion. Native screenshot sizes are those of the official gallery viewport.

The capture script disables the Toast processing only in the static gallery instance to freeze its
readability timer, then forces a render frame. Production timer/motion code is unchanged.

| Layout | PL default100 | PSEUDO default100 | PL HC130 | PSEUDO HC130 |
|---|---|---|---|---|
| COMPACT | [PL default100](COMPACT-PL-default100.png) | [PSEUDO default100](COMPACT-PSEUDO-default100.png) | [PL hc130](COMPACT-PL-hc130.png) | [PSEUDO hc130](COMPACT-PSEUDO-hc130.png) |
| REGULAR | [PL default100](REGULAR-PL-default100.png) | [PSEUDO default100](REGULAR-PSEUDO-default100.png) | [PL hc130](REGULAR-PL-hc130.png) | [PSEUDO hc130](REGULAR-PSEUDO-hc130.png) |
| TABLET | [PL default100](TABLET-PL-default100.png) | [PSEUDO default100](TABLET-PSEUDO-default100.png) | [PL hc130](TABLET-PL-hc130.png) | [PSEUDO hc130](TABLET-PSEUDO-hc130.png) |

To reproduce, run the external capture.gd with the pinned engine against an isolated copy of game/
on an X11 display; create /workspace/scratch/T-0243-captures first. The source writes only capture
artifacts, not gameplay saves/settings. Gallery owners restore their locale/pseudo state on exit.

Native automated transition tests exercise real Tween completion and reentrancy with reduction off;
gallery captures show settled copy/style only. Android Activity/background and physical Back remain
on-device QA gates.
