extends GutTest


func _level(bonus: Array = ["DAM", "ODA"]) -> LevelData:
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	var data: Dictionary = pack["levels"][1]
	data["bonus"] = bonus
	return LevelData.from_dict(data)


func _snapshot() -> Dictionary:
	var board: BoardState = BoardState.new(_level())
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 2])).kind, AttemptResult.Kind.LEVEL)
	assert_eq(board.evaluate(PackedInt32Array([0, 3, 2])).kind, AttemptResult.Kind.BONUS)
	assert_true(board.reveal_cell(Vector2i(2, 1)))
	return board.to_dict()


func test_history_requires_opt_in_and_preserves_partial_board() -> void:
	var snapshot: Dictionary = _snapshot()
	var updated: LevelData = _level(["ODA"])
	assert_null(BoardState.from_dict(updated, snapshot), "Default strict contract stays intact")
	var restored: BoardState = BoardState.from_dict(updated, snapshot, true)
	assert_not_null(restored)
	if restored == null:
		return
	watch_signals(restored)
	assert_eq_deep(restored.to_dict(), snapshot)
	assert_eq(restored.found_words(), PackedStringArray(["DOM"]))
	assert_eq(restored.bonus_words(), PackedStringArray(["DAM"]))
	assert_false(restored.is_complete())
	assert_eq(restored.evaluate(PackedInt32Array([0, 3, 2])).kind, AttemptResult.Kind.INVALID)
	assert_eq_deep(restored.to_dict(), snapshot)
	assert_signal_not_emitted(restored, "completed")
	assert_eq(restored.evaluate(PackedInt32Array([1, 0, 3])).kind, AttemptResult.Kind.BONUS)
	assert_eq(restored.bonus_words(), PackedStringArray(["DAM", "ODA"]))


func test_reintroduced_credit_is_not_credited_again_after_roundtrip() -> void:
	var snapshot: Dictionary = _snapshot()
	var retired: BoardState = BoardState.from_dict(_level([]), snapshot, true)
	assert_not_null(retired)
	if retired == null:
		return
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(retired.to_dict()))
	var restored: BoardState = BoardState.from_dict(_level(), serialized, true)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.evaluate(PackedInt32Array([0, 3, 2])).kind, AttemptResult.Kind.ALREADY_FOUND)
	assert_eq(restored.bonus_words().size(), 1)
	assert_eq_deep(restored.to_dict(), snapshot)


func test_historical_mode_rejects_malformed_or_nonformable_records() -> void:
	var snapshot: Dictionary = _snapshot()
	for bonus: Array in [
		["DAM", "DAM"], [42], ["DA"], ["DAMOD"], ["DDD"], ["dam"], ["DÓM"], ["DOM"]
	]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad["bonus_words"] = bonus
		assert_null(BoardState.from_dict(_level([]), bad, true), str(bonus))
	var wrong_id: Dictionary = snapshot.duplicate(true)
	wrong_id["level_id"] = "other-id"
	assert_null(BoardState.from_dict(_level([]), wrong_id, true))
	var bad_cell: Dictionary = snapshot.duplicate(true)
	bad_cell["revealed_cells"].append([0, 3])
	assert_null(BoardState.from_dict(_level([]), bad_cell, true))
	var bad_found: Dictionary = snapshot.duplicate(true)
	bad_found["found_words"] = []
	assert_null(BoardState.from_dict(_level([]), bad_found, true))


func test_repeated_letters_require_distinct_available_tiles() -> void:
	var data: Dictionary = {
		"id": "repeated",
		"letters": ["K", "A", "A", "S"],
		"grid": {"w": 4, "h": 1},
		"words": [{"w": "KASA", "x": 0, "y": 0, "dir": "h"}],
		"bonus": []
	}
	var level: LevelData = LevelData.from_dict(data)
	var snapshot: Dictionary = BoardState.new(level).to_dict()
	snapshot["bonus_words"] = ["ASA"]
	var restored: BoardState = BoardState.from_dict(level, snapshot, true)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.bonus_words(), PackedStringArray(["ASA"]))
	for word: String in ["AAA", "SSS"]:
		snapshot["bonus_words"] = [word]
		assert_null(BoardState.from_dict(level, snapshot, true))
