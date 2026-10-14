class_name Sheet
extends Control
## @api Modal caller-owned content. Future Nav consults handle_back before leaving a screen.

signal dismissed(reason: StringName)
const GROUP: StringName = &"catalog_sheet"
@export var title_key: String = "":
	set(next):
		title_key = next
		_refresh_copy()
@export var dismissible: bool = true:
	set(next):
		dismissible = next
		_refresh_busy()
@export var busy: bool = false:
	set(next):
		busy = next
		_refresh_busy()
var state: StringName:
	get:
		return _state
var _state: StringName = &"closed"
var _claiming: bool = false
var _content: Control
var _panel: PanelContainer
var _scroll: ScrollContainer
var _title: Label
var _header: HBoxContainer
var _close: IconButton
var _scrim: ColorRect
var _transition: Tween
var _previous_focus: Control
var _redirecting: bool = false
var _reason: StringName = &"action"
var _pointer: int = -1
var _touch: bool = false
var _bounds_owner: Control
var _start_y: float = 0
var _refreshing: bool = false
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _enter_tree() -> void:
	add_to_group(GROUP)
	_catalog.register_all()
	if _panel != null:
		_connect_signals()
		_mount_content()
		_refresh_copy()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	_scrim = ColorRect.new()
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", Tokens.Space.M)
	_panel.add_child(column)
	_header = HBoxContainer.new()
	column.add_child(_header)
	_title = CatalogSurface.label(&"Subtitle")
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title)
	_close = IconButton.new()
	_close.configure_icon(preload("res://assets/icons/x.svg"), "ui.sheet.close")
	_header.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_connect_signals()
	_mount_content()
	_refresh_copy()
	_refresh_theme()
	_refresh_busy()
	visible = false
	set_process(false)
	set_process_input(false)


## @api Content belongs to the caller; invalid ownership preserves the old content.
func configure_content(content: Control) -> Error:
	if content == null:
		return ERR_INVALID_PARAMETER
	if content != null:
		if content == self or content.is_ancestor_of(self):
			return ERR_INVALID_PARAMETER
		if content.get_parent() != null and content != _content:
			return ERR_ALREADY_IN_USE
	if is_instance_valid(_content) and _content != content and _content.get_parent() == _scroll:
		if _content.minimum_size_changed.is_connected(_on_resize):
			_content.minimum_size_changed.disconnect(_on_resize)
		_scroll.remove_child(_content)
	_content = content
	_mount_content()
	_layout()
	return OK


func _mount_content() -> void:
	if _scroll != null and is_instance_valid(_content) and _content.get_parent() == null:
		_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.add_child(_content)
	if is_instance_valid(_content) and not _content.minimum_size_changed.is_connected(_on_resize):
		_content.minimum_size_changed.connect(_on_resize)


## @api One visible sheet per viewport; busy/non-dismissible predecessor remains authoritative.
func open() -> Error:
	if not is_node_ready() or not is_inside_tree():
		return ERR_UNCONFIGURED
	if _state in [&"open", &"opening"]:
		return OK
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var claimant: Sheet = node as Sheet
		if claimant.get_viewport() == get_viewport() and claimant._claiming:
			return ERR_BUSY
	_claiming = true
	var result: Error = _replace_previous()
	if result != OK:
		_claiming = false
		return result
	get_parent().move_child(self, -1)
	if _state == &"closed":
		_previous_focus = get_viewport().gui_get_focus_owner()
	visible = true
	_state = &"opening"
	_layout()
	_focus_first()
	_animate(true)
	set_process_input(true)
	_claiming = false
	return OK


func _replace_previous() -> Error:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other: Sheet = node as Sheet
		if other != self and other.get_viewport() == get_viewport() and other.state != &"closed":
			if other.busy or not other.dismissible:
				return ERR_BUSY
			other.close(true)
			other._finish_close()
			if other.state != &"closed":
				return ERR_BUSY
	return OK


