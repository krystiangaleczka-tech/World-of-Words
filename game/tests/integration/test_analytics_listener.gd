extends GutTest

const ANALYTICS_SCRIPT: Script = preload("res://services/analytics.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const ROOT: String = "user://t0251-analytics-listener"
const INSTALL_ID: String = "123e4567-e89b-42d3-a456-426614174000"


class FakeNav:
	extends Node
	signal screen_changed(screen: int)
	var screen: int = 0
	var slot: int = 0

	func enter(next_screen: int, next_slot: int = 0) -> void:
		screen = next_screen
		slot = next_slot
		screen_changed.emit(next_screen)

	func current_screen() -> int:
		return screen

	func level_slot() -> int:
		return slot


class FixedClock:
	extends Clock
	var ticks: int = 1000

	func monotonic_msec() -> int:
		return ticks


var _previous: AnalyticsAdapter
var _fake: AnalyticsFake
var _analytics: Node
var _save: SAVE_SCRIPT
var _config: CONFIG_SCRIPT
var _content: CONTENT_SCRIPT
var _events: EVENTS_SCRIPT
var _nav: FakeNav
var _clock: FixedClock


func before_each() -> void:
	_previous = Platform.analytics
	_fake = AnalyticsFake.new()
	Platform.analytics = _fake
	_clear_storage()
	DirAccess.make_dir_recursive_absolute(ROOT)
	_clock = FixedClock.new()
	_save = SAVE_SCRIPT.new()
	_save.initialize(_clock)
	_save.configure(SaveStorage.new(ROOT + "/save.json"), func() -> String: return INSTALL_ID)
	add_child_autofree(_save)
	assert_eq(_save.load(), OK)
	_config = CONFIG_SCRIPT.new()
	add_child_autofree(_config)
	assert_eq(_config.load(), OK)
	_content = CONTENT_SCRIPT.new()
	add_child_autofree(_content)
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/content"), OK)
	_events = EVENTS_SCRIPT.new()
	add_child_autofree(_events)
	_nav = FakeNav.new()
	add_child_autofree(_nav)
	_analytics = ANALYTICS_SCRIPT.new()
	add_child_autofree(_analytics)
	assert_eq(
		_analytics.start_runtime(
			_save,
			_config,
			_content,
			_events,
			AnalyticsQueue.new(SaveStorage.new(ROOT + "/queue.json"))
		),
		OK
	)
	assert_eq(_analytics.configure_listener(_save, _content, _nav, _clock), OK)


func after_each() -> void:
	Platform.analytics = _previous
	_clear_storage()


func _clear_storage() -> void:
	for filename: String in ["save.json", "queue.json"]:
		for suffix: String in ["", ".tmp", ".bak"]:
			var path: String = ROOT + "/" + filename + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(ROOT):
		DirAccess.remove_absolute(ROOT)


func _names() -> Array[String]:
	var values: Array[String] = []
	for entry: Dictionary in _fake.calls.entries:
		values.append(str(entry["arguments"][0]))
	return values


func _params(name: String) -> Dictionary:
	for entry: Dictionary in _fake.calls.entries:
		if entry["arguments"][0] == name:
			return (entry["arguments"][1] as Dictionary).duplicate(true)
	return {}


func _occurrences(name: String) -> int:
	return _names().count(name)


func test_boot_listener_is_idempotent_and_respects_consent_fifo() -> void:
	assert_eq(_analytics.configure_listener(_save, _content, _nav, _clock), OK)
	_nav.enter(1, 1)
	assert_eq(_fake.calls.entries.size(), 0)
	assert_eq(_analytics.pending_count(), 4)
	_events.consent_changed.emit(true)
	assert_eq(_names(), ["app_boot", "content_version_loaded", "nav_screen", "level_start"])
	assert_eq(_params("nav_screen")["screen"], "LEVEL")
	var level: LevelData = _content.level_for_slot(1)
	assert_eq(_params("level_start")["level_id"], level.get_id())
	_nav.enter(2)
	assert_eq(_params("nav_screen")["screen"], "LEVEL")
	assert_eq(_occurrences("app_boot"), 1)


func test_word_telemetry_keeps_unicode_and_completion_uses_committed_counts() -> void:
	_events.consent_changed.emit(true)
	_nav.enter(1, 1)
	_events.word_found.emit("KOT")
	_events.bonus_found.emit("TEST")
	_events.bonus_found.emit("TEST")
	_events.invalid_word.emit("ŻÓŁĆ")
	_events.hint_used.emit()
	_events.shuffle_performed.emit(1)
	_events.stars_earned.emit("pl", 1, 2)
	_clock.ticks = 1250
	_events.level_completed.emit(1)
	_events.level_completed.emit(1)
	assert_eq(_occurrences("level_complete"), 1)
	assert_eq(_params("invalid_word_submitted")["letters"], "ŻÓŁĆ")
	assert_eq(_params("invalid_word_submitted")["language"], "pl")
	assert_eq(_occurrences("bonus_word_found"), 1)
	assert_eq(_occurrences("shuffle_used"), 1)
	assert_eq(_occurrences("hint_used"), 0)
	var completed: Dictionary = _params("level_complete")
	assert_eq(completed["duration_ms"], 250)
	assert_eq(completed["hints_used"], 1)
	assert_eq(completed["reveals_used"], 0)
	assert_eq(completed["bonus_words"], 1)
	assert_eq(completed["stars"], 2)


func test_domain_events_have_only_registered_fields() -> void:
	_events.consent_changed.emit(true)
	_events.economy_changed.emit(&"grant", &"level_complete", {"coins": 12, "hint": 1}, {})
	_events.economy_changed.emit(&"spend", &"hint", {"coins": 7}, {})
	_events.stars_earned.emit("pl", 1, 3)
	_events.postcard_piece_revealed.emit("pl", "site_1", 2)
	_events.location_complete.emit("pl", "site_1")
	_events.feature_unlocked.emit("pl", &"hint", 3)
	assert_eq(_params("economy_grant")["coins"], 12)
	assert_eq(_params("economy_grant")["hint"], 1)
	assert_eq(_params("economy_grant")["reveal"], 0)
	assert_eq(_params("economy_spend")["coins"], 7)
	assert_eq(_params("stars_earned")["stars"], 3)
	assert_eq(_params("postcard_piece_revealed")["pieces"], 2)
	assert_eq(_params("location_complete")["location_id"], "site_1")
	assert_eq(_params("feature_unlocked")["feature"], "hint")


func test_navigation_clears_attribution_and_denial_discards_pending() -> void:
	_nav.enter(1, 1)
	_nav.enter(2)
	_events.invalid_word.emit("NIE")
	_events.shuffle_performed.emit(1)
	_events.consent_changed.emit(false)
	assert_eq(_analytics.pending_count(), 0)
	assert_eq(_fake.calls.entries.size(), 0)
	_events.consent_changed.emit(true)
	assert_eq(_occurrences("invalid_word_submitted"), 0)
	assert_eq(_occurrences("shuffle_used"), 0)
	_nav.enter(1, 1)
	_events.invalid_word.emit("TAK")
	assert_eq(_params("invalid_word_submitted")["letters"], "TAK")


func test_last_load_report_is_copied_and_fresh_is_not_migrated() -> void:
	var report: Dictionary = _save.last_load_report()
	assert_eq(report, {"corrupted": false, "from_version": 0, "to_version": 0})
	report["corrupted"] = true
	assert_false(_save.last_load_report()["corrupted"])
	_events.consent_changed.emit(true)
	assert_eq(_occurrences("save_migrated"), 0)
	assert_eq(_occurrences("save_corrupted"), 0)


func test_load_report_detects_actual_v3_upgrade_and_corrupt_original() -> void:
	var legacy: String = FileAccess.get_file_as_string("res://tests/fixtures/save/v3.json")
	var migrated_path: String = ROOT + "/legacy.json"
	var file: FileAccess = FileAccess.open(migrated_path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(legacy)
	file.close()
	var migrated: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(migrated)
	migrated.initialize(_clock)
	migrated.configure(SaveStorage.new(migrated_path))
	assert_eq(migrated.load(), OK)
	assert_eq(
		migrated.last_load_report(),
		{"corrupted": false, "from_version": 3, "to_version": 4}
	)
	var broken_path: String = ROOT + "/broken.json"
	var bad_file: FileAccess = FileAccess.open(broken_path, FileAccess.WRITE)
	assert_not_null(bad_file)
	bad_file.store_string("{bad json")
	bad_file.close()
	var recovered: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(recovered)
	recovered.initialize(_clock)
	recovered.configure(SaveStorage.new(broken_path), func() -> String: return INSTALL_ID)
	assert_eq(recovered.load(), OK)
	assert_eq(
		recovered.last_load_report(),
		{"corrupted": true, "from_version": 0, "to_version": 0}
	)
	for path: String in [migrated_path, broken_path]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
