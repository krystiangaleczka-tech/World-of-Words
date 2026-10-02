# DESIGN.md — Design system and UX flows

Status: v1 for Chris's review. Owner: Opus + Chris for the foundation, Sol afterwards. Source: design pass `docs/design-pass/10-ui-ux.md` and `docs/design-pass/03-architektura-gry.md`; requirements from `PRODUCT.md` (canonical for config keys, event names and product names; this file follows it). Every value marked **provisional** is a v0 placeholder until the visual-direction task replaces it; names and structure are the contract, values are not. Balance numbers (unlock slots, prices, ad frequency) are owned by `GAME_DESIGN.md` and live in `game/data/config/*.json`; this document only references their keys, with defaults copied from `PRODUCT.md#first-10-minutes-timeline`.

Anchors are stable; tasks link to them (`DESIGN.md#level-motion`, `DESIGN.md#primarybutton`). Sections: `#principles`, `#how-we-work`, `#tokens`, `#typography`, `#layout`, `#components`, `#motion-haptics-and-sound` (incl. `#level-motion`), `#feedback-matrix`, `#accessibility`, `#screen-map-and-ux-flows`, `#screen-specs`, `#copy-and-tone`, `#gallery-and-review`.

## Principles

1. **Calm and readable.** Warm, quiet background; one accent colour; generous spacing; large letters. The grid and the wheel are the visual centre of the game. Nothing competes with them during play.
2. **Game feel first.** Swipe latency, haptics and the letter-to-grid motion matter more than any menu. Level-screen motion is specified in one table (`#level-motion`) and tuned on device by Chris.
3. **No popup clutter.** No sale banners, no "special offer" interruptions, no daily-reward popups, no stacked dialogs. The only true modal overlays are system dialogs (UMP consent, ATT, store purchase sheets, the interstitial itself).
4. **Sheets instead of modal popups.** Secondary content (shop, hint options, language picker) opens in a bottom `Sheet` that can be dismissed by tapping the scrim, swiping down or pressing Android back. Only one sheet is open at a time; a sheet never opens another sheet (it replaces its content).
5. **One primary action per screen.** Each screen has at most one `PrimaryButton`. Everything else is `SecondaryButton`, `TextButton`, `IconButton` or a `ListRow`.
6. **Never block progress with money.** No screen hides "Continue" behind an ad or a purchase. Rewarded offers are optional and always have a non-ad alternative or a plain close.
7. **Information is never colour-only.** Every state also has a shape, icon, motion or text cue.
8. **Built from components and tokens.** Screens are assembled from the catalog below; no screen invents its own colours, sizes, durations or widgets.

## How we work

### Pipeline

```
1. Visual direction   Opus + Chris: verbal moodboard, 2-3 HTML/CSS mockups of Level, then Home and Level
                      complete, using token-named CSS variables (#tokens-css-mirror). Chris picks on his
                      phone browser. Accepted mockups (screenshot + HTML) go to docs/design/.
2. Tokens             Values from the accepted mockup -> game/ui/tokens.gd (single source of truth).
3. Generated theme    build script -> game/ui/theme/generated/*.tres. Nobody edits .tres by hand.
4. Components+gallery game/ui/components/<Name>.tscn/.gd, each shown in game/ui/gallery/ in every
                      state x layout class x language (#gallery-and-review).
5. Screen specs       Sol writes each screen as a component tree (#screen-specs format) in the task.
6. Screens            Cheap executor assembles the tree in game/features/<screen>/.
7. Review             Gallery screenshots + device screenshots in the PR, compared with the mockup.
```

No production screen is built before step 4 for the components it uses. Phase 1 skips steps 1, 3 and 4: it uses `tokens.gd` v0 (the provisional values in this document) and raw but token-driven level components.

### Who does what

| Step | Primary | Second | Chris |
|---|---|---|---|
| Visual direction, mockups, token values | OPUS (direction, mockups with token-named CSS variables, incl. onboarding overlays); SOL transcribes accepted values into `tokens.gd` | SOL | decides taste on device |
| `tokens.gd` contract + theme generator | SOL (contract), CHEAP (generator, needs runtime) | — | — |
| Components + gallery | CHEAP (runtime); OPUS for `LetterWheelView`/`BoardView` game feel if CHEAP stalls | SOL review | device check for `high` UI tasks |
| Screen specs (component trees, states, copy keys) | SOL | OPUS via the visual-direction mockups (Level complete, onboarding overlays) and the onboarding second opinion | approves wave |
| Screen implementation | CHEAP | SOL review | screenshot review |
| Level-motion tuning | HUMAN (Chris on device) + CHEAP edits token values | — | owns the feel |
| Phase UX audit | OPUS in the P2 vertical-slice audit and the P3 soft-launch readiness audit; P1 feel is judged by Chris at the fun gate | — | decides |

### Rules (quote these into UI tasks)

- **R-UI-1** A screen task may not create a component. If a needed component or state is missing, STOP (S4) and request a separate `ui.components` task.
- **R-UI-2** New component = separate task (`area: ui.components`), including its gallery entry.
- **R-UI-3** No raw numbers in scenes or feature scripts: no literal colours, font sizes, margins, radii or durations in `game/features/**` or `game/ui/components/**`. Use `Tokens.*`, theme type variations or theme constants. Allowed literals: `0`, `1`, `-1`, array indices, and ratios defined in `Layout.*`. (Candidate CI check: `tools/check_tokens.py` greps for `Color(`, `#rrggbb`, numeric `tween_property` durations outside `game/ui/tokens.gd`.)
- **R-UI-4** Strings shown to players use translation keys (`#copy-and-tone`), never literals.
- **R-UI-5** Never edit `game/ui/theme/generated/`. Change `tokens.gd`, rerun the generator.
- **R-UI-6** Every UI PR with `UI: med|high` attaches screenshots per `#pr-screenshot-rules`.

## Tokens

**All values in this section are provisional until the visual-direction task.** Units: px at the 1080x1920 design resolution (3 px per dp on the 360 dp-wide COMPACT reference phone, about 2.6 px per dp on a 412 dp-wide phone), ms for durations. Touch sizes are computed for the 360 dp case so they hold on the smallest supported phone.

### Palette

Semantic names only (never `blue_500`). `PaletteHC` mirrors every name for high contrast.

| Token | Purpose | v0 | HC v0 |
|---|---|---|---|
| `Palette.BG` | screen background | `#F6F1E7` | `#FFFFFF` |
| `Palette.SURFACE` | cards, sheets, top bar | `#FFFFFF` | `#FFFFFF` |
| `Palette.SURFACE_ALT` | wheel disc, list row pressed, tracks | `#EDE5D6` | `#E6E6E6` |
| `Palette.PRIMARY` | primary button, selected tiles, accents | `#2F6F62` | `#00473D` |
| `Palette.ON_PRIMARY` | text/icons on PRIMARY | `#FFFFFF` | `#FFFFFF` |
| `Palette.TEXT` | body text, tile letters | `#1F2A30` | `#000000` |
| `Palette.TEXT_MUTED` | secondary text, disabled labels | `#5E6A70` | `#333333` |
| `Palette.SUCCESS` | word found accent, success toasts | `#2E8B57` | `#1B5E20` |
| `Palette.BONUS` | bonus word, bonus meter | `#C8902E` | `#7A4F00` |
| `Palette.ERROR` | invalid word tint, failed states | `#C0453A` | `#9B1C12` |
| `Palette.TILE` | wheel tile fill | `#FFFDF8` | `#FFFFFF` |
| `Palette.TILE_SELECTED` | tile in current chain | `#2F6F62` | `#00473D` |
| `Palette.LINE` | swipe line | `#3E8C7C` | `#00473D` |
| `Palette.CELL_EMPTY` | unrevealed grid cell | `#E3DBCB` | `#CFCFCF` |
| `Palette.CELL_FILLED` | revealed cell fill | `#FFFFFF` | `#FFFFFF` |
| `Palette.CELL_HINTED` | cell revealed by hint (not yet by word) | `#F3E2B8` | `#FFE08A` |
| `Palette.COIN` | coin icon and coin count accent | `#E0A526` | `#7A4F00` |
| `Palette.SCRIM` *(addition)* | dim layer behind sheets | `#1F2A3066` | `#000000A0` |
| `Palette.STROKE` *(addition)* | borders, dividers, cell outline | `#D8CFBF` | `#000000` |

HC rules: text contrast >= 7:1 on its background, cell and tile outlines always drawn (`STROKE`, 2 px -> 4 px), no information carried by tint alone. No dark theme in MVP (Later).

### Type

Sizes for text scale 100 %. `CELL_LETTER` is geometric (ratio of cell size), never text-scaled.

| Token | Use | Size | Weight |
|---|---|---|---|
| `Type.DISPLAY` | level number on Level complete, big counters | 88 | ExtraBold |
| `Type.TITLE` | screen titles, location name | 60 | Bold |
| `Type.SUBTITLE` *(addition)* | card titles, sheet titles | 48 | Bold |
| `Type.BODY` | paragraphs, list rows | 42 | Regular |
| `Type.LABEL` | buttons, tabs, pills | 40 | SemiBold |
| `Type.CAPTION` *(addition)* | hints under rows, badge text (minimum size) | 32 | SemiBold |
| `Type.NUMERIC` *(addition)* | coin counts, timers (tabular numerals) | 40 | Bold |
| `Type.TILE_LETTER` | wheel letters | 84 | ExtraBold |
| `Type.PREVIEW` *(addition)* | current-word bubble | 64 | ExtraBold |
| `Type.CELL_LETTER_RATIO` | cell letter size = cell side x ratio | 0.62 | ExtraBold |

