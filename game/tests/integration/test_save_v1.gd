extends GutTest

const SAVE_SCRIPT = preload("res://services/save.gd")
const ID: String = "12345678-1234-4234-8234-123456789abc"
const TEST_PATH: String = "user://t0036-save-test.json"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class InterruptedStorage:
	extends SaveStorage

	var stop_at: StringName

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


func _fixture() -> Dictionary:
	return (
		JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save/v1.json"))
		as Dictionary
	)


func _write(text: String, suffix: String = "") -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH + suffix, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func _save(storage: SaveStorage = null) -> SAVE_SCRIPT:
	var service: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(service)
	service.initialize(FixedClock.new())
	service.configure(
		storage if storage != null else SaveStorage.new(TEST_PATH), func() -> String: return ID
	)
	return service


func test_golden_v1_exact_defaults_and_round_trip() -> void:
	var golden: Dictionary = _fixture()
	assert_eq(golden["schema_version"], 1.0)
	var migrated: Dictionary = SaveMigrations.new().upgrade(golden)
	assert_true(SaveSchema.is_valid(migrated))
	assert_eq_deep(
		SaveSchema.fresh(ID, "2026-10-02T12:00:00Z", "0.1.0"), SaveSchema.canonical(migrated)
	)
	_write(JSON.stringify(golden))
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.load(), OK)
	assert_eq(service.get_section(&"meta")["install_id"], ID)
	var progress: Dictionary = service.get_section(&"progress")
	progress["by_lang"]["pl"]["current_slot"] = 2
	assert_eq(service.set_section(&"progress", progress), OK)
	assert_eq(service.flush(), OK)
	var restored: SAVE_SCRIPT = _save()
	assert_eq(restored.load(), OK)
	assert_eq(restored.get_section(&"progress")["by_lang"]["pl"]["current_slot"], 2)
	assert_eq(restored.get_section(&"meta")["install_id"], ID)
	assert_typeof(restored.get_section(&"economy")["coins"], TYPE_INT)
	assert_typeof(restored.get_section(&"progress")["by_lang"]["pl"]["current_slot"], TYPE_INT)
	assert_eq_deep(SaveStorage.new(TEST_PATH).read_document(".bak"), golden)


func test_first_install_persists_identity_once_and_emits_no_corruption() -> void:
	watch_signals(Events)
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.load(), OK)
	var persisted: Dictionary = SaveStorage.new(TEST_PATH).read_document()
	assert_eq(persisted["meta"]["install_id"], ID)
	assert_eq(persisted["meta"]["created_at"], "2026-10-02T12:00:00Z")
	var second: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(second)
	second.initialize(FixedClock.new())
	second.configure(
		SaveStorage.new(TEST_PATH),
		func() -> String:
			fail_test("Existing save must not generate another identity")
			return ID
	)
	assert_eq(second.load(), OK)
	assert_eq(second.get_section(&"meta")["install_id"], ID)
	assert_signal_not_emitted(Events, "save_corrupted")


func test_primary_wins_over_uncommitted_temp_and_recovery_order_is_temp_then_backup() -> void:
	var golden: Dictionary = _fixture()
	var pending: Dictionary = golden.duplicate(true)
	pending["progress"]["by_lang"]["pl"]["current_slot"] = 3
	_write(JSON.stringify(golden))
	_write(JSON.stringify(pending), ".tmp")
	_write(JSON.stringify(golden), ".bak")
	assert_eq(_load_slot(), 1)
	_write("{invalid")
	assert_eq(_load_slot(), 3)
	_write("{truncated", ".tmp")
	assert_eq(_load_slot(), 1)


func _load_slot() -> int:
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.load(), OK)
	return int(service.get_section(&"progress")["by_lang"]["pl"]["current_slot"])


func test_invalid_primary_shapes_fall_back_to_valid_backup() -> void:
	var missing_version: Dictionary = _fixture()
	missing_version.erase("schema_version")
	var future: Dictionary = _fixture()
	future["schema_version"] = SaveSchema.VERSION + 1
	var malformed: Dictionary = _fixture()
	malformed["settings"]["haptics_enabled"] = "true"
	var bad_identity: Dictionary = _fixture()
	bad_identity["meta"]["install_id"] = "not-a-uuid"
	_write(JSON.stringify(_fixture()), ".bak")
	for data: Variant in [missing_version, future, malformed, bad_identity, [], null]:
		_write(JSON.stringify(data))
		var service: SAVE_SCRIPT = _save()
		watch_signals(service)
		assert_eq(service.load(), OK)
		assert_eq(service.get_section(&"meta")["install_id"], ID)
		assert_signal_emit_count(service, "backup_restored", 1)
		assert_eq(service.load(), OK)
		assert_signal_emit_count(service, "backup_restored", 1)


