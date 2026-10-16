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


class FailingProgress:
	extends "res://services/progress.gd"

	func complete_level(_slot: int) -> Error:
		return ERR_CANT_CREATE


class GateStorage:
	extends SaveStorage
	var blocked: bool = false

	func checkpoint(_step: StringName) -> Error:
		return ERR_CANT_CREATE if blocked else OK


var _previous: AnalyticsAdapter
var _fake: AnalyticsFake
var _analytics: Node
var _save: SAVE_SCRIPT
var _config: CONFIG_SCRIPT
var _content: CONTENT_SCRIPT
var _events: EVENTS_SCRIPT
var _nav: FakeNav
var _clock: FixedClock
var _storage: GateStorage


func before_each() -> void:
	_previous = Platform.analytics
	_fake = AnalyticsFake.new()
	Platform.analytics = _fake
	_clear_storage()
	DirAccess.make_dir_recursive_absolute(ROOT)
	_clock = FixedClock.new()
	_save = SAVE_SCRIPT.new()
	_save.initialize(_clock)
	_storage = GateStorage.new(ROOT + "/save.json")
	_save.configure(_storage, func() -> String: return INSTALL_ID)
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
	_analytics._begin_listener_boot()
	_analytics._finish_listener_boot(true)


func after_each() -> void:
	Platform.analytics = _previous
	_clear_storage()


func _clear_storage() -> void:
	var directory: DirAccess = DirAccess.open(ROOT)
	if directory != null:
		for filename: String in directory.get_files():
			DirAccess.remove_absolute(ROOT + "/" + filename)
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
	_events.bonus_found.emit("TOK")
	_events.bonus_found.emit("TOK")
	_events.invalid_word.emit("ŻÓŁĆ")
	_events.hint_used.emit()
	_events.shuffle_performed.emit(1)
	_events.stars_earned.emit("pl", 1, 2)
	_clock.ticks = 1250
	_events.level_completed.emit(1)
	_events.level_completed.emit(1)
	await get_tree().process_frame
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
	assert_eq(migrated.last_load_report(), {"corrupted": false, "from_version": 3, "to_version": 4})
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
	assert_eq(recovered.last_load_report(), {"corrupted": true, "from_version": 0, "to_version": 0})
	for path: String in [migrated_path, broken_path]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func test_controller_final_word_and_final_hint_are_included_before_completion() -> void:
	_events.consent_changed.emit(true)
	_nav.enter(1, 1)
	var controller: LevelController = LevelController.new()
	add_child_autofree(controller)
	controller.configure(BoardState.new(_content.level_for_slot(1)), null, _events, false)
	controller.submit(PackedInt32Array([0, 1, 2]))
	await get_tree().process_frame
	assert_eq(_occurrences("word_found"), 1)
	assert_eq(_occurrences("level_complete"), 1)
	assert_lt(_names().find("word_found"), _names().find("level_complete"))
	_fake.calls.entries.clear()
	_nav.enter(1, 1)
	controller.configure(BoardState.new(_content.level_for_slot(1)), null, _events, false)
	for index: int in range(3):
		assert_true(controller.hint())
	await get_tree().process_frame
	assert_eq(_params("level_complete")["hints_used"], 3)
	assert_eq(_occurrences("hint_used"), 0)


func test_failed_controller_persistence_does_not_emit_successful_completion() -> void:
	_events.consent_changed.emit(true)
	_nav.enter(1, 1)
	var controller: LevelController = LevelController.new()
	var progress: FailingProgress = FailingProgress.new()
	add_child_autofree(controller)
	add_child_autofree(progress)
	controller.configure(BoardState.new(_content.level_for_slot(1)), progress, _events)
	assert_null(controller.submit(PackedInt32Array([0, 1, 2])))
	await get_tree().process_frame
	assert_eq(_occurrences("word_found"), 0)
	assert_eq(_occurrences("level_complete"), 0)


func test_completion_survives_immediate_navigation_and_visit_counters_reset() -> void:
	_events.consent_changed.emit(true)
	_nav.enter(1, 1)
	_events.hint_used.emit()
	_events.stars_earned.emit("en", 1, 3)
	_events.stars_earned.emit("pl", 2, 3)
	_clock.ticks = 900
	_events.level_completed.emit(2)
	assert_eq(_occurrences("level_complete"), 0)
	_events.level_completed.emit(1)
	_nav.enter(2)
	assert_eq(_params("level_complete")["duration_ms"], 0)
	assert_eq(_params("level_complete")["hints_used"], 1)
	assert_eq(_params("level_complete")["stars"], 0)
	_fake.calls.entries.clear()
	_nav.enter(1, 2)
	_events.level_completed.emit(1)
	_events.level_completed.emit(2)
	await get_tree().process_frame
	assert_eq(_occurrences("level_complete"), 1)
	assert_eq(_params("level_complete")["slot"], 2)
	assert_eq(_params("level_complete")["hints_used"], 0)
	assert_eq(_params("level_complete")["bonus_words"], 0)


