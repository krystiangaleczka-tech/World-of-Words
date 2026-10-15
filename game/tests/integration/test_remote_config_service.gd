extends GutTest

const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const ANALYTICS_SCRIPT: Script = preload("res://services/analytics.gd")
const CACHE: String = "user://t0255-config-cache.json"
const INSTALL: String = "123e4567-e89b-42d3-a456-426614174000"
const TUNABLE: StringName = &"ads.interstitial.min_levels_between"

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
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(CACHE + suffix):
			DirAccess.remove_absolute(CACHE + suffix)


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
	assert_eq(_config.start_remote(INSTALL, _analytics, "http://insecure", CACHE), ERR_INVALID_PARAMETER)
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), OK)
	assert_eq(_config.get_int(&"config.remote.timeout_ms"), 3000)
	assert_eq(_config.start_remote(INSTALL, _analytics, "", CACHE), ERR_ALREADY_IN_USE)