func test_all_corrupt_copies_emit_once_and_remain_until_explicit_flush() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		_write("{corrupt", suffix)
	watch_signals(Events)
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.load(), OK)
	assert_eq(service.load(), OK)
	assert_signal_emit_count(Events, "save_corrupted", 1)
	assert_eq(service.get_section(&"progress")["by_lang"]["pl"]["current_slot"], 1)
	assert_eq(FileAccess.get_file_as_string(TEST_PATH), "{corrupt")
	assert_eq(service.flush(), OK)
	assert_true(SaveSchema.is_valid(SaveStorage.new(TEST_PATH).read_document()))


func test_backup_recovery_never_overwrites_valid_backup_with_corrupt_primary() -> void:
	_write("{bad")
	var golden: Dictionary = _fixture()
	_write(JSON.stringify(golden), ".bak")
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.load(), OK)
	assert_eq(service.flush(), OK)
	assert_eq_deep(SaveStorage.new(TEST_PATH).read_document(".bak"), golden)
	assert_eq_deep(
		SaveSchema.canonical(SaveStorage.new(TEST_PATH).read_document()),
		SaveSchema.canonical(SaveMigrations.new().upgrade(golden))
	)


func test_each_atomic_write_boundary_recovers_last_committed_or_new_document() -> void:
	for step: StringName in [
		&"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		_clean_files()
		_write(JSON.stringify(_fixture()))
		var storage: InterruptedStorage = InterruptedStorage.new(TEST_PATH)
		storage.stop_at = step
		var service: SAVE_SCRIPT = _save(storage)
		assert_eq(service.load(), OK)
		var progress: Dictionary = service.get_section(&"progress")
		progress["by_lang"]["pl"]["current_slot"] = 4
		assert_eq(service.set_section(&"progress", progress), OK)
		watch_signals(service)
		assert_eq(service.flush(), ERR_BUSY)
		assert_signal_emitted_with_parameters(service, "flush_failed", [ERR_BUSY])
		var expected: int = 4 if step in [&"backup_rotated", &"primary_promoted"] else 1
		assert_eq(_load_slot(), expected)
		storage.stop_at = &""
		assert_eq(service.flush(), OK)
		assert_eq(_load_slot(), 4)


func test_truncated_temp_without_primary_recovers_backup() -> void:
	_write("{half-written", ".tmp")
	_write(JSON.stringify(_fixture()), ".bak")
	assert_eq(_load_slot(), 1)


func test_io_error_preserves_dirty_data_and_retries() -> void:
	var storage: SaveStorage = SaveStorage.new(TEST_PATH + "/unavailable/save.json")
	var service: SAVE_SCRIPT = _save(storage)
	watch_signals(service)
	assert_ne(service.load(), OK)
	assert_signal_emitted(service, "flush_failed")
	storage.path = TEST_PATH
	assert_eq(service.flush(), OK)
	assert_eq(_load_slot(), 1)


func test_owner_sections_are_copies_and_invalid_changes_are_rejected() -> void:
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.load(), OK)
	var progress: Dictionary = service.get_section(&"progress")
	progress["by_lang"]["pl"]["current_slot"] = 9
	assert_eq(service.get_section(&"progress")["by_lang"]["pl"]["current_slot"], 1)
	assert_eq(service.set_section(&"meta", {}), ERR_INVALID_PARAMETER)
	assert_eq(service.set_section(&"progress", {}), ERR_INVALID_DATA)
	var economy: Dictionary = service.get_section(&"economy")
	economy["coins"] = 1.5
	assert_eq(service.set_section(&"economy", economy), ERR_INVALID_DATA)
	assert_eq(service.get_section(&"unknown"), {})


