extends GutTest

const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const ANALYTICS_SCRIPT: Script = preload("res://services/analytics.gd")
const CACHE: String = "user://t0255-config-cache.json"
const SAVE_PATH: String = "user://t0255-save.json"
const QUEUE_PATH: String = "user://t0255-analytics-queue.json"
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const INSTALL: String = "123e4567-e89b-42d3-a456-426614174000"
const TUNABLE: StringName = &"ads.interstitial.min_levels_between"


class FailingStorage:
	extends SaveStorage
	var fail_step: StringName = &""

	func checkpoint(step: StringName) -> Error:
		return ERR_CANT_CREATE if step == fail_step else OK


class FaultyConfig:
	extends "res://services/config.gd"
	var storage: FailingStorage
	var fail_cleanup: bool = false

	func _create_cache(path: String) -> SaveStorage:
		storage = FailingStorage.new(path)
		return storage

	func _discard_cache_temp() -> Error:
		return ERR_CANT_CREATE if fail_cleanup else super()


class CallbackFake:
	extends AnalyticsFake
	var on_log: Callable
	var on_property: Callable

	func log_event(name: String, params: Dictionary) -> void:
		super.log_event(name, params)
		if on_log.is_valid():
			on_log.call()

	func set_user_property(key: String, value: String) -> void:
		super.set_user_property(key, value)
		if on_property.is_valid():
			on_property.call()


var _config: CONFIG_SCRIPT
var _analytics: ANALYTICS_SCRIPT
var _previous: AnalyticsAdapter
var _fake: AnalyticsFake


func before_each() -> void:
	_clear()
	_previous = Platform.analytics
	_fake = AnalyticsFake.new()
	Platform.analytics = _fake
	_config = CONFIG_SCRIPT.new()
	add_child_autofree(_config)
	assert_eq(_config.load(), OK)
	_analytics = ANALYTICS_SCRIPT.new()
	add_child_autofree(_analytics)
	assert_eq(_analytics.load(), OK)
	assert_eq(_analytics.configure_stub(30), OK)


func after_each() -> void:
	Platform.analytics = _previous
	_clear()


func _clear() -> void:
	for path: String in [CACHE, SAVE_PATH, QUEUE_PATH]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func _document(value: int = 5) -> Dictionary:
	return {
		"version": 1,
		"values": {str(TUNABLE): value},
		"experiments":
		[
			{
				"id": "ad_frequency",
				"variants": [{"id": "control", "weight": 50}, {"id": "variant", "weight": 50}]
			}
		]
	}


func _reboot() -> CONFIG_SCRIPT:
	var service: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	add_child_autofree(service)
	assert_eq(service.load(), OK)
	assert_eq(service.start_remote(INSTALL, _analytics, "", CACHE), OK)
	return service


func test_default_cache_then_valid_remote_and_offline_restart() -> void:
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), OK)
	assert_eq(_config.get_int(TUNABLE), 4)
	assert_eq(_config.accept_remote_document(_document()), OK)
	assert_eq(_config.get_int(TUNABLE), 5)
	assert_eq(_config.get_int(&"ads.interstitial.first_slot"), 16)
	assert_true(FileAccess.file_exists(CACHE))
	assert_eq(_reboot().get_int(TUNABLE), 5)


func test_invalid_candidate_and_failed_http_keep_last_valid() -> void:
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), OK)
	assert_eq(_config.accept_remote_document(_document()), OK)
	assert_eq(_config.accept_remote_document({}), ERR_INVALID_DATA)
	_config.call(
		"_on_remote_finished",
		HTTPRequest.RESULT_SUCCESS,
		503,
		PackedStringArray(),
		JSON.stringify(_document(8)).to_utf8_buffer()
	)
	_config.call(
		"_on_remote_finished",
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		"{broken".to_utf8_buffer()
	)
	assert_eq(_config.get_int(TUNABLE), 5)
	assert_eq(_reboot().get_int(TUNABLE), 5)


