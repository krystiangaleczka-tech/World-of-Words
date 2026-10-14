extends GutTest

const SERVICE_SCRIPT: Script = preload("res://services/analytics.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const ROOT: String = "user://t0250-analytics-service"
const SAVE_PATH: String = ROOT + "/save.json"
const QUEUE_PATH: String = ROOT + "/analytics_queue.json"
const CONFIG_PATH: String = ROOT + "/config"
const CONTENT_ROOT: String = "res://tests/fixtures/content"
const INSTALL_ID: String = "123e4567-e89b-42d3-a456-426614174000"


class FailingStorage:
	extends SaveStorage
	var fail_step: StringName
	var fail_promotion: bool = false

	func _init(target: String, step: StringName) -> void:
		super(target)
		fail_step = step

	func checkpoint(step: StringName) -> Error:
		return ERR_CANT_CREATE if step == fail_step else OK

	func promote_temp() -> Error:
		return ERR_CANT_CREATE if fail_promotion else super()


class FailingRemovalQueue:
	extends AnalyticsQueue
	var failed_path: String = ""
	var removal_attempts: Array[String] = []

	func _init(storage: SaveStorage) -> void:
		super(storage)

	func _remove_if_present(path: String) -> Error:
		removal_attempts.append(path)
		if path == failed_path and FileAccess.file_exists(path):
			return ERR_CANT_CREATE
		return super(path)


var _previous: AnalyticsAdapter
var _fake: AnalyticsFake
var _save: SAVE_SCRIPT
var _config: CONFIG_SCRIPT
var _content: CONTENT_SCRIPT
var _events: EVENTS_SCRIPT
var _services: Array[Node] = []


func before_each() -> void:
	_previous = Platform.analytics
	_fake = AnalyticsFake.new()
	Platform.analytics = _fake
	_clean_root()
	DirAccess.make_dir_recursive_absolute(CONFIG_PATH)
	_write_text(
		CONFIG_PATH + "/analytics.json",
		(
			JSON
			. stringify(
				{
					"analytics.queue.max_events":
					{
						"default": 2,
						"type": "int",
						"range": [1, 3],
						"description": "Test queue bound",
						"owner": "Test",
						"remote": false,
					}
				}
			)
		)
	)
	_save = SAVE_SCRIPT.new()
	_save.initialize(Clock.new())
	_save.configure(SaveStorage.new(SAVE_PATH), func() -> String: return INSTALL_ID)
	add_child_autofree(_save)
	assert_eq(_save.load(), OK)
	_config = CONFIG_SCRIPT.new()
	add_child_autofree(_config)
	assert_eq(_config.load(CONFIG_PATH), OK)
	_content = CONTENT_SCRIPT.new()
	add_child_autofree(_content)
	assert_eq(_content.load_manifest("pl", CONTENT_ROOT), OK)
	_events = EVENTS_SCRIPT.new()
	add_child_autofree(_events)


func after_each() -> void:
	for service: Node in _services:
		if is_instance_valid(service):
			service.free()
	_services.clear()
	Platform.analytics = _previous
	_clean_root()


func _service(
	storage: SaveStorage = null, expected: Error = OK, queue: AnalyticsQueue = null
) -> SERVICE_SCRIPT:
	var service: SERVICE_SCRIPT = SERVICE_SCRIPT.new()
	add_child(service)
	_services.append(service)
	var selected: SaveStorage = storage if storage != null else SaveStorage.new(QUEUE_PATH)
	assert_eq(
		service.start_runtime(
			_save,
			_config,
			_content,
			_events,
			queue if queue != null else AnalyticsQueue.new(selected)
		),
		expected
	)
	return service


func _restart(service: SERVICE_SCRIPT) -> SERVICE_SCRIPT:
	_services.erase(service)
	service.free()
	return _service()


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func _clean_root() -> void:
	if not DirAccess.dir_exists_absolute(ROOT):
		return
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path: String in [QUEUE_PATH, QUEUE_PATH + ".tmp", QUEUE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(CONFIG_PATH):
		var directory: DirAccess = DirAccess.open(CONFIG_PATH)
		for filename: String in directory.get_files():
			DirAccess.remove_absolute(CONFIG_PATH.path_join(filename))
		DirAccess.remove_absolute(CONFIG_PATH)
	DirAccess.remove_absolute(ROOT)


func test_unknown_consent_persists_snapshots_and_restart_preserves_fifo_bound() -> void:
	var service: SERVICE_SCRIPT = _service()
	var buckets: Dictionary = {"variant_b": 99, "experiment_a": 2}
	assert_eq(service.set_experiment_buckets(buckets), OK)
	var params: Dictionary = {"screen": "Level"}
	assert_eq(service.track(&"nav_screen", params), OK)
	buckets["experiment_a"] = 7
	params["screen"] = "Home"
	assert_eq(service.track(&"app_boot"), OK)
	assert_eq(service.track(&"app_background"), ERR_OUT_OF_MEMORY)
	assert_eq(_fake.calls.entries.size(), 0)
	assert_eq(service.pending_count(), 2)
	service = _restart(service)
	assert_eq(service.pending_count(), 2)
	_events.consent_changed.emit(true)
	assert_eq(service.pending_count(), 0)
	assert_eq(_fake.calls.entries.size(), 2)
	assert_eq(_fake.calls.entries[0]["arguments"][0], "nav_screen")
	var delivered: Dictionary = _fake.calls.entries[0]["arguments"][1]
	assert_eq(delivered["screen"], "Level")
	assert_eq(delivered["install_id"], INSTALL_ID)
	assert_eq(delivered["app_version"], "0.1.0")
	assert_eq(delivered["content_version"], 1)
	assert_eq(delivered["language"], "pl")
	assert_eq(delivered["experiment_buckets"], '{"experiment_a":2,"variant_b":99}')
	assert_eq(service.track(&"app_foreground"), OK)
	assert_eq(_fake.calls.entries.size(), 3)
	assert_eq(service.pending_count(), 0)


func test_denial_and_revocation_drop_without_bypassing_registry_validation() -> void:
	var service: SERVICE_SCRIPT = _service()
	assert_eq(service.track(&"app_boot"), OK)
	var unrelated: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(unrelated)
	unrelated.consent_changed.emit(true)
	assert_eq(service.pending_count(), 1)
	assert_eq(_fake.calls.entries.size(), 0)
	_events.consent_changed.emit(false)
	assert_eq(service.pending_count(), 0)
	assert_eq(_fake.calls.entries.size(), 0)
	assert_eq(service.track(&"app_background"), OK)
	assert_eq(service.track(&"missing_event"), ERR_INVALID_DATA)
	assert_push_error("missing_event")
	assert_eq(service.pending_count(), 0)
	_events.consent_changed.emit(true)
	assert_eq(service.track(&"app_foreground"), OK)
	assert_eq(_fake.calls.entries.size(), 1)
	_events.consent_changed.emit(false)
	assert_eq(service.track(&"app_background"), OK)
	assert_eq(_fake.calls.entries.size(), 1)


func test_bucket_contract_and_common_collisions_are_strict() -> void:
	var service: SERVICE_SCRIPT = _service()
	for buckets: Dictionary in [
		{"BadName": 1}, {"bad-name": 1}, {"a": -1}, {"a": 100}, {"a": 1.0}, {1: 1}
	]:
		assert_eq(service.set_experiment_buckets(buckets), ERR_INVALID_PARAMETER)
	assert_eq(service.set_experiment_buckets({"test_group": 0}), OK)
	assert_eq(
		service.track(&"invalid_word_submitted", {"language": "en", "slot": 1, "letters": "ABC"}),
		ERR_INVALID_DATA
	)
	assert_eq(
		service.track(&"invalid_word_submitted", {"language": "pl", "slot": 1, "letters": "ABC"}),
		OK
	)
	var parsed_document: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
	assert_true(parsed_document is Dictionary)
	var document: Dictionary = parsed_document as Dictionary
	_services.erase(service)
	service.free()
	var stored_events: Array = document["events"]
	var stored_context: Dictionary = (stored_events[0] as Dictionary)["context"]
	stored_context["experiment_buckets"] = '{ "test_group":0}'
	_write_text(QUEUE_PATH, JSON.stringify(document))
	service = _service()
	assert_eq(service.pending_count(), 0)


func test_temp_recovery_and_wholly_corrupt_reset_are_nonfatal() -> void:
	var service: SERVICE_SCRIPT = _service()
	assert_eq(service.track(&"app_boot"), OK)
	var valid: String = FileAccess.get_file_as_string(QUEUE_PATH)
	service = _restart_after_files(service, "{broken", valid, "{broken")
	assert_eq(service.pending_count(), 1)
	assert_true(FileAccess.file_exists(QUEUE_PATH))
	assert_false(FileAccess.file_exists(QUEUE_PATH + ".tmp"))
	valid = FileAccess.get_file_as_string(QUEUE_PATH)
	service = _restart_after_files(service, "{broken", "{broken", valid)
	assert_eq(service.pending_count(), 1)
	assert_true(FileAccess.file_exists(QUEUE_PATH))
	assert_eq(FileAccess.get_file_as_string(QUEUE_PATH + ".bak"), valid)
	_services.erase(service)
	service.free()
	_write_text(QUEUE_PATH, "{broken")
	_write_text(QUEUE_PATH + ".tmp", "[]")
	_write_text(QUEUE_PATH + ".bak", "{}")
	service = _service()
	assert_eq(service.pending_count(), 0)
	var reset: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
	assert_true(reset is Dictionary)
	assert_eq((reset as Dictionary)["events"], [])


func _restart_after_files(
	service: SERVICE_SCRIPT, primary: String, temporary: String, backup: String
) -> SERVICE_SCRIPT:
	_services.erase(service)
	service.free()
	_write_text(QUEUE_PATH, primary)
	_write_text(QUEUE_PATH + ".tmp", temporary)
	_write_text(QUEUE_PATH + ".bak", backup)
	return _service()


func test_failed_acceptance_is_not_exposed_as_pending() -> void:
	var storage: FailingStorage = FailingStorage.new(QUEUE_PATH, &"")
	var service: SERVICE_SCRIPT = _service(storage)
	storage.fail_step = &"temp_written"
	assert_eq(service.track(&"app_boot"), ERR_CANT_CREATE)
	assert_eq(service.pending_count(), 0)
	assert_eq(_fake.calls.entries.size(), 0)
	service = _restart(service)
	assert_eq(service.pending_count(), 0)


func test_post_rotation_checkpoint_failures_restore_accepted_candidate() -> void:
	for step: StringName in [&"backup_rotated", &"primary_promoted"]:
		_clean_queue()
		var storage: FailingStorage = FailingStorage.new(QUEUE_PATH, &"")
		var service: SERVICE_SCRIPT = _service(storage)
		storage.fail_step = step
		assert_eq(service.track(&"app_boot"), OK)
		assert_eq(service.pending_count(), 1)
		service = _restart(service)
		assert_eq(service.pending_count(), 1)
		_services.erase(service)
		service.free()


func test_failed_post_rotation_promotion_preserves_accepted_temp_for_retry() -> void:
	var storage: FailingStorage = FailingStorage.new(QUEUE_PATH, &"")
	var service: SERVICE_SCRIPT = _service(storage)
	storage.fail_step = &"backup_rotated"
	storage.fail_promotion = true
	assert_eq(service.track(&"app_boot"), OK)
	assert_eq(service.pending_count(), 1)
	assert_false(FileAccess.file_exists(QUEUE_PATH))
	assert_true(FileAccess.file_exists(QUEUE_PATH + ".tmp"))
	storage.fail_step = &""
	assert_eq(service.track(&"app_foreground"), ERR_CANT_CREATE)
	assert_eq(service.pending_count(), 1)
	storage.fail_promotion = false
	assert_eq(service.track(&"app_foreground"), OK)
	assert_eq(service.pending_count(), 2)
	service = _restart(service)
	assert_eq(service.pending_count(), 2)


func test_interrupted_recovery_preserves_the_accepted_temp_or_backup() -> void:
	var service: SERVICE_SCRIPT = _service()
	assert_eq(service.track(&"app_boot"), OK)
	var valid: String = FileAccess.get_file_as_string(QUEUE_PATH)
	_services.erase(service)
	service.free()
	_write_text(QUEUE_PATH, "{broken")
	_write_text(QUEUE_PATH + ".tmp", valid)
	var temp_failure: FailingStorage = FailingStorage.new(QUEUE_PATH, &"")
	temp_failure.fail_promotion = true
	service = _service(temp_failure, ERR_CANT_CREATE)
	assert_false(service.runtime_ready())
	assert_eq(FileAccess.get_file_as_string(QUEUE_PATH + ".tmp"), valid)
	_services.erase(service)
	service.free()
	service = _service()
	assert_eq(service.pending_count(), 1)
	_services.erase(service)
	service.free()
	_write_text(QUEUE_PATH, "{broken")
	_write_text(QUEUE_PATH + ".tmp", "{broken")
	_write_text(QUEUE_PATH + ".bak", valid)
	var backup_failure: FailingStorage = FailingStorage.new(QUEUE_PATH, &"temp_written")
	service = _service(backup_failure, ERR_CANT_CREATE)
	assert_false(service.runtime_ready())
	assert_eq(FileAccess.get_file_as_string(QUEUE_PATH + ".bak"), valid)
	_services.erase(service)
	service.free()
	service = _service()
	assert_eq(service.pending_count(), 1)


func test_failed_handoff_checkpoint_retries_at_least_once_and_denial_purges() -> void:
	var storage: FailingStorage = FailingStorage.new(QUEUE_PATH, &"")
	var service: SERVICE_SCRIPT = _service(storage)
	assert_eq(service.track(&"app_boot"), OK)
	storage.fail_step = &"temp_written"
	_events.consent_changed.emit(true)
	assert_eq(_fake.calls.entries.size(), 1)
	assert_eq(service.pending_count(), 1)
	storage.fail_step = &""
	assert_eq(service.flush(), OK)
	assert_eq(_fake.calls.entries.size(), 2)
	assert_eq(service.pending_count(), 0)
	assert_eq(service.track(&"app_foreground"), OK)
	storage.fail_step = &"temp_written"
	_events.consent_changed.emit(false)
	assert_eq(service.pending_count(), 0)
	assert_true(FileAccess.file_exists(QUEUE_PATH))
	var cleared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
	assert_eq(cleared["events"], [])
	for suffix: String in [".tmp", ".bak"]:
		assert_false(FileAccess.file_exists(QUEUE_PATH + suffix))


func test_revocation_attempts_every_copy_when_one_removal_fails() -> void:
	var storage: FailingStorage = FailingStorage.new(QUEUE_PATH, &"")
	var queue: FailingRemovalQueue = FailingRemovalQueue.new(storage)
	var service: SERVICE_SCRIPT = _service(storage, OK, queue)
	assert_eq(service.track(&"app_boot"), OK)
	storage.fail_step = &"temp_written"
	queue.failed_path = QUEUE_PATH + ".tmp"
	_events.consent_changed.emit(false)
	assert_eq(service.pending_count(), 0)
	for path: String in [QUEUE_PATH, QUEUE_PATH + ".tmp", QUEUE_PATH + ".bak"]:
		assert_true(queue.removal_attempts.has(path))
	_services.erase(service)
	service.free()
	service = _service()
	assert_eq(service.pending_count(), 0)


func test_revocation_clears_pending_temp_state_after_backup_removal_failure() -> void:
	var storage: FailingStorage = FailingStorage.new(QUEUE_PATH, &"")
	var queue: FailingRemovalQueue = FailingRemovalQueue.new(storage)
	var service: SERVICE_SCRIPT = _service(storage, OK, queue)
	assert_eq(service.track(&"app_boot"), OK)
	storage.fail_step = &"backup_rotated"
	storage.fail_promotion = true
	queue.failed_path = QUEUE_PATH + ".bak"
	_events.consent_changed.emit(false)
	assert_eq(service.pending_count(), 0)
	assert_false(FileAccess.file_exists(QUEUE_PATH + ".tmp"))
	assert_eq(FileAccess.get_file_as_string(QUEUE_PATH + ".bak"), "")
	storage.fail_step = &""
	storage.fail_promotion = false
	_events.consent_changed.emit(true)
	assert_eq(service.track(&"app_foreground"), OK)
	assert_eq(_fake.calls.entries.size(), 1)
	assert_eq(_fake.calls.entries[0]["arguments"][0], "app_foreground")
	service = _restart(service)
	assert_eq(service.pending_count(), 0)


func test_runtime_preconditions_mode_exclusivity_and_idempotence() -> void:
	var service: SERVICE_SCRIPT = SERVICE_SCRIPT.new()
	add_child(service)
	_services.append(service)
	assert_false(service.runtime_ready())
	assert_eq(
		service.start_runtime(null, _config, _content, _events, AnalyticsQueue.new()),
		ERR_UNCONFIGURED
	)
	assert_eq(service.configure_stub(2), OK)
	assert_eq(
		service.start_runtime(_save, _config, _content, _events, AnalyticsQueue.new()),
		ERR_ALREADY_IN_USE
	)
	var runtime: SERVICE_SCRIPT = _service()
	assert_true(runtime.runtime_ready())
	assert_eq(runtime.start_runtime(_save, _config, _content, _events), OK)
	assert_eq(runtime.configure_stub(2), ERR_ALREADY_IN_USE)
	assert_eq(_events.consent_changed.get_connections().size(), 1)
	_services.erase(runtime)
	runtime.free()
	assert_eq(_events.consent_changed.get_connections().size(), 0)
	_events.consent_changed.emit(true)


func _clean_queue() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = QUEUE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
