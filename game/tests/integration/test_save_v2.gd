extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const TEST_PATH: String = "user://t0110-save-v2-test.json"
const ID: String = "12345678-1234-4234-8234-123456789abc"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class ObservedStorage:
	extends SaveStorage

	var commits: int = 0
	var stop_at: StringName = &""

	func commit(text: String, rotate_primary: bool) -> Error:
		commits += 1
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


func _fixture(version: int) -> Dictionary:
	return (
		JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/save/v%d.json" % version)
		)
		as Dictionary
	)


func _write(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(data))
	file.close()


func _save(storage: SaveStorage) -> SAVE_SCRIPT:
	var service: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(service)
	service.initialize(FixedClock.new())
	service.configure(
		storage,
		func() -> String:
			fail_test("Loading a valid migrated save must preserve the existing identity")
			return ID
	)
	return service


func _level() -> LevelData:
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	return LevelData.from_dict(pack["levels"][1])


func _snapshot() -> Dictionary:
	var board: BoardState = BoardState.new(_level())
	board.evaluate(PackedInt32Array([0, 1, 2]))
	board.evaluate(PackedInt32Array([0, 3, 2]))
	return board.to_dict()


func test_golden_migration_and_preservation() -> void:
	var v1: Dictionary = _fixture(1)
	var original: Dictionary = v1.duplicate(true)
	var v2: Dictionary = SaveMigrations.new().upgrade(v1)
	assert_eq_deep(SaveSchema.canonical(v2), SaveSchema.canonical(_fixture(2)))
	assert_eq_deep(v1, original)
	assert_eq_deep(
		SaveSchema.fresh(ID, "2026-10-02T12:00:00Z", "0.1.0"), SaveSchema.canonical(_fixture(2))
	)
	v1["root_extension"] = {"history": [1, "kept", null]}
	for section: StringName in SaveSchema.SECTIONS:
		v1[str(section)]["extension"] = {"kept": true}
	v1["settings"]["haptics_enabled"] = false
	v1["economy"]["coins"] = 37
	v1["economy"]["items"]["hint"] = 2
	v1["daily"]["completed_days"] = ["2026-10-01"]
	v1["monetization"]["processed_transactions"] = ["purchase-token"]
	v1["progress"]["by_lang"]["pl"]["current_slot"] = 2
	v1["progress"]["by_lang"]["pl"]["completed_slot"] = 1
	v1["progress"]["by_lang"]["pl"]["level_state"] = _snapshot()
	v1["progress"]["by_lang"]["pl"]["extension"] = ["kept"]
	v1["progress"]["by_lang"]["en"] = v1["progress"]["by_lang"]["pl"].duplicate(true)
	v1["progress"]["by_lang"]["en"]["completed_slot"] = 4
	v1["progress"]["by_lang"]["en"]["current_slot"] = 5
	original = v1.duplicate(true)
	v2 = SaveMigrations.new().upgrade(v1)
	assert_true(SaveSchema.is_valid(v2))
	var expected: Dictionary = v1.duplicate(true)
	expected["schema_version"] = 2
	for language: String in expected["progress"]["by_lang"]:
		var state: Dictionary = expected["progress"]["by_lang"][language]
		state["highest_completed_slot"] = state["completed_slot"]
	assert_eq_deep(v2, expected)
	assert_eq_deep(v1, original)
	var canonical: Dictionary = SaveSchema.canonical(v2)
	assert_eq_deep(canonical["root_extension"], original["root_extension"])
	var restored: BoardState = BoardState.from_dict(
		_level(), canonical["progress"]["by_lang"]["pl"]["level_state"]
	)
	assert_not_null(restored)
	assert_eq_deep(restored.to_dict(), _snapshot())
	var before_canonical: Dictionary = v2.duplicate(true)
	canonical["progress"]["by_lang"]["en"]["extension"].append("changed")
	canonical["progress"]["by_lang"]["pl"]["level_state"]["revealed_cells"].append([9, 9])
	assert_eq_deep(v2, before_canonical)
	assert_eq_deep(v1, original)


