extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const TEST_PATH: String = "user://t0145-temp-recovery.json"
const ID: String = "12345678-1234-4234-8234-123456789abc"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class ObservedStorage:
	extends SaveStorage

	var commits: int = 0
	var promotions: int = 0
	var reject_promotion: bool = false
	var truncate_output: bool = false
	var stop_at: StringName = &""

	func promote_temp() -> Error:
		promotions += 1
		return ERR_BUSY if reject_promotion else super.promote_temp()

	func commit(text: String, rotate_primary: bool) -> Error:
		commits += 1
		if truncate_output:
			var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
			if file == null:
				return FileAccess.get_open_error()
			file.close()
			return ERR_FILE_CANT_WRITE
		return super.commit(text, rotate_primary)

	func checkpoint(step: StringName) -> Error:
		return ERR_BUSY if step == stop_at else OK


func before_each() -> void:
	_clean_files()


func after_each() -> void:
	_clean_files()


func _clean_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)


func _document(version: int = 2) -> Dictionary:
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v%d.json" % version)
	)
	data["progress"]["by_lang"]["pl"]["current_slot"] = 4
	data["progress"]["by_lang"]["pl"]["completed_slot"] = 3
	if version == 2:
		data["progress"]["by_lang"]["pl"]["highest_completed_slot"] = 3
	data["settings"]["haptics_enabled"] = false
	return data


func _write(data: Dictionary, suffix: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH + suffix, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(data))
	file.close()


func _save(storage: SaveStorage = null) -> SAVE_SCRIPT:
	var service: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(service)
	service.initialize(FixedClock.new())
	service.configure(
		storage if storage != null else SaveStorage.new(TEST_PATH),
		func() -> String:
			fail_test("A recovered save must not generate a fresh identity")
			return ID
	)
	return service


func _assert_restored(slot: int) -> void:
	var restored: SAVE_SCRIPT = _save()
	assert_eq(restored.load(), OK)
	assert_eq(restored.get_section(&"meta")["install_id"], ID)
	assert_eq(restored.get_setting(&"haptics_enabled"), false)
	assert_eq(restored.get_section(&"progress")["by_lang"]["pl"]["current_slot"], slot)


func _advance(service: SAVE_SCRIPT) -> void:
	var progress: Dictionary = service.get_section(&"progress")
	progress["by_lang"]["pl"]["current_slot"] = 5
	progress["by_lang"]["pl"]["completed_slot"] = 4
	progress["by_lang"]["pl"]["highest_completed_slot"] = 4
	assert_eq(service.set_section(&"progress", progress), OK)


func test_sole_temp_survives_truncated_output_and_retry() -> void:
	_write(_document(), ".tmp")
	var storage: ObservedStorage = ObservedStorage.new(TEST_PATH)
	var service: SAVE_SCRIPT = _save(storage)
	assert_eq(service.load(), OK)
	_advance(service)
	storage.truncate_output = true
	watch_signals(service)
	assert_eq(service.flush(), ERR_FILE_CANT_WRITE)
	assert_signal_emitted_with_parameters(service, "flush_failed", [ERR_FILE_CANT_WRITE])
	_assert_restored(4)
	storage.truncate_output = false
	assert_eq(service.flush(), OK)
	_assert_restored(5)
	assert_eq(storage.promotions, 1)
	assert_eq(
		(
			SaveStorage
			. new(TEST_PATH)
			. read_document(".bak")["progress"]["by_lang"]["pl"]["current_slot"]
		),
		4
	)


func test_promotion_failure_preserves_source_and_is_retryable() -> void:
	_write(_document(), ".tmp")
	var original: String = FileAccess.get_file_as_string(TEST_PATH + ".tmp")
	var storage: ObservedStorage = ObservedStorage.new(TEST_PATH)
	storage.reject_promotion = true
	var service: SAVE_SCRIPT = _save(storage)
	assert_eq(service.load(), OK)
	_advance(service)
	assert_eq(service.flush(), ERR_BUSY)
	assert_eq(storage.commits, 0)
	assert_eq(FileAccess.get_file_as_string(TEST_PATH + ".tmp"), original)
	_assert_restored(4)
	storage.reject_promotion = false
	assert_eq(service.flush(), OK)
	_assert_restored(5)


func test_open_interruption_preserves_temp_recovery_and_normal_primary() -> void:
	for suffix: String in [".tmp", ""]:
		_clean_files()
		_write(_document(), suffix)
		var storage: ObservedStorage = ObservedStorage.new(TEST_PATH)
		var service: SAVE_SCRIPT = _save(storage)
		assert_eq(service.load(), OK)
		_advance(service)
		storage.stop_at = &"temp_opened"
		assert_eq(service.flush(), ERR_BUSY)
		_assert_restored(4)
		storage.stop_at = &""
		assert_eq(service.flush(), OK)
		_assert_restored(5)


func test_v1_temp_migrates_with_original_backup() -> void:
	var original: Dictionary = _document(1)
	_write(original, ".tmp")
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.load(), OK)
	assert_eq(service.flush(), OK)
	_assert_restored(4)
	assert_eq(FileAccess.get_file_as_string(TEST_PATH + ".bak"), JSON.stringify(original))
	assert_eq(SaveStorage.new(TEST_PATH).read_document()["schema_version"], 2.0)


func test_debug_reset_failure_keeps_recovered_progress_and_retries() -> void:
	_write(_document(), ".tmp")
	var storage: ObservedStorage = ObservedStorage.new(TEST_PATH)
	var service: SAVE_SCRIPT = _save(storage)
	assert_eq(service.load(), OK)
	storage.truncate_output = true
	assert_eq(service.debug_reset(), ERR_FILE_CANT_WRITE)
	_assert_restored(4)
	assert_eq(service.get_section(&"progress")["by_lang"]["pl"]["current_slot"], 4)
	storage.truncate_output = false
	assert_eq(service.debug_reset(), OK)
	_assert_restored(1)


func test_load_only_does_not_promote_or_rewrite() -> void:
	_write(_document(), ".tmp")
	var original: String = FileAccess.get_file_as_string(TEST_PATH + ".tmp")
	var storage: ObservedStorage = ObservedStorage.new(TEST_PATH)
	var service: SAVE_SCRIPT = _save(storage)
	watch_signals(service)
	assert_eq(service.load(), OK)
	assert_eq(service.load(), OK)
	assert_signal_emit_count(service, "backup_restored", 1)
	assert_eq(storage.promotions, 0)
	assert_eq(storage.commits, 0)
	assert_false(FileAccess.file_exists(TEST_PATH))
	assert_eq(FileAccess.get_file_as_string(TEST_PATH + ".tmp"), original)