func test_json_http_decoding_handles_integral_numbers_without_losing_validation() -> void:
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), OK)
	_config.call(
		"_on_remote_finished",
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		JSON.stringify(_document(6)).to_utf8_buffer()
	)
	assert_eq(_config.get_int(TUNABLE), 6)
	assert_eq(_reboot().get_int(TUNABLE), 6)


func test_cache_recovers_valid_backup_when_primary_corrupt() -> void:
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), OK)
	assert_eq(_config.accept_remote_document(_document(5)), OK)
	assert_eq(_config.accept_remote_document(_document(6)), OK)
	var corrupted: FileAccess = FileAccess.open(CACHE, FileAccess.WRITE)
	assert_not_null(corrupted)
	corrupted.store_string("{bad json")
	corrupted.close()
	assert_eq(_reboot().get_int(TUNABLE), 5)


func test_failed_writes_preserve_last_valid_cache_and_activation() -> void:
	for step: StringName in [&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated"]:
		_clear()
		var service: FaultyConfig = FaultyConfig.new()
		add_child_autofree(service)
		assert_eq(service.load(), OK)
		assert_eq(service.start_remote(INSTALL, _analytics, "", CACHE), OK)
		assert_eq(service.accept_remote_document(_document(5)), OK)
		service.storage.fail_step = step
		assert_eq(service.accept_remote_document(_document(7)), ERR_CANT_CREATE)
		assert_eq(service.get_int(TUNABLE), 5)
		assert_eq(_reboot().get_int(TUNABLE), 5)


func test_recovered_temp_and_backup_survive_interrupted_replacement() -> void:
	for suffix: String in [".tmp", ".bak"]:
		_clear()
		var file: FileAccess = FileAccess.open(CACHE + suffix, FileAccess.WRITE)
		file.store_string(JSON.stringify(_document(5)))
		file.close()
		var corrupt: FileAccess = FileAccess.open(CACHE, FileAccess.WRITE)
		corrupt.store_string("{broken")
		corrupt.close()
		var service: FaultyConfig = FaultyConfig.new()
		add_child_autofree(service)
		assert_eq(service.load(), OK)
		assert_eq(service.start_remote(INSTALL, _analytics, "", CACHE), OK)
		assert_eq(service.get_int(TUNABLE), 5)
		service.storage.fail_step = &"temp_written"
		assert_eq(service.accept_remote_document(_document(7)), ERR_CANT_CREATE)
		assert_eq(_reboot().get_int(TUNABLE), 5)
		service.storage.fail_step = &"primary_promoted"
		assert_eq(service.accept_remote_document(_document(7)), OK)
		assert_eq(service.get_int(TUNABLE), 7)
		assert_eq(_reboot().get_int(TUNABLE), 7)


func test_incompatible_experiment_ids_and_wrong_typed_reads_are_rejected() -> void:
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), OK)
	assert_eq(_config.accept_remote_document(_document(5)), OK)
	var invalid: Dictionary = _document(7)
	invalid["experiments"][0]["id"] = "Bad-Id"
	assert_eq(_config.accept_remote_document(invalid), ERR_INVALID_DATA)
	assert_eq(_config.get_int(TUNABLE), 5)
	assert_eq(_reboot().get_int(TUNABLE), 5)
	assert_eq(_config.get_string(TUNABLE), "")
	assert_push_error(str(TUNABLE))


func test_failed_cleanup_cannot_resurrect_a_rejected_candidate() -> void:
	var service: FaultyConfig = FaultyConfig.new()
	add_child_autofree(service)
	assert_eq(service.load(), OK)
	assert_eq(service.start_remote(INSTALL, _analytics, "", CACHE), OK)
	assert_eq(service.accept_remote_document(_document(5)), OK)
	service.storage.fail_step = &"backup_rotated"
	service.fail_cleanup = true
	assert_eq(service.accept_remote_document(_document(7)), ERR_CANT_CREATE)
	assert_eq(service.get_int(TUNABLE), 5)
	assert_true(FileAccess.file_exists(CACHE + ".tmp"))
	assert_eq(_reboot().get_int(TUNABLE), 5)
	# If canonical restore itself cannot complete, prefer the last accepted backup over temp.
	assert_eq(DirAccess.rename_absolute(CACHE, CACHE + ".bak"), OK)
	assert_eq(_reboot().get_int(TUNABLE), 5)


