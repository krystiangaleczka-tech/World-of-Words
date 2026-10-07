extends GutTest


func _board() -> BoardState:
	var level: LevelData = LevelData.from_dict(
		{
			"id": "hint",
			"letters": ["D", "O", "M", "A"],
			"grid": {"w": 3, "h": 4},
			"words":
			[{"w": "MODA", "x": 2, "y": 0, "dir": "v"}, {"w": "DOM", "x": 0, "y": 0, "dir": "h"}],
			"bonus": []
		}
	)
	return BoardState.new(level)


func test_shortest_and_data_order_tie() -> void:
	var board: BoardState = _board()
	var snapshot: Dictionary = board.to_dict()
	assert_eq(HintLogic.next_cell(board), Vector2i.ZERO)
	assert_eq_deep(board.to_dict(), snapshot)
	var tie: LevelData = LevelData.from_dict(
		{
			"id": "tie",
			"letters": ["K", "O", "T"],
			"grid": {"w": 3, "h": 3},
			"words":
			[{"w": "TOK", "x": 2, "y": 0, "dir": "v"}, {"w": "KOT", "x": 0, "y": 0, "dir": "h"}],
			"bonus": []
		}
	)
	assert_eq(HintLogic.next_cell(BoardState.new(tie)), Vector2i(2, 0))


func test_skip_revealed_and_complete() -> void:
	var board: BoardState = _board()
	board.reveal_cell(Vector2i.ZERO)
	assert_eq(HintLogic.next_cell(board), Vector2i(1, 0))
	assert_eq(HintLogic.next_cell(null), Vector2i(-1, -1))
	for index: int in 6:
		board.reveal_cell(HintLogic.next_cell(board))
	assert_true(board.is_complete())
	assert_eq(HintLogic.next_cell(board), Vector2i(-1, -1))


func test_repeated_hints_terminate() -> void:
	var board: BoardState = _board()
	var seen: Array[Vector2i] = []
	for index: int in 6:
		var cell: Vector2i = HintLogic.next_cell(board)
		assert_false(cell in seen)
		seen.append(cell)
		assert_true(board.reveal_cell(cell))
	assert_true(board.is_complete())
	assert_eq(board.found_words().size(), 2)
