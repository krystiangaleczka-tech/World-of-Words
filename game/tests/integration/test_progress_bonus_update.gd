extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")
const TEST_PATH: String = "user://t0147-bonus-update.json"
const ID: String = "12345678-1234-4234-8234-123456789abc"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class UpdatedContent:
	extends "res://services/content.gd"
	var level: LevelData

	func is_loaded() -> bool:
		return true

	func get_language() -> String:
		return "pl"

	func level_for_slot(slot: int) -> LevelData:
		return level if slot == 2 else null


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)


func _save() -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(FixedClock.new())
	save.configure(SaveStorage.new(TEST_PATH), func() -> String: return ID)
	assert_eq(save.load(), OK)
	return save


func _content(bonus: Array) -> UpdatedContent:
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	var data: Dictionary = pack["levels"][1]
	data["bonus"] = bonus
	var content: UpdatedContent = UpdatedContent.new()
	add_child_autofree(content)
	content.level = LevelData.from_dict(data)
	return content


func _progress(save: SAVE_SCRIPT, content: UpdatedContent) -> PROGRESS_SCRIPT:
	var progress: PROGRESS_SCRIPT = PROGRESS_SCRIPT.new()
	add_child_autofree(progress)
	progress.configure(save, content)
	return progress


func _seed() -> Dictionary:
	var save: SAVE_SCRIPT = _save()
	var section: Dictionary = save.get_section(&"progress")
	section["by_lang"]["pl"]["current_slot"] = 2
	assert_eq(save.set_section(&"progress", section), OK)
	var content: UpdatedContent = _content(["DAM", "ODA"])
	var board: BoardState = BoardState.new(content.level)
	board.evaluate(PackedInt32Array([0, 1, 2]))
	board.evaluate(PackedInt32Array([0, 3, 2]))
	assert_true(board.reveal_cell(Vector2i(2, 1)))
	assert_eq(_progress(save, content).save_level(board), OK)
	return board.to_dict()


func test_bonus_removal_resave_and_reintroduction_preserve_progress() -> void:
	var snapshot: Dictionary = _seed()
	var save: SAVE_SCRIPT = _save()
	var content: UpdatedContent = _content(["ODA"])
	var progress: PROGRESS_SCRIPT = _progress(save, content)
	watch_signals(progress)
	var board: BoardState = progress.restore_level(content.level)
	assert_not_null(board)
	if board == null:
		return
	assert_eq_deep(board.to_dict(), snapshot)
	assert_eq(board.evaluate(PackedInt32Array([0, 3, 2])).kind, AttemptResult.Kind.INVALID)
	assert_eq(progress.save_level(board), OK)
	var restored: BoardState = _progress(_save(), content).restore_level(content.level)
	assert_eq_deep(restored.to_dict(), snapshot)
	var reintroduced: UpdatedContent = _content(["DAM", "ODA"])
	var again: BoardState = _progress(_save(), reintroduced).restore_level(reintroduced.level)
	assert_eq(again.evaluate(PackedInt32Array([0, 3, 2])).kind, AttemptResult.Kind.ALREADY_FOUND)
	assert_eq(again.bonus_words().size(), 1)
	assert_eq_deep(again.to_dict(), snapshot)
	assert_signal_not_emitted(progress, "completed")
	assert_eq(save.get_section(&"progress")["bonus_meter"], 0)
	assert_eq(save.get_section(&"economy")["coins"], 0)


func test_invalid_historical_bonus_still_falls_back_to_fresh_board() -> void:
	_seed()
	var save: SAVE_SCRIPT = _save()
	var section: Dictionary = save.get_section(&"progress")
	section["by_lang"]["pl"]["level_state"]["bonus_words"] = ["DDD"]
	assert_eq(save.set_section(&"progress", section), OK)
	assert_eq(save.flush(), OK)
	var content: UpdatedContent = _content([])
	var restored: BoardState = _progress(_save(), content).restore_level(content.level)
	assert_not_null(restored)
	if restored != null:
		assert_true(restored.revealed_cells().is_empty())
		assert_true(restored.found_words().is_empty())
		assert_true(restored.bonus_words().is_empty())
