# T-0218 settings controls and navigation tabs

Fresh main e191b21; presentation only. Toggle preserves native boolean press/toggle semantics,
with silent program value updates, mandatory translated name, on/off accessibility description,
check in on knob, focus and native disabled styles. Native action motion/reduction inherited.
Unconfigured controls suppress their own shortcut processing without swallowing sibling input.

CatalogSlider preserves native HSlider normalized range/step and pointer/key value signals.
144x144 grabber textures define hit area; PRIMARY/SURFACE_ALT track. Direct ScreenTouch/Drag
uses the same native range without event allocations, captures first pointer and consumes its
emulated duplicates only while owned. Cancel/exit/reconfigure/release release ownership. Sound
preview intent occurs only on changed gesture release; expected native input values distinguish
program changes during keyboard/mouse gestures. Music/program/unchanged/canceled gestures stay
silent. set_available(bool) cancels even transient same-frame changes; native editable writes are
observed at next input/draw (native setter has no observable signal for false→true between both).
No Audio/Events/platform call. CatalogSlider avoids colliding with engine Slider class.

NavTab selected is caller-owned, native pressed intent never changes it. Lock swaps to official
lock glyph and level label, suppresses input, updates theme; NEW Badge marks highlighted. Selected
has check cue and PRIMARY/ON_PRIMARY contrast. Focus style is ring-only, retaining contrast.
Unbuilt items hidden; independent copy ownership and re-entry signal lifecycle retained.

Validation: pinnedGodot4.7.2;372GUT (14 new behavior tests),311pipeline,451tools via make check;
14generated outputs,UI guards,65levels. Native mouse/key/shortcut and direct touch tests cover
release timing/program changes/availability cancellation/ownership teardown/emulated sibling
input, finite atomic config/clamp/step, required names,144thumb/root, theme/copy/re-entry,
selected/locked/NEW/unbuilt and gallery scroll/fit. Existing assertions unchanged.

36 native Compatibility/llvmpipe captures:3classes xPL/PSEUDO xdefault100/HC130 x3scrollbands,
fake insets/reduced motion, selected tab focused. Ignored builds/T-0218-preview capture.gd/PNGs;
COMPACT/PSEUDO/HC130 toggles/sliders/tabs inspected clean. Startup smoke clean. Device/taste/Opus
and actual TalkBack/VoiceOver gates stay open; T-0327 CI gallery renderer pending. No settings,
service/save/config/project/export/theme/token changes. Fresh review/finalCI tracked in PR.
