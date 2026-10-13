class_name WordPreview
extends Label
## @api Word text with translated shape cues and interruptible result motion.

var _layout_width: float = -1.0
var _laying_out: bool = false
var _updating_theme: bool = false
var _kind: int = -1
var _cue: Label
var _copy: LevelCopy = LevelCopy.new()
var _bubble: StyleBoxFlat = StyleBoxFlat.new()
var _tween: Tween
var _offset_x: float = 0.0:
	set(value):
		position.x += value - _offset_x
		_offset_x = value


func _enter_tree() -> void:
	_copy.register()
	if _cue != null:
		if not _cue.minimum_size_changed.is_connected(_layout_cue):
			_cue.minimum_size_changed.connect(_layout_cue)
		if not resized.is_connected(_layout_cue):
			resized.connect(_layout_cue)
		_refresh_theme()
		_refresh_cue()


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	theme_type_variation = &"Preview"
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_theme_stylebox_override("normal", _bubble)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue = Label.new()
	_cue.name = "Feedback"
	_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue.theme_type_variation = &"Caption"
	_cue.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cue.minimum_size_changed.connect(_layout_cue)
	add_child(_cue)
	resized.connect(_layout_cue)
	_copy.register()
	_refresh_theme()
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
	if _updating_theme:
		return
	_updating_theme = true
	var color: Color = get_theme_color(&"TEXT", &"Palette")
	var key: String = ""
	match _kind:
		AttemptResult.Kind.LEVEL:
			color = get_theme_color(&"PRIMARY", &"Palette")
			key = "level.feedback.level"
		AttemptResult.Kind.BONUS:
			color = get_theme_color(&"BONUS", &"Palette")
			key = "level.feedback.bonus"
		AttemptResult.Kind.ALREADY_FOUND:
			color = get_theme_color(&"TEXT_MUTED", &"Palette")
			key = "level.feedback.already_found"
		AttemptResult.Kind.INVALID:
			color = get_theme_color(&"ERROR", &"Palette")
			key = "level.feedback.invalid"
	_bubble.bg_color = (
		get_theme_color(&"SURFACE", &"Palette") if not text.is_empty() else Color.TRANSPARENT
	)
	add_theme_color_override("font_color", color)
	if is_instance_valid(_cue):
		_cue.text = tr(key) if not key.is_empty() else ""
		_cue.add_theme_color_override("font_color", color)

	_updating_theme = false


func _refresh_theme() -> void:
	if _updating_theme:
		return
	_updating_theme = true
	_bubble.set_corner_radius_all(Tokens.Radius.FULL)
	_bubble.content_margin_left = Tokens.Space.S
	_bubble.content_margin_right = Tokens.Space.S
	custom_minimum_size.y = (
		get_theme_font_size(&"font_size", &"Preview")
		+ get_theme_font_size(&"font_size", &"Caption")
		+ Tokens.Space.M
	)
	_layout_cue()
	_updating_theme = false


func _layout_cue() -> void:
	if _laying_out:
		return
	_laying_out = true
	if _layout_width != size.x:
		_reset_motion()
		_layout_width = size.x
	var word_height: float = get_theme_font(&"font", &"Preview").get_height(
		get_theme_font_size(&"font_size", &"Preview")
	)
	if is_instance_valid(_cue):
		_cue.position = Vector2(0, word_height + Tokens.Space.XS)
		_cue.size.x = size.x
		_cue.size.y = _cue.get_minimum_size().y
		custom_minimum_size.y = word_height + _cue.size.y + Tokens.Space.M
	pivot_offset = size / 2.0
	_laying_out = false


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
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()
		_refresh_cue()
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_cue()


func _exit_tree() -> void:
	_reset_motion()
	if resized.is_connected(_layout_cue):
		resized.disconnect(_layout_cue)
	if is_instance_valid(_cue) and _cue.minimum_size_changed.is_connected(_layout_cue):
		_cue.minimum_size_changed.disconnect(_layout_cue)
	_copy.unregister()
