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
var _motion_speed: float = 1.0
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
	set_process(true)
	_feedback = create_tween().set_speed_scale(_motion_speed).set_parallel(true)
	_feedback.tween_property(self, "_letter_alpha", 1.0, Tokens.dur(Tokens.Motion.FAST))
	(
		_feedback
		. tween_property(self, "scale", Vector2.ONE, Tokens.dur(Tokens.Motion.BASE))
		. set_trans(Tokens.Ease.SPRING.x)
		. set_ease(Tokens.Ease.SPRING.y)
	)

	_feedback.chain().tween_callback(finish_motion)


## @api Temporary highlight, preserving filled/hinted state through repeated calls.
func highlight(delay: float = 0.0) -> void:
	var previous: State = _base_state
	state = previous
	if previous == State.EMPTY or Tokens.reduced_motion or not is_inside_tree():
		return
	# Preserve the underlying state while showing the temporary highlight.
	_set_highlight()
	pivot_offset = size / 2.0
	set_process(true)
	_feedback = create_tween().set_speed_scale(_motion_speed)
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
	set_process(false)
	if _feedback != null and _feedback.is_valid():
		_feedback.kill()
	_feedback = null
	scale = Vector2.ONE
	_letter_alpha = 1.0
	modulate = Color.WHITE


func _exit_tree() -> void:
	state = _base_state


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
		queue_redraw()


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if side <= 0:
		return
	var highlighted: bool = state == State.HIGHLIGHTED
	_style.bg_color = get_theme_color(&"CELL_EMPTY", &"Palette")
	if state == State.HINTED:
		_style.bg_color = get_theme_color(&"CELL_HINTED", &"Palette")
	elif state != State.EMPTY:
		_style.bg_color = get_theme_color(&"CELL_FILLED", &"Palette")
	_style.border_color = (
		get_theme_color(&"PRIMARY", &"Palette")
		if highlighted
		else get_theme_color(&"STROKE", &"Palette")
	)
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
	var font: Font = get_theme_font(&"font", &"TileLetter")
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
		Color(get_theme_color(&"TEXT", &"Palette"), _letter_alpha)
	)
	if state == State.HINTED:
		var radius: float = side * Tokens.Layout.HINT_DOT_RATIO
		draw_circle(
			Vector2(size.x / 2.0, size.y - radius * 2.0),
			radius,
			get_theme_color(&"TEXT", &"Palette")
		)


## @api Commit visual fill now, while the pooled letter is still in flight.
func prepare_landing() -> void:
	state = State.FILLED
	_letter_alpha = 0.0


## @api Filled glyph lands with a bounded FAST scale pop.
func land() -> void:
	state = State.FILLED
	if Tokens.reduced_motion or not is_inside_tree():
		return
	_feedback = (
		create_tween()
		. set_speed_scale(_motion_speed)
		. set_trans(Tokens.Ease.SPRING.x)
		. set_ease(Tokens.Ease.SPRING.y)
	)
	var half_fast: float = Tokens.dur(Tokens.Motion.FAST) / 2
	_feedback.tween_property(self, "scale", Vector2.ONE * Tokens.Layout.LANDING_SCALE, half_fast)
	_feedback.tween_property(self, "scale", Vector2.ONE, half_fast)
	_feedback.tween_callback(finish_motion)
	set_process(true)


## @api Brightness flash preserves the underlying revealed state.
func flash() -> void:
	finish_motion()
	if state == State.EMPTY or Tokens.reduced_motion or not is_inside_tree():
		return
	_feedback = create_tween().set_speed_scale(_motion_speed).set_trans(Tokens.Ease.OUT.x).set_ease(
		Tokens.Ease.OUT.y
	)
	var bright: Color = Color.WHITE * Tokens.Layout.WORD_FLASH_SCALE
	bright.a = 1
	var half_base: float = Tokens.dur(Tokens.Motion.BASE) / 2
	_feedback.tween_property(self, "modulate", bright, half_base)
	_feedback.tween_property(self, "modulate", Color.WHITE, half_base)
	_feedback.tween_callback(finish_motion)
	set_process(true)


## @api Settle the logical state without introducing any additional effect.
func finish_motion() -> void:
	state = _base_state
	modulate = Color.WHITE


func _process(_delta: float) -> void:
	if Tokens.reduced_motion:
		finish_motion()


## @api Reduced flight mapping: owned FAST fade in place, no scale motion.
func fade_filled() -> void:
	state = State.FILLED
	modulate.a = 0
	_feedback = create_tween().set_speed_scale(_motion_speed)
	_feedback.tween_property(self, "modulate:a", 1.0, Tokens.dur(Tokens.Motion.FAST))
	_feedback.tween_callback(finish_motion)


## @api Presentation-only timing scale for the bounded completion sequence.
func set_motion_speed(speed_value: float) -> Error:
	if not is_finite(speed_value) or speed_value <= 0:
		return ERR_INVALID_PARAMETER
	_motion_speed = speed_value
	if _feedback != null:
		_feedback.set_speed_scale(speed_value)
	return OK
