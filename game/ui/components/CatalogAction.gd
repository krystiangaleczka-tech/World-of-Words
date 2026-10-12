class_name CatalogAction
extends ActionButton
## Internal native action with passive wrapped content and token surface.

var column: VBoxContainer
var _margin: MarginContainer
var _title_label: Label
var _subtitle_label: Label
var _styled_disabled: bool = false
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _enter_tree() -> void:
	_catalog.register_all()
	super._enter_tree()
	if column != null:
		_connect_content()


func _ready() -> void:
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, Tokens.Space.M)
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.Space.S)
	_margin.add_child(column)
	_build_content()
	super._ready()
	_connect_content()
	_layout_copy()


func _build_content() -> void:
	_title_label = CatalogSurface.label()
	column.add_child(_title_label)
	_subtitle_label = CatalogSurface.label(&"Caption")
	column.add_child(_subtitle_label)


func _kind() -> StringName:
	return &"secondary"


func _refresh_copy() -> void:
	text = ""
	accessibility_name = text_key
	accessibility_description = sublabel_key
	if _sublabel != null:
		_sublabel.visible = false
	if _title_label != null:
		_title_label.text = tr(text_key) if not text_key.is_empty() else ""
		_subtitle_label.text = tr(sublabel_key) if not sublabel_key.is_empty() else ""
		_subtitle_label.visible = not sublabel_key.is_empty()


func _layout_copy() -> void:
	pivot_offset = size / 2
	if _margin != null:
		var minimum: Vector2 = _margin.get_combined_minimum_size()
		custom_minimum_size = Vector2(
			maxf(Tokens.Touch.MIN_TARGET, minimum.x), maxf(Tokens.Touch.MIN_TARGET, minimum.y)
		)


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	_refreshing = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = CatalogSurface.panel(self)
		if "pressed" in state:
			box.bg_color = _palette(&"SURFACE_ALT")
		if state == "focus" or highlighted:
			box.set_border_width_all(Tokens.Action.OUTLINE_WIDTH)
			box.border_color = _palette(&"PRIMARY")
		add_theme_stylebox_override(state, box)
	_title_label.add_theme_color_override(
		"font_color", _palette(&"TEXT_MUTED" if disabled else &"TEXT")
	)
	_subtitle_label.add_theme_color_override("font_color", _palette(&"TEXT_MUTED"))
	_styled_disabled = disabled
	_refreshing = false


func _check_disabled() -> void:
	super._check_disabled()
	if disabled != _styled_disabled:
		_refresh_theme()
	_refresh_available()


func _refresh_available() -> void:
	pass


func _sync_state() -> void:
	super._sync_state()
	if is_node_ready():
		set_process_input(true)
		_refresh_available()


func _input(event: InputEvent) -> void:
	super._input(event)
	_refresh_available()


func _connect_content() -> void:
	if not _margin.minimum_size_changed.is_connected(_layout_copy):
		_margin.minimum_size_changed.connect(_layout_copy)


func _exit_tree() -> void:
	if _margin.minimum_size_changed.is_connected(_layout_copy):
		_margin.minimum_size_changed.disconnect(_layout_copy)
	_catalog.unregister()
	super._exit_tree()
