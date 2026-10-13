---
id: T-0220
title: Add one-shot reward feedback and piecewise location postcards
epic: E14
type: feat
area: ui.components
risk: medium
executor: sol
think: high
ui: med
status: review
depends_on: [T-0219]
touch:
  - game/ui/components/RewardBurst.gd*
  - game/ui/components/RewardBurst.tscn
  - game/ui/components/LocationPostcard.gd*
  - game/ui/components/LocationPostcard.tscn
  - game/ui/tokens.gd
  - game/ui/theme/generate_theme.gd
  - game/tests/unit/ui/test_v1_tokens.gd
  - docs/design/tokens.css
  - game/ui/gallery/rewards.gd*
  - game/ui/gallery/rewards.tscn
  - game/ui/gallery/gallery.gd
  - game/locale/ui.csv
  - game/locale/gallery.csv
  - game/tests/integration/test_reward_postcard.gd*
  - docs/qa/T-0220-reward-postcard.md
  - tasks/T-0220-reward-postcard.md
revision: 1
---

## Goal
Provide passive reward presentation and caller-owned postcard progress. No economy, stars,
progression, save or screen integration; callers provide final values and image resources.

## Context
- docs/DESIGN.md#rewardburst — one-shot CPUParticles2D, approximately24particles; static under reduction.
- docs/DESIGN.md#locationpostcard — paper/outlined unrevealed pieces, complete stamp and caption.
- docs/DESIGN.md#level-motion and #reduced-motion-mapping — SLOW particle life; FAST/SPRING icon pop.
- docs/GAME_DESIGN.md#postcards — caller config pieces1–16; ordered reveals, no stars spent.

## Current state
Fresh main7a34063 contains merged T-0219,384GUT. CatalogSurface/LocaleCatalog/generated themes,
17 official glyphs, gallery and CSS generator exist. RewardBurst/LocationPostcard do not exist.
Owner authorizes five serial coding tasks with review/CI/merge; device/taste gates stay open.
T-0221 is a HUMAN device gate depending on T-0326/T-0226/T-0327 and remains pending separately.

## Specification
1. RewardBurst extends Control, passive: play(kind:StringName,amount:int,origin:Vector2)->Error;
   coins|stars|chest|postcard_piece official coins/star/gift/map glyph. Reject unknown kind, negative
   amount or nonfinite origin atomically. Require mounted/ready and non-Container overlay parent;
   origin is parent-local. Optional Numeric +amount appears only for positive count, exact int64.
   Native finished(kind,amount) is presentation-only, exactly once per completed play; replacement/
   cancel/exit cancel old completion silently, no gameplay work or service/Events calls.
2. Normal: one-shot CPUParticles2D24particles, lifeSLOW; icon0→1 FAST/SPRING, amount label static.
   End hides effect. Replay stops old particles/tween; no stale callbacks. Reduced before/during:
   no particles/scale movement, static icon+amount remains until owner cancel/replay/exit;
   finished emits once immediately. Callback may replay safely. Own copy/theme/re-entry lifecycle.
   Reward visual constants belong to Tokens.Reward; CSS group/completeness oracle include them.
3. LocationPostcard extends PanelContainer: configure(texture:Texture2D,total:int,revealed:int,
   preset:thumb|full=full)->Error rejects null image, total outside documented1–16, invalid counts
   or preset atomically. Expose read-only texture/total/revealed/preset/state. No Config calls.
   Normalized row-major near-square partitions cover entire image including incomplete last row;
   revealed pieces use cropped image, hidden pieces use procedural paper grain and STROKE outlines.
4. State locked|in_progress|complete|revealing. Full shows official check stamp+translated complete
   caption; other states numeric revealed/total and locked icon when zero. SURFACE/Radius.M/MID.
   Thumb preferred288width; full expands available width. Image aspect preserved, layout grows with
   caption/theme; all descendants passive. Public piece_region(index)->Rect2 is normalized crop,
   invalid index empty. Masks and stamp distinguish state without depending on colour.
5. reveal_next()->Error animates next piece BASE/OUT crossfade, logical count increments immediately;
   reject complete/unconfigured. Interrupted reveal settles prior logical piece before next.
   Reduced before/during jumps to logical target; configure/exit kills old work; re-entry keeps
   image/count and owned translations/signals. Completion stamp appears after displayed reveal.
6. Rewards gallery scrolls four burst kinds and postcard locked/partial/complete/animated, both sizes;
   replay controls. Gallery uses a procedural gradient fixture, not final location artwork. Static
   review matrix plus normal replay/particles smoke. Existing assertions retained; no new dependencies.

## UX rules (docs/DESIGN.md#rules-quote-these-into-ui-tasks)
R-UI-1/2 dedicated catalog only; R-UI-3 token/theme visuals and motion; R-UI-4 static locale keys;
R-UI-5 generated themes untouched (CSS regeneration only); R-UI-6 native3classes xPL/PSEUDO
xdefault100/HC130 matrix. Physical devices/readers/art/taste/Opus gates remain open.

## Tests
- Burst atomic config/int64/parent coordinates, native particles/count/life/passive descendants,
  replay/cancel/exit/re-entry, reduction before/during, exactly-once/reentrant finished, locale/theme.
- Postcard invalid atomic,1–16 full normalized coverage including non-square last row, all states,
  ordered/interrupted/reduced/live reduction reveal and completion stamp, no stale callbacks,
  resize/aspect/thumbnail/full/theme/copy/re-entry/passivity.
- Gallery inventory/scroll/wrappingHC130/PSEUDO, CSS complete mirror, existing tests unchanged.
  Full make check, task/scope lint, deterministic review pack/fresh independent review, final13CI.

## Out of scope
Game rewards/progression/save/config/assets generation, service or feature wiring, platform/export,
project settings, HUMAN T-0221 certification and ROADMAP changes.

## Escalation (resolved by owner direction)
S9 stop recorded in draft PR146; owner explicitly authorized diagnosis and fix.
Container-owned SubViewport receives native GUI events through its host viewport. The test
now sends screen-transformed button coordinates to the host rather than directly injecting
into the child viewport. All396 GUT pass; no assertion or production input behavior weakened.
