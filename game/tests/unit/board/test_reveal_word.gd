extends GutTest


func _board() -> BoardState:
	return BoardState.new(
		LevelData.from_dict(
			{
				"id": "reveal",
				"letters": ["D", "O", "M", "A"],
				"grid": {"w": 4, "h": 4},
				"words":
				[
					{"w": "MODA", "x": 2, "y": 0, "dir": "v"},
					{"w": "DOM", "x": 0, "y": 0, "dir": "h"},
					{"w": "ODAM", "x": 0, "y": 3, "dir": "h"}
				],
				"bonus": ["ODA"]
			}
		)
	)


func test_longest_first_tie_and_pure_repeated_result() -> void:
	var board: BoardState = _board()
	var before: Dictionary = board.to_dict()
	assert_eq(HintLogic.reveal_word(board), "MODA")
	assert_eq(HintLogic.reveal_word(board), "MODA")
	assert_eq_deep(board.to_dict(), before)
	assert_eq(HintLogic.next_cell(board), Vector2i.ZERO)


func test_partial_reveals_keep_length_priority_and_found_words_are_skipped() -> void:
	var board: BoardState = _board()
	board.reveal_cell(Vector2i(2, 0))
	board.reveal_cell(Vector2i(2, 1))
	board.reveal_cell(Vector2i(2, 2))
	assert_eq(HintLogic.reveal_word(board), "MODA")
	board.reveal_cell(Vector2i(2, 3))
	assert_eq(HintLogic.reveal_word(board), "ODAM")
	assert_true("MODA" in board.found_words())


func test_caller_reveals_all_target_cells_until_complete_without_bonus_target() -> void:
	var board: BoardState = _board()
	var targets: Array[String] = []
	while not board.is_complete():
		var target: String = HintLogic.reveal_word(board)
		assert_false(target.is_empty())
		targets.append(target)
		for index: int in board.get_level().word_count():
			if board.get_level().word(index) == target:
				for cell: Vector2i in board.get_level().word_cells(index):
					board.reveal_cell(cell)
	assert_eq(targets, ["MODA", "ODAM", "DOM"])
	assert_eq(HintLogic.reveal_word(board), "")
	assert_eq(HintLogic.reveal_word(null), "")
	assert_eq(HintLogic.reveal_word(BoardState.new(null)), "")
	assert_true(board.bonus_words().is_empty())
