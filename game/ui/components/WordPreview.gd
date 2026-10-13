class_name WordPreview
extends Label
## @api Word text with translated shape cues and interruptible result motion.

signal bonus_arrived(target: Control)

var _bonus_ghost: Label
var _bonus_active: bool = false
var _bonus_target: Control
var _bonus_word: String = ""
var _target_motion: Tween
var _pulse_target: Control
var _target_scale: Vector2 = Vector2.ONE
var _target_pivot: Vector2 = Vector2.ZERO
var _layout_height: float = -1.0
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
	_bonus_ghost = Label.new()
	_bonus_ghost.name = "BonusFlight"
	_bonus_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus_ghost.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_bonus_ghost.theme_type_variation = &"Preview"
	_bonus_ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bonus_ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bonus_ghost.set_as_top_level(true)
	_bonus_ghost.visible = false
	add_child(_bonus_ghost)
	_refresh_theme()
	_layout_cue()
	_refresh_cue()
	set_process(false)


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
		_tween.set_parallel(true)
		_tint_main(get_theme_color(&"TEXT", &"Palette"))
		_tween.tween_method(_shake_invalid, 0.0, 1.0, Tokens.dur(Tokens.Motion.BASE))
		_tween.tween_method(
			_tint_main,
			get_theme_color(&"TEXT", &"Palette"),
			get_theme_color(&"ERROR", &"Palette"),
			Tokens.dur(Tokens.Motion.FAST)
		)
		_tween.chain().tween_property(self, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.FAST))
	elif _kind == AttemptResult.Kind.ALREADY_FOUND:
		_tween.tween_property(self, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.BASE))
	else:
		var half_fast: float = Tokens.dur(Tokens.Motion.FAST) / 2
		(
			_tween
			. tween_property(
				self, "scale", Vector2.ONE * Tokens.Layout.PREVIEW_VALID_SCALE, half_fast
			)
			. set_trans(Tokens.Ease.SPRING.x)
			. set_ease(Tokens.Ease.SPRING.y)
		)
		_tween.tween_property(self, "scale", Vector2.ONE, half_fast)
		_tween.tween_interval(Tokens.dur(Tokens.Motion.TOAST_HOLD))
		_tween.tween_property(self, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.SLOW))
	_tween.chain().tween_callback(_finish_feedback)
	set_process(true)


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
	var arrival: Control
	if (
		_layout_width != size.x
		or (
			_layout_height > 0
			and _layout_height != size.y
			and (
				_bonus_active
				or _target_motion != null
				or not is_equal_approx(size.y, custom_minimum_size.y)
			)
		)
	):
		arrival = _bonus_target if _bonus_active else null
		var word: String = _bonus_word
		_reset_motion()
		if _kind == AttemptResult.Kind.BONUS and not word.is_empty():
			text = word
			_refresh_cue()
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
	_layout_height = size.y
	_laying_out = false
	if _valid_target(arrival):
		bonus_arrived.emit(arrival)


func _finish_feedback() -> void:
	_tween = null
	clear()


func _reset_motion() -> void:
	set_process(false)
	_restore_target()
	_bonus_active = false
	_bonus_target = null
	_bonus_word = ""
	if _bonus_ghost != null:
		_bonus_ghost.visible = false
		_bonus_ghost.scale = Vector2.ONE
	if _tween != null:
		_tween.kill()
		_tween = null
	_offset_x = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if _updating_theme:
			return
		var arrival: Control = _bonus_target if _bonus_active else null
		var word: String = _bonus_word
		_reset_motion()
		if _kind == AttemptResult.Kind.BONUS and not word.is_empty():
			text = word
		_refresh_theme()
		_refresh_cue()
		if _valid_target(arrival):
			bonus_arrived.emit(arrival)
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_cue()


func _exit_tree() -> void:
	var word: String = _bonus_word
	_reset_motion()
	if _kind == AttemptResult.Kind.BONUS and not word.is_empty():
		text = word
	if resized.is_connected(_layout_cue):
		resized.disconnect(_layout_cue)
	if is_instance_valid(_cue) and _cue.minimum_size_changed.is_connected(_layout_cue):
		_cue.minimum_size_changed.disconnect(_layout_cue)
	_copy.unregister()


func _valid_target(target: Variant) -> bool:
	return (
		is_instance_valid(target)
		and target is Control
		and target != self
		and not is_ancestor_of(target)
		and target.is_inside_tree()
		and target.get_viewport() == get_viewport()
		and target.get_canvas() == get_canvas()
	)