func test_repeated_boot_setup_and_failed_boot_do_not_fabricate_boot_diagnostics() -> void:
	_events.consent_changed.emit(true)
	_analytics._begin_listener_boot()
	_nav.enter(1, 1)
	_analytics._finish_listener_boot(true)
	assert_eq(_occurrences("app_boot"), 1)
	assert_eq(_occurrences("level_start"), 1)
	var other: FakeNav = FakeNav.new()
	add_child_autofree(other)
	assert_eq(_analytics.configure_listener(_save, _content, other, _clock), OK)
	_analytics._begin_listener_boot()
	other.enter(1, 1)
	_analytics._finish_listener_boot(false)
	assert_eq(_occurrences("app_boot"), 1)
	assert_eq(_occurrences("level_start"), 1)
	_nav.enter(1, 2)
	assert_eq(_occurrences("level_start"), 1, "Old navigation was disconnected")
	_analytics._begin_listener_boot()
	other.enter(1, 1)
	_analytics._finish_listener_boot(true)
	assert_eq(_occurrences("app_boot"), 2)
	assert_eq(_occurrences("level_start"), 2)


func test_lifecycle_settings_and_listener_teardown_use_live_owners_only() -> void:
	_events.consent_changed.emit(true)
	var listener: Node = _analytics.get_child(0)
	listener.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	listener.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	listener.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	listener.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	listener.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(_occurrences("app_background"), 1)
	assert_eq(_occurrences("app_foreground"), 1)
	_storage.blocked = true
	assert_eq(_save.set_setting(&"sfx_volume", 0.0), ERR_CANT_CREATE)
	assert_eq(_occurrences("settings_changed"), 0)
	_storage.blocked = false
	assert_eq(_save.flush(), OK)
	assert_eq(_params("settings_changed")["setting"], "sfx_volume")
	assert_false(_params("settings_changed").has("value"))
	listener.free()
	var count: int = _fake.calls.entries.size()
	_events.invalid_word.emit("NIE")
	_events.feature_unlocked.emit("pl", &"hint", 7)
	_nav.enter(1, 1)
	assert_eq(_fake.calls.entries.size(), count)


func test_already_found_kind_malformed_economy_and_unavailable_attribution() -> void:
	_events.consent_changed.emit(true)
	_nav.enter(1, 1)
	_events.already_found.emit("TOK")
	assert_eq(_params("already_found_word")["kind"], "bonus")
	_fake.calls.entries.clear()
	_events.already_found.emit("KOT")
	assert_eq(_params("already_found_word")["kind"], "level")
	_events.economy_changed.emit(&"unknown", &"hint", {"coins": 1}, {})
	_events.economy_changed.emit(&"spend", &"hint", {"coins": -1}, {})
	_events.economy_changed.emit(&"grant", &"hint", {"coins": "1"}, {})
	assert_eq(_occurrences("economy_spend"), 0)
	assert_eq(_occurrences("economy_grant"), 0)
	_nav.slot = 2
	_events.invalid_word.emit("STALE")
	assert_eq(_occurrences("invalid_word_submitted"), 0)
	_nav.enter(1, 99)
	_events.invalid_word.emit("MISSING")
	assert_eq(_occurrences("invalid_word_submitted"), 0)


func test_stub_and_full_queue_cannot_change_gameplay_outcomes() -> void:
	var stub: ANALYTICS_SCRIPT = ANALYTICS_SCRIPT.new()
	add_child_autofree(stub)
	assert_eq(stub.configure_stub(1), OK)
	assert_eq(stub.configure_listener(_save, _content, _nav, _clock), ERR_UNCONFIGURED)
	var capacity: int = _config.get_int(&"analytics.queue.max_events")
	for index: int in range(capacity - _analytics.pending_count()):
		assert_eq(_analytics.track(&"app_boot"), OK)
	_nav.enter(1, 1)
	var controller: LevelController = LevelController.new()
	add_child_autofree(controller)
	controller.configure(BoardState.new(_content.level_for_slot(1)), null, _events, false)
	assert_not_null(controller.submit(PackedInt32Array([0, 1, 2])))
	await get_tree().process_frame
	assert_true(controller.is_complete())
	assert_eq(_analytics.pending_count(), capacity)
	assert_eq(_fake.calls.entries.size(), 0)


func _write_document(path: String, document: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(document, "", true, true))
	file.close()