## @api Owner force is for teardown/navigation, never an implicit busy dismissal.
func close(force: bool = false) -> bool:
	if _state == &"closed":
		return false
	if not force and (busy or not dismissible):
		return false
	if _state == &"closing":
		return true
	_state = &"closing"
	_animate(false)
	return true


## @api True means Back was consumed, including a modal busy state.
func handle_back() -> bool:
	if _state == &"closed":
		return false
	_reason = &"back"
	close()
	return true


func _animate(opening: bool) -> void:
	_cancel_transition()
	if Tokens.reduced_motion:
		if opening:
			_finish_open()
		else:
			_finish_close()
		return
	var target: Vector2 = _panel.position
	var duration: float = Tokens.dur(Tokens.Motion.BASE if opening else Tokens.Motion.FAST)
	var ease: Vector2i = Tokens.Ease.OUT if opening else Tokens.Ease.IN
	if opening:
		_panel.position.y = size.y
		modulate.a = 0
	_transition = create_tween().set_parallel(true).set_trans(ease.x).set_ease(ease.y)
	_transition.tween_property(self, "modulate:a", 1.0 if opening else 0.0, duration)
	_transition.tween_property(
		_panel, "position", target if opening else Vector2(target.x, size.y), duration
	)
	_transition.chain().tween_callback(_finish_open if opening else _finish_close)
	set_process(true)


func _cancel_transition() -> void:
	if _transition != null:
		_transition.kill()
		_transition = null
	set_process(false)


func _finish_open() -> void:
	_cancel_transition()
	_state = &"open"
	modulate.a = 1
	_layout()


func _finish_close() -> void:
	if _state == &"closed":
		return
	_cancel_transition()
	_state = &"closed"
	visible = false
	set_process_input(false)
	if (
		is_instance_valid(_previous_focus)
		and _previous_focus.is_inside_tree()
		and _previous_focus.is_visible_in_tree()
	):
		_previous_focus.grab_focus()
	var reason: StringName = _reason
	_reason = &"action"
	_pointer = -1
	_touch = false
	dismissed.emit(reason)


func _layout() -> void:
	if _panel == null or not is_inside_tree():
		return
	var rect: Rect2 = CatalogSurface.bounds(self)
	var desired: float = _header.get_combined_minimum_size().y + Tokens.Space.L * 2 + Tokens.Space.M
	if is_instance_valid(_content):
		desired += _content.get_combined_minimum_size().y
	_panel.size = Vector2(
		minf(rect.size.x, Tokens.Layout.MAX_CONTENT_WIDTH),
		minf(desired, rect.size.y * Tokens.Layout.SHEET_MAX_RATIO)
	)
	_panel.position = Vector2(
		rect.position.x + (rect.size.x - _panel.size.x) / 2, rect.end.y - _panel.size.y
	)


func _on_resize() -> void:
	if _transition != null:
		if _state == &"opening":
			_finish_open()
		else:
			_finish_close()
	_layout()


func _refresh_copy() -> void:
	if _title != null:
		_title.text = tr(title_key) if not title_key.is_empty() else ""
		accessibility_name = title_key
		_layout()


func _refresh_theme() -> void:
	if _panel == null or _refreshing:
		return
	_refreshing = true
	_scrim.color = get_theme_color(&"SCRIM", &"Palette")
	var box: StyleBoxFlat = CatalogSurface.panel(self, Tokens.Space.L, Tokens.Radius.L, &"HIGH")
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	_panel.add_theme_stylebox_override("panel", box)
	_refreshing = false
	_layout()


func _refresh_busy() -> void:
	if _close != null:
		_close.loading = busy
		_close.disabled = busy or not dismissible
		if (
			_state != &"closed"
			and _close.disabled
			and get_viewport().gui_get_focus_owner() == _close
		):
			_focus_first()


