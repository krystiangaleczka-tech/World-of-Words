class_name TopBar
extends Control
## @api Fixed-height header; callers own detached slot controls.

signal fits_changed(value: bool)

@export var title_key: String = "":
	set(value):
		title_key = value
		_refresh_title()
@export var transparent: bool = true:
	set(value):
		transparent = value
		_refresh_theme()
var leading: Array[Control]:
	get:
		return _leading.duplicate()
	set(value):
		configure(value, title_key, _trailing)
var trailing: Array[Control]:
	get:
		return _trailing.duplicate()
	set(value):
		configure(_leading, title_key, value)
var fits: bool = true
var _leading: Array[Control] = []
var _trailing: Array[Control] = []
var _title: Label
var _surface: ColorRect
var _copy: Array[Translation] = []
var _laying_out: bool = false


func _enter_tree() -> void:
	_register_translations()
	if _title != null:
		_connect_layout()
		_refresh_title()


func _ready() -> void:
	custom_minimum_size.y = Tokens.Layout.TOP_BAR_H
	_surface = ColorRect.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_surface, 0)
	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = &"Subtitle"
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_connect_layout()
	_refresh_theme()
	_refresh_title()


## @api Validate entire configuration before detaching or mounting any slot.
func configure(
	leading_controls: Array[Control], key: String, trailing_controls: Array[Control]
) -> Error:
	if leading_controls.size() > 3 or trailing_controls.size() > 3:
		return ERR_INVALID_PARAMETER
	var seen: Array[Control] = []
	for control: Control in leading_controls + trailing_controls:
		if (
			control == null
			or control in [self, _title, _surface]
			or control in seen
			or control is TextButton
		):
			return ERR_INVALID_PARAMETER
		if control is Button and not control is IconButton:
			return ERR_INVALID_PARAMETER
		if control.is_ancestor_of(self):
			return ERR_INVALID_PARAMETER
		if control.get_parent() != null and control.get_parent() != self:
			return ERR_ALREADY_IN_USE
		seen.append(control)
	for control: Control in leading + trailing:
		if control not in seen and control.get_parent() == self:
			if control.minimum_size_changed.is_connected(_layout_slots):
				control.minimum_size_changed.disconnect(_layout_slots)
			remove_child(control)
	_leading = leading_controls.duplicate()
	_trailing = trailing_controls.duplicate()
	title_key = key
	for control: Control in seen:
		if control.get_parent() == null:
			add_child(control)
		if not control.minimum_size_changed.is_connected(_layout_slots):
			control.minimum_size_changed.connect(_layout_slots)
	_layout_slots()
	return OK


func _connect_layout() -> void:
	if _title != null and not _title.minimum_size_changed.is_connected(_layout_slots):
		_title.minimum_size_changed.connect(_layout_slots)
	if not resized.is_connected(_layout_slots):
		resized.connect(_layout_slots)
	for control: Control in leading + trailing:
		if not control.minimum_size_changed.is_connected(_layout_slots):
			control.minimum_size_changed.connect(_layout_slots)


func _width(controls: Array[Control]) -> float:
	var total: float = 0
	for control: Control in controls:
		total += control.get_combined_minimum_size().x
	return total + max(controls.size() - 1, 0) * Tokens.Space.S


func _layout_slots() -> void:
	if _title == null or _laying_out:
		return
	_laying_out = true
	var lane: float = maxf(_width(leading), _width(trailing))
	var room: float = maxf(size.x - (lane + Tokens.Space.S) * 2, 0)
	_title.position = Vector2(lane + Tokens.Space.S, 0)
	_title.size = Vector2(room, Tokens.Layout.TOP_BAR_H)
	var next_fits: bool = room > 0 and _title_height(room) <= Tokens.Layout.TOP_BAR_H
	if fits != next_fits:
		fits = next_fits
		fits_changed.emit(fits)
	_title.visible = fits and not title_key.is_empty()
	for controls: Array[Control] in [leading, trailing]:
		var cursor: float = (
			0
			if controls == leading
			else maxf(size.x - _width(trailing), _width(leading) + Tokens.Space.S)
		)
		for control: Control in controls:
			var minimum: Vector2 = control.get_combined_minimum_size()
			control.position = Vector2(cursor, maxf((Tokens.Layout.TOP_BAR_H - minimum.y) / 2.0, 0))
			control.size = minimum
			control.visible = true
			cursor += minimum.x + Tokens.Space.S
	_laying_out = false


func _refresh_title() -> void:
	if _title != null:
		_title.text = tr(title_key) if not title_key.is_empty() else ""
		_layout_slots()


func _refresh_theme() -> void:
	if _surface != null:
		_surface.visible = not transparent
		_surface.color = (
			get_theme_color(&"SURFACE", &"Palette")
			if has_theme_color(&"SURFACE", &"Palette")
			else Tokens.Palette.SURFACE
		)
		_layout_slots()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_title()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _exit_tree() -> void:
	if _title != null and _title.minimum_size_changed.is_connected(_layout_slots):
		_title.minimum_size_changed.disconnect(_layout_slots)
	if resized.is_connected(_layout_slots):
		resized.disconnect(_layout_slots)
	for control: Control in leading + trailing:
		if is_instance_valid(control) and control.minimum_size_changed.is_connected(_layout_slots):
			control.minimum_size_changed.disconnect(_layout_slots)
	for translation: Translation in _copy:
		TranslationServer.remove_translation(translation)
	_copy.clear()


func _register_translations() -> void:
	if not _copy.is_empty():
		return
	for file: String in ResourceLoader.list_directory("res://locale"):
		if not file.ends_with(".translation"):
			continue
		var source: Translation = load("res://locale/" + file) as Translation
		if source != null:
			var translation: Translation = source.duplicate() as Translation
			TranslationServer.add_translation(translation)
			_copy.append(translation)


func _title_height(width_value: float) -> float:
	# Shape independently: a hidden Label can retain its previous wrapped minimum.
	var font: Font = _title.get_theme_font(&"font")
	var font_size: int = _title.get_theme_font_size(&"font_size")
	return (
		font
		. get_multiline_string_size(
			_title.text,
			HORIZONTAL_ALIGNMENT_CENTER,
			width_value,
			font_size,
			-1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		)
		. y
	)
