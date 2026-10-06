extends GutTest

const NAV_SCRIPT = preload("res://services/nav.gd")
const SAVE_SCRIPT = preload("res://services/save.gd")
const CONFIG_SCRIPT = preload("res://services/config.gd")
const CONTENT_SCRIPT = preload("res://services/content.gd")
const FIXTURE: String = "res://tests/fixtures/content"
const SAVE_PATH: String = "user://t0043-nav-save.json"
const GOLDEN: String = "res://tests/fixtures/save/v1.json"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1_790_000_000

	func monotonic_msec() -> int:
		return 0


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(SAVE_PATH + suffix)


func _write_save(slot: int) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	data["progress"]["by_lang"]["pl"]["current_slot"] = slot
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _nav() -> NAV_SCRIPT:
	var clock: FixedClock = FixedClock.new()
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	var nav: NAV_SCRIPT = NAV_SCRIPT.new()
	for service: ServiceStub in [save, config, content, nav]:
		add_child_autofree(service)
		service.initialize(clock)
	save.configure(
		SaveStorage.new(SAVE_PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	nav.configure(save, config, content)
	return nav


func _host() -> Node:
	var host: Node = Node.new()
	add_child_autofree(host)
	return host


func test_fresh_install_boots_into_level_one() -> void:
	var nav: NAV_SCRIPT = _nav()
	watch_signals(nav)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.BOOT)
	assert_eq(nav.start(_host(), FIXTURE), OK)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.LEVEL)
	assert_eq(nav.level_slot(), 1)
	assert_signal_emitted_with_parameters(nav, "screen_changed", [NAV_SCRIPT.Screen.LEVEL])
	assert_signal_not_emitted(nav, "boot_failed")
	assert_true(FileAccess.file_exists(SAVE_PATH), "boot loads (and creates) the save")


func test_returning_player_resumes_saved_slot() -> void:
	_write_save(3)
	var nav: NAV_SCRIPT = _nav()
	assert_eq(nav.start(_host(), FIXTURE), OK)
	assert_eq(nav.level_slot(), 3)


func test_saved_slot_beyond_content_is_clamped() -> void:
	_write_save(9)
	var nav: NAV_SCRIPT = _nav()
	assert_eq(nav.start(_host(), FIXTURE), OK)
	assert_eq(nav.level_slot(), 3)


func test_missing_content_fails_boot_and_stays_on_boot() -> void:
	var nav: NAV_SCRIPT = _nav()
	watch_signals(nav)
	assert_eq(nav.start(_host(), "res://tests/fixtures/missing"), ERR_FILE_NOT_FOUND)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.BOOT)
	assert_signal_emitted_with_parameters(nav, "boot_failed", [ERR_FILE_NOT_FOUND])
	assert_signal_not_emitted(nav, "screen_changed")


func test_home_only_after_boot_and_back_to_level() -> void:
	var nav: NAV_SCRIPT = _nav()
	assert_eq(nav.go_home(), ERR_UNCONFIGURED)
	nav.start(_host(), FIXTURE)
	assert_eq(nav.go_home(), OK)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.HOME)
	assert_eq(nav.go_to_level(2), OK)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.LEVEL)
	assert_eq(nav.level_slot(), 2)


func test_unknown_slot_is_rejected_without_changing_screen() -> void:
	var nav: NAV_SCRIPT = _nav()
	assert_eq(nav.go_to_level(1), ERR_INVALID_PARAMETER)
	nav.start(_host(), FIXTURE)
	for slot: int in [0, 4]:
		assert_eq(nav.go_to_level(slot), ERR_INVALID_PARAMETER)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.LEVEL)
	assert_eq(nav.level_slot(), 1)


func test_screens_without_scene_files_mount_nothing() -> void:
	var nav: NAV_SCRIPT = _nav()
	var host: Node = _host()
	nav.start(host, FIXTURE)
	assert_null(nav.mounted_screen())
	assert_eq(host.get_child_count(), 0)