func _request(reason: StringName) -> void:
	_reason = reason
	close()


func _on_close() -> void:
	_request(&"button")


func _on_scrim(event: InputEvent) -> void:
	if (
		(
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
		or (event is InputEventScreenTouch and event.pressed)
	):
		_request(&"scrim")
	accept_event()


func _on_header(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _pointer == -1:
			_pointer = event.index
			_touch = true
			_start_y = event.position.y
		elif not event.pressed and _touch and event.index == _pointer:
			_pointer = -1
			if not event.canceled and event.position.y - _start_y > Tokens.Space.L:
				_request(&"swipe")
			_touch = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _touch:
			return
		if event.pressed and _pointer == -1:
			_pointer = 0
			_start_y = event.position.y
		elif not event.pressed and _pointer == 0:
			_pointer = -1
			if event.position.y - _start_y > Tokens.Space.L:
				_request(&"swipe")


func _focusables(root: Node, result: Array[Control]) -> void:
	for child: Node in root.get_children():
		if (
			child is Control
			and child.is_visible_in_tree()
			and child.focus_mode != Control.FOCUS_NONE
			and not (child is BaseButton and child.disabled)
		):
			result.append(child)
		_focusables(child, result)


func _focus_first() -> void:
	var choices: Array[Control] = []
	_focusables(_panel, choices)
	if choices.is_empty():
		grab_focus()
	else:
		choices[0].grab_focus()


func _on_focus(focused: Control) -> void:
	if (
		_state == &"closed"
		or _redirecting
		or focused == self
		or (is_instance_valid(focused) and _panel.is_ancestor_of(focused))
	):
		return
	_redirecting = true
	_focus_first()
	_redirecting = false


func _input(event: InputEvent) -> void:
	if _state == &"closed":
		return
	if event.is_action_pressed(&"ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_focus_next") or event.is_action_pressed(&"ui_focus_prev"):
		var choices: Array[Control] = []
		_focusables(_panel, choices)
		if not choices.is_empty():
			var index: int = choices.find(get_viewport().gui_get_focus_owner())
			index = posmod(
				index + (-1 if event.is_action_pressed(&"ui_focus_prev") else 1), choices.size()
			)
			choices[index].grab_focus()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if Tokens.reduced_motion:
		if _state == &"opening":
			_finish_open()
		else:
			_finish_close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for owner: Node in get_tree().get_nodes_in_group(&"nav_back_owner"):
			if owner.get_viewport() == get_viewport():
				return
		handle_back()


func _connect_signals() -> void:
	_bounds_owner = CatalogSurface.bounds_owner(self)
	if _bounds_owner != null and not _bounds_owner.resized.is_connected(_on_resize):
		_bounds_owner.resized.connect(_on_resize)
	for pair: Array in [
		[resized, _on_resize],
		[_scrim.gui_input, _on_scrim],
		[_header.gui_input, _on_header],
		[_close.pressed, _on_close],
		[get_viewport().gui_focus_changed, _on_focus]
	]:
		if not (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).connect(pair[1])


func _exit_tree() -> void:
	_cancel_transition()
	_state = &"closed"
	visible = false
	set_process_input(false)
	if is_instance_valid(_content) and _content.get_parent() == _scroll:
		if _content.minimum_size_changed.is_connected(_on_resize):
			_content.minimum_size_changed.disconnect(_on_resize)
		_scroll.remove_child(_content)
	for pair: Array in [
		[resized, _on_resize],
		[_scrim.gui_input, _on_scrim],
		[_header.gui_input, _on_header],
		[_close.pressed, _on_close],
		[get_viewport().gui_focus_changed, _on_focus]
	]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	if is_instance_valid(_bounds_owner) and _bounds_owner.resized.is_connected(_on_resize):
		_bounds_owner.resized.disconnect(_on_resize)
	_pointer = -1
	_touch = false
	remove_from_group(GROUP)
	_catalog.unregister()
