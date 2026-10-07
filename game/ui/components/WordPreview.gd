class_name WordPreview
extends Label
## @api Word text with translated shape cues and interruptible result motion.

var _kind: int = -1
var _cue: Label
var _copy: LevelCopy = LevelCopy.new()
var _tween: Tween
var _offset_x: float = 0.0:
	set(value):
		position.x += value - _offset_x
		_offset_x = value


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size.y = Tokens.Type.PREVIEW + Tokens.Type.CAPTION + Tokens.Space.M
	add_theme_font_size_override("font_size", Tokens.Type.PREVIEW)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue = Label.new()
	_cue.name = "Feedback"
	_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue.add_theme_font_size_override("font_size", Tokens.Type.CAPTION)
	add_child(_cue)
	resized.connect(_layout_cue)
	_copy.register()
	_layout_cue()
	_refresh_cue()


## @api Show the word spelled by the active chain's original tile indices.
func set_building(word: String) -> void:
	_reset_motion()
	_kind = -1
	text = word
	_refresh_cue()


func clear() -> void:
	set_building("")


func show_result(result: AttemptResult) -> void:
	clear()
	if result == null or result.word.length() < LevelData.MIN_TILES:
		return
	_kind = result.kind
	text = result.word
	_refresh_cue()
	if Tokens.reduced_motion or not is_inside_tree():
		return
	_tween = create_tween().set_trans(Tokens.Ease.OUT.x).set_ease(Tokens.Ease.OUT.y)
	if _kind == AttemptResult.Kind.INVALID:
		_tween.tween_property(
			self, "_offset_x", float(Tokens.Layout.SHAKE_OFFSET), Tokens.dur(Tokens.Motion.FAST)
		)
		_tween.tween_property(self, "_offset_x", 0.0, Tokens.dur(Tokens.Motion.FAST))
	else:
		scale = Vector2.ONE * Tokens.Layout.TILE_SELECTED_SCALE
		_tween.tween_property(self, "scale", Vector2.ONE, Tokens.dur(Tokens.Motion.BASE))
	_tween.tween_interval(Tokens.dur(Tokens.Motion.TOAST_HOLD))
	_tween.tween_property(self, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.SLOW))
	_tween.tween_callback(_finish_feedback)


## @api -1 for empty/building, otherwise the current AttemptResult.Kind.
func feedback_kind() -> int:
	return _kind


func _refresh_cue() -> void:
	var color: Color = Tokens.Palette.TEXT
	var key: String = ""
	match _kind:
		AttemptResult.Kind.LEVEL:
			color = Tokens.Palette.PRIMARY
			key = "level.feedback.level"
		AttemptResult.Kind.BONUS:
			color = Tokens.Palette.BONUS
			key = "level.feedback.bonus"
		AttemptResult.Kind.ALREADY_FOUND:
			color = Tokens.Palette.TEXT_MUTED
			key = "level.feedback.already_found"
		AttemptResult.Kind.INVALID:
			color = Tokens.Palette.ERROR
			key = "level.feedback.invalid"
	add_theme_color_override("font_color", color)
	if is_instance_valid(_cue):
		_cue.text = tr(key) if not key.is_empty() else ""
		_cue.add_theme_color_override("font_color", color)


func _layout_cue() -> void:
	_reset_motion()
	if is_instance_valid(_cue):
		_cue.position = Vector2(0, Tokens.Type.PREVIEW + Tokens.Space.XS)
		_cue.size = Vector2(size.x, Tokens.Type.CAPTION + Tokens.Space.XS)
	pivot_offset = size / 2.0


func _finish_feedback() -> void:
	_tween = null
	clear()


func _reset_motion() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_offset_x = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_cue()


func _exit_tree() -> void:
	_reset_motion()
	if resized.is_connected(_layout_cue):
		resized.disconnect(_layout_cue)
	_copy.unregister()