func test_assignments_are_tracked_using_registered_analytics_event() -> void:
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), OK)
	assert_eq(_config.accept_remote_document(_document()), OK)
	assert_eq(_analytics.flush(), OK)
	var expected_bucket: int = RemoteConfigContract.bucket(INSTALL, "ad_frequency")
	var found_assignment: bool = false
	var found_applied: bool = false
	for entry: Dictionary in _fake.calls.entries:
		var arguments: Array = entry["arguments"]
		if arguments[0] == "experiment_assigned":
			found_assignment = true
			assert_eq(arguments[1]["experiment_id"], "ad_frequency")
			assert_eq(arguments[1]["bucket"], expected_bucket)
		elif arguments[0] == "remote_config_applied":
			found_applied = true
	assert_true(found_assignment)
	assert_true(found_applied)


func test_https_endpoint_validation_does_not_block_cache_only_boot() -> void:
	assert_eq(
		_config.start_remote(INSTALL, _analytics, "http://insecure", CACHE), ERR_INVALID_PARAMETER
	)
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), OK)
	assert_eq(_config.get_int(&"config.remote.timeout_ms"), 3000)
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), ERR_ALREADY_IN_USE)


func test_remote_bucket_user_property_requires_analytics_consent() -> void:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	save.initialize(Clock.new())
	save.configure(SaveStorage.new(SAVE_PATH), func() -> String: return INSTALL)
	add_child_autofree(save)
	assert_eq(save.load(), OK)
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	add_child_autofree(content)
	assert_eq(content.load_manifest("pl", "res://tests/fixtures/content"), OK)
	var events: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(events)
	var runtime: ANALYTICS_SCRIPT = ANALYTICS_SCRIPT.new()
	add_child_autofree(runtime)
	var queue: AnalyticsQueue = AnalyticsQueue.new(SaveStorage.new(QUEUE_PATH))
	assert_eq(runtime.start_runtime(save, _config, content, events, queue), OK)
	assert_eq(_config.start_remote(INSTALL, runtime, "", CACHE), OK)
	assert_eq(_config.accept_remote_document(_document()), OK)
	assert_eq(_fake.calls.entries.size(), 0)
	events.consent_changed.emit(false)
	assert_eq(_fake.calls.entries.size(), 0)
	events.consent_changed.emit(true)
	assert_eq(_fake.calls.entries.size(), 1)
	assert_eq(_fake.calls.entries[0]["arguments"][0], "experiment_buckets")
	assert_true(str(_fake.calls.entries[0]["arguments"][1]).contains("ad_frequency"))
	var removed: Dictionary = _document()
	removed["experiments"] = []
	assert_eq(_config.accept_remote_document(removed), OK)
	assert_eq(_fake.calls.entries[1]["arguments"], ["experiment_buckets", ""])
	var reentrant: Array[Error] = []
	var callback_fake: CallbackFake = CallbackFake.new()
	Platform.analytics = callback_fake
	callback_fake.on_log = func() -> void:
		reentrant.append(_config.accept_remote_document(removed))
		reentrant.append(_config.load())
	assert_eq(_config.accept_remote_document(removed), OK)
	assert_eq(reentrant, [ERR_BUSY, ERR_BUSY])
	callback_fake.on_log = Callable()
	assert_eq(runtime.set_experiment_buckets({"ad_frequency": 0}, true), OK)
	var fresh: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	add_child_autofree(fresh)
	assert_eq(fresh.load(), OK)
	_clear()
	reentrant.clear()
	callback_fake.on_property = func() -> void:
		reentrant.append(fresh.accept_remote_document(removed))
		reentrant.append(fresh.load())
	assert_eq(fresh.start_remote(INSTALL, runtime, "", CACHE), OK)
	assert_eq(reentrant, [ERR_BUSY, ERR_BUSY])
	callback_fake.on_property = Callable()
	assert_eq(fresh.accept_remote_document(removed), OK)
