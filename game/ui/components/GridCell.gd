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
		_cancel_feedback()
		state = value
		_base_state = value
		queue_redraw()

var _style: StyleBoxFlat = StyleBoxFlat.new()
var _feedback: Tween
var _base_state: State = State.EMPTY
var _letter_alpha: float = 1.0:
	set(value):
		_letter_alpha = value
		queue_redraw()


## @api Reveal feedback; logical state is available immediately.
func reveal(hinted: bool) -> void:
	state = State.HINTED if hinted else State.FILLED
	if Tokens.reduced_motion or not is_inside_tree():
		return
	pivot_offset = size / 2.0
	scale = Vector2.ONE / Tokens.Layout.TILE_SELECTED_SCALE
	_letter_alpha = 0.0
	_feedback = create_tween().set_parallel(true)
	_feedback.tween_property(self, "_letter_alpha", 1.0, Tokens.dur(Tokens.Motion.FAST))
	(
		_feedback
		. tween_property(self, "scale", Vector2.ONE, Tokens.dur(Tokens.Motion.BASE))
		. set_trans(Tokens.Ease.SPRING.x)
		. set_ease(Tokens.Ease.SPRING.y)
	)


## @api Temporary highlight, preserving filled/hinted state through repeated calls.
func highlight(delay: float = 0.0) -> void:
	var previous: State = _base_state
	state = previous
	if previous == State.EMPTY or Tokens.reduced_motion or not is_inside_tree():
		return
	# Preserve the underlying state while showing the temporary highlight.
	_set_highlight()
	pivot_offset = size / 2.0
	_feedback = create_tween()
	_feedback.tween_interval(delay)
	(
		_feedback
		. tween_property(
			self,
			"scale",
			Vector2.ONE * Tokens.Layout.TILE_SELECTED_SCALE,
			Tokens.dur(Tokens.Motion.FAST)
		)
		. set_trans(Tokens.Ease.OUT.x)
		. set_ease(Tokens.Ease.OUT.y)
	)
	_feedback.tween_property(self, "scale", Vector2.ONE, Tokens.dur(Tokens.Motion.FAST))
	_feedback.tween_callback(_finish_highlight.bind(previous))


func _set_highlight() -> void:
	var previous: State = _base_state
	state = State.HIGHLIGHTED
	_base_state = previous


func _finish_highlight(previous: State) -> void:
	_feedback = null
	state = previous


func _cancel_feedback() -> void:
	if _feedback != null and _feedback.is_valid():
		_feedback.kill()
	_feedback = null
	scale = Vector2.ONE
	_letter_alpha = 1.0


func _exit_tree() -> void:
	state = _base_state


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
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
		Color(Tokens.Palette.TEXT, _letter_alpha)
	)
	if state == State.HINTED:
		var radius: float = side * Tokens.Layout.HINT_DOT_RATIO
		draw_circle(Vector2(size.x / 2.0, size.y - radius * 2.0), radius, Tokens.Palette.TEXT)
