extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const TEST_PATH: String = "user://t0284-settings.json"

var _themes: Array[String] = []
var _previous_motion: bool = false


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


func before_each() -> void:
	_previous_motion = Tokens.reduced_motion
	_themes.clear()
	_clean_files()


func after_each() -> void:
	Tokens.reduced_motion = _previous_motion
	_clean_files()


func _clean_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)


func _save() -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(FixedClock.new())
	save.configure(
		SaveStorage.new(TEST_PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert_eq(save.load(), OK)
	return save


func _sink(path: String) -> void:
	_themes.append(path)


func test_unbound_controller_fails_closed() -> void:
	var controller: SettingsController = SettingsController.new()
	assert_eq(controller.set_value(&"sfx_volume", 0.5), ERR_UNCONFIGURED)
	assert_null(controller.get_value(&"sfx_volume"))
	controller.apply_all()
	assert_eq(_themes.size(), 0)


func test_invalid_values_are_rejected_without_writing() -> void:
	var save: SAVE_SCRIPT = _save()
	var controller: SettingsController = SettingsController.new()
	controller.bind(save)
	var bad: Dictionary = {
		&"sfx_volume": [1.5, -0.1, "0.5", 1, NAN],
		&"music_volume": [2.0, null],
		&"haptics_enabled": [1, "true"],
		&"reduced_motion": [0, null],
		&"high_contrast": ["no"],
		&"text_scale": [3, -1, 1.0, "1"],
		&"language": ["", 5],
	}
	for key: StringName in bad:
		for value: Variant in bad[key]:
			assert_eq(controller.set_value(key, value), ERR_INVALID_DATA, "%s %s" % [key, value])
	assert_eq(controller.set_value(&"unknown", true), ERR_INVALID_PARAMETER)
	assert_eq(controller.get_value(&"sfx_volume"), 1.0)
	assert_eq(controller.get_value(&"text_scale"), 0)


func test_valid_values_persist_and_reload() -> void:
	var save: SAVE_SCRIPT = _save()
	var controller: SettingsController = SettingsController.new()
	controller.bind(save)
	assert_eq(controller.set_value(&"music_volume", 0.25), OK)
	assert_eq(controller.set_value(&"text_scale", 2), OK)
	assert_eq(controller.set_value(&"language", "en"), OK)
	var reloaded: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(reloaded)
	reloaded.initialize(FixedClock.new())
	reloaded.configure(SaveStorage.new(TEST_PATH))
	assert_eq(reloaded.load(), OK)
	assert_eq(reloaded.get_setting(&"music_volume"), 0.25)
	assert_eq(reloaded.get_setting(&"text_scale"), 2)
	assert_eq(reloaded.get_setting(&"language"), "en")


func test_theme_path_maps_all_six_variants() -> void:
	var dir: String = "res://ui/theme/generated/"
	assert_eq(SettingsController.theme_path(false, 0), dir + "theme_default_100.tres")
	assert_eq(SettingsController.theme_path(false, 1), dir + "theme_default_115.tres")
	assert_eq(SettingsController.theme_path(false, 2), dir + "theme_default_130.tres")
	assert_eq(SettingsController.theme_path(true, 0), dir + "theme_hc_100.tres")
	assert_eq(SettingsController.theme_path(true, 1), dir + "theme_hc_115.tres")
	assert_eq(SettingsController.theme_path(true, 2), dir + "theme_hc_130.tres")
	assert_eq(SettingsController.theme_path(true, 9), dir + "theme_hc_100.tres")
	for variant: String in ["default", "hc"]:
		for scale: String in ["100", "115", "130"]:
			assert_true(ResourceLoader.exists(dir + "theme_%s_%s.tres" % [variant, scale]))


func test_bind_applies_then_reapplies_on_change_until_unbind() -> void:
	var save: SAVE_SCRIPT = _save()
	var controller: SettingsController = SettingsController.new()
	Tokens.reduced_motion = false
	controller.bind(save, _sink)
	assert_eq(_themes.size(), 1)
	assert_eq(controller.set_value(&"high_contrast", true), OK)
	assert_eq(controller.set_value(&"text_scale", 1), OK)
	assert_eq(_themes.back(), SettingsController.theme_path(true, 1))
	assert_eq(controller.set_value(&"reduced_motion", true), OK)
	assert_true(Tokens.reduced_motion)
	controller.unbind()
	var count: int = _themes.size()
	save.set_setting(&"high_contrast", false)
	assert_eq(_themes.size(), count)


func test_os_reduced_motion_default() -> void:
	var save: SAVE_SCRIPT = _save()
	var controller: SettingsController = SettingsController.new()
	controller.bind(save, Callable(), func() -> int: return -1)
	assert_false(Tokens.reduced_motion)
	controller.bind(save, Callable(), func() -> int: return 0)
	assert_false(Tokens.reduced_motion)
	controller.bind(save, Callable(), func() -> int: return 1)
	assert_true(Tokens.reduced_motion)
	controller.unbind()
