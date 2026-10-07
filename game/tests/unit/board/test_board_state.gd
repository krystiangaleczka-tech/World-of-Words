extends GutTest


func _level(index: int = 1) -> LevelData:
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	return LevelData.from_dict(pack["levels"][index])


func test_membership_bonus_and_repeats() -> void:
	var board: BoardState = BoardState.new(_level())
	assert_null(board.evaluate(PackedInt32Array([0, 1])))
	assert_eq(board.evaluate(PackedInt32Array([0, 3, 2])).kind, AttemptResult.Kind.BONUS)
	assert_eq(board.evaluate(PackedInt32Array([0, 3, 2])).kind, AttemptResult.Kind.ALREADY_FOUND)
	var before: Dictionary = board.to_dict()
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 3])).kind, AttemptResult.Kind.INVALID)
	assert_eq(board.evaluate(PackedInt32Array([0, 0, 2])).kind, AttemptResult.Kind.INVALID)
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 99])).kind, AttemptResult.Kind.INVALID)
	assert_eq_deep(board.to_dict(), before)
	assert_eq(board.bonus_words().size(), 1)
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 2])).kind, AttemptResult.Kind.LEVEL)
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 2])).kind, AttemptResult.Kind.ALREADY_FOUND)


func test_repeated_letters_use_distinct_indices() -> void:
	var board: BoardState = BoardState.new(_level(2))
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 2, 3, 1])).kind, AttemptResult.Kind.INVALID)
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 2, 3, 4])).kind, AttemptResult.Kind.LEVEL)
	assert_eq(
		board.evaluate(PackedInt32Array([0, 4, 2, 3, 1])).kind, AttemptResult.Kind.ALREADY_FOUND
	)
	assert_eq(board.evaluate(PackedInt32Array([3, 1, 2, 4])).kind, AttemptResult.Kind.BONUS)
	assert_eq(board.evaluate(PackedInt32Array([3, 4, 2, 1])).kind, AttemptResult.Kind.ALREADY_FOUND)


func test_intersections_hints_and_completion_once() -> void:
	var board: BoardState = BoardState.new(_level())
	watch_signals(board)
	assert_false(board.reveal_cell(Vector2i(-1, 0)))
	for cell: Vector2i in _level().word_cells(0):
		assert_true(board.reveal_cell(cell))
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 2])).kind, AttemptResult.Kind.ALREADY_FOUND)
	var result: AttemptResult = board.evaluate(PackedInt32Array([2, 1, 0, 3]))
	assert_eq(result.cells_to_reveal.size(), 3)
	assert_eq(board.revealed_cells().size(), 6)
	assert_true(board.is_complete())
	assert_signal_emit_count(board, "completed", 1)
	assert_false(board.reveal_cell(Vector2i.ZERO))
	board.evaluate(PackedInt32Array([2, 1, 0, 3]))
	assert_signal_emit_count(board, "completed", 1)


func test_snapshot_round_trip() -> void:
	var level: LevelData = _level()
	var board: BoardState = BoardState.new(level)
	board.evaluate(PackedInt32Array([0, 3, 2]))
	board.evaluate(PackedInt32Array([0, 1, 2]))
	var data: Dictionary = JSON.parse_string(JSON.stringify(board.to_dict()))
	var restored: BoardState = BoardState.from_dict(level, data)
	assert_not_null(restored)
	assert_eq_deep(restored.to_dict(), board.to_dict())
	watch_signals(restored)
	restored.evaluate(PackedInt32Array([2, 1, 0, 3]))
	assert_signal_emit_count(restored, "completed", 1)
	var done: BoardState = BoardState.from_dict(level, restored.to_dict())
	watch_signals(done)
	done.evaluate(PackedInt32Array([2, 1, 0, 3]))
	assert_signal_not_emitted(done, "completed")