### Space, Radius, Elevation

- `Space` (multiples of 8): `XS` 8, `S` 16, `M` 32, `L` 48, `XL` 64, `XXL` 96. Gaps between siblings use one step; screen padding `M`.
- `Radius`: `S` 16 (cells, small chips), `M` 28 (cards, tiles), `L` 44 (sheet top corners), `FULL` 999 (pills, buttons), `CELL_RATIO` 0.18 *(addition)*: cell radius = cell side x ratio.
- `Elevation` (StyleBoxFlat shadow size, offset y, colour): `NONE` 0; `LOW` 8, 4, `#0000001F` (tiles, cards); `MID` 16, 8, `#00000029` (pills, toasts); `HIGH` 32, 12, `#00000033` (sheets). Cells use no shadow.

### Motion and Ease

| Token | v0 ms | Use |
|---|---|---|
| `Motion.INSTANT` | 0 | state swaps; reduced-motion target |
| `Motion.FAST` | 120 | press feedback, pops, toast in/out |
| `Motion.BASE` | 240 | screen transitions, letter flight, sheets |
| `Motion.SLOW` | 420 | level-complete layer, count-up floor, highlight pulse |
| `Motion.STAGGER` *(addition)* | 40 | delay between letters / cells in a sequence |
| `Motion.CELEBRATE` *(addition)* | 1200 | max time from last word to Level complete layer |
| `Motion.TOAST_HOLD` *(addition)* | 1600 | toast visible time |
| `Motion.COUNT_UP_MAX` *(addition)* | 900 | coin count-up cap |

| Token | Godot mapping |
|---|---|
| `Ease.OUT` | `TRANS_CUBIC`, `EASE_OUT` (default for entering) |
| `Ease.IN` *(addition)* | `TRANS_CUBIC`, `EASE_IN` (leaving) |
| `Ease.IN_OUT` | `TRANS_SINE`, `EASE_IN_OUT` (moves between two rest points) |
| `Ease.SPRING` | `TRANS_BACK`, `EASE_OUT` (pops, landings) |

### Touch and Layout

| Token | v0 | Meaning |
|---|---|---|
| `Touch.MIN_TARGET` | 144 | min tappable size: 48 dp at 360 dp width |
| `Touch.TILE_HIT_RATIO` | 1.35 | wheel hit radius = tile radius x ratio |
| `Touch.DRAG_SLOP` *(addition)* | 12 | movement before a tap becomes a drag |
| `Layout.TABLET_MAX_ASPECT` | 1.65 | safe-area height/width below this = TABLET |
| `Layout.COMPACT_MAX_ASPECT` | 1.95 | below this (and not TABLET) = COMPACT, else REGULAR |
| `Layout.MAX_CONTENT_WIDTH` | 1080 | content column cap (TABLET) |
| `Layout.TOP_BAR_H` | 144 (all classes) | top bar height (holds a `Touch.MIN_TARGET` IconButton) |
| `Layout.WHEEL_WIDTH_RATIO` | REGULAR 0.66, COMPACT 0.62, TABLET 0.66 | wheel diameter / content width; leaves >= `Touch.MIN_TARGET` + `Space.M` beside the wheel for corner buttons |
| `Layout.WHEEL_MIN` / `WHEEL_MAX` | 560 / 800 | wheel diameter clamp |
| `Layout.GRID_MIN_RATIO` | 0.42 | grid area >= this share of body height; else wheel shrinks |
| `Layout.CELL_MIN` / `CELL_MAX` | 64 / 150 | cell side clamp (pipeline keeps grids within CELL_MIN on COMPACT) |
| `Layout.SHEET_MAX_RATIO` | 0.85 | max sheet height / screen height |

### tokens.gd shape

```gdscript
# game/ui/tokens.gd  — single source of truth. Values provisional (v0).
class_name Tokens
extends RefCounted

class Palette:
	const BG := Color("#F6F1E7")
	const PRIMARY := Color("#2F6F62")  # ... every name from DESIGN.md#palette

class PaletteHC:
	const BG := Color("#FFFFFF")  # ... same names, high-contrast values

class Space:
	const XS := 8
	const S := 16  # ... M, L, XL, XXL

class Motion:
	const INSTANT := 0
	const FAST := 120
	const BASE := 240
	const SLOW := 420
	const STAGGER := 40

class Ease:
	const OUT := Vector2i(Tween.TRANS_CUBIC, Tween.EASE_OUT)
	const SPRING := Vector2i(Tween.TRANS_BACK, Tween.EASE_OUT)

static var reduced_motion := false  # set by the settings feature at boot and on change

## Duration in seconds for a Motion token; the central reduced-motion switch.
static func dur(ms: int) -> float:
	return 0.0 if reduced_motion and ms > Motion.FAST else ms / 1000.0
```

Reading rules: Control-based components read colours, font sizes and margins from the active theme (`get_theme_color(&"TILE", &"Palette")`, theme type variations) so high contrast and text scaling switch everything at once; they refresh on `NOTIFICATION_THEME_CHANGED`. `Tokens.*` constants are read directly only for motion, touch and layout values, by the theme generator, and in Phase 1.

### Tokens CSS mirror

Mockups use CSS custom properties with a mechanical name mapping: `Group.NAME` -> `--Group-NAME` (case kept, dot becomes dash): `Palette.TILE_SELECTED` -> `--Palette-TILE_SELECTED`, `Space.M` -> `--Space-M`, `Motion.BASE` -> `--Motion-BASE` (value `240ms`), `Type.TITLE` -> `--Type-TITLE-size` / `--Type-TITLE-weight`. Mockup px = design px / 2.6 (CSS px on a phone), stated once in the mockup's `:root`. After step 2 of the pipeline the generator also writes `docs/design/tokens.css` so later mockups start from current values.

## Typography

Requirements:
- Full Polish and German coverage: `ąćęłńóśźż ĄĆĘŁŃÓŚŹŻ äöüß ÄÖÜẞ` (capital sharp s U+1E9E), plus basic punctuation, `„ ” – …`, and digits.
- Tiles show uppercase letters; uppercase must be unambiguous at small size (`I` vs `l`, `Ó` vs `O`, `Ż` vs `Ź` diacritics clearly separated from the letter and not clipped by tight line metrics).
- Tabular numerals (`tnum`) for every counter that animates (coins, bonus meter, timers).
- Licence: SIL OFL 1.1; licence text shipped and listed in Settings > Licences.

Candidates (**verify glyph coverage, `tnum` support and licence before adopting**; the result goes into a decision record):
1. **Nunito** (OFL, variable weight 200-1000): rounded and friendly; tiles in ExtraBold.
2. **Inter** (OFL, variable): very legible UI text with `tnum`; fallback if Nunito fails a requirement, or as the numeric font for `Type.NUMERIC`.

Use one family if it passes all requirements. Implement as `FontVariation` resources (`game/assets/fonts/`) with weight axis and `opentype_features = {"tnum": 1}` for `Type.NUMERIC`. Phase 1 may use Godot's default font if a debug-screen check shows all Polish letters render correctly.

Usage: `DISPLAY` and `TITLE` at most once per screen; `BODY` for any running text; `LABEL` for anything tappable; `CAPTION` is the floor (nothing smaller). Uppercase only on tiles, cells and preview.

Text scaling steps: 100 % / 115 % / 130 % (setting "Text size": Normal / Large / Larger). Applies to all `Type.*` except `TILE_LETTER`, `PREVIEW` and `CELL_LETTER_RATIO` (geometry-bound). Layouts must not clip at 130 % in the pseudo-locale (+35 %, German from P3); rows grow vertically, labels wrap to max 2 lines, buttons never truncate their label (they grow in height).

## Layout

- **Portrait only** (`display/window/handheld/orientation = portrait`). Before locking iPad to portrait, verify Apple's current iPadOS multitasking/resizing requirements; because layout classes are recomputed on every resize, an arbitrary window size still degrades gracefully.
- Design resolution 1080x1920, `stretch/mode = canvas_items`, `stretch/aspect = expand` (project.godot is a hotspot: `infra` task). Logical viewport width is >= 1080 and height >= 1920; tall phones get extra height, tablets get extra width.

### ScreenScaffold and safe areas
Every screen root is a `ScreenScaffold`. It converts `DisplayServer.get_display_safe_area()` (screen px) to viewport coordinates (`viewport_size / DisplayServer.window_get_size()`), applies the insets as margins, recomputes on `get_viewport().size_changed`, and exposes `layout_class`. Background (`BG` or location art) bleeds under the insets; content and touch targets never do. Gallery and desktop runs can inject fake insets (`debug_insets`) to simulate a notch and home indicator.

### Layout classes
Computed from the safe-area rect in viewport units: `aspect = height / width`.

