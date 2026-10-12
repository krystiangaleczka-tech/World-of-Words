---
id: T-0208
title: Bind Inter fonts and activate the Ceramic default theme
epic: E12
type: infra
area: infra
risk: high
executor: sol
think: med
ui: low
status: review
depends_on: [T-0203]
touch:
  - game/project.godot
  - game/assets/fonts/**
  - game/ui/theme/**
  - game/services/nav.gd
  - game/tests/unit/ui/test_theme_generator.gd
  - game/tests/integration/test_theme_font_activation.gd*
  - tasks/T-0208-theme-font-activation.md
revision: 2
---

## Goal
Activate the default100 Ceramic theme and the selected Inter font family, with explicit
OpenType settings and menu-only low-processor mode. Prepare project settings without
changing exports, native integrations or the final Level component styling.

## Context
- `docs/DESIGN.md#typography`: one family; weight variants; tnum for numeric counters.
- `docs/DESIGN.md#tokensgd-shape`: styling from active themes.
- Roadmap T-0208; FR-PLAT-04, NFR-08; decision0009 Haptics and iOS audio (Ambient).
- Owner selected Inter in T-0205 5eaa29c; unchanged fonts pinned to Google Fonts
  bd8f81ddb5c74d5c8897b36ad88b440266245103. The SHA256 is recorded below/assets provenance.

## Current state
- Fresh main ab67ff0, fast-forwarded to reviewed T-0207
  716d968a7164faef91c885e4dfd3ed3f0e5bb128 (12/12 CI PASS) as a stacked draft.
- Six inactive generated themes, EditorScript/CLI generator and weights metadata exist.
  Their actual font resources are null; test_theme_generator.gd explicitly checks that.
- No game/assets/fonts exists; Inter binary/OFL from T-0205 local reviewed artifact are
  available with SHA25629160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031.
- project.godot has no custom theme/font, quit_on_go_back override or low-processor setting.
- services/nav.gd start(host:Node,content_root:String)->Error and _enter(screen:Screen)->void
  own screen routing and screen_changed. Screen.LEVEL is the active game; other screens are menus.
- decision0009 selects Ambient/default-style iOS audio. Pinned engine property hint confirms
  audio/general/ios/session_category=0 means Ambient; no native silent-switch proof exists.

## Specification
1. Copy unmodified pinned Inter.ttf and its full OFL into game/assets/fonts, with source URL,
   commit/hash and generator instructions. Also generate a licence Resource containing the
   full OFL notice: the existing all_resources export includes .tres but its include_filter
   does not include raw .txt. This ships the notice without changing export settings.
   Do not add Nunito, dependencies or SDKs.
2. Extend the existing generator to create five external FontVariation resources: regular400,
   semibold600, bold700, extrabold800 and numeric700. Base is a generated Inter.res FontFile containing exactly the unchanged Inter.ttf bytes; fixed opsz14,
   cv08=1/cv05=1 for all; numeric also tnum=1/pnum=0. Do not use simulated emboldening.
   Variation coordinates/features use the pinned TextServer's OpenType tag representation.
3. Bind theme.default_font and Label/font to regular; Button/font to semibold. Bind each
   Type font and Label variation to the table weight; Numeric uses the numeric resource.
   Preserve palette/sizes/scaling/CSS mappings and generate all resources via the tool.
   Current drawn wheel/cell components read default_font and get Inter regular for now;
   their intended ExtraBold/type binding is explicitly deferred to T-0222/T-0223.
4. project.godot: gui/theme/custom=default100 generated theme; quit_on_go_back=false;
   application/run/low_processor_mode=true at boot; audio/general/ios/session_category=0
   per decision0009. No export/manifest/plist/signing/permissions or orientation change.
5. Nav.start enters BOOT with OS.low_processor_usage_mode=true. Nav._enter applies false
   on LEVEL and true on every other screen, before mounting/emitting screen_changed.
   No API, signal/order, settings/save format or gameplay change. Do not introduce sleep
   tuning or FPS/thermal claims; idle-level redraw optimization remains later work.
6. Update T-0207's unbound-font assertion to verify Inter binding; retain its palette/size/
   independence checks. Document actual bindings in theme README and font provenance.

## Tests
File game/tests/integration/test_theme_font_activation.gd:
- Exact source hash/OFL, base-font identity, native PL/DE/punctuation coverage.
- Every weight has exact wght/opsz/cv08/cv05, no synthetic emboldening; numeric tnum/pnum.
- Native Godot shaping: equal tabular advances for all ten digits; proportional comparison
  has differing advances. I/l alternate shaping yields different glyphs from features-off.
- All six saved themes load; default/Label/Button/Type variations bind expected resources.
- Project custom theme, quit flag, boot low-mode and Ambient configuration match specification.
- Nav Level->Home->Level toggles low mode through public routing; observe mode at signal
  time and restore OS state in test teardown. Use existing injected-clock/content/save fixtures.
- Regenerate twice and compare theme/font/CSS hashes; make check, scope/task checks,
  fresh independent review and final-head CI. Native font/screenshot QA on desktop plus
  physical phone/iPhone readability/back/silent-switch/battery evidence stays explicit.

## UX rules (DESIGN.md#rules-quote-these-into-ui-tasks)
- R-UI-1: No new screen component; missing state -> separate task.
- R-UI-2: New component requires its own task/gallery entry.
- R-UI-3: Visual values come from Tokens/theme.
- R-UI-4: Player text uses translation keys.
- R-UI-5: Generated themes are only changed by running the generator.
- R-UI-6: Screenshot evidence follows DESIGN; no physical-device result inferred.

## Acceptance
All automated behavior checks pass; active font/theme renders native PL/DE without clipping
in the reviewed specimen. Physical device QA remains pending rather than fabricated.
No claim that all final component styles, a11y/settings or release device gates are complete.

## Out of scope
Final wheel/board/screen/stylebox migration, Settings UI/theme switching, idle-level redraw
optimization, native audio service/plugins, exports, signing, secrets, permissions, plist,
orientation, economy/save/consent/analytics and old gate closure.

## Rollback
Revert this task to restore the inactive theme and fallback font; no data migration.

## Escalation log
2026-10-12: Chris said “kontynuuj” after T-0207 completion and the explicit T-0208 handoff.
This authorizes the stated theme/font/project activation task as a new bounded step on the
reviewed pinned prerequisite, with stacked PR baseT-0207; merge parent first. Scheduling
T-0203 is done. Original FUN/device/Opus/Q10/Q14 and release audio/thermal checks stay open.
The task explicitly lists project.godot changes (S7) and Nav behavior/tests (S3/S5); no
S11 export/signing/native permission changes are included or inferred.

Implementation evidence: make check PASS (288 GUT,311 pipeline,370 tools, registries and
65 content levels). Native PL/DE/shaping and desktop theme/Level previews inspected;
14 generated base-font/variation/theme/licence/CSS outputs are byte-identical across two processes.
Physical phone/iPhone, Back/silent-switch and battery evidence remain pending.

Revision2: CI exposed first-import ordering: project custom theme loads before TTF import
cache exists on a fresh checkout. Generate an import-independent compressed FontFile
Inter.res containing exact source TTF data and point variations at it. Verify its embedded
bytes hash, native shaping, deterministic regeneration and a completely empty-cache import.
No Makefile/CI/export change or weakened error guard. All resources remain generated.
