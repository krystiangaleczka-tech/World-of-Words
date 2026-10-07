extends GutTest


func _level() -> LevelData:
	return LevelData.from_dict(
		{
			"id": "contract",
			"slot": 1,
			"letters": ["K", "O", "T"],
			"words": [{"w": "KOT", "x": 0, "y": 0, "dir": "h"}],
			"bonus": ["TOK"],
			"grid": {"w": 3, "h": 1}
		}
	)


func test_fresh_contract_and_copies() -> void:
	var level: LevelData = _level()
	var board: BoardState = BoardState.new(level)
	assert_same(board.get_level(), level)
	assert_false(board.is_complete())
	var copy: Array[Vector2i] = board.revealed_cells()
	copy.append(Vector2i.ZERO)
	var words: PackedStringArray = board.found_words()
	words.append("KOT")
	assert_true(board.revealed_cells().is_empty())
	assert_true(board.found_words().is_empty())
	assert_true(board.bonus_words().is_empty())


func test_ignored_and_invalid_attempts() -> void:
	var board: BoardState = BoardState.new(_level())
	assert_null(board.evaluate(PackedInt32Array([0, 1])))
	assert_eq(board.evaluate(PackedInt32Array([0, 0, 2])).kind, AttemptResult.Kind.INVALID)
	assert_false(board.is_complete())


func test_json_round_trip_and_reject_corruption() -> void:
	var level: LevelData = _level()
	var source: BoardState = BoardState.new(level)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(source.to_dict()))
	var restored: BoardState = BoardState.from_dict(level, snapshot)
	assert_not_null(restored)
	assert_eq_deep(restored.to_dict(), source.to_dict())
	for change: Dictionary in [
		{"level_id": "other"},
		{"found_words": ["KOT"]},
		{"bonus_words": ["bad"]},
		{"revealed_cells": [[true, 0]]},
		{"revealed_cells": [[0.5, 0]]},
		{"revealed_cells": [[9, 9]]},
		{"revealed_cells": [[0, 0], [0, 0]]}
	]:
		var malformed: Dictionary = snapshot.duplicate(true)
		malformed.merge(change, true)
		assert_null(BoardState.from_dict(level, malformed), str(change))
	var valid: Dictionary = {
		"level_id": "contract",
		"found_words": ["KOT"],
		"bonus_words": ["TOK"],
		"revealed_cells": [[0, 0], [1, 0], [2, 0]]
	}
	assert_true(BoardState.from_dict(level, valid).is_complete())