| Class | Rule | Typical devices |
|---|---|---|
| `TABLET` | aspect < `Layout.TABLET_MAX_ASPECT` (1.65) | iPad (1.33-1.43), 16:10 tablets (1.6), foldables open |
| `COMPACT` | 1.65 <= aspect < `Layout.COMPACT_MAX_ASPECT` (1.95) | 16:9 phones, small 720p Androids |
| `REGULAR` | aspect >= 1.95 | modern 19.5:9 / 20:9 phones |

On TABLET the content column is capped at `Layout.MAX_CONTENT_WIDTH` and centred; backgrounds fill the rest. The wheel never grows beyond `Layout.WHEEL_MAX`.

### Level screen geometry
Level body (inside safe area, below the top bar) is a vertical stack of two rectangles plus a strip:

```
TopBar (Layout.TOP_BAR_H)
Grid area      flex: takes all remaining height, >= GRID_MIN_RATIO of body
Preview strip  WordPreview, height Type.PREVIEW + 2*Space.S
Wheel area     wheel diameter + Space.L top/bottom; HintButton / shuffle IconButton in its corners
```

| Class | Wheel diameter | Grid share of body (approx.) | Notes |
|---|---|---|---|
| REGULAR | 0.66 x width = ~713 | ~52 % | one power-up button per corner of the wheel area, never stacked |
| COMPACT | 0.62 x width = ~670 | ~48 % | top bar 144; preview strip tighter (`Space.XS`) |
| TABLET | 0.66 x column, clamped to 800 | ~55 % | column 1080, art fills sides |

Grid fitting: `cell = min(area_w / cols, area_h / rows)` minus `Space.XS` gap, clamped to `[CELL_MIN, CELL_MAX]`, grid centred. The grid **scales to fit and never scrolls**. If the wheel would push the grid below `GRID_MIN_RATIO`, the wheel shrinks towards `WHEEL_MIN` first. Grids that cannot meet `CELL_MIN` on COMPACT are a content bug (pipeline validator), not a layout case.

### Reference devices
| Device | Class | Why |
|---|---|---|
| Small Android, 5.5" 720x1280 (cheap reference phone) | COMPACT | performance + smallest layout |
| iPhone with Dynamic Island (e.g. 15/16) | REGULAR | safe-area insets, iOS haptics |
| iPad (10th gen or Air) | TABLET | content column, wheel cap |
| Optional: mid Android 20:9 | REGULAR | gesture navigation inset |

## Components

Location: `game/ui/components/<Name>.tscn` + `<Name>.gd` (`class_name <Name>`). Each component: typed `@export` parameters, signals for user intent (never calls services), all states listed below, a gallery entry. States vocabulary: normal, pressed, disabled, loading, highlighted (attention), plus component-specific ones. Phase: **P1** = provisional version used by the Core Prototype; **P2** = final version built on the generated theme. Additions to the baseline catalog are marked *(addition)*. Layout primitives (`VBox`, `HBox`, `Spacer`, `Margin`, `Text` = `Label` with a `Type.*` theme type variation) are not components and need no task.

### ScreenScaffold
**Purpose:** root of every screen: background, safe-area margins, optional `TopBar`, body, optional bottom row. **Params:** `top_bar: TopBar?`, `background: Texture2D?`, `bottom: Control?`, `debug_insets: Rect2`. **Exposes:** `layout_class: StringName`, signal `layout_class_changed(cls)`. **Tokens:** `Palette.BG`, `Layout.*`, `Space.M` default body padding. **Don't:** nest scaffolds; put content outside its body. **Phase:** P1 (safe area only), P2 final.

### TopBar
**Purpose:** fixed header row: leading slot, centre title, trailing slot. **Params:** `leading: Array[Control]`, `title_key: String`, `trailing: Array[Control]`. **Tokens:** `Layout.TOP_BAR_H`, `Palette.SURFACE` or transparent (Level), `Type.SUBTITLE`, `Space.S`. **Don't:** more than 3 controls per side; text buttons in the bar. **Phase:** P1 minimal, P2.

### PrimaryButton
**Purpose:** the single main action of a screen ("Continue", "Play"). **Params:** `text_key`, `icon: Texture2D?`, `sublabel_key?` (e.g. price). **States:** normal, pressed (scale 0.96, `Motion.FAST`), disabled (`TEXT_MUTED` on `SURFACE_ALT`), loading (spinner replaces icon, label kept, input ignored), highlighted (slow pulse, max 3 cycles). **Tokens:** `PRIMARY`, `ON_PRIMARY`, `Type.LABEL`, `Radius.FULL`, `Elevation.LOW`, min height `Touch.MIN_TARGET`. **Behaviour:** emits `pressed` once; ignores repeat taps while loading. **Don't:** two per screen; use for destructive or ad actions. **Phase:** P1 (plain), P2.

### SecondaryButton
**Purpose:** alternative actions ("x2 with ad", "Restore purchases"). **Params/states:** as PrimaryButton, plus `badge: StringName` (`ad` shows a video icon so ad actions are never hidden). **Tokens:** `SURFACE`, `PRIMARY` text and 3 px `STROKE`/`PRIMARY` outline. **Phase:** P2.

### TextButton *(addition)*
**Purpose:** lowest-emphasis action ("No thanks", "Privacy policy"). Text only, `PRIMARY` colour, underline on pressed. Hit area still `Touch.MIN_TARGET` tall. **Phase:** P2.

### IconButton
**Purpose:** icon-only action (settings, back/home, shuffle, close). **Params:** `icon`, `a11y_label_key` (required), `size: S|M`. **States:** normal, pressed, disabled, highlighted. **Tokens:** `Touch.MIN_TARGET`, `Radius.FULL`, `SURFACE`. Icons from one open set (Lucide or Material Symbols, decided in visual direction), SVG in `game/assets/icons/`. **Don't:** draw custom icons in tasks. **Phase:** P1, P2.

### CurrencyPill
**Purpose:** shows a balance (coins; stars on Journey). Tappable when `action` set (coins -> Shop sheet). **Params:** `kind: coins|stars`, `value: int`, `action_enabled: bool`. **States:** normal, pressed, counting (count-up running), highlighted (pop at end of count-up). **Tokens:** `Type.NUMERIC`, `COIN`, `SURFACE`, `Elevation.MID`, `Radius.FULL`. **Behaviour:** `set_value(v, animate)` uses `#level-motion` coin count-up. **Phase:** P2.

### Badge
**Purpose:** small count or state marker on an icon/tab ("NEW", "3", lock). **Params:** `text`, `kind: info|lock|new`. **Tokens:** `Type.CAPTION`, `PRIMARY`/`BONUS`, `Radius.FULL`. **Don't:** red "urgent" dots for marketing. **Phase:** P2.

### ProgressBar
**Purpose:** linear progress (postcard progress, chest progress inside `BonusMeter`). **Params:** `value: float 0..1`, `label_key?`, `tint: primary|bonus`. **States:** normal, filling (tween `Motion.BASE`), complete (icon + label, not just colour). **Tokens:** `SURFACE_ALT` track, `Radius.FULL`. **Phase:** P2.

### Sheet
**Purpose:** bottom panel replacing popups (shop, hint options, language, confirmations). **Params:** `title_key`, `content: Control`, `dismissible: bool = true`. **States:** closed, opening, open, closing, busy (non-dismissible during a purchase/ad request). **Behaviour:** scrim tap, swipe down, Android back close it (unless busy). Height = content, max `Layout.SHEET_MAX_RATIO`; content scrolls inside if longer. One sheet at a time; opening another replaces content. Focus trapped for screen readers. **Tokens:** `SURFACE`, `SCRIM`, `Radius.L` (top corners), `Elevation.HIGH`, `Space.L` padding. **Phase:** P2.

### Toast
**Purpose:** transient, non-blocking message ("Purchase restored", "No ad available"). **Params:** `text_key`, `icon?`, `kind: info|success|error`. One at a time; new replaces old. **Position:** on Level above the preview strip; elsewhere below the top bar. No buttons. **Tokens:** `SURFACE`, `TEXT`, `Elevation.MID`, `Motion.TOAST_HOLD`. **Phase:** P1 (plain label), P2.

### Card
**Purpose:** grouped content block (shop product, journey location). **Params:** `title_key`, `body: Control`, `media: Texture2D?`, `action?`. **States:** normal, pressed (if tappable), disabled/locked (lock Badge + text, desaturated media), highlighted (current). **Tokens:** `SURFACE`, `Radius.M`, `Elevation.LOW`. **Phase:** P2.

### ListRow
**Purpose:** settings and options rows. **Params:** `title_key`, `subtitle_key?`, `leading_icon?`, `trailing: none|chevron|value|toggle|slider`. **States:** normal, pressed, disabled. Min height `Touch.MIN_TARGET`; whole row tappable. **Tokens:** `Type.BODY`, `Type.CAPTION`, `STROKE` divider. **Phase:** P2.

### Toggle
**Purpose:** on/off setting. **Params:** `value: bool`, `a11y_label_key`. **States:** on, off, pressed, disabled. On state shows a check glyph in the knob (not colour only). **Tokens:** `PRIMARY`, `SURFACE_ALT`. **Phase:** P2.

