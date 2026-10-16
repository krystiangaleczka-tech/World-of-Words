# T-0274 native Shop Sheet evidence

Godot 4.7.2 stable, native GLES3 on Linux llvmpipe, reduced motion. Run from repo:

```sh
DISPLAY=:99 /tmp/wow-godot/Godot_v4.7.2-stable_linux.x86_64 --path game --audio-driver Dummy --script ../docs/qa/T-0274/capture.gd
```

The 24 PNGs capture top and bottom for COMPACT 1080x1920, REGULAR 1080x2340,
TABLET 1440x1920; PL/PSEUDO; default100/HC130. Each uses the actual Shop scene,
actual Save/Economy/Monetization and injected Fake providers. Prices 12,99 zł/4,99 zł
are test fixtures, not live prices or approved store products. Coin/reward amounts
come from config. No Nav, boot, consent, store or platform SDK is activated.

Compared with `docs/design/T-0205/evidence/shop_COMPACT_PL_default.png`:
three catalog Cards retain ordering and Primary/Secondary hierarchy; existing Sheet
owns its header, close, focus and scroll. CurrencyPill is the right-aligned first
body item because Sheet has no public header accessory API. This bounded composition
preserves the component boundary; it intentionally differs from the mockup header
placement. Catalog token shadows/corner/button sizes are used without local styling.
The currency column reserves numeric width beside the expandable native icon using
the catalog font metrics and tokens. Long PSEUDO/HC copy wraps; bottom shots demonstrate reachability of the complete free
rewarded action and iOS restore. A cut Card in a top shot is scroll content, not loss.

Integration tests cover owner-derived prices and copies, no price/offline and finite
query timeout, malformed/duplicate provider data, native input, durable grants,
ownership/Primary swap, deferred/cancel/failure, request-only restore with immediate/
deferred/repeated failures, no-fill/new-visit retry/cap, failed earned-write retry,
external placement pending state, reentry and synchronous listener replacement guards.
The 12-case executable layout matrix checks scroll bounds and action targets.

Desktop evidence does not certify Android/iOS SDKs, device accessibility, performance,
physical screenshots or Chris's visual/taste gate. Those remain release gates, as in
T-0245/T-0246. Restore batch outcomes cannot be certified without a provider batch
completion signal; the UI deliberately reports request acceptance only.
