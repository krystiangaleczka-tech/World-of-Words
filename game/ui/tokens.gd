class_name Tokens
extends RefCounted
## @api Provisional P1 design constants; final accepted styling belongs to T-0206.

static var reduced_motion: bool = false


class Palette:
	const BG: Color = Color("#F6F1E7")
	const SURFACE: Color = Color("#FFFFFF")
	const SURFACE_ALT: Color = Color("#EDE5D6")
	const PRIMARY: Color = Color("#2F6F62")
	const ON_PRIMARY: Color = Color("#FFFFFF")
	const TEXT: Color = Color("#1F2A30")
	const TEXT_MUTED: Color = Color("#5E6A70")
	const SUCCESS: Color = Color("#2E8B57")
	const BONUS: Color = Color("#C8902E")
	const ERROR: Color = Color("#C0453A")
	const TILE: Color = Color("#FFFDF8")
	const TILE_SELECTED: Color = Color("#2F6F62")
	const LINE: Color = Color("#3E8C7C")
	const CELL_EMPTY: Color = Color("#E3DBCB")
	const CELL_FILLED: Color = Color("#FFFFFF")
	const CELL_HINTED: Color = Color("#F3E2B8")
	const COIN: Color = Color("#E0A526")
	const SCRIM: Color = Color("#1F2A3066")
	const STROKE: Color = Color("#D8CFBF")


class PaletteHC:
	const BG: Color = Color("#FFFFFF")
	const SURFACE: Color = Color("#FFFFFF")
	const SURFACE_ALT: Color = Color("#E6E6E6")
	const PRIMARY: Color = Color("#00473D")
	const ON_PRIMARY: Color = Color("#FFFFFF")
	const TEXT: Color = Color("#000000")
	const TEXT_MUTED: Color = Color("#333333")
	const SUCCESS: Color = Color("#1B5E20")
	const BONUS: Color = Color("#7A4F00")
	const ERROR: Color = Color("#9B1C12")
	const TILE: Color = Color("#FFFFFF")
	const TILE_SELECTED: Color = Color("#00473D")
	const LINE: Color = Color("#00473D")
	const CELL_EMPTY: Color = Color("#CFCFCF")
	const CELL_FILLED: Color = Color("#FFFFFF")
	const CELL_HINTED: Color = Color("#FFE08A")
	const COIN: Color = Color("#7A4F00")
	const SCRIM: Color = Color("#000000A0")
	const STROKE: Color = Color("#000000")


class Type:
	const DISPLAY: int = 88
	const TITLE: int = 60
	const SUBTITLE: int = 48
	const BODY: int = 42
	const LABEL: int = 40
	const CAPTION: int = 32
	const NUMERIC: int = 40
	const TILE_LETTER: int = 84
	const PREVIEW: int = 64
	const CELL_LETTER_RATIO: float = 0.62


class Space:
	const XS: int = 8
	const S: int = 16
	const M: int = 32
	const L: int = 48
	const XL: int = 64
	const XXL: int = 96


class Radius:
	const S: int = 16
	const M: int = 28
	const L: int = 44
	const FULL: int = 999
	const CELL_RATIO: float = 0.18


class Motion:
	const INSTANT: int = 0
	const FAST: int = 120
	const BASE: int = 240
	const SLOW: int = 420
	const STAGGER: int = 40
	const CELEBRATE: int = 1200
	const TOAST_HOLD: int = 1600
	const COUNT_UP_MAX: int = 900


class Touch:
	const MIN_TARGET: int = 144
	const TILE_HIT_RATIO: float = 1.35
	const DRAG_SLOP: int = 12


class Layout:
	const TABLET_MAX_ASPECT: float = 1.65
	const COMPACT_MAX_ASPECT: float = 1.95
	const MAX_CONTENT_WIDTH: int = 1080
	const TOP_BAR_H: int = 144
	const WHEEL_WIDTH_RATIO: float = 0.66
	const WHEEL_COMPACT_RATIO: float = 0.62
	const WHEEL_MIN: int = 560
	const WHEEL_MAX: int = 800
	const GRID_MIN_RATIO: float = 0.42
	const CELL_MIN: int = 64
	const CELL_MAX: int = 150
	const SHEET_MAX_RATIO: float = 0.85
	# Provisional P1 additions: ring/tile geometry, connector, selection and feedback cues.
	const WHEEL_RING_RATIO: float = 0.35
	const TILE_RADIUS_RATIO: float = 0.12
	const LINE_WIDTH: int = 18
	const TILE_SELECTED_SCALE: float = 1.12
	const HINT_DOT_RATIO: float = 0.06
	const SHAKE_OFFSET: int = 16


class Ease:
	const OUT: Vector2i = Vector2i(Tween.TRANS_CUBIC, Tween.EASE_OUT)
	const IN: Vector2i = Vector2i(Tween.TRANS_CUBIC, Tween.EASE_IN)
	const IN_OUT: Vector2i = Vector2i(Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	const SPRING: Vector2i = Vector2i(Tween.TRANS_BACK, Tween.EASE_OUT)


## @api Token milliseconds to seconds; long transitions are instant with reduced motion.
static func dur(milliseconds: int) -> float:
	if reduced_motion and milliseconds > Motion.FAST:
		return 0.0
	return maxf(milliseconds, 0) / 1000.0