### Slider *(addition)*
**Purpose:** separate sound and music volumes. **Params:** `value 0..1`, `step 0.1`, `a11y_label_key`. Plays a preview cue on release (sound slider only). **Tokens:** `PRIMARY`, `SURFACE_ALT`, thumb >= `Touch.MIN_TARGET` hit area. **Phase:** P2.

### NavTab
**Purpose:** bottom navigation item on Home (Journey, Daily, Collection). **Params:** `icon`, `label_key`, `locked_label_key?` (e.g. "Level 15"). **States:** normal, selected, locked (lock icon + level label), highlighted (newly unlocked, Badge "NEW"). Tabs for unbuilt features are hidden, not locked. **Phase:** P2.

### LetterTile
**Purpose:** one letter on the wheel. **Params:** `letter: String` (uppercase grapheme from level data), `index: int`. **States:** normal, selected (`TILE_SELECTED`, `ON_PRIMARY`, scale 1.12), hinted-start (outline pulse when a hint marks the first letter, if GAME_DESIGN chooses it), disabled (during shuffle). **Tokens:** `TILE`, `TEXT`, `Type.TILE_LETTER`, `Elevation.LOW`. **Don't:** handle input (the wheel does). **Phase:** P1, P2.

### LetterWheelView
**Purpose:** the swipe input. Lays out N `LetterTile`s on a circle, draws the line, emits `chain_changed(indices: PackedInt32Array)` and `word_attempted(indices)` on release. **Params:** `letters: PackedStringArray`, `diameter` (from layout). **States:** idle, dragging, locked (animation in progress; input ignored), shuffling. **Behaviour (from ARCHITECTURE):** touch/drag events; hit radius = tile radius x `Touch.TILE_HIT_RATIO`; backtrack by returning to the previous tile; second finger ignored; line updated every frame with no allocations (preallocated `Line2D` points); haptic `tick` per added letter via `Events`; tiles are indices, never characters. **Tokens:** `SURFACE_ALT` disc, `LINE` (width 18 px), `Touch.*`. **Phase:** P1 (game-feel critical), P2 polish.

### WordPreview *(addition)*
**Purpose:** shows the current chain as a word bubble above the wheel and plays result feedback. **Params:** `text`. **States:** empty, building, level, bonus, already_found, invalid (see `#feedback-matrix`). **Tokens:** `Type.PREVIEW`, `SURFACE`, `PRIMARY`, `BONUS`, `ERROR`, `Radius.FULL`. **Phase:** P1, P2.

### TutorialHand *(addition)*
**Purpose:** animated hand that traces the swipe gesture over the wheel on slot 1 (PRODUCT.md FR-ONB-02, timeline slot 1). **Params:** `points: PackedVector2Array` (tile centres from `LetterWheelView`, in order of the target word), `loop: bool = true`. **States:** playing (hand moves tile to tile at `Motion.SLOW` per segment, pauses `Motion.BASE` at the end, repeats), hidden (fades out `Motion.FAST` on the first touch of the wheel and stays hidden after the first found word). **Behaviour:** ignores input (`mouse_filter = IGNORE`), so the player swipes through it; draws above the wheel, below Toasts. Reduced motion: static arrow along the path + the `CAPTION` line, no movement. **Tokens:** `Palette.TEXT` at 85 % alpha with `Elevation.MID` shadow, `Motion.*`, `Ease.IN_OUT`. **Don't:** add text inside the hand; reuse it for coach marks (those use `highlighted` states, `#feature-unlock-gating`). **Phase:** P2.

### GridCell
**Purpose:** one crossword cell. **Params:** `letter`, `cell_size`. **States:** empty (`CELL_EMPTY`), hinted (`CELL_HINTED` + letter + small dot marker), filled (`CELL_FILLED` + letter), highlighted (already-found pulse). **Tokens:** `CELL_*`, `Type.CELL_LETTER_RATIO`, `Radius.CELL_RATIO`, `STROKE`. **Phase:** P1, P2.

### BoardView
**Purpose:** renders the grid from `LevelData` coordinates, fits it to its rect (`#level-screen-geometry`), plays reveal/landing/wave animations. **Params:** `level: LevelData`, `board_state` snapshot. **API:** `cell_global_position(cell) -> Vector2` (target for flying letters), `reveal_word(cells)`, `reveal_cell(cell, hinted)`, `play_wave()`. **Phase:** P1, P2.

### BonusMeter
**Purpose:** bonus-word counter and chest progress. **Params:** `count`, `target` (from `economy` config), `visible_from_slot` (handled by screen). **States:** normal, filling, full (chest icon + "Open" label, highlighted), already (pulse), highlighted (coach mark on first appearance). **Tokens:** `BONUS`, `Type.NUMERIC`. **Phase:** P1 as plain `Text` counter, P2.

### HintButton
**Purpose:** power-up button with count/price. **Params:** `kind: hint|reveal`, `count: int`, `price: int`. **States:** normal (count Badge, or coin price when count = 0), pressed, disabled (level finished or animation locked), loading (rewarded request), highlighted (stuck-player offer pulse, `#flow-stuck-player`). Shuffle uses an `IconButton`, not this component. **Phase:** P1 (free hint, no count), P2.

### RewardBurst
**Purpose:** one-shot celebration at a point: particles + icon pop + optional amount label ("+25"). **Params:** `kind: coins|stars|chest|postcard_piece`, `amount`, `origin`. Uses `CPUParticles2D` (one-shot, about 24 particles). Reduced motion: static icon + label, no particles. **Phase:** P2.

### LocationPostcard
**Purpose:** postcard art split into pieces revealed by stars. **Params:** `texture`, `pieces_total`, `pieces_revealed`, `size: thumb|full`. **States:** locked, in_progress, complete (stamp + caption), revealing (one piece animates in). Unrevealed pieces: paper texture with piece outline (shape cue). **Tokens:** `Radius.M`, `Elevation.MID`, `STROKE`. **Phase:** P2.

### StatePanel *(addition)*
**Purpose:** empty / offline / error content inside a screen or sheet: icon, title, body, one action. **Params:** `kind: offline|error|empty|unavailable`, `title_key`, `body_key`, `action_key?`. **Phase:** P2.

### CalendarDay
**Purpose:** one day in the daily calendar. **Params:** `day: int`, `state`. **States:** future (muted, disabled), today (outline + "Today" label), done (check icon), missed (empty circle), frozen (snowflake icon), reward (gift icon on milestone days). **Tokens:** `Type.NUMERIC`, `PRIMARY`, `SUCCESS`. **Phase:** P3.

### StreakFlame
**Purpose:** streak count in the top bar. **Params:** `days: int`, `state: active|at_risk|frozen|broken`. Each state has its own icon variant and label, not just colour. **Phase:** P3.

## Motion, haptics and sound

Global rules:
- Every duration comes from `Motion.*` through `Tokens.dur()`; every ease from `Ease.*`.
- Kill the previous tween on a node before starting a new one (`AGENTS.md` rule).
- Features emit `Events` signals; Audio and haptics listen (logic calls, effects listen). Haptic pattern names: `tick` (lightest, per letter), `soft` (neutral acknowledgement), `success`, `error` (gentle, never a long buzz). Sound cue names are keys in `game/data/audio/cues.json`.
- Input is never blocked longer than `Motion.BASE` by an animation except the level-complete sequence.
- **No loading screens between levels.** The next level is loaded and its scene prepared when the last word is released; the completion animation hides the work. The only loading UI in the game is the boot splash and `loading` button states.

### Level motion

All values tunable by Chris on device by editing `tokens.gd`; the table defines structure.