func test_migrated_primary_is_flushed() -> void:
	var v1: Dictionary = _fixture(1)
	v1["progress"]["by_lang"]["pl"]["current_slot"] = 3
	v1["progress"]["by_lang"]["pl"]["completed_slot"] = 2
	v1["economy"]["coins"] = 37
	_write(v1)
	var original_text: String = FileAccess.get_file_as_string(TEST_PATH)
	var storage: ObservedStorage = ObservedStorage.new(TEST_PATH)
	var service: SAVE_SCRIPT = _save(storage)
	watch_signals(service)
	watch_signals(Events)
	assert_eq(service.load(), OK)
	assert_eq(service.load(), OK)
	assert_eq(storage.commits, 0, "load upgrades only in memory")
	assert_eq(service.get_section(&"progress")["by_lang"]["pl"]["highest_completed_slot"], 2)
	assert_eq(service.get_section(&"economy")["coins"], 37)
	assert_eq(FileAccess.get_file_as_string(TEST_PATH), original_text)
	assert_signal_not_emitted(Events, "save_corrupted")
	assert_signal_not_emitted(service, "backup_restored")
	storage.stop_at = &"temp_flushed"
	assert_eq(service.flush(), ERR_BUSY)
	assert_eq(FileAccess.get_file_as_string(TEST_PATH), original_text)
	storage.stop_at = &""
	assert_eq(service.flush(), OK)
	assert_eq(storage.commits, 2, "failed migration flush must remain dirty for retry")
	assert_eq_deep(
		SaveSchema.canonical(storage.read_document()),
		SaveSchema.canonical(SaveMigrations.new().upgrade(v1))
	)
	assert_eq(FileAccess.get_file_as_string(TEST_PATH + ".bak"), original_text)
	var next_storage: ObservedStorage = ObservedStorage.new(TEST_PATH)
	var next_service: SAVE_SCRIPT = _save(next_storage)
	assert_eq(next_service.load(), OK)
	assert_eq(next_service.flush(), OK)
	assert_eq(next_storage.commits, 0, "already-current primary is clean")
	assert_eq(next_service.get_section(&"meta")["install_id"], ID)
	assert_eq(next_service.get_section(&"progress"), service.get_section(&"progress"))


func test_multilanguage_and_bad_progress() -> void:
	var data: Dictionary = _fixture(2)
	data["progress"]["by_lang"]["en"] = SaveSchema.LANGUAGE_STATE.duplicate(true)
	data["progress"]["by_lang"]["de"] = SaveSchema.LANGUAGE_STATE.duplicate(true)
	data["progress"]["by_lang"]["en"]["current_slot"] = 5
	data["progress"]["by_lang"]["en"]["highest_completed_slot"] = 4
	data["progress"]["by_lang"]["de"]["level_state"] = _snapshot()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_true(SaveSchema.is_valid(parsed))
	var canonical: Dictionary = SaveSchema.canonical(parsed)
	for language: String in canonical["progress"]["by_lang"]:
		for key: String in ["current_slot", "completed_slot", "highest_completed_slot", "stars"]:
			assert_typeof(canonical["progress"]["by_lang"][language][key], TYPE_INT)
	var without_pl: Dictionary = data.duplicate(true)
	without_pl["progress"]["by_lang"].erase("pl")
	assert_true(SaveSchema.is_valid(without_pl), "language maps must not require Polish")
	without_pl["progress"]["by_lang"].clear()
	assert_true(
		SaveSchema.is_valid(without_pl), "absent language progress starts from defaults later"
	)
	for change: Dictionary in [
		{"current_slot": 0},
		{"current_slot": true},
		{"current_slot": 1.5},
		{"highest_completed_slot": -1},
		{"highest_completed_slot": "3"},
		{"completed_slot": -1},
		{"stars": -1},
		{"location_pieces": []},
		{"level_state": []},
		{"level_state": {"level_id": "incomplete"}},
	]:
		var bad: Dictionary = data.duplicate(true)
		bad["progress"]["by_lang"]["en"].merge(change, true)
		assert_false(SaveSchema.is_valid(bad), str(change))
	for state: Variant in [null, [], {}, {"current_slot": 1}]:
		var bad: Dictionary = data.duplicate(true)
		bad["progress"]["by_lang"]["en"] = state
		assert_false(SaveSchema.is_valid(bad), "every language must have a complete valid state")
	var missing: Dictionary = data.duplicate(true)
	missing["progress"]["by_lang"]["de"].erase("highest_completed_slot")
	assert_false(SaveSchema.is_valid(missing))
	var empty_language: Dictionary = data.duplicate(true)
	empty_language["progress"]["by_lang"][""] = SaveSchema.LANGUAGE_STATE.duplicate(true)
	assert_false(SaveSchema.is_valid(empty_language))


func test_bad_snapshots_and_content_validation_boundary() -> void:
	for change: Dictionary in [
		{"level_id": ""},
		{"found_words": [42]},
		{"found_words": ["DOM", "DOM"]},
		{"bonus_words": [""]},
		{"revealed_cells": [[true, 0]]},
		{"revealed_cells": [[0.5, 0]]},
		{"revealed_cells": [[-1, 0]]},
		{"revealed_cells": [[LevelData.MAX_GRID, 0]]},
		{"revealed_cells": [[0]]},
		{"revealed_cells": [[0, 0], [0, 0]]}
	]:
		var bad: Dictionary = _fixture(2)
		var snapshot: Dictionary = _snapshot()
		snapshot.merge(change, true)
		bad["progress"]["by_lang"]["pl"]["level_state"] = snapshot
		assert_false(SaveSchema.is_valid(bad), str(change))
	var stale: Dictionary = _fixture(2)
	var snapshot: Dictionary = _snapshot()
	snapshot["level_id"] = "old-content-id"
	stale["progress"]["by_lang"]["pl"]["level_state"] = snapshot
	assert_true(SaveSchema.is_valid(stale), "Save validates structure without loading content")
	assert_null(BoardState.from_dict(_level(), snapshot))
