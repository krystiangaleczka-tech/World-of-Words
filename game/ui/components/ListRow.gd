class_name ListRow
extends CatalogAction
## @api Native option intent; nested toggle/slider owns its own input and caller lifetime.

@export var title_key: String:
	get:
		return text_key
	set(next):
		text_key = next
@export var subtitle_key: String:
	get:
		return sublabel_key
	set(next):
		sublabel_key = next
@export var leading_icon: Texture2D:
	set(next):
		leading_icon = next
		_refresh_copy()
var trailing_kind: StringName = &"none"
var trailing_value: String = "":
	set(next):
		trailing_value = next
		_refresh_copy()
var _leading: TextureRect
var _chevron: TextureRect
var _value_label: Label
var _slot: VBoxContainer
var _trailing: Control
var _suppressed: bool = false
var _previous_available: bool = true


func _build_content() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.Space.S)
	column.add_child(row)
	_leading = CatalogSurface.icon(null)
	row.add_child(_leading)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	_title_label = CatalogSurface.label()
	copy.add_child(_title_label)
	_subtitle_label = CatalogSurface.label(&"Caption")
	copy.add_child(_subtitle_label)
	_chevron = CatalogSurface.icon(preload("res://assets/icons/arrow-left.svg"))
	_chevron.flip_h = true
	row.add_child(_chevron)
	_value_label = CatalogSurface.label(&"Numeric")
	_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_value_label)
	_slot = VBoxContainer.new()
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_slot)
	_mount_trailing()


## @api Toggle must be BaseButton, slider native Slider. Noninteractive kinds require null.
func configure_trailing(control: Control, variant: StringName) -> Error:
	if variant not in [&"none", &"chevron", &"value", &"toggle", &"slider"]:
		return ERR_INVALID_PARAMETER
	if variant in [&"toggle", &"slider"]:
		if control == null or control == self or control.is_ancestor_of(self):
			return ERR_INVALID_PARAMETER
		if (
			(variant == &"toggle" and not control is BaseButton)
			or (variant == &"slider" and not control is Slider)
		):
			return ERR_INVALID_PARAMETER
		if control.get_parent() != null and control != _trailing:
			return ERR_ALREADY_IN_USE
	elif control != null:
		return ERR_INVALID_PARAMETER
	_detach_trailing()
	_trailing = control
	trailing_kind = variant
	_mount_trailing()
	_refresh_copy()
	return OK


func _mount_trailing() -> void:
	if _slot != null and is_instance_valid(_trailing) and _trailing.get_parent() == null:
		_slot.add_child(_trailing)
		_refresh_available()


func _detach_trailing() -> void:
	_restore_available()
	if is_instance_valid(_trailing) and _trailing.get_parent() == _slot:
		_slot.remove_child(_trailing)


func _restore_available() -> void:
	if _suppressed and is_instance_valid(_trailing):
		if _trailing is BaseButton:
			(_trailing as BaseButton).disabled = not _previous_available
		else:
			(_trailing as Slider).editable = _previous_available
	_suppressed = false


func _refresh_available() -> void:
	if not is_instance_valid(_trailing):
		return
	if disabled or loading:
		if not _suppressed:
			_previous_available = (
				not (_trailing as BaseButton).disabled
				if _trailing is BaseButton
				else (_trailing as Slider).editable
			)
			_suppressed = true
		if _trailing is BaseButton:
			(_trailing as BaseButton).disabled = true
		else:
			(_trailing as Slider).editable = false
	else:
		_restore_available()


func _refresh_copy() -> void:
	super._refresh_copy()
	if _leading != null:
		_leading.texture = leading_icon
		_leading.visible = leading_icon != null
		_chevron.visible = trailing_kind == &"chevron"
		_value_label.text = trailing_value
		_value_label.visible = trailing_kind == &"value"
		_slot.visible = trailing_kind in [&"toggle", &"slider"]


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing:
		return
	super._refresh_theme()
	_refreshing = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = get_theme_stylebox(state).duplicate() as StyleBoxFlat
		box.shadow_size = 0
		box.set_corner_radius_all(0)
		box.border_width_bottom = Tokens.Action.OUTLINE_WIDTH
		box.border_color = _palette(&"PRIMARY" if state == "focus" else &"STROKE")
		add_theme_stylebox_override(state, box)
	_leading.modulate = _palette(&"TEXT_MUTED" if disabled else &"PRIMARY")
	_chevron.modulate = _leading.modulate
	_refreshing = false


func _enter_tree() -> void:
	super._enter_tree()
	if _slot != null:
		_mount_trailing()


func _exit_tree() -> void:
	_detach_trailing()
	super._exit_tree()