| Event | Animation (property, duration, ease) | Haptic | Sound cue |
|---|---|---|---|
| Touch letter | tile `scale` 1.0 -> 1.12, `FAST`, `SPRING`; colour swap `INSTANT` | `tick` | `tile_touch` (pitch +1 step per chain letter, cap 8) |
| Extend line | `Line2D` last point follows finger every frame; no tween | — | — |
| Backtrack | released tile `scale` -> 1.0, `FAST`, `OUT`; colour back `INSTANT` | `tick` | `tile_back` (pitch -1 step) |
| Release, < 3 letters | preview `modulate:a` -> 0, `FAST`, `IN`; no result feedback | — | — |
| Release valid level word | preview `scale` 1.0 -> 1.08 -> 1.0, `FAST`, `SPRING` | `success` | `word_valid` |
| Letters fly to grid | ghost letters `global_position` preview -> cell, `BASE`, `IN_OUT`, `STAGGER` per letter; `scale` 1.0 -> cell size | — | `letter_land` (quiet, per letter) |
| Letter lands | cell `CELL_EMPTY` -> `CELL_FILLED`, `scale` 1.0 -> 1.1 -> 1.0, `FAST`, `SPRING` | — | — |
| Word complete | word cells `modulate` 1.0 -> 1.25 -> 1.0, `BASE`, `OUT` | — | — |
| Bonus word | preview flies to `BonusMeter` (`global_position`, `scale` -> 0.4), `BASE`, `IN_OUT`; meter fill `BASE`, `OUT`; meter icon pop `FAST`, `SPRING`; label "Bonus word" above preview for `TOAST_HOLD` | `success` | `word_bonus` |
| Already found | target cells (or meter) `scale` 1.0 -> 1.06 -> 1.0 twice, `FAST`, `IN_OUT`; preview fades `BASE` with label | `soft` | `word_already` |
| Invalid | preview `position:x` shake +-24 px, 3 cycles in `BASE`, `OUT`; tint `TEXT` -> `ERROR`; fade `FAST` | `error` | `word_invalid` (soft, low) |
| Hint reveal | cell -> `CELL_HINTED`, letter `scale` 0.6 -> 1.0 + fade in, `BASE`, `SPRING`; HintButton count pop | `soft` | `hint_reveal` |
| Reveal word | as hint reveal per cell, `STAGGER` x 2, then word-complete flash | `success` | `reveal_word` |
| Shuffle | tiles `position` along arc to new slots, all together, `BASE`, `IN_OUT`; wheel locked meanwhile | `tick` | `shuffle` |
| Level complete | cell wave: each cell `scale` 1.0 -> 1.12 -> 1.0, `FAST`, delay (row + col) x `STAGGER`; then Level complete layer (`modulate:a` + `position:y` +48 -> 0, `SLOW`, `OUT`); total <= `CELEBRATE` | `success` | `level_complete` |
| Reward burst | `RewardBurst` particles lifetime `SLOW`; icon `scale` 0 -> 1, `FAST`, `SPRING` | `soft` | `reward` |
| Coin count-up | label value old -> new over min(`SLOW` + 20 ms x delta, `COUNT_UP_MAX`), `OUT`, tabular digits; pill pop at end `FAST`, `SPRING` | — | `coin_tick` (max 10 ticks) |
| Button press | `scale` 1.0 -> 0.96 -> 1.0, `FAST`, `OUT` | — | `ui_tap` |
| Screen transition | out: `modulate:a` 1 -> 0, `FAST`, `IN`; in: `modulate:a` 0 -> 1 + `position:y` +48 -> 0, `BASE`, `OUT` | — | — |
| Sheet open / close | scrim `modulate:a` 0 -> 1, `BASE`; panel `position:y` offscreen -> rest, `BASE`, `OUT`; close `FAST`, `IN` | — | `sheet_open` / `sheet_close` |
| Toast | in: `modulate:a` + `position:y` -16 -> 0, `FAST`, `OUT`; hold `TOAST_HOLD`; out `FAST`, `IN` | — | — (`success` kind: `toast_success`) |

### Reduced motion mapping
Applied in one place (`Tokens.dur()` plus a `Tokens.reduced_motion` check in the few components below):

| Normal | Reduced |
|---|---|
| durations > `FAST` | `INSTANT` (via `Tokens.dur()`) |
| slides, scale pops, wave | none; state change shown with a `FAST` cross-fade |
| invalid shake | no shake; `ERROR` tint + `x` icon + label (see `#feedback-matrix`) |
| letters flying to grid | letters fade in place in their cells (`FAST`) |
| RewardBurst particles | static icon + amount label |
| coin count-up | value jumps to final |
| highlighted pulses | static outline + Badge |

Haptics and sound are unaffected by reduced motion (separate settings).

## Feedback matrix

`BoardState.evaluate()` returns one of four kinds. **BANNED is not a separate client state**: banned words are in neither the level set nor the bonus set, so they evaluate to INVALID and get exactly the INVALID feedback (decision 0004 rule 7).

| Kind | Visual | Text | Sound | Haptic |
|---|---|---|---|---|
| LEVEL | preview pop (`PRIMARY`), letters fly into cells, cells fill, word flash | none (the word appears in the grid) | `word_valid` | `success` |
| BONUS | preview turns `BONUS`, star icon, flies to `BonusMeter`, meter +1 | "Bonus word" label above preview | `word_bonus` | `success` |
| ALREADY_FOUND | matching grid word (or meter) pulses; preview fades | "Already found" label | `word_already` | `soft` |
| INVALID | preview shake + `ERROR` tint + `x` icon, then fade; nothing else changes | none by default; with reduced motion or high contrast: "Not in our word list" | `word_invalid` | `error` |
| INVALID (BANNED) | identical to INVALID | identical | identical | identical |

Shape/text cues guarantee no state is colour-only: LEVEL = letters move into the grid, BONUS = star icon + label, ALREADY_FOUND = target pulse + label, INVALID = shake or `x` icon. Chains shorter than 3 letters are not attempts: no feedback.

## Accessibility

| Feature | Spec | Phase |
|---|---|---|
| Text scaling | 100 / 115 / 130 % (`#typography`); generated theme variants | P2 |
| High contrast | `PaletteHC` + outlines; generated theme variant; toggle in Settings | P2 |
| Colour-independent cues | `#feedback-matrix`; locked = lock icon + label; toggles show a check | P1 for level feedback, P2 rest |
| Reduced motion | Settings toggle; default follows OS setting where the platform exposes it | P2 |
| Haptics off | Settings toggle; haptic listener becomes a no-op | P1 (debug), P2 (Settings) |
| Separate volumes | sound effects and music sliders | P2 |
| Touch targets | >= `Touch.MIN_TARGET` for every tappable; wheel hit radius enlarged | P1 |
| Screen readers | `a11y_label_key` on every `IconButton`, `NavTab`, `Toggle`, `Slider`, `HintButton`, `CurrencyPill`; buttons expose their label; focus order = visual order. Gameplay (wheel/grid) is not promised as accessible; the Level screen exposes level number, found/total words and bonus count as a readable summary | P2 (verify Godot screen-reader support on the pinned version) |

Theme variants generated: `theme_<default|hc>_<100|115|130>.tres` (6 files). The settings feature applies the matching one to the root window; `Tokens.reduced_motion` is set at boot from the save.

## Screen map and UX flows

### Screen map

| Screen | Scene path | Phase | Notes |
|---|---|---|---|
| Boot | owned by `services.nav` (path per `ARCHITECTURE.md#areas`) | P0 | splash <= 1.5 s, loads save, config, content manifest |
| Level | `features/level/` | P1 | includes the Level complete layer |
| Level complete | layer inside Level | P1 minimal, P2 | not a Nav screen: allows preload of next level |
| Home | `features/home/` | P0 empty, P2 | unlocked by `unlocks.journey_slot` |
| Journey | `features/journey/` | P2 | 1 region in P2, multi-region in P3 |
| Location postcard | `features/journey/postcard` | P2 | |
| Settings | `features/settings/` | P2 | |
| Shop | Sheet from `features/shop/` | P2 | opened from CurrencyPill, HintButton options, Settings |
| Daily | `features/daily/` | P3 | calendar + today's puzzle (uses Level scene in daily mode) |
| Collection | `features/collection/` | P3 | location and monthly calendar postcards |
| Debug | `features/debug/` | P1 | debug builds only |
| System overlays | UMP form, ATT prompt, store sheet, ad | P2 | not ours; never stacked with a Sheet |

```
Boot ──first launch / slot < journey_slot──► Level ◄──────────────┐
  └──returning, slot >= journey_slot──► Home ──Play──► Level      │
Home ──NavTab──► Journey ──► Location postcard ──Play──► Level    │
Home ──IconButton──► Settings ──► Shop sheet / Privacy options    │
Home / Level ──CurrencyPill──► Shop sheet                         │
Level ──last word──► Level complete layer ──Continue──► [interstitial?] ──┘
                                     └──location finished──► Location postcard
Level ──IconButton(home)──► Home        (Home NavTab Daily ──► Daily, P3)
```

Android back: closes an open Sheet; on Level goes to Home (once Home is unlocked, otherwise backgrounds the app); on Home backgrounds the app; elsewhere goes back one screen. Never a "Quit?" dialog.

### Feature unlock gating

Gating is data: keys in `game/data/config/unlocks.json`, `consent.json` and `ads.json` (values owned by `GAME_DESIGN.md#unlocks`; defaults and names below are copied from `PRODUCT.md#first-10-minutes-timeline`, which is canonical). A gated feature is absent until its slot (hidden, never shown locked inside Level), then appears with at most one coach mark, never a popup (PRODUCT.md FR-ONB-03).

**Coach mark** = the target component's `highlighted` state plus one inline `Text(Type.CAPTION)` label beside it (copy key `onboarding.coach.<feature>`). Any tap anywhere dismisses it; it also ends after `Motion.TOAST_HOLD` x 2. No overlay, no scrim, no arrow, no new component. Shown once per feature, recorded in the save, and each emits `onboarding_step` (FR-ONB-05). Coach marks and the consent steps do not count toward `onboarding.max_prompts_per_session` (FR-ONB-04).