func test_settings_persist_signal_only_on_success_and_reject_invalid_values() -> void:
	var storage: InterruptedStorage = InterruptedStorage.new(TEST_PATH)
	var service: SAVE_SCRIPT = _save(storage)
	assert_eq(service.load(), OK)
	watch_signals(service)
	assert_eq(service.set_setting(&"haptics_enabled", false), OK)
	assert_signal_emitted_with_parameters(service, "setting_changed", [&"haptics_enabled"])
	assert_eq(_loaded_setting(&"haptics_enabled"), false)
	assert_eq(service.set_setting(&"unknown", true), ERR_INVALID_PARAMETER)
	assert_eq(service.set_setting(&"haptics_enabled", "false"), ERR_INVALID_DATA)
	storage.stop_at = &"temp_flushed"
	assert_eq(service.set_setting(&"music_volume", 0.4), ERR_BUSY)
	assert_signal_emit_count(service, "setting_changed", 1)
	storage.stop_at = &""
	assert_eq(service.set_setting(&"music_volume", 0.4), OK)
	assert_eq(_loaded_setting(&"music_volume"), 0.4)


func _loaded_setting(key: StringName) -> Variant:
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.load(), OK)
	return service.get_setting(key)


func test_meaningful_flush_and_background_persist_without_per_frame_work() -> void:
	var service: SAVE_SCRIPT = _save()
	assert_eq(service.flush(), ERR_UNCONFIGURED)
	assert_eq(service.load(), OK)
	var progress: Dictionary = service.get_section(&"progress")
	progress["by_lang"]["pl"]["current_slot"] = 5
	assert_eq(service.set_section(&"progress", progress), OK)
	assert_eq(_load_slot(), 1)
	assert_eq(service.request_flush(), OK)
	assert_eq(_load_slot(), 5)
	progress["by_lang"]["pl"]["current_slot"] = 6
	assert_eq(service.set_section(&"progress", progress), OK)
	service.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_load_slot(), 6)


func test_migration_chain_preserves_golden_source_and_rejects_missing_or_invalid_steps() -> void:
	var golden: Dictionary = _fixture()
	var chain: SaveMigrations = SaveMigrations.new(3)
	assert_eq(chain.upgrade(golden), {})
	var to_v2: Callable = func(data: Dictionary) -> Dictionary:
		data["schema_version"] = 2
		return data
	assert_eq(chain.register_step(1, to_v2), OK)
	assert_eq(chain.upgrade(golden), {})
	var to_v3: Callable = func(data: Dictionary) -> Dictionary:
		data["schema_version"] = 3
		return data
	assert_eq(chain.register_step(2, to_v3), OK)
	var upgraded: Dictionary = chain.upgrade(golden)
	assert_eq(upgraded["schema_version"], 3)
	assert_eq(golden["schema_version"], 1.0)
	assert_eq(upgraded["meta"]["install_id"], ID)
	assert_eq(chain.register_step(1, Callable()), ERR_INVALID_PARAMETER)
	var invalid: SaveMigrations = SaveMigrations.new(2)
	invalid.register_step(1, func(data: Dictionary) -> Dictionary: return data)
	assert_eq(invalid.upgrade(golden), {})
	assert_eq(SaveMigrations.new().upgrade(upgraded), {})


func test_non_json_values_and_unsafe_numbers_are_rejected() -> void:
	var data: Dictionary = SaveMigrations.new().upgrade(_fixture())
	assert_true(SaveSchema.is_valid(data))
	data["economy"]["coins"] = 9007199254740992
	assert_false(SaveSchema.is_valid(data))
	data = SaveMigrations.new().upgrade(_fixture())
	data["progress"]["level_state"] = RefCounted.new()
	assert_false(SaveSchema.is_valid(data))
	data = SaveMigrations.new().upgrade(_fixture())
	data["settings"]["music_volume"] = NAN
	assert_false(SaveSchema.is_valid(data))


func test_uuid_v4_format_uses_injected_entropy_without_mutating_input() -> void:
	var entropy: PackedByteArray = PackedByteArray(
		[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
	)
	assert_eq(SaveSchema.new_install_id(entropy), "00010203-0405-4607-8809-0a0b0c0d0e0f")
	assert_eq(entropy[6], 6)
	assert_eq(entropy[8], 8)
	assert_eq(SaveSchema.new_install_id(PackedByteArray([1, 2, 3])), "")
