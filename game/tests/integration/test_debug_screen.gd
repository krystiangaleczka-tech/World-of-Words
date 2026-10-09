extends GutTest

const SAVE_SCRIPT = preload("res://services/save.gd")
const CONFIG_SCRIPT = preload("res://services/config.gd")
const CONTENT_SCRIPT = preload("res://services/content.gd")
const NAV_SCRIPT = preload("res://services/nav.gd")
const DEBUG_SCRIPT = preload("res://features/debug/debug.gd")
const PATH: String = "user://t0048-debug-screen.json"
const FIXTURE: String = "res://tests/fixtures/content"
var _locale: String


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1_790_000_000


class InterruptedStorage:
	extends SaveStorage
	var fail: bool = false

	func checkpoint(step: StringName) -> Error:
		return ERR_BUSY if fail and step == &"temp_written" else OK


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("pl")
	_clean()


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func _bundle(storage: SaveStorage = null, root: String = FIXTURE) -> Dictionary:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	var nav: NAV_SCRIPT = NAV_SCRIPT.new()
	var host: Control = Control.new()
	for service: ServiceStub in [save, config, content, nav]:
		add_child_autofree(service)
		service.initialize(FixedClock.new())
	add_child_autofree(host)
	save.configure(
		storage if storage != null else SaveStorage.new(PATH),
		func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	nav.configure(save, config, content)
	assert_eq(nav.start(host, root), OK if root == FIXTURE else ERR_FILE_NOT_FOUND)
	var economy: Dictionary = save.get_section(&"economy")
	economy["coins"] = 42
	assert_eq(save.set_section(&"economy", economy), OK)
	assert_eq(save.flush(), OK)
	assert_eq(nav.go_debug(), OK)
	return {"save": save, "content": content, "nav": nav, "screen": nav.mounted_screen()}


func _snapshot(save: SAVE_SCRIPT) -> Dictionary:
	var result: Dictionary = {}
	for section: StringName in SaveSchema.SECTIONS:
		result[section] = save.get_section(section)
	return result


func test_debug_route_mounts_versions() -> void:
	var bundle: Dictionary = _bundle()
	var screen: DEBUG_SCRIPT = bundle["screen"]
	assert_true(screen is ScreenScaffold)
	assert_eq(
		(screen.get_node("Safe/Body/AppVersion") as Label).text,
		"Wersja aplikacji: " + str(ProjectSettings.get_setting("application/config/version", ""))
	)
	assert_eq(
		(screen.get_node("Safe/Body/ContentVersion") as Label).text,
		"Wersja poziomów: " + str((bundle["content"] as CONTENT_SCRIPT).content_version())
	)
	assert_false((screen.get_node("Safe/Body/Confirm") as TextButton).visible)
	assert_false((screen.get_node("Safe/Body/Cancel") as TextButton).visible)


func test_confirmed_reset_returns_to_level_one() -> void:
	var bundle: Dictionary = _bundle()
	var save: SAVE_SCRIPT = bundle["save"]
	var screen: DEBUG_SCRIPT = bundle["screen"]
	var nav: NAV_SCRIPT = bundle["nav"]
	var prior: Dictionary = _snapshot(save)
	assert_eq(screen.confirm_reset(), ERR_UNCONFIGURED)
	assert_eq_deep(_snapshot(save), prior)
	(screen.get_node("Safe/Body/Reset") as TextButton).pressed.emit()
	assert_true((screen.get_node("Safe/Body/Confirm") as TextButton).visible)
	assert_eq_deep(_snapshot(save), prior)
	assert_eq(screen.confirm_reset(), OK)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.LEVEL)
	assert_eq(nav.level_slot(), 1)
	assert_true(nav.mounted_screen() is LevelScreen)
	assert_eq(save.get_section(&"economy")["coins"], 0)
	for section: StringName in [&"meta", &"settings", &"monetization"]:
		assert_eq_deep(save.get_section(section), prior[section])
	assert_eq(SaveStorage.new(PATH).read_document()["economy"]["coins"], 0)


func test_cancel_preserves_save() -> void:
	var bundle: Dictionary = _bundle()
	var save: SAVE_SCRIPT = bundle["save"]
	var screen: DEBUG_SCRIPT = bundle["screen"]
	var prior: Dictionary = _snapshot(save)
	screen.request_reset()
	(screen.get_node("Safe/Body/Cancel") as TextButton).pressed.emit()
	assert_false((screen.get_node("Safe/Body/Confirm") as TextButton).visible)
	assert_eq(screen.confirm_reset(), ERR_UNCONFIGURED)
	assert_eq_deep(_snapshot(save), prior)
	assert_eq((bundle["nav"] as NAV_SCRIPT).current_screen(), NAV_SCRIPT.Screen.DEBUG)


func test_reset_failure_keeps_debug_and_shows_error() -> void:
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	var bundle: Dictionary = _bundle(storage)
	var save: SAVE_SCRIPT = bundle["save"]
	var screen: DEBUG_SCRIPT = bundle["screen"]
	var nav: NAV_SCRIPT = bundle["nav"]
	var prior: Dictionary = _snapshot(save)
	storage.fail = true
	screen.request_reset()
	assert_eq(screen.confirm_reset(), ERR_BUSY)
	assert_eq_deep(_snapshot(save), prior)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.DEBUG)
	assert_same(nav.mounted_screen(), screen)
	assert_eq((screen.get_node("Safe/Body/Status") as Label).text, "Nie udało się zakończyć resetu")
	assert_false((screen.get_node("Safe/Body/Confirm") as TextButton).disabled)
	storage.fail = false
	assert_eq(screen.confirm_reset(), OK)


func test_polish_and_english_copy() -> void:
	var bundle: Dictionary = _bundle()
	var screen: DEBUG_SCRIPT = bundle["screen"]
	var reset: TextButton = screen.get_node("Safe/Body/Reset") as TextButton
	assert_eq(reset.text, "Resetuj postęp")
	screen.request_reset()
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(reset.text, "Reset progress")
	assert_eq((screen.get_node("Safe/Body/Title") as Label).text, "Developer tools")
	assert_eq(
		(screen.get_node("Safe/Body/Status") as Label).text, "Confirm clearing progress and coins"
	)
	TranslationServer.set_locale("pl")
	await get_tree().process_frame
	assert_eq(reset.text, "Resetuj postęp")


func test_missing_content_still_shows_diagnostics_and_failed_navigation() -> void:
	var bundle: Dictionary = _bundle(null, "res://tests/fixtures/missing")
	var screen: DEBUG_SCRIPT = bundle["screen"]
	var nav: NAV_SCRIPT = bundle["nav"]
	assert_eq((screen.get_node("Safe/Body/ContentVersion") as Label).text, "Wersja poziomów: 0")
	screen.request_reset()
	assert_eq(screen.confirm_reset(), ERR_INVALID_PARAMETER)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.DEBUG)
	assert_same(nav.mounted_screen(), screen)
	assert_eq((screen.get_node("Safe/Body/Status") as Label).text, "Nie udało się zakończyć resetu")
	(screen.get_node("Safe/Body/Home") as TextButton).pressed.emit()
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.HOME)