| Slot (default) | Feature | Config key | First appearance |
|---|---|---|---|
| 1 | Swipe tutorial | — | `TutorialHand` over the wheel + `CAPTION` `level.tutorial.connect` until the first word; only board, preview and wheel on screen |
| after 1 | UMP consent form (where required) | `consent.ump_after_slot` | `#flow-consent-and-att` |
| 2 | Shuffle button | `unlocks.shuffle_slot` | coach mark on `IconButton(shuffle)` |
| 5 | Bonus meter | `unlocks.bonus_meter_slot` | appears with the level's first bonus word; coach mark on `BonusMeter` |
| after 6 (iOS) | ATT system prompt with the UMP IDFA explainer | `consent.att_after_slot` | `#flow-consent-and-att` |
| 7 | Hint (with free onboarding hints), coins pill, Shop | `unlocks.hint_slot`, `economy.grant.onboarding_hints` | `HintButton(hint)` with its count Badge + coach mark; `CurrencyPill(coins)` appears without a coach mark |
| 10 | Home, Journey, postcards | `unlocks.journey_slot` | Level complete shows postcard progress; Continue leads to Home once |
| 12 | Reveal word | `unlocks.reveal_slot` | coach mark on `HintButton(reveal)` |
| 12 | Rewarded x2 on Level complete | `unlocks.double_reward_slot` | `SecondaryButton` with ad badge, no coach mark |
| 15 (P3) | Daily + streak | `unlocks.daily_slot` | `NavTab(daily)` with Badge "NEW" |
| 16+ | Interstitials eligible | `ads.interstitial.first_slot` | — (ad policy, `#flow-interstitial-placement`) |

Constraint (config validator unit test, PRODUCT.md): `consent.ump_after_slot <= consent.att_after_slot < min(unlocks.hint_slot, unlocks.double_reward_slot, ads.interstitial.first_slot)`. Consent and ATT are resolved before the first moment an ad could be offered.

### Flow: first launch
1. Boot splash (app icon on `BG`, no text, no spinner unless > 1.5 s).
2. **Straight into Level 1.** No login, no consent form, no ATT, no notification permission, no language picker (UI and content language = device language if its content ships, else PL; while only PL content ships, EN UI is reachable in debug builds only; PRODUCT.md FR-LOC-01, FR-SET-02), no "welcome" popup.
3. Level 1: animated hand traces the first word on the wheel until the player finds a word; no text instructions beyond one `CAPTION` line ("Connect letters to make words").
4. Until `unlocks.journey_slot`, levels chain directly (Level complete -> Continue -> next level); features appear per `#feature-unlock-gating`. The ads SDK is not initialised before UMP resolves (and on iOS no ad is requested before ATT resolves); remote config is fetched silently and cached.

