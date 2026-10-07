class_name LetterTile
extends Control
## @api Passive wheel tile; input belongs exclusively to LetterWheelView.

var letter: String = "":
	set(value):
		letter = value
		queue_redraw()
var index: int = -1
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0
	draw_circle(center, radius, Tokens.Palette.TILE_SELECTED if selected else Tokens.Palette.TILE)
	var font: Font = get_theme_default_font()
	var font_size: int = mini(Tokens.Type.TILE_LETTER, int(size.y * Tokens.Type.CELL_LETTER_RATIO))
	if font_size <= 0:
		return
	var width: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(
		font,
		center + Vector2(-width / 2.0, baseline),
		letter,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Tokens.Palette.ON_PRIMARY if selected else Tokens.Palette.TEXT
	)