func test_startup_reports_actual_upgrade_backup_and_compatibility_outcomes_once() -> void:
	_events.consent_changed.emit(true)
	for version: int in [1, 2, 3, 4]:
		var path: String = ROOT + "/v%d.json" % version
		var source: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/save/v%d.json" % version)
		)
		_write_document(path, source)
		var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
		add_child_autofree(save)
		save.initialize(_clock)
		save.configure(SaveStorage.new(path))
		assert_eq(save.load(), OK)
		assert_eq(_analytics.start_runtime(save, _config, _content, _events), OK)
		assert_eq(_analytics.configure_listener(save, _content, _nav, _clock), OK)
		_fake.calls.entries.clear()
		_analytics._begin_listener_boot()
		_analytics._finish_listener_boot(true)
		_analytics._begin_listener_boot()
		_analytics._finish_listener_boot(true)
		assert_eq(_occurrences("app_boot"), 1)
		assert_eq(_occurrences("save_corrupted"), 0)
		assert_eq(_occurrences("save_migrated"), 1 if version < 4 else 0)
		if version < 4:
			assert_eq(_params("save_migrated")["from_version"], version)
			assert_eq(_params("save_migrated")["to_version"], 4)
	for compatibility: bool in [false, true]:
		var path: String = ROOT + "/recovery%s.json" % compatibility
		var source: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(
				"res://tests/fixtures/save/v%d.json" % (3 if compatibility else 4)
			)
		)
		if compatibility:
			source["meta"]["atomic"] = {"legacy": "preserve"}
		_write_document(path + ".bak", source)
		_write_document(path, {"invalid": true})
		var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
		add_child_autofree(save)
		save.initialize(_clock)
		save.configure(SaveStorage.new(path))
		assert_eq(save.load(), OK)
		assert_eq(save.last_load_report(), {"corrupted": false, "from_version": 0, "to_version": 0})
		assert_eq(_analytics.start_runtime(save, _config, _content, _events), OK)
		assert_eq(_analytics.configure_listener(save, _content, _nav, _clock), OK)
		_fake.calls.entries.clear()
		_analytics._begin_listener_boot()
		_analytics._finish_listener_boot(true)
		assert_eq(_occurrences("save_migrated"), 0)
		assert_eq(_occurrences("save_corrupted"), 0)


func test_corrupt_save_diagnostic_waits_for_successful_boot() -> void:
	var path: String = ROOT + "/corrupt.json"
	_write_document(path, {"invalid": true})
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(_clock)
	save.configure(SaveStorage.new(path), func() -> String: return INSTALL_ID)
	assert_eq(save.load(), OK)
	assert_eq(_analytics.start_runtime(save, _config, _content, _events), OK)
	assert_eq(_analytics.configure_listener(save, _content, _nav, _clock), OK)
	_events.consent_changed.emit(true)
	_fake.calls.entries.clear()
	_analytics._begin_listener_boot()
	_analytics._finish_listener_boot(false)
	assert_eq(_fake.calls.entries.size(), 0)
	_analytics._begin_listener_boot()
	_analytics._finish_listener_boot(true)
	assert_eq(_occurrences("save_corrupted"), 1)
	assert_eq(_params("save_corrupted")["schema_version"], 0)


func test_pending_completion_keeps_original_context_when_runtime_owners_change() -> void:
	_events.consent_changed.emit(true)
	_nav.enter(1, 1)
	_events.level_completed.emit(1)
	var other: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(other)
	other.initialize(_clock)
	other.configure(
		SaveStorage.new(ROOT + "/other.json"),
		func() -> String: return "123e4567-e89b-42d3-a456-426614174001"
	)
	assert_eq(other.load(), OK)
	assert_eq(_analytics.start_runtime(other, _config, _content, _events), OK)
	assert_eq(_params("level_complete")["install_id"], INSTALL_ID)
	assert_eq(_analytics.configure_listener(other, _content, _nav, _clock), OK)
	await get_tree().process_frame
	assert_eq(_occurrences("level_complete"), 1)


func test_real_economy_and_progress_receipts_reach_listener_after_commit() -> void:
	_events.consent_changed.emit(true)
	assert_eq(_content.load_manifest("pl", "res://content"), OK)
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(_clock)
	save.configure(SaveStorage.new(ROOT + "/receipts.json"), func() -> String: return INSTALL_ID)
	var economy: Node = load("res://services/economy.gd").new()
	var progress: Node = load("res://services/progress.gd").new()
	add_child_autofree(economy)
	add_child_autofree(progress)
	economy.initialize(_clock)
	progress.initialize(_clock)
	economy.configure(save, _config, _events)
	progress.configure(save, _content)
	assert_eq(progress.configure_atomic(_config), OK)
	var port: AtomicProgressPort = AtomicProgressPort.new()
	assert_eq(port.configure(save, progress, economy), OK)
	assert_eq(save.load(), OK)
	assert_eq(progress.configure_p2(_config, port, _events), OK)
	assert_eq(_analytics.start_runtime(save, _config, _content, _events), OK)
	assert_eq(_analytics.configure_listener(save, _content, _nav, _clock), OK)
	assert_eq(economy.grant(&"earned", {"coins": 12}), OK)
	assert_true(economy.spend(&"hint", {"coins": 7}))
	assert_eq(_params("economy_grant")["coins"], 12)
	assert_eq(_params("economy_spend")["coins"], 7)
	_nav.enter(1, 1)
	var level: LevelData = _content.level_for_slot(1)
	var board: BoardState = BoardState.new(level)
	for index: int in range(level.word_count()):
		for cell: Vector2i in level.word_cells(index):
			board.reveal_cell(cell)
	assert_eq(progress.bind_board(board), OK)
	assert_eq(progress.complete_level(1), OK)
	_events.level_completed.emit(1)
	await get_tree().process_frame
	assert_eq(_occurrences("stars_earned"), 1)
	assert_eq(_params("level_complete")["stars"], _params("stars_earned")["stars"])