### Flow: consent and ATT
Consent is shown **before the ads SDK is initialised, never before level 1** (PRODUCT.md FR-CONSENT-01, FR-CONSENT-04, FR-ADS-06). Both steps happen on the Level complete layer, after the player taps Continue and before the next level appears; the next level is already preloaded behind them.
- **UMP (all platforms), after slot `consent.ump_after_slot` (default 1):** `Platform.consent` requests consent info; if UMP reports a form is required (EEA/UK and other regulated regions), show the UMP form (Google's UI, full screen). Then initialise the ads SDK with the resulting consent state. Outside regulated regions: no form; ads initialise silently at this point.
- **ATT (iOS only), after slot `consent.att_after_slot` (default 6):** show UMP's IDFA explainer message (configured in the AdMob console), then the ATT system prompt. No custom pre-prompt screen. No ad is requested on iOS before ATT resolves. Denial still allows non-personalised ads; no follow-up screen.
- Then the next level fades in. Neither step stacks with a Sheet or a Toast.
- If the app is killed or a form errors: that step stays unresolved, ads stay uninitialised (or, on iOS, unrequested); the step is retried on the next Level complete. Rewarded offers show their no-ad state (`#flow-rewarded` step 4) until then; because of the slot constraint above, no ad offer exists yet in normal play.
- Later launches: consent info is refreshed silently at boot (FR-CONSENT-01); if UMP reports the form is required again, it is shown at the next Level complete, never at boot.
- Analytics before the consent decision is queued locally (FR-CONSENT-02); no UI.
- Settings > Privacy options opens the UMP privacy options form (row shown only when UMP requires it, FR-CONSENT-03).

### Flow: returning user
- Boot -> Home if `slot >= unlocks.journey_slot`, else straight to the next level.
- No popups on Home. Pending results (restored purchase, backup restore) appear as one `Toast` each.
- Play on Home always continues the next campaign slot (resumes an in-progress level if the save contains one; save content owned by `ARCHITECTURE.md`).

### Flow: level loop
1. Level appears; wheel input is enabled immediately and stays responsive during letter flight.
2. Swipe -> `word_attempted` -> `BoardState.evaluate()` -> feedback per `#feedback-matrix`. Shuffle any time (free); Hint/Reveal via `HintButton` (`#flow-stuck-player`).
3. Last level word released -> next level preload starts -> `#flow-level-complete`.

### Flow: level complete
1. Wave on the grid, `level_complete` cue (<= `Motion.CELEBRATE`).
2. Level complete layer: level number (`DISPLAY`), stars earned, coin reward with count-up into the pill, postcard ProgressBar (from `journey_slot`), bonus chest opening if the meter is full (RewardBurst here, never mid-level).
3. One `PrimaryButton` "Continue". Optional `SecondaryButton` "x2 coins" with ad badge (from `double_reward_slot`; still offered with Remove Forced Ads, because rewarded ads are always opt-in).
4. Continue -> UMP or ATT step if due (`#flow-consent-and-att`) -> interstitial if `ad_policy` allows -> next level. If the location's postcard just completed: Location postcard screen first, then Continue leads to the next level.

### Flow: stuck player
- Trigger (config `hint.offer_idle_seconds`, default 45; `hint.offer_invalid_streak`, default 5): no new word for that long, or that many INVALID attempts in a row.
- Offer: `HintButton` enters highlighted state (max 3 pulses) and an inline `CAPTION` label "Need a hint?" appears next to it for `TOAST_HOLD`. No popup, no sheet opens by itself. At most once per level.
- Tap HintButton with count > 0 or enough coins: reveal immediately (`Economy.spend` happens in the service; price shown on the button beforehand).
- Tap with no count and not enough coins: Hint options Sheet: "Watch an ad for a free hint" (SecondaryButton with ad badge), "Get coins" (opens Shop content in the same Sheet), TextButton "Not now".
- Phase 1: hint is free and unlimited; no offer logic.

### Flow: interstitial placement
- Only between campaign levels (never after a daily puzzle): after Continue on Level complete, after any consent step, before the next level.
- Decision: `ad_policy.should_show_interstitial(state, config, now)`; never before `ads.interstitial.first_slot`, never at session start, never right after a purchase, never with Remove Forced Ads.
- Not loaded / fails: skip silently, go to the next level. No countdown text, no "ad in 3 s" banners.
- After the ad closes: next level is already prepared; it appears with a normal transition.

### Flow: rewarded
1. Player taps an ad-badged action (hint options, x2 coins, free coins in the Shop). Button -> loading; Sheet -> busy.
2. Ad shown -> reward granted **only** in the reward-earned callback -> Toast success + RewardBurst at the target (coins pill or HintButton).
3. Closed early: Toast "Ad not finished, no reward". Button back to normal.
4. No fill / offline / consent unresolved: the button is shown disabled with `CAPTION` "No ad available right now"; the non-ad alternative stays enabled. Never a dead button without explanation. Retry happens on the next opening, not by polling.
5. App backgrounded during the ad: state resolved by the adapter callback when the app resumes.

### Flow: purchase
Shop Sheet states:

| State | UI |
|---|---|
| loading prices | product Cards show skeleton price; buttons disabled |
| store unavailable / offline | `StatePanel(offline)` inside the Sheet with "Try again" |
| ready | Cards with localised store prices; Remove Forced Ads Card shows "Owned" (disabled) if entitled |
| pending | tapped product button -> loading; Sheet busy (not dismissible) until the store sheet returns |
| success | Sheet becomes dismissible, RewardBurst on the Card, coin count-up into pill or "Owned" state, Toast "Thank you" |
| deferred (Ask to Buy / Play pending) | Card shows "Waiting for approval"; grant happens later (boot or resume) with a Toast |
| failed | inline error `CAPTION` under the Card + "Try again"; no auto retry |
| cancelled | silently back to ready |
| restore | Settings and Shop (iOS): `TextButton` "Restore purchases" -> loading -> Toast "Purchases restored" or "Nothing to restore" or error |

Unfinished transactions are processed at boot (ARCHITECTURE IAP flow); the player sees only a Toast on Home or Level.

### Flow: offline and errors
- The game is fully playable offline. Offline only affects: rewarded ads (no-ad state), Shop (StatePanel offline), remote config (cached/default silently). No global "you are offline" banner.
- Content pack fails to load: full-screen `StatePanel(error)` "Something went wrong" with "Try again" and "Back to Home"; analytics event; never a crash loop.
- Save corrupted, backup restored: one Toast on the first screen "Progress restored from backup".
- Save lost (no backup): one-time `StatePanel` explaining progress could not be loaded, with "Restore purchases" as the action, then normal first launch.

## Screen specs

Format (from design pass 10 §7): `screen`, `scaffold`, `body`, `bottom`, `states`, `spacing`. Only components from `#components`; strings are translation keys; numbers are tokens.

### Level (P1 provisional)
```yaml
screen: level            # phase P1
scaffold: { top_bar: [Text(key: level.hud.level_n, style: Type.SUBTITLE), Spacer, IconButton(debug, debug_builds_only)] }
body:
  - BoardView(level: current_level)              # grid area, flex
  - Text(key: level.hud.bonus_count, style: Type.CAPTION)   # plain counter, no BonusMeter yet
  - WordPreview()
  - HBox: [IconButton(shuffle), Spacer, IconButton(hint)]    # hint free, unlimited
  - LetterWheelView(letters: current_level.letters)
states:
  complete: "minimal Level complete layer: Text(level.complete.title), PrimaryButton(level.complete.continue)"
spacing: Space.M between body items; layout per DESIGN.md#level-screen-geometry
```

### Level (P2 final)
```yaml
screen: level            # phase P2
scaffold:
  top_bar: [IconButton(home, from: unlocks.journey_slot), Text(key: level.hud.level_n), Spacer, CurrencyPill(coins, from: unlocks.hint_slot), IconButton(settings)]
  background: location art (dimmed) or BG
body:
  - BoardView(level: current_level)
  - HBox: [BonusMeter(from: unlocks.bonus_meter_slot), Spacer]
  - WordPreview()
  - Overlay(wheel area):
      - LetterWheelView(letters)
      - corner_bottom_left: IconButton(shuffle, from: unlocks.shuffle_slot)
      - corner_bottom_right: HintButton(hint, from: unlocks.hint_slot)
      - corner_top_right: HintButton(reveal, from: unlocks.reveal_slot)
      - TutorialHand(points: target word tile centres)      # slot 1 only
      # one control per corner, never stacked; no button rect may intersect a tile hit circle
states:
  first_level: "slot 1: only BoardView, WordPreview, LetterWheelView and Text(level.hud.level_n); TutorialHand + Text(level.tutorial.connect, Type.CAPTION) until the first word; settings IconButton hidden on slot 1 only"
  stuck: "HintButton(hint) highlighted + inline label level.hint.offer (DESIGN.md#flow-stuck-player)"
  animating: "LetterWheelView locked only during shuffle; HintButton disabled during reveal"
  coach_mark: "target control highlighted + inline Text(onboarding.coach.<feature>, Type.CAPTION) (DESIGN.md#feature-unlock-gating)"
  landmark: "P3: Badge(info, text: level.hud.landmark) beside the level number + location art at full strength; otherwise identical (DESIGN.md#level-landmark-p3)"
  complete: "Level complete layer (below)"
spacing: Space.M; Space.S in COMPACT
```

### Level complete
```yaml
screen: level_complete          # layer inside Level
body:
  - Text(key: level.complete.title, style: Type.TITLE)
  - Text(value: level_number, style: Type.DISPLAY)
  - HBox: [CurrencyPill(stars, value: stars_earned), CurrencyPill(coins, value: reward)]  # count-up
  - LocationPostcard(size: thumb) + ProgressBar(postcard_progress)   # from journey_slot
  - RewardBurst(chest)                                              # only if bonus chest full
  - PrimaryButton(text: level.complete.continue, action: continue_flow)
  - SecondaryButton(text: level.complete.double, badge: ad, from: unlocks.double_reward_slot)
states:
  rewarded_loading: "SecondaryButton loading"
  rewarded_unavailable: "SecondaryButton disabled + Text(level.complete.no_ad, Type.CAPTION)"
  doubled: "SecondaryButton hidden, coin count-up to doubled value"
  postcard_complete: "LocationPostcard complete state; Continue opens Location postcard"
spacing: Space.L between items; content vertically centred
```

### Home
```yaml
screen: home
scaffold: { top_bar: [CurrencyPill(coins), Spacer, IconButton(settings)], background: current location art }
body:
  - Text(key: location.<id>.name, style: Type.TITLE)
  - LocationPostcard(size: full, progress: location.pieces_revealed / location.pieces_total)
  - PrimaryButton(text: home.main.play, sublabel: home.main.level_n, action: Nav.level(next_slot))
bottom: [NavTab(journey), NavTab(daily, P3), NavTab(collection, P3)]
states:
  daily_locked: "NavTab(daily) locked, label home.nav.unlocks_at_level (P3)"
  pending_toast: "one Toast for restored purchase / backup restore"
spacing: Space.L between body items
```

### Journey (1 region)
```yaml
screen: journey
scaffold: { top_bar: [IconButton(back), Text(key: journey.region.<id>.name), Spacer, CurrencyPill(stars)] }
body:
  - VBox(scroll): for each location in region
      - Card(media: LocationPostcard(thumb), title: location.<id>.name, body: ProgressBar(pieces), state: locked|current|complete)
states:
  locked: "Card disabled + Badge(lock) + Text(journey.location.unlocks_at_level)"
  current: "Card highlighted; tap -> Location postcard"
  region_complete: "Text(journey.region.complete) + Badge; next region teaser hidden in P2"
spacing: Space.M between cards
```

### Location postcard
```yaml
screen: location_postcard
scaffold: { top_bar: [IconButton(back), Spacer, CurrencyPill(stars)] }
body:
  - LocationPostcard(size: full)
  - Text(key: location.<id>.name, style: Type.TITLE)
  - Text(key: location.<id>.fact, style: Type.BODY)      # one short fact line
  - PrimaryButton(text: postcard.main.continue, action: Nav.level(next_slot))
states:
  revealing: "on arrival from Level complete: newest piece animates in + RewardBurst(postcard_piece)"
  complete: "stamp on postcard + Text(postcard.main.complete)"
spacing: Space.L
```

### Settings
```yaml
screen: settings
scaffold: { top_bar: [IconButton(back), Text(key: settings.main.title)] }
body (VBox scroll, sections with Text(Type.CAPTION) headers):
  - sound:     [ListRow(settings.sound.effects, Slider), ListRow(settings.sound.music, Slider), ListRow(settings.sound.haptics, Toggle)]
  - display:   [ListRow(settings.display.reduced_motion, Toggle), ListRow(settings.display.high_contrast, Toggle), ListRow(settings.display.text_size, value) -> Sheet(options)]
  - language:  [ListRow(settings.language.row, trailing: value) -> Sheet(options)]
  - purchases: [ListRow(settings.purchases.remove_forced_ads) -> Shop sheet, ListRow(settings.purchases.restore)]
  - privacy:   [ListRow(settings.privacy.options, only if UMP requires), ListRow(settings.privacy.policy, opens browser)]
  - about:     [ListRow(settings.about.licences, opens licences screen: Godot licence + third-party, SDK, font, icon, audio and dictionary notices, FR-SET-03), ListRow(settings.about.support, subtitle: short install id; opens mail with install_id prefilled), Text(version + short install id, Type.CAPTION)]
states:
  remove_forced_ads_owned: "ListRow shows value settings.purchases.owned, disabled"
  restoring: "restore row loading; Toast on result"
  language_changed: "UI and content switch together and reload in place; only languages whose content ships are listed (PRODUCT.md FR-LOC-01, FR-SET-02)"
spacing: Space.S between rows, Space.L between sections
```

### Shop sheet
```yaml
screen: shop                     # Sheet content
sheet: { title: shop.sheet.title, trailing: CurrencyPill(coins) }
body:
  - Card(title: shop.remove_forced_ads.title, body: Text(shop.remove_forced_ads.body), action: PrimaryButton(price))   # nc.remove_forced_ads.v1
  - Card(title: shop.coins_pack.title, body: Text(amount), action: SecondaryButton(price))                              # c.coins_s.v1
  - Card(title: shop.free_coins.title, body: Text(shop.free_coins.body), action: SecondaryButton(text: shop.free_coins.watch, badge: ad))   # rewarded, ads.rewarded.shop_coins.daily_cap
  - TextButton(shop.sheet.restore)              # iOS only (Settings has Restore on both platforms, PRODUCT.md FR-IAP-06)
states:
  purchase: "see DESIGN.md#flow-purchase (loading, offline, pending, success, deferred, failed, cancelled, owned)"
  free_coins_capped: "SecondaryButton disabled + Text(shop.free_coins.capped, Type.CAPTION)"
  free_coins_unavailable: "per DESIGN.md#flow-rewarded step 4"
note: "one PrimaryButton: Remove Forced Ads when not owned; when owned, its Card shows Owned and the coin pack becomes Primary. P3 adds Cards for c.coins_m.v1, c.coins_l.v1 and c.starter_pack.v1 (starter pack Card hidden after its one purchase), all SecondaryButtons (FR-IAP-09)"
spacing: Space.M
```

### Daily calendar (P3)
```yaml
screen: daily            # phase P3
scaffold: { top_bar: [IconButton(back), Text(key: daily.main.title), Spacer, StreakFlame(days)] }
body:
  - Text(key: daily.main.month_name, style: Type.SUBTITLE)
  - Grid(7 columns): CalendarDay(day, state) for each day of month
  - Card(title: daily.main.today, body: Text(daily.main.reward_preview))
  - PrimaryButton(text: daily.main.play_today, action: Nav.level(daily: today))
states:
  today_done: "PrimaryButton disabled with label daily.main.come_back_tomorrow; today CalendarDay done"
  streak_at_risk: "StreakFlame at_risk + Text(daily.streak.at_risk, Type.CAPTION)"
  freeze_used: "CalendarDay frozen for the missed day + Toast once"
  streak_repairable: "within streak.repair.window_hours of a break: Card(daily.streak.repair) with SecondaryButton(badge: ad) (FR-STREAK-04)"
  milestone: "reward CalendarDay; reward granted on Level complete of the daily puzzle"
spacing: Space.M
```

### Journey (multi-region, P3)
```yaml
screen: journey          # phase P3; replaces the P2 single-region body
scaffold: { top_bar: [IconButton(back), Text(key: journey.main.title), Spacer, CurrencyPill(stars)] }
body:
  - VBox(scroll, opens scrolled to the current region): for each region in manifest order
      - Text(key: journey.region.<id>.name, style: Type.SUBTITLE) + Text(journey.region.progress, value: "N / M", Type.CAPTION)
      - VBox: Card(media: LocationPostcard(thumb), title: location.<id>.name, body: ProgressBar(pieces), state: locked|current|complete) per location
states:
  region_locked: "region header with Badge(lock) + Text(journey.region.unlocks_after, Type.CAPTION); its location Cards hidden (only the next locked region is shown as a teaser)"
  region_complete: "region header with Badge(info, journey.region.complete); Cards collapsed to one row of LocationPostcard thumbs"
  complete_location_tap: "opens Location postcard (view only; completed levels are not replayable, PRODUCT.md FR-PROG-06)"
spacing: Space.L between regions, Space.M between cards
```

### Level landmark (P3)
Landmark levels (PRODUCT.md FR-META-07) use the normal Level screen with no new components:
- Before the level: the Level complete layer of the previous slot shows `Text(level.complete.next_landmark, Type.CAPTION)` above Continue. No extra screen.
- During the level: `Badge(info, text: level.hud.landmark)` next to the level number in the TopBar; background is the location art at full strength instead of dimmed. Wheel up to 8 letters (`#gallery-scene` covers it); the grid follows `#level-screen-geometry` unchanged.
- On completion: same Level complete layer; `RewardBurst(postcard_piece)` if the landmark reveals a piece. The following "breather" level has no special UI.

### Collection (P3)
```yaml
screen: collection       # phase P3, NavTab(collection)
scaffold: { top_bar: [IconButton(back), Text(key: collection.main.title)] }
body:
  - Text(key: collection.section.locations, style: Type.CAPTION)
  - Grid(2 columns, scroll): LocationPostcard(size: thumb) for each location postcard, earned first
  - Text(key: collection.section.monthly, style: Type.CAPTION)
  - Grid(2 columns): LocationPostcard(size: thumb) for each monthly calendar postcard (FR-DAILY-04)
states:
  empty: "StatePanel(empty) with action collection.empty.play -> Nav.level(next_slot)"
  locked_item: "LocationPostcard locked state + Text(month or location name, Type.CAPTION); never hidden, so the player sees what can be earned"
  item_tap: "earned item opens Location postcard (view only); locked item does nothing"
spacing: Space.M grid gap, Space.L between sections
```

### Home end of content (P3)
```yaml
screen: home             # state of Home, PRODUCT.md FR-PROG-07
when: next_slot > last shipped slot
body:
  - Text(key: location.<id>.name, style: Type.TITLE)            # last location, complete
  - LocationPostcard(size: full, state: complete)
  - StatePanel(empty, title: home.end.title, body: home.end.more_levels_coming)
  - PrimaryButton(text: daily.main.play_today, action: Nav.daily)  # daily stays available
states:
  daily_done: "PrimaryButton replaced by Text(daily.main.come_back_tomorrow, Type.BODY); no Play button that leads nowhere"
  new_levels_arrived: "after an update adds slots, Home returns to the normal state; no popup, one Toast home.end.new_levels"
spacing: Space.L
```

## Copy and tone

- Short, warm, calm. Second person, present tense. No exclamation chains, no urgency ("Hurry!", "Last chance").
- Polish first, written by a native speaker (Chris approves); EN second; DE later. Keys are English.
- Polish: avoid gendered past-tense forms addressed to the player ("Utknąłeś/Utknęłaś"); use neutral phrasing ("Potrzebna podpowiedź?", "Poziom ukończony").
- No plural-dependent sentences (Polish has three plural forms, CSV keys do not handle plurals): use "number + icon" or "Label: N".
- Never blame: the dictionary can be wrong, so invalid copy says "not in our word list", not "wrong".
- Name products honestly: the IAP is always "Remove Forced Ads" / "Usuń wymuszone reklamy", never "Remove Ads", because rewarded ads stay available (PRODUCT.md FR-ADS-07).

| Key | PL | EN | DE |
|---|---|---|---|
| `level.feedback.bonus` | Słowo bonusowe | Bonus word | Bonuswort |
| `level.feedback.already_found` | Już znalezione | Already found | Schon gefunden |
| `level.feedback.invalid` | Tego słowa nie ma na naszej liście | Not in our word list | Nicht in unserer Liste |
| `level.hint.offer` | Potrzebna podpowiedź? | Need a hint? | Ein Tipp gefällig? |
| `level.hint.sheet_watch_ad` | Obejrzyj reklamę i odkryj literę | Watch an ad to reveal a letter | Werbung ansehen, Buchstaben aufdecken |
| `level.complete.continue` | Dalej | Continue | Weiter |
| `ads.rewarded.unavailable` | Brak reklamy w tej chwili | No ad available right now | Gerade keine Werbung verfügbar |
| `shop.remove_forced_ads.title` | Usuń wymuszone reklamy | Remove Forced Ads | Erzwungene Werbung entfernen |
| `shop.remove_forced_ads.body` | Koniec reklam między poziomami. Reklamy za nagrody oglądasz tylko wtedy, gdy chcesz. | No more ads between levels. Reward ads stay your choice. | Keine Werbung mehr zwischen Levels. Werbung für Belohnungen bleibt freiwillig. |
| `shop.free_coins.capped` | Na dziś to wszystko. Wróć jutro. | That's all for today. Come back tomorrow. | Das war's für heute. Komm morgen wieder. |
| `home.end.more_levels_coming` | Nowe poziomy wkrótce. Zagraj w zagadkę dnia. | More levels are coming soon. Try the daily puzzle. | Neue Level kommen bald. Spiel das Tagesrätsel. |

Translation keys: `area.screen.element` in lowercase snake case, e.g. `level.hud.level_n`, `shop.sheet.restore`, `settings.display.text_size`. `area` matches the CSV file (`game/locale/<area>.csv`); content-derived names use ids (`location.<id>.name`). Placeholders use Godot `{name}` format (`"Poziom {n}"`). Keys are never reused for a different meaning.

## Gallery and review

### Gallery scene
`game/ui/gallery/gallery.tscn` (runnable on desktop and device, excluded from release export) shows:
- every component in every state listed in `#components`, labelled with component and state names;
- switches: layout class (resizes the preview viewport to 1080x1920 COMPACT, 1080x2340 REGULAR, 1440x1920 TABLET), language PL / EN / PSEUDO (Godot pseudolocalization: `internationalization/pseudolocalization/use_pseudolocalization`, expansion ratio 0.35, accents on) / DE (from P3), contrast default / HC, text size 100 / 115 / 130 %, reduced motion on/off, fake safe-area insets on/off;
- sample strings: PL `ZAŻÓŁĆ GĘŚLĄ JAŹŃ` and `Przywróć zakupy`; DE (from P3) `ÄÖÜ ẞ äöüß`, `Einkäufe wiederherstellen`, `Erzwungene Werbung entfernen`; EN baseline; numbers `0`, `9 999`, `99 999` in `Type.NUMERIC`; an 8-letter wheel (landmark maximum, PRODUCT.md FR-WHEEL-09) and the largest supported grid;
- a motion page that replays each `#level-motion` row on demand.

### PR screenshot rules
- `UI: low`: gallery screenshot of the changed component/state (REGULAR, PL).
- `UI: med`: gallery screenshots in COMPACT, REGULAR and TABLET; PL plus PSEUDO for any text change (PL plus DE once DE strings exist, P3).
- `UI: high`: as med + device screenshots (reference devices) by Chris + the mockup side by side.
- Gallery screenshots come from the CI gallery job (rendered headless, attached as a PR artifact) once it exists; an executor without a runtime never supplies them by hand. Device screenshots stay Chris's.
- Screenshots are attached in the PR "Screenshots" section, named `<screen|component>_<class>_<lang>_<state>.png`. Accepted mockups and reference screenshots live in `docs/design/`.

### Design review checklist
1. Only catalog components; no new widget created inside a screen task (R-UI-1).
2. No raw colours, sizes or durations (R-UI-3); theme not hand-edited (R-UI-5).
3. One PrimaryButton per screen; no popup where a Sheet or Toast fits.
4. Safe area respected on the notch device; nothing under the home indicator.
5. Works in COMPACT, REGULAR, TABLET; grid fits without scrolling.
6. PL and PSEUDO strings (DE from P3) fit at 130 % text size; no truncation of button labels.
7. Every state has a non-colour cue; HC variant readable.
8. Every tappable >= `Touch.MIN_TARGET`; IconButtons have `a11y_label_key`.
9. Motion uses tokens and `Tokens.dur()`; reduced motion behaves per mapping.
10. Strings are translation keys following `area.screen.element`.
11. Ad actions carry the ad badge; no dead buttons (disabled states explain why).
12. Matches the accepted mockup; deviations listed under "Deviations / concerns".
13. No button rect intersects any wheel tile hit circle in COMPACT, REGULAR or TABLET (gallery assertion on the Level screen).
