class_name SettingsController
extends RefCounted
## @api Validated access to the closed settings set plus apply hooks. Save stays the owner.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const THEME_DIR: String = "res://ui/theme/generated/"
const SCALES: PackedStringArray = ["100", "115", "130"]

var _save: SAVE_SCRIPT
var _theme_sink: Callable
var _os_reduced_motion: Callable
var _bound: bool = false


## @api Pure mapping to one of the six generated themes; unknown scales use 100.
static func theme_path(high_contrast: bool, text_scale: int) -> String:
	var scale: String = (
		SCALES[text_scale] if text_scale >= 0 and text_scale < SCALES.size() else "100"
	)
	return "%stheme_%s_%s.tres" % [THEME_DIR, "hc" if high_contrast else "default", scale]


## @api Connect to Save and apply the current values. os_reduced_motion returns 1, 0 or -1.
func bind(
	save: SAVE_SCRIPT, theme_sink: Callable = Callable(), os_reduced_motion: Callable = Callable()
) -> void:
	unbind()
	_save = save
	_theme_sink = theme_sink
	_os_reduced_motion = os_reduced_motion
	_save.setting_changed.connect(_on_setting_changed)
	_bound = true
	apply_all()


## @api Disconnect; safe to call repeatedly.
func unbind() -> void:
	if (
		_bound
		and is_instance_valid(_save)
		and _save.setting_changed.is_connected(_on_setting_changed)
	):
		_save.setting_changed.disconnect(_on_setting_changed)
	_bound = false


## @api Stored value, or null for unknown keys or before bind.
func get_value(key: StringName) -> Variant:
	if not _bound or not _save.is_loaded():
		return null
	return _save.get_setting(key)


## @api Validate, then persist through Save; applying happens on its setting_changed signal.
func set_value(key: StringName, value: Variant) -> Error:
	if not _bound or not _save.is_loaded():
		return ERR_UNCONFIGURED
	if key not in SaveSchema.SETTINGS:
		return ERR_INVALID_PARAMETER
	if not _valid(key, value):
		return ERR_INVALID_DATA
	return _save.set_setting(key, value)


## @api Stored reduced motion OR an OS value of 1; the schema has no unset state.
func effective_reduced_motion() -> bool:
	if get_value(&"reduced_motion") == true:
		return true
	return _os_reduced_motion.is_valid() and _os_reduced_motion.call() == 1


## @api Push current values into Tokens and the theme sink.
func apply_all() -> void:
	if not _bound or not _save.is_loaded():
		return
	Tokens.reduced_motion = effective_reduced_motion()
	if _theme_sink.is_valid():
		var scale: Variant = get_value(&"text_scale")
		_theme_sink.call(
			theme_path(get_value(&"high_contrast") == true, scale if scale is int else 0)
		)


func _valid(key: StringName, value: Variant) -> bool:
	match key:
		&"sfx_volume", &"music_volume":
			return value is float and is_finite(value) and value >= 0.0 and value <= 1.0
		&"haptics_enabled", &"reduced_motion", &"high_contrast":
			return value is bool
		&"text_scale":
			return value is int and value >= 0 and value <= 2
		&"language":
			return value is String and not value.is_empty()
	return false


func _on_setting_changed(_key: StringName) -> void:
	apply_all()
