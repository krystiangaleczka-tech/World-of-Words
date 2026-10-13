---
id: T-0209
title: Import the Ceramic Lucide icon set and shipped licence notice
epic: E14
type: feat
area: assets.art
risk: low
executor: sol
think: med
ui: low
status: done
depends_on: [T-0203]
touch:
  - game/assets/icons/**
  - game/tests/integration/test_icon_assets.gd*
  - tasks/T-0209-icon-assets.md
revision: 1
---

## Goal
Provide the 17 Lucide glyphs proposed by T-0205 as imported, tintable SVG textures and
ship their complete upstream licence for the later Settings licence screen.

## Context
- ROADMAP T-0209: icon set import and licence entries; DESIGN.md#iconbutton requires
  one open icon set, SVG in game/assets/icons/, no custom icons in screen tasks.
- Pinned T-0205 5eaa29c art-style.md and sources.json propose Lucide commit
  70562c1ee1c4fdcf736fe97bc893fb8511927934 and exactly these 17 official glyphs.
- Owner's next-task request authorizes this bounded asset import. It does not accept
  postcard/app-icon art or close T-0205 Q14, iPad, taste or Opus gates.

## Current state
- Fresh main ab67ff0 fast-forwarded to reviewed T-0191 4ab6c44 (12/12 CI PASS).
  This is a stacked draft; parent must merge first.
- game/assets/icons does not exist; IconButton.gd remains the existing prototype.
- game/export_presets.cfg uses all_resources with *.json included; raw text notices
  are not automatically exported. T-0208 font_license.tres demonstrates Resource metadata.
- Existing GUT integration discovery includes test_*.gd in tests/integration.

## Specification
1. Import house, settings, arrow-left, shuffle, lightbulb, sparkles, coins, star,
   lock, play, check, hand, route, video, x, map-pinned and gift from the pinned upstream.
   Preserve geometry, 24x24 viewBox, stroke width 2, round cap/join and no fill.
2. Normalize only stroke=currentColor to stroke=#ffffff as a colourless tint mask
   for Godot TextureRect/self_modulate. Record original and installed SHA256 values.
   Keep transparent backgrounds and import at 4x (96x96 pixels), lossless, no mipmaps.
3. Ship the entire upstream LICENSE (ISC plus Feather-derived MIT) byte-identically.
   Also embed it in icon_license.tres metadata/license_notice so all_resources exports it.
   Metadata records source URL, set name, pinned commit and SPDX ISC AND MIT.
4. sources.json lists each exact URL, upstream/local hash and semantic usage. README
   explains tinting, provenance, licence-screen handoff and the asset-only nature of this task.
5. Do not activate icons in screens, change components/export settings or add dependencies.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1/R-UI-2: existing catalog components only; no widget is created here.
- R-UI-3: later consumers tint using Palette tokens; white is the source mask, not UI colour.
- R-UI-4: no player-facing strings added.
- R-UI-5: generated themes remain untouched.
- R-UI-6: capture a REGULAR/PL contact sheet of imported icons; CI gallery is not available yet.

## Tests
File: game/tests/integration/test_icon_assets.gd
- All 17 declared textures load at 96x96, have transparent and visible pixels, and their
  visible pixels are white tint masks; installed source hashes match pinned manifest.
- Every semantic usage is unique and present; SVG geometry/import invariants are retained.
- Licence Resource reproduces the exact upstream notice/hash and provenance/SPDX metadata.
- make check, scope/task lint, fresh independent review and final-head CI pass.
- Export a release resource pack without signing/config changes; mount it in a separate
  process and verify all icon textures and complete licence Resource load.

## Acceptance
Required tests pass; visually inspect the contact sheet for recognisable consistent glyphs.
Screens/settings activation and device taste review belong to subsequent component tasks.

## Out of scope
App icon/postcards, icon buttons, settings UI, a11y label wiring, theme/config/economy/save,
new addon/dependency, export/platform/signing changes and ROADMAP edits.

## Escalation log
2026-10-12: bounded next-task handoff uses the pinned T-0205 proposed set and reviewed
installed runtime stack. Scheduling T-0203 is done; original manual acceptance gates stay
open. Imported SVG/metadata/licence files are the asset payload; task size guidance applies
to handwritten integration logic. No platform or gameplay behavior is changed.
