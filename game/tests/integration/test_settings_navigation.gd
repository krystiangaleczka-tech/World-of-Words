extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const CONTENT: Script = preload("res://services/content.gd")
const PROGRESS: Script = preload("res://services/progress.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const NAV: Script = preload("res://services/nav.gd")
const EVENTS: Script = preload("res://services/events.gd")
const FIXTURE: Script = preload("res://tests/integration/test_shipped_campaign_flow.gd")
const LANGUAGE_CONTENT: String = "res://tests/fixtures/settings/content"
const HIGH_CONTRAST: Theme = preload("res://ui/theme/generated/theme_hc_100.tres")

var _nav: NAV
var _save: SAVE
var _content: CONTENT
var _config: TestConfig
var _host: Control
var _storage: FIXTURE.MemoryStorage
var _motion: bool
var _locale: String
var _low_mode: bool


class TestConfig:
	extends "res://services/config.gd"
	var journey_slot: int = 0

	func get_int(key: StringName) -> int:
		if key == &"unlocks.journey_slot" and journey_slot > 0:
			return journey_slot
		return super.get_int(key)


func before_each() -> void:
	_motion = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	_low_mode = OS.low_processor_usage_mode
	_storage = FIXTURE.MemoryStorage.new()
	_storage.document.settings.reduced_motion = true
	_save = SAVE.new()
	_content = CONTENT.new()
	_nav = NAV.new()
	_config = TestConfig.new()
	var progress: PROGRESS = PROGRESS.new()
	var economy: ECONOMY = ECONOMY.new()
	var events: EVENTS = EVENTS.new()
	var clock: Clock = FIXTURE.FixedClock.new()
	for node: ServiceStub in [_save, _config, _content, _nav, progress, economy, events]:
		add_child_autofree(node)
		node.initialize(clock)
	_host = Control.new()
	add_child_autofree(_host)
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save.configure(_storage)
	_nav.configure(_save, _config, _content)
	assert_eq(_nav.configure_p2(Callable(), false), OK)
	_nav.configure_offline_campaign(
		OfflineCampaign.new(_save, _config, _content, progress, economy, events)
	)
	_nav.configure_settings_host(_host)


func after_each() -> void:
	_host.queue_free()
	await get_tree().process_frame
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)
	OS.low_processor_usage_mode = _low_mode


func _stage_slot(language: String, slot: int) -> void:
	var state: Dictionary = SaveSchema.LANGUAGE_STATE.duplicate(true)
	state.current_slot = slot
	state.highest_completed_slot = slot - 1
	state.completed_slot = slot - 1
	_storage.document.progress.by_lang[language] = state


func _settings() -> SettingsScreen:
	assert_eq(_nav.current_screen(), _nav.Screen.SETTINGS)
	return _nav.mounted_screen().get_node("Settings") as SettingsScreen


func test_home_settings_persist_theme_and_licences_return_through_same_visit() -> void:
	_stage_slot("pl", 12)
	assert_eq(_nav.start(_host), OK)
	assert_eq(_nav.current_screen(), _nav.Screen.HOME)
	var button: IconButton = _nav.mounted_screen().find_child("Settings", true, false) as IconButton
	assert_false(button.disabled)
	button.pressed.emit()
	var screen: SettingsScreen = _settings()
	for action: StringName in [
		&"restore", &"privacy_options", &"privacy_policy", &"support", &"shop"
	]:
		assert_false(screen.rows[action].is_visible_in_tree(), str(action))
	var column: Node = screen.rows[&"shop"].get_parent()
	for heading: String in ["Section_purchases", "Section_privacy"]:
		assert_false((column.get_node(heading) as Label).is_visible_in_tree(), heading)
	(screen.controls[&"high_contrast"] as Toggle).value_changed.emit(true)
	assert_true(_storage.document.settings.high_contrast)
	assert_eq(_host.theme, HIGH_CONTRAST)
	screen.rows[&"licences"].pressed.emit()
	var licences: LicencesScreen = _nav.mounted_screen().get_node("Licences") as LicencesScreen
	assert_false(screen.is_visible_in_tree())
	assert_true(licences.is_visible_in_tree())
	licences.rows[&"godot"].pressed.emit()
	assert_eq(licences.notice.text, Engine.get_license_text())
	assert_eq(_nav.handle_back(), OK)
	assert_eq(licences.selected_id, &"")
	assert_eq(_nav.handle_back(), OK)
	assert_true(screen.is_visible_in_tree())
	assert_false(licences.is_visible_in_tree())
	screen.back.pressed.emit()
	assert_eq(_nav.current_screen(), _nav.Screen.HOME)
	assert_eq(
		_nav.mounted_screen().get_theme_color(&"BG", &"Palette"),
		HIGH_CONTRAST.get_color(&"BG", &"Palette")
	)


