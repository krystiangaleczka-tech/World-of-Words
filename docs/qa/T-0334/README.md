# T-0334 Card store action evidence

Reference: [Shop mockup](../../design/T-0205/evidence/shop_COMPACT_PL_default.png)
and DESIGN.md#shop-sheet. This component task supplies the missing Secondary/ad
footer and opaque value captions before the screen task. It does not render a
live store, assert approved prices or implement a purchase.

Twelve native Godot images cover COMPACT/REGULAR/TABLET, PL/PSEUDO and default100/
HC130. Each shows Primary price, Secondary price and Secondary ad action. Prices
are synthetic fixtures and remain unchanged under pseudolocalization; action
identity and Card copy remain translated. Both button variants use existing tokens.

Reproduce from repository root with a display-enabled Godot 4.7.2 runtime:

```
DISPLAY=:99 godot --path game --audio-driver Dummy --script ../docs/qa/T-0334/capture.gd
```

The session uses an Xorg dummy display and Mesa llvmpipe. Desktop screenshots
verify component rendering only. Device, screen-reader hardware, FUN and taste
certification remain open and are not claimed by this evidence.
