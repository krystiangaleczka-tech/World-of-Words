extends GutTest

const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const FIXTURE: String = "res://tests/fixtures/content"
const TEST_PATH: String = "user://t0111-progress-contract.json"
const INSTALL_ID: String = "12345678-1234-4234-8234-123456789abc"

var _progress: PROGRESS_SCRIPT = null
var _save: SAVE_SCRIPT = null
var _content: CONTENT_SCRIPT = null


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


func before_each() -> void:
	_clean()
	_save = SAVE_SCRIPT.new()
	add_child_autofree(_save)
	_save.initialize(FixedClock.new())
	_save.configure(SaveStorage.new(TEST_PATH), func() -> String: return INSTALL_ID)
	_content = CONTENT_SCRIPT.new()
	add_child_autofree(_content)
	_progress = PROGRESS_SCRIPT.new()
	add_child_autofree(_progress)
	_progress.configure(_save, _content)


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)


func _load() -> void:
	assert_eq(_save.load(), OK)
	assert_eq(_content.load_manifest("pl", FIXTURE), OK)


func _level_with_partial_board() -> BoardState:
	var level: LevelData = _content.level_for_slot(2)
	var board: BoardState = BoardState.new(level)
	board.evaluate(PackedInt32Array([0, 1, 2]))
	board.evaluate(PackedInt32Array([0, 3, 2]))
	return board


func test_language_defaults_and_isolation() -> void:
	_load()
	assert_eq(_progress.current_slot(), 1)
	assert_eq(_progress.highest_completed_slot(), 0)
	assert_eq(_progress.current_slot("de"), 1)
	assert_eq(_progress.highest_completed_slot("de"), 0)
	var progress_data: Dictionary = _save.get_section(&"progress")
	progress_data["by_lang"]["pl"]["current_slot"] = 3
	progress_data["by_lang"]["pl"]["highest_completed_slot"] = 2
	var english: Dictionary = SaveSchema.LANGUAGE_STATE.duplicate(true)
	english["current_slot"] = 8
	english["highest_completed_slot"] = 7
	progress_data["by_lang"]["en"] = english
	assert_eq(_save.set_section(&"progress", progress_data), OK)
	assert_eq(_progress.current_slot(), 3)
	assert_eq(_progress.highest_completed_slot(), 2)
	assert_eq(_progress.current_slot("pl"), 3)
	assert_eq(_progress.highest_completed_slot("pl"), 2)
	assert_eq(_progress.current_slot("en"), 8)
	assert_eq(_progress.highest_completed_slot("en"), 7)
	assert_eq(_progress.current_slot("de"), 1)
	assert_eq(_progress.highest_completed_slot("de"), 0)
	assert_false(_save.get_section(&"progress")["by_lang"].has("de"))


func test_restore_matching_or_stale_snapshot() -> void:
	_load()
	var level: LevelData = _content.level_for_slot(2)
	var board: BoardState = _level_with_partial_board()
	var snapshot: Dictionary = board.to_dict()
	var progress_data: Dictionary = _save.get_section(&"progress")
	progress_data["by_lang"]["pl"]["current_slot"] = 2
	progress_data["by_lang"]["pl"]["level_state"] = snapshot
	assert_eq(_save.set_section(&"progress", progress_data), OK)
	var restored: BoardState = _progress.restore_level(level)
	assert_not_null(restored)
	assert_eq_deep(restored.to_dict(), snapshot)
	assert_null(_progress.restore_level(_content.level_for_slot(1)))
	var stale_data: Dictionary = _save.get_section(&"progress")
	stale_data["by_lang"]["pl"]["level_state"]["level_id"] = "pl-c-old-content"
	assert_eq(_save.set_section(&"progress", stale_data), OK)
	var fresh: BoardState = _progress.restore_level(level)
	assert_not_null(fresh)
	assert_eq(fresh.found_words(), PackedStringArray())
	assert_eq(fresh.bonus_words(), PackedStringArray())
	assert_true(fresh.revealed_cells().is_empty())
	assert_eq(fresh.to_dict()["level_id"], level.get_id())
	assert_eq(
		_save.get_section(&"progress")["by_lang"]["pl"]["level_state"]["level_id"],
		"pl-c-old-content"
	)
	var invalid_data: Dictionary = _save.get_section(&"progress")
	invalid_data["by_lang"]["pl"]["level_state"] = snapshot.duplicate(true)
	invalid_data["by_lang"]["pl"]["level_state"]["found_words"] = ["NOT_A_LEVEL_WORD"]
	assert_eq(_save.set_section(&"progress", invalid_data), OK)
	fresh = _progress.restore_level(level)
	assert_not_null(fresh)
	assert_true(fresh.revealed_cells().is_empty())
	assert_eq(
		_save.get_section(&"progress")["by_lang"]["pl"]["level_state"]["found_words"],
		["NOT_A_LEVEL_WORD"]
	)


func test_readiness_and_frozen_writes() -> void:
	assert_eq(_progress.current_slot(), -1)
	assert_eq(_progress.highest_completed_slot(), -1)
	assert_null(_progress.restore_level(null))
	assert_eq(_progress.save_level(null), ERR_UNCONFIGURED)
	assert_eq(_progress.complete_level(1), ERR_UNCONFIGURED)
	assert_eq(_save.load(), OK)
	assert_eq(_progress.current_slot(), -1, "Content must load before Progress reads")
	assert_eq(_content.load_manifest("pl", FIXTURE), OK)
	assert_eq(_progress.current_slot(), 1)
	var level: LevelData = _content.level_for_slot(1)
	assert_not_null(_progress.restore_level(level))
	assert_eq(_progress.save_level(BoardState.new(level)), ERR_UNAVAILABLE)
	assert_eq(_progress.complete_level(1), ERR_UNAVAILABLE)
	assert_eq(_progress.save_level(null), ERR_INVALID_PARAMETER)
	assert_eq(_progress.complete_level(2), ERR_INVALID_PARAMETER)
	assert_eq(_save.set_setting(&"language", "en"), OK)
	assert_eq(_progress.current_slot(), -1, "Save and Content languages must match")
	assert_eq(_progress.highest_completed_slot(), -1)
	assert_null(_progress.restore_level(level))
	assert_eq(_progress.save_level(BoardState.new(level)), ERR_UNCONFIGURED)
	assert_eq(_progress.complete_level(1), ERR_UNCONFIGURED)
