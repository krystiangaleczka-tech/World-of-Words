class_name ActionButton
extends Button
## @api Shared native action states. Callers own pressed intent and disabled availability.

@export var text_key: String = "":
	set(value):
		text_key = value
		_refresh_copy()
@export var sublabel_key: String = "":
	set(value):
		sublabel_key = value
		_refresh_copy()
@export var loading: bool = false:
	set(value):
		if loading == value:
			return
		loading = value
		if value:
			_was_disabled = disabled
			_saved_icon = icon
			icon = _spinner_texture()
			disabled = true
		else:
			icon = _saved_icon
			disabled = _was_disabled
		_sync_state()
@export var highlighted: bool = false:
	set(value):
		if highlighted == value:
			return
		highlighted = value
		_sync_state()

var _copy: LevelCopy = LevelCopy.new()
var _sublabel: Label
var _was_disabled: bool = false
var _saved_icon: Texture2D
var _motion: Tween
var _angle: float = 0
var _refreshing: bool = false
var _sublabel_height: float = 0


func _enter_tree() -> void:
	_copy.register()
	if _sublabel != null:
		_connect_signals()
		_refresh_copy()
		_refresh_theme()
		_sync_state()


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	clip_text = false
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2.ONE * Tokens.Touch.MIN_TARGET
	_sublabel = Label.new()
	_sublabel.name = "Sublabel"
	_sublabel.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_sublabel.theme_type_variation = &"Caption"
	_sublabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sublabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sublabel)
	_connect_signals()
	_refresh_copy()
	_refresh_theme()
	_sync_state()


## @api Compatibility alias: idempotent, restores the initial disabled value.
func set_busy(busy: bool) -> void:
	loading = busy


func _connect_signals() -> void:
	for connection: Array in [
		[resized, _layout_copy],
		[button_down, _press_down],
		[button_up, _press_up],
		[draw, _check_disabled],
		[_sublabel.minimum_size_changed, _layout_copy]
	]:
		if not (connection[0] as Signal).is_connected(connection[1]):
			(connection[0] as Signal).connect(connection[1])


func _refresh_copy() -> void:
	text = tr(text_key) if not text_key.is_empty() else ""
	# Native accessibility getters translate keys even with auto translation disabled.
	accessibility_name = text_key
	if _sublabel != null:
		_sublabel.text = tr(sublabel_key) if not sublabel_key.is_empty() else ""
		_sublabel.visible = not sublabel_key.is_empty()
		accessibility_description = sublabel_key
		_layout_copy()


func _layout_copy() -> void:
	if _sublabel == null or _refreshing:
		return
	pivot_offset = size / 2
	_sublabel.position.x = Tokens.Space.M
	_sublabel.size.x = maxf(size.x - Tokens.Space.M * 2, 1)
	var height: float = _sublabel.get_minimum_size().y if _sublabel.visible else 0.0
	_sublabel.size.y = height
	_sublabel.position.y = maxf(size.y - Tokens.Space.S - height, 0)
	if not is_equal_approx(height, _sublabel_height):
		_sublabel_height = height
		_refresh_theme()
	queue_redraw()


func _palette(key: StringName) -> Color:
	return get_theme_color(key, &"Palette")


func _kind() -> StringName:
	return &"primary"


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	_refreshing = true
	add_theme_font_size_override("font_size", get_theme_font_size(&"LABEL", &"Type"))
	add_theme_font_override("font", get_theme_font(&"LABEL", &"Type"))
	add_theme_constant_override("icon_max_width", Tokens.Space.L)
	add_theme_constant_override("h_separation", Tokens.Space.S)
	var primary: bool = _kind() == &"primary"
	var plain: bool = _kind() == &"text"
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_corner_radius_all(Tokens.Radius.FULL)
		style.content_margin_left = Tokens.Space.M + _ad_space()
		style.content_margin_right = Tokens.Space.M
		style.content_margin_top = Tokens.Space.S
		style.content_margin_bottom = Tokens.Space.S + _sublabel_height
		if _sublabel_height > 0:
			style.content_margin_bottom += Tokens.Space.XS
		style.bg_color = _palette(&"PRIMARY" if primary else &"SURFACE")
		if state == "disabled":
			style.bg_color = _palette(&"SURFACE_ALT")
		if plain or state == "focus":
			style.draw_center = false
		if not primary and not plain:
			style.set_border_width_all(Tokens.Action.OUTLINE_WIDTH)
			style.border_color = _palette(&"PRIMARY" if "pressed" in state else &"STROKE")
		if primary and state != "disabled" and state != "focus":
			style.shadow_size = Tokens.Elevation.LOW
			style.shadow_offset.y = Tokens.Elevation.LOW_OFFSET_Y
			style.shadow_color = get_theme_color(&"LOW_COLOR", &"Elevation")
		if highlighted and state in ["normal", "hover"]:
			style.set_border_width_all(Tokens.Action.OUTLINE_WIDTH)
			style.border_color = _palette(&"ON_PRIMARY" if primary else &"PRIMARY")
		if state == "focus":
			style.set_border_width_all(Tokens.Space.XS)
			style.border_color = _palette(&"TEXT")
		add_theme_stylebox_override(state, style)
	for suffix: String in ["", "_hover", "_pressed", "_hover_pressed", "_focus", "_disabled"]:
		var colour: Color = _palette(&"ON_PRIMARY" if primary else &"PRIMARY")
		if suffix == "_disabled":
			colour = _palette(&"TEXT_MUTED")
		add_theme_color_override("font%s_color" % suffix, colour)
		var icon_state: String = "normal" if suffix.is_empty() else suffix.trim_prefix("_")
		add_theme_color_override("icon_%s_color" % icon_state, colour)
	_sublabel.add_theme_color_override(
		"font_color",
		_palette(&"TEXT_MUTED" if disabled else (&"ON_PRIMARY" if primary else &"PRIMARY"))
	)
	_refreshing = false
	queue_redraw()


