class_name GridCell
extends Control
## @api Passive crossword cell. BoardView owns geometry; BoardState owns gameplay.

enum State { EMPTY, HINTED, FILLED, HIGHLIGHTED }

var letter: String = "":
	set(value):
		letter = value
		queue_redraw()
var state: State = State.EMPTY:
	set(value):
		state = value
		queue_redraw()

var _style: StyleBoxFlat = StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if side <= 0:
		return
	var highlighted: bool = state == State.HIGHLIGHTED
	_style.bg_color = Tokens.Palette.CELL_EMPTY
	if state == State.HINTED:
		_style.bg_color = Tokens.Palette.CELL_HINTED
	elif state != State.EMPTY:
		_style.bg_color = Tokens.Palette.CELL_FILLED
	_style.border_color = Tokens.Palette.PRIMARY if highlighted else Tokens.Palette.STROKE
	# A highlighted inset outline remains visible without relying on colour alone.
	_style.set_border_width_all(
		(
			int(side * Tokens.Layout.HINT_DOT_RATIO)
			if highlighted
			else ceili(get_theme_default_base_scale())
		)
	)
	_style.set_corner_radius_all(int(side * Tokens.Radius.CELL_RATIO))
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	if state == State.EMPTY:
		return
	var font: Font = get_theme_default_font()
	var font_size: int = int(side * Tokens.Type.CELL_LETTER_RATIO)
	if font_size <= 0:
		return
	var width: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(
		font,
		size / 2.0 + Vector2(-width / 2.0, baseline),
		letter,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Tokens.Palette.TEXT
	)
	if state == State.HINTED:
		var radius: float = side * Tokens.Layout.HINT_DOT_RATIO
		draw_circle(Vector2(size.x / 2.0, size.y - radius * 2.0), radius, Tokens.Palette.TEXT)
