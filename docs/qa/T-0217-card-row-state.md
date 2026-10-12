# T-0217 content catalog

Fresh main bed7489; presentation only. Card caller body remains detached without freeing on
replacement/exit and remounts on re-entry. Passive body validation rejects interactive controls
including unfocusable text inputs. Native card shortcut processing is disabled per card when
passive/locked, preserving sibling shortcut delivery. Tappable and footer intent remain separate;
locked/disabled/loading suppress both. Lock Badge plus full-width translated explanation and
local desaturation shader give shape/text cues. Media uses palette tint for official monochrome art.

ListRow retains native whole-row press and nested BaseButton/Slider input without doubling intent.
Disabled/loading captures and restores each child's prior native availability; detach restores it.
Body/Caption wrap around intrinsic one-line Numeric value, forward arrow and prototype controls.
CatalogAction minimum grows with content, uses token surface/LOW/Radius.M and inherited motion;
style refresh follows native disabled changes instead of allocating styles every draw.
StatePanel four distinct official glyphs (route/offline, x/error, map/empty, lock/unavailable),
wrapped copy and one optional PrimaryButton emit intent only. Copy ownership survives re-entry.

Validation: Godot4.7.2,358 GUT (11 new behavior tests),311 pipeline,451 tools via full make check;
UI guards/14 generated outputs current,65 campaign levels. Existing assertions unchanged. Native
mouse/shortcut tests cover passive/tappable/card footer/locked/disabled/loading, sibling shortcuts,
row/child double-intent avoidance/restoration, ownership and atomic invalid trees, copy/theme,
StatePanel variants and action, galleryHC130/PSEUDO width/scroll/minimum144. Fresh review in PR.

48 native Compatibility/llvmpipe captures:3classes xPL/PSEUDO xdefault100/HC130 x4scroll bands
(cards,locked,rows,states), fake insets/reduced motion. Repro script and PNGs in ignored
builds/T-0217-preview. COMPACT/PSEUDO/HC130 four bands inspected and corrected long lock-caption
and numeric wrapping. Startup smoke clean. Device/TalkBack/VoiceOver/taste/Opus gates stay open;
T-0327 CI gallery renderer pending. No service/economy/save/project/export/theme/token changes.
