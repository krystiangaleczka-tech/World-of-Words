extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const TEST_PATH: String = "user://t0146-settings-retry.json"
const ID: String = "12345678-1234-4234-8234-123456789abc"

var _storage: FailingStorage
var _save: SAVE_SCRIPT
var _notices: Array[StringName] = []


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class FailingStorage:
	extends SaveStorage
	var failure: Error = OK

	func checkpoint(step: StringName) -> Error:
		return failure if step == &"temp_opened" else OK


func before_each() -> void:
	_clean()
	_notices.clear()
	_storage = FailingStorage.new(TEST_PATH)
	_save = _new_save(_storage)
	_save.setting_changed.connect(_on_setting)


func after_each() -> void:
	_save.setting_changed.disconnect(_on_setting)
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)


func _new_save(storage: SaveStorage) -> SAVE_SCRIPT:
	var service: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(service)
	service.initialize(FixedClock.new())
	service.configure(storage, func() -> String: return ID)
	assert_eq(service.load(), OK)
	return service


func _on_setting(key: StringName) -> void:
	_notices.append(key)


func test_plain_retry_notifies_after_durability_and_only_once() -> void:
	_storage.failure = ERR_BUSY
	assert_eq(_save.set_setting(&"haptics_enabled", false), ERR_BUSY)
	assert_eq(_notices.size(), 0)
	assert_false(_save.get_setting(&"haptics_enabled"), "Dirty read semantics stay unchanged")
	assert_true(_new_save(SaveStorage.new(TEST_PATH)).get_setting(&"haptics_enabled"))
	_storage.failure = OK
	var on_durable: Callable = func(key: StringName) -> void:
		assert_eq(_storage.read_document()["settings"][str(key)], _save.get_setting(key))
	_save.setting_changed.connect(on_durable)
	assert_eq(_save.flush(), OK)
	_save.setting_changed.disconnect(on_durable)
	assert_eq(_notices, [&"haptics_enabled"])
	assert_false(_new_save(SaveStorage.new(TEST_PATH)).get_setting(&"haptics_enabled"))
	assert_eq(_save.flush(), OK)
	assert_eq(_notices.size(), 1)


func test_failed_edits_coalesce_and_invalid_edits_never_queue() -> void:
	_storage.failure = ERR_BUSY
	assert_eq(_save.set_setting(&"music_volume", 0.1), ERR_BUSY)
	assert_eq(_save.set_setting(&"music_volume", 0.4), ERR_BUSY)
	assert_eq(_save.set_setting(&"high_contrast", true), ERR_BUSY)
	assert_eq(_save.set_setting(&"language", 42), ERR_INVALID_DATA)
	assert_eq(_save.set_setting(&"unknown", false), ERR_INVALID_PARAMETER)
	assert_eq(_notices.size(), 0)
	_storage.failure = OK
	assert_eq(_save.flush(), OK)
	assert_eq(_notices, [&"music_volume", &"high_contrast"])
	var reloaded: SAVE_SCRIPT = _new_save(SaveStorage.new(TEST_PATH))
	assert_eq(reloaded.get_setting(&"music_volume"), 0.4)
	assert_eq(reloaded.get_setting(&"high_contrast"), true)
	assert_eq(reloaded.get_setting(&"language"), "pl")


func test_other_owner_flush_publishes_pending_settings() -> void:
	_storage.failure = ERR_BUSY
	assert_eq(_save.set_setting(&"reduced_motion", true), ERR_BUSY)
	var section: Dictionary = _save.get_section(&"economy")
	section["coins"] = 7
	assert_eq(_save.set_section(&"economy", section), OK)
	_storage.failure = OK
	assert_eq(_save.flush(), OK)
	assert_eq(_notices, [&"reduced_motion"])
	var reloaded: SAVE_SCRIPT = _new_save(SaveStorage.new(TEST_PATH))
	assert_eq(reloaded.get_section(&"economy")["coins"], 7)
	assert_true(reloaded.get_setting(&"reduced_motion"))


func test_request_and_pause_retry_publish_pending_settings() -> void:
	_storage.failure = ERR_BUSY
	assert_eq(_save.set_setting(&"high_contrast", true), ERR_BUSY)
	_storage.failure = OK
	assert_eq(_save.request_flush(), OK)
	assert_eq(_notices, [&"high_contrast"])
	_storage.failure = ERR_BUSY
	assert_eq(_save.set_setting(&"language", "en"), ERR_BUSY)
	_storage.failure = OK
	_save.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_notices, [&"high_contrast", &"language"])
	assert_eq(_new_save(SaveStorage.new(TEST_PATH)).get_setting(&"language"), "en")


func test_debug_reset_preserves_and_releases_pending_settings() -> void:
	_storage.failure = ERR_BUSY
	assert_eq(_save.set_setting(&"haptics_enabled", false), ERR_BUSY)
	assert_eq(_save.debug_reset(), ERR_BUSY)
	assert_eq(_notices.size(), 0)
	_storage.failure = OK
	assert_eq(_save.debug_reset(), OK)
	assert_eq(_notices, [&"haptics_enabled"])
	assert_false(_new_save(SaveStorage.new(TEST_PATH)).get_setting(&"haptics_enabled"))
	assert_eq(_save.flush(), OK)
	assert_eq(_notices.size(), 1)


func test_callback_failed_edit_survives_publication_for_later_retry() -> void:
	var on_change: Callable = func(key: StringName) -> void:
		if key == &"haptics_enabled":
			_storage.failure = ERR_BUSY
			assert_eq(_save.set_setting(&"reduced_motion", true), ERR_BUSY)
	_save.setting_changed.connect(on_change)
	assert_eq(_save.set_setting(&"haptics_enabled", false), OK)
	assert_eq(_notices, [&"haptics_enabled"])
	assert_false(_storage.read_document()["settings"]["reduced_motion"])
	_storage.failure = OK
	assert_eq(_save.flush(), OK)
	assert_eq(_notices, [&"haptics_enabled", &"reduced_motion"])
	assert_true(_new_save(SaveStorage.new(TEST_PATH)).get_setting(&"reduced_motion"))
	_save.setting_changed.disconnect(on_change)
	assert_eq(_save.flush(), OK)
	assert_eq(_notices.size(), 2)