func test_level_settings_returns_to_the_committed_board() -> void:
	_stage_slot("pl", 12)
	assert_eq(_nav.start(_host), OK)
	assert_eq(_nav.go_to_level(12), OK)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	var data: LevelData = level.controller.get_board().get_level()
	var word: String = data.word(0)
	var tiles: PackedInt32Array = []
	for letter: String in word:
		for tile: int in data.tile_count():
			if data.tile_letter(tile) == letter and not tiles.has(tile):
				tiles.append(tile)
				break
	level.wheel.word_attempted.emit(tiles)
	assert_false(level.controller.is_complete())
	assert_true(word in level.controller.get_board().found_words())
	assert_false(level.p2_hud.settings.disabled)
	level.p2_hud.settings.pressed.emit()
	var settings: SettingsScreen = _settings()
	_storage.fail = true
	(settings.controls[&"haptics_enabled"] as Toggle).value_changed.emit(false)
	assert_true(settings.retry_button.visible)
	assert_eq(_nav.handle_back(), ERR_BUSY)
	assert_true(_storage.document.settings.haptics_enabled)
	_storage.fail = false
	settings.retry_button.pressed.emit()
	assert_false(_storage.document.settings.haptics_enabled)
	assert_eq(_nav.handle_back(), OK)
	level = _nav.mounted_screen() as LevelScreen
	assert_eq(_nav.level_slot(), 12)
	assert_true(word in level.controller.get_board().found_words())


func test_changing_shipped_language_resumes_its_own_campaign() -> void:
	_config.journey_slot = 2
	_stage_slot("pl", 2)
	_stage_slot("en", 3)
	assert_eq(_nav.start(_host, LANGUAGE_CONTENT), OK)
	assert_eq(_nav.go_to_level(2), OK)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	level.p2_hud.settings.pressed.emit()
	var settings: SettingsScreen = _settings()
	settings.rows[&"language"].pressed.emit()
	assert_true(settings.language_options.has("en"))
	assert_false(settings.language_options.has("de"))
	settings.language_options["en"].pressed.emit()
	assert_eq(_content.get_language(), "en")
	assert_eq(_storage.document.settings.language, "en")
	assert_eq(TranslationServer.get_locale(), "en")
	await get_tree().process_frame
	assert_eq(_nav.handle_back(), OK)
	assert_eq(_nav.current_screen(), _nav.Screen.LEVEL)
	assert_eq(_nav.level_slot(), 3)
	assert_eq(int(_storage.document.progress.by_lang.pl.current_slot), 2)
	assert_eq(_nav.go_home(), OK)
	var button: IconButton = _nav.mounted_screen().find_child("Settings", true, false) as IconButton
	button.pressed.emit()
	settings = _settings()
	settings.rows[&"language"].pressed.emit()
	settings.language_options["pl"].pressed.emit()
	await get_tree().process_frame
	assert_eq(_nav.handle_back(), OK)
	assert_eq(_nav.current_screen(), _nav.Screen.HOME)
	assert_eq(_nav.level_slot(), 2)


func test_unbound_navigation_disables_both_settings_entry_points() -> void:
	_nav.configure_settings_host(null)
	_stage_slot("pl", 12)
	assert_eq(_nav.start(_host), OK)
	var button: IconButton = _nav.mounted_screen().find_child("Settings", true, false) as IconButton
	assert_true(button.disabled)
	assert_eq(_nav.go_to_level(12), OK)
	var level: LevelScreen = _nav.mounted_screen() as LevelScreen
	assert_true(level.p2_hud.settings.disabled)
