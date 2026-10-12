class_name CatalogSlider
extends HSlider
## @api Native normalized volume; changed sound gestures emit preview intent on release only.

signal preview_requested(value: float)
@export var a11y_label_key: String = "":
	set(next):
		if next.strip_edges().is_empty():
			return
		a11y_label_key = next.strip_edges()
		_refresh_copy()
		_refresh_available()
@export var sound_preview: bool = false
var _unconfigured: bool = false
var _was_editable: bool = true
var _dragging: bool = false
var _key_active: bool = false
var _changed: bool = false
var _expected_value: float = 0
var _mouse_offset: float = 0
var _touch_pointer: int = -1
var _touch_initial: float = 0
var _refreshing: bool = false
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _init() -> void:
	min_value = 0
	max_value = 1
	step = 0.1


## @api Programmatic configuration never requests preview.
func configure(next: float, key: String, preview: bool = false) -> Error:
	if not is_finite(next) or key.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	_cancel_gesture()
	a11y_label_key = key
	sound_preview = preview
	value = next
	_refresh_copy()
	return OK


func _enter_tree() -> void:
	_catalog.register_all()
	if is_node_ready():
		_connect_signals()
		_refresh_copy()
		_refresh_theme()
		set_process_input(true)


func _ready() -> void:
	min_value = 0
	max_value = 1
	step = 0.1
	var width: float = Tokens.Touch.MIN_TARGET * 2.0
	custom_minimum_size = Vector2(width, Tokens.Touch.MIN_TARGET)
	_connect_signals()
	_refresh_copy()
	_refresh_theme()
	_refresh_available()
	set_process_input(true)


func _refresh_available() -> void:
	if a11y_label_key.is_empty():
		if not _unconfigured:
			_was_editable = editable
			_unconfigured = true
		editable = false
	elif _unconfigured:
		editable = _was_editable
		_unconfigured = false
	if not editable:
		_cancel_gesture()


func _refresh_copy() -> void:
	accessibility_name = a11y_label_key
	accessibility_description = str(roundi(value * 100)) + "%"
	tooltip_text = tr(a11y_label_key) if not a11y_label_key.is_empty() else ""


func _on_value(next: float) -> void:
	_refresh_copy()
	if _dragging or _key_active:
		if is_equal_approx(next, _expected_value):
			_changed = true
		else:
			_cancel_gesture()


func _on_drag_started() -> void:
	_dragging = editable
	_changed = false


func _on_drag_ended(changed: bool) -> void:
	var emit_preview: bool = _dragging and changed and editable and sound_preview
	_cancel_gesture()
	if emit_preview:
		preview_requested.emit(value)


func _cancel_gesture() -> void:
	_dragging = false
	_key_active = false
	_changed = false
	_touch_pointer = -1


## @api Atomic cancellation when availability is changed, including disable/re-enable in one frame.
func set_available(enabled: bool) -> void:
	_cancel_gesture()
	editable = enabled


func _position_value(x: float) -> float:
	var half: float = Tokens.Touch.MIN_TARGET / 2.0
	return snappedf(
		clampf((x - half - _mouse_offset) / maxf(size.x - Tokens.Touch.MIN_TARGET, 1), 0, 1), step
	)


func _direction(event: InputEvent) -> bool:
	return (
		event.is_action(&"ui_left")
		or event.is_action(&"ui_right")
		or event.is_action(&"ui_up")
		or event.is_action(&"ui_down")
	)


func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventScreenTouch and event.pressed and _touch_pointer == -1:
		_cancel_gesture()
		_touch_pointer = event.index
		_touch_initial = value
		_dragging = true
		_mouse_offset = 0
		grab_focus()
		_expected_value = _position_value(event.position.x)
		value = _expected_value
		accept_event()
	elif (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	):
		var center: float = (
			Tokens.Touch.MIN_TARGET / 2.0 + value * (size.x - Tokens.Touch.MIN_TARGET)
		)
		_mouse_offset = (
			event.position.x - center
			if absf(event.position.x - center) <= Tokens.Touch.MIN_TARGET / 2.0
			else 0
		)
		_expected_value = _position_value(event.position.x)
	elif event is InputEventMouseMotion and _dragging:
		_expected_value = _position_value(event.position.x)
	elif event is InputEventKey and _direction(event):
		if event.pressed:
			_key_active = true
			var forward: bool = event.is_action(&"ui_right") or event.is_action(&"ui_up")
			_expected_value = snappedf(
				clampf(value + (step if forward else -step), min_value, max_value), step
			)
		else:
			var emit_preview: bool = _key_active and _changed and sound_preview
			_cancel_gesture()
			if emit_preview:
				preview_requested.emit(value)


func _input(event: InputEvent) -> void:
	_refresh_available()
	if (
		event is InputEventMouse
		and event.device == InputEvent.DEVICE_ID_EMULATION
		and _touch_pointer != -1
	):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and event.index == _touch_pointer:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		_expected_value = _position_value(point.x)
		value = _expected_value
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed and event.index == _touch_pointer:
		var emit_preview: bool = (
			not event.canceled
			and editable
			and sound_preview
			and not is_equal_approx(value, _touch_initial)
		)
		_cancel_gesture()
		get_viewport().set_input_as_handled()
		if emit_preview:
			preview_requested.emit(value)
	elif event is InputEventKey and event.keycode == KEY_ESCAPE:
		_cancel_gesture()


func _thumb(colour: Color) -> GradientTexture2D:
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.width = Tokens.Touch.MIN_TARGET
	texture.height = Tokens.Touch.MIN_TARGET
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2.ONE / 2
	texture.fill_to = Vector2(1, 0.5)
	var gradient: Gradient = Gradient.new()
	var clear: Color = colour
	clear.a = 0
	gradient.offsets = PackedFloat32Array(
		[0, 1.0 - float(Tokens.Space.XS) / Tokens.Touch.MIN_TARGET, 1]
	)
	gradient.colors = PackedColorArray([colour, colour, clear])
	texture.gradient = gradient
	return texture


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	_refreshing = true
	var track: StyleBoxFlat = CatalogSurface.panel(self, Tokens.Space.XS, Tokens.Radius.FULL)
	track.bg_color = get_theme_color(&"SURFACE_ALT", &"Palette")
	track.shadow_size = 0
	add_theme_stylebox_override("slider", track)
	var fill: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	fill.bg_color = get_theme_color(&"PRIMARY", &"Palette")
	add_theme_stylebox_override("grabber_area", fill)
	add_theme_stylebox_override("grabber_area_highlight", fill)
	for state: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		add_theme_icon_override(
			state,
			_thumb(
				get_theme_color(
					&"TEXT_MUTED" if state == "grabber_disabled" else &"PRIMARY", &"Palette"
				)
			)
		)
	_refreshing = false


func _connect_signals() -> void:
	for pair: Array in [
		[value_changed, _on_value],
		[drag_started, _on_drag_started],
		[drag_ended, _on_drag_ended],
		[focus_exited, _cancel_gesture]
	]:
		if not (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).connect(pair[1])


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_DRAW:
		_refresh_available()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _exit_tree() -> void:
	_cancel_gesture()
	set_process_input(false)
	for pair: Array in [
		[value_changed, _on_value],
		[drag_started, _on_drag_started],
		[drag_ended, _on_drag_ended],
		[focus_exited, _cancel_gesture]
	]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	_catalog.unregister()
