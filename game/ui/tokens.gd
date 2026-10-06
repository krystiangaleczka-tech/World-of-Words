class_name Tokens
extends RefCounted
## @api Minimal provisional DESIGN subset for Phase 0 diagnostics. Full contract remains T-0103.


class Palette:
	const BG: Color = Color("#F6F1E7")
	const PRIMARY: Color = Color("#2F6F62")
	const TEXT: Color = Color("#1F2A30")
	const TEXT_MUTED: Color = Color("#5E6A70")
	const ERROR: Color = Color("#C0453A")


class Type:
	const TITLE: int = 60
	const BODY: int = 42
	const LABEL: int = 40
	const CAPTION: int = 32


class Space:
	const S: int = 16
	const M: int = 32


class Touch:
	const MIN_TARGET: int = 144


class Layout:
	const TABLET_MAX_ASPECT: float = 1.65
	const COMPACT_MAX_ASPECT: float = 1.95