## @api Passive bonus flight; arrival is a presentation notification only.
func fly_bonus(target: Control) -> Error:
	var word: String = text if not text.is_empty() else _bonus_word
	if (
		_kind != AttemptResult.Kind.BONUS
		or word.length() < LevelData.MIN_TILES
		or not _valid_target(target)
	):
		return ERR_INVALID_PARAMETER
	if not is_node_ready() or _bonus_ghost == null:
		return ERR_UNCONFIGURED
	_reset_motion()
	_bonus_target = target
	_bonus_word = word
	if Tokens.reduced_motion:
		text = word
		bonus_arrived.emit(target)
		return OK
	_bonus_active = true
	_bonus_ghost.text = word
	_bonus_ghost.add_theme_color_override("font_color", get_theme_color(&"BONUS", &"Palette"))
	var font: Font = get_theme_font(&"font", &"Preview")
	_bonus_ghost.size = (
		font.get_string_size(
			word, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size(&"font_size", &"Preview")
		)
		+ Vector2.ONE * Tokens.Space.M
	)
	_bonus_ghost.pivot_offset = _bonus_ghost.size / 2
	_place_bonus_center(get_global_transform() * (size / 2))
	_bonus_ghost.visible = true
	text = ""
	_refresh_cue()
	_tween = create_tween().set_parallel(true).set_trans(Tokens.Ease.IN_OUT.x).set_ease(
		Tokens.Ease.IN_OUT.y
	)
	_tween.tween_method(
		_place_bonus_center,
		get_global_transform() * (size / 2),
		target.get_global_transform() * (target.size / 2),
		Tokens.dur(Tokens.Motion.BASE)
	)
	_tween.tween_property(
		_bonus_ghost,
		"scale",
		Vector2.ONE * Tokens.Layout.BONUS_FLIGHT_SCALE,
		Tokens.dur(Tokens.Motion.BASE)
	)
	_tween.chain().tween_callback(_finish_bonus_flight)
	_tween.chain().tween_interval(Tokens.dur(Tokens.Motion.TOAST_HOLD))
	_tween.chain().tween_property(self, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.FAST))
	_tween.chain().tween_callback(_finish_feedback)
	set_process(true)
	return OK


func _place_bonus_center(center: Vector2) -> void:
	# Top-level position retains the centered pivot while scale changes.
	_bonus_ghost.position = center - _bonus_ghost.size / 2


func _finish_bonus_flight() -> void:
	if not _valid_target(_bonus_target):
		_settle_bonus(false)
		return
	_bonus_active = false
	_bonus_ghost.visible = false
	bonus_arrived.emit(_bonus_target)


## @api Already-found target pulse; meter retains ownership of its catalog presentation.
func pulse_already_target(target: Control) -> Error:
	if _kind != AttemptResult.Kind.ALREADY_FOUND or not _valid_target(target):
		return ERR_INVALID_PARAMETER
	_restore_target()
	if target is BonusMeter:
		return (target as BonusMeter).pulse_already()
	if Tokens.reduced_motion:
		return OK
	_pulse_target = target
	_target_scale = target.scale
	_target_pivot = target.pivot_offset
	target.pivot_offset = target.size / 2
	_target_motion = create_tween().set_trans(Tokens.Ease.IN_OUT.x).set_ease(Tokens.Ease.IN_OUT.y)
	var half_fast: float = Tokens.dur(Tokens.Motion.FAST) / 2
	for pulse: int in 2:
		_target_motion.tween_property(
			target, "scale", _target_scale * Tokens.Action.ALREADY_SCALE, half_fast
		)
		_target_motion.tween_property(target, "scale", _target_scale, half_fast)
	_target_motion.tween_callback(_restore_target)
	set_process(true)
	return OK


func _restore_target() -> void:
	if _target_motion != null:
		_target_motion.kill()
		_target_motion = null
	if is_instance_valid(_pulse_target):
		_pulse_target.scale = _target_scale
		_pulse_target.pivot_offset = _target_pivot
	_pulse_target = null


## @api Silent short-chain release fade, without any AttemptResult.
func fade_short() -> Error:
	if not is_inside_tree() or not is_node_ready():
		return ERR_UNCONFIGURED
	if _kind != -1 or text.length() < 1 or text.length() >= LevelData.MIN_TILES:
		return ERR_INVALID_PARAMETER
	_reset_motion()
	_tween = create_tween().set_trans(Tokens.Ease.IN.x).set_ease(Tokens.Ease.IN.y)
	_tween.tween_property(self, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.FAST))
	_tween.tween_callback(_finish_feedback)
	return OK


func _shake_invalid(progress_value: float) -> void:
	_offset_x = (
		sin(progress_value * TAU * Tokens.Layout.INVALID_CYCLES) * Tokens.Layout.SHAKE_OFFSET
	)


func _tint_main(color: Color) -> void:
	_updating_theme = true
	add_theme_color_override("font_color", color)
	_updating_theme = false


func _settle_bonus(complete: bool) -> void:
	var arrival: Control = _bonus_target if _bonus_active and complete else null
	var word: String = _bonus_word
	_reset_motion()
	if _kind == AttemptResult.Kind.BONUS and not word.is_empty():
		text = word
	_refresh_cue()
	if _valid_target(arrival):
		bonus_arrived.emit(arrival)


func _process(_delta: float) -> void:
	if Tokens.reduced_motion:
		_settle_bonus(true)
	elif _bonus_active and not _valid_target(_bonus_target):
		_settle_bonus(false)
	elif (
		_target_motion != null
		and (not is_instance_valid(_pulse_target) or not _pulse_target.is_inside_tree())
	):
		_restore_target()