func _ad_space() -> float:
	return 0.0


func _spinner_texture() -> Texture2D:
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.width = Tokens.Space.L
	texture.height = Tokens.Space.L
	var gradient: Gradient = Gradient.new()
	var transparent: Color = Tokens.Palette.SURFACE
	transparent.a = 0
	gradient.colors = PackedColorArray([transparent, transparent])
	texture.gradient = gradient
	return texture


func _sync_state() -> void:
	if not is_node_ready():
		return
	_stop_motion()
	set_process_input(loading)
	set_process((loading or highlighted) and not Tokens.reduced_motion)
	_refresh_theme()
	if highlighted and not loading and not disabled and not Tokens.reduced_motion:
		_motion = create_tween().set_loops(3)
		_motion.set_trans(Tokens.Ease.IN_OUT.x).set_ease(Tokens.Ease.IN_OUT.y)
		_motion.tween_property(
			self, "scale", Vector2.ONE / Tokens.Action.PRESS_SCALE, Tokens.dur(Tokens.Motion.SLOW)
		)
		_motion.tween_property(self, "scale", Vector2.ONE, Tokens.dur(Tokens.Motion.SLOW))


func _check_disabled() -> void:
	if disabled:
		_stop_motion()
	if _sublabel != null:
		var colour: Color = _palette(
			&"TEXT_MUTED" if disabled else (&"ON_PRIMARY" if _kind() == &"primary" else &"PRIMARY")
		)
		if _sublabel.get_theme_color("font_color") != colour:
			_sublabel.add_theme_color_override("font_color", colour)


func _press_down() -> void:
	if not disabled and not loading:
		_animate_scale(Vector2.ONE * Tokens.Action.PRESS_SCALE)


func _press_up() -> void:
	_animate_scale(Vector2.ONE)


func _animate_scale(target: Vector2) -> void:
	if _motion != null:
		_motion.kill()
	if Tokens.reduced_motion or disabled or loading:
		scale = Vector2.ONE
		return
	set_process(true)
	_motion = create_tween().set_trans(Tokens.Ease.OUT.x).set_ease(Tokens.Ease.OUT.y)
	_motion.tween_property(self, "scale", target, Tokens.dur(Tokens.Motion.FAST))


func _stop_motion() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	scale = Vector2.ONE


func _input(_event: InputEvent) -> void:
	# Native availability may be changed by a caller while work is still pending.
	# Reassert suppression before GUI/shortcut dispatch without consuming other input.
	if loading:
		disabled = true


func _process(delta: float) -> void:
	if Tokens.reduced_motion:
		_stop_motion()
		set_process(false)
		_angle = 0
	elif loading:
		_angle = fmod(_angle + delta * TAU / Tokens.dur(Tokens.Motion.SLOW), TAU)
	elif _motion == null or not _motion.is_running():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if loading:
		var centre: Vector2 = Vector2(
			Tokens.Space.M + _ad_space() + Tokens.Space.L / 2.0, (size.y - _sublabel_height) / 2.0
		)
		draw_arc(
			centre,
			Tokens.Space.S,
			_angle,
			_angle + TAU * (1.0 - 1.0 / Tokens.Space.XS),
			Tokens.Space.M,
			_palette(&"TEXT_MUTED"),
			Tokens.Action.OUTLINE_WIDTH,
			true
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _exit_tree() -> void:
	_stop_motion()
	set_process(false)
	set_process_input(false)
	for connection: Array in [
		[resized, _layout_copy],
		[button_down, _press_down],
		[button_up, _press_up],
		[draw, _check_disabled]
	]:
		if (connection[0] as Signal).is_connected(connection[1]):
			(connection[0] as Signal).disconnect(connection[1])
	if _sublabel != null and _sublabel.minimum_size_changed.is_connected(_layout_copy):
		_sublabel.minimum_size_changed.disconnect(_layout_copy)
	_copy.unregister()
