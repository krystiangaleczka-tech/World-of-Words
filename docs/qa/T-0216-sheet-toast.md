# T-0216 modal sheets and transient toasts

Presentation catalog on fresh main ba46675. Sheet owns its chrome, caller retains content.
Viewport-local transient replacement claim prevents dismissed callbacks opening competing panels;
open raises modal above previous sibling controls. Busy/non-dismissible Back consumes without
closing, native focus is trapped/restored, header gestures track first pointer and canceled input.
Null/self/ancestor/foreign content rejects atomically; exit detaches and re-entry remounts.

CatalogSurface converts safe scaffold body into owner/parent coordinates; nested Toast bounds
use actual owner dimensions. Sheet scrolls at .85 cap, title wraps, bottom safe anchor persists.
DESIGN motion is preserved: Sheet BASE/OUT offscreen opening, FAST/IN closing; Toast FAST/OUT
fade and Space.S slide, FAST/IN exit. Reduction settles Sheet and removes Toast movement;
TOAST_HOLD remains readability duration. Replacement/exit kill stale tweens and timers.

Validation: pinned Godot4.7.2;347 GUT assertions suites passing (13 new behavior tests), plus
make check pipeline311/tools451, UI/static guards and generated resources. Tests include real
viewport scrim/close/Back/Tab/swipe/cancel input, later sibling blocking, reentrant callback claim,
nested Toast resize, caller content ownership, busy gates, scroll/safe/theme/locale/reduction,
passive Toast descendants, atomic replacement and Timer lifetime. Existing tests retained.

Native Compatibility/llvmpipe capture matrix:60 frames (normal/busy Sheet and3 Toast variants),
3 classes x PL/PSEUDO x default100/HC130, reduced motion/fake insets. Ignored artifacts under
builds/T-0216-preview, reproducible capture.gd. Gallery provides owner force-close and replay
inside scroll content, including busy demo. Native startup smoke checked. Local previews keep
physical device/Android production routing/VoiceOver/TalkBack/taste/Opus gates open. No Nav,
service/save/economy/theme/project/export changes. Independent review and final CI tracked in PR.
