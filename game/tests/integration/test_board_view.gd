extends GutTest


func _level(index: int = 1) -> LevelData:
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	return LevelData.from_dict(pack["levels"][index])


func _view(board: BoardState) -> BoardView:
	var view: BoardView = load("res://ui/components/BoardView.tscn").instantiate() as BoardView
	view.size = Vector2(800, 700)
	add_child_autofree(view)
	view.set_board(board)
	return view


func test_shared_cells_and_visual_states() -> void:
	var level: LevelData = _level()
	var board: BoardState = BoardState.new(level)
	var view: BoardView = _view(board)
	assert_eq(view.get_child_count(), 6, "DOM and MODA share one cell")
	assert_null(view.cell_node(Vector2i(0, 1)))
	var shared: GridCell = view.cell_node(Vector2i(2, 0))
	assert_eq(shared.letter, "M")
	assert_eq(shared.state, GridCell.State.EMPTY)
	board.reveal_cell(Vector2i(2, 1))
	view.refresh()
	assert_eq(view.cell_node(Vector2i(2, 1)).state, GridCell.State.HINTED)
	board.evaluate(PackedInt32Array([0, 1, 2]))
	view.reveal_word(level.word_cells(0))
	assert_same(view.cell_node(Vector2i(2, 0)), shared)
	assert_eq(shared.state, GridCell.State.FILLED)
	view.play_wave()
	assert_eq(shared.state, GridCell.State.HIGHLIGHTED)
	assert_eq(view.cell_node(Vector2i(2, 3)).state, GridCell.State.EMPTY)
	view.refresh()
	assert_eq(shared.state, GridCell.State.FILLED)
	var snapshot: Dictionary = board.to_dict()
	view.reveal_cell(Vector2i(2, 3), true)
	assert_eq(view.cell_node(Vector2i(2, 3)).state, GridCell.State.HINTED)
	view.reveal_cell(Vector2i(9, 9), false)
	assert_eq_deep(board.to_dict(), snapshot)
	view.set_board(BoardState.from_dict(level, snapshot))
	assert_eq(view.cell_node(Vector2i(2, 1)).state, GridCell.State.HINTED)
	view.set_board(BoardState.new(_level(0)))
	assert_eq(view.get_child_count(), 3)
	assert_null(view.cell_node(Vector2i(2, 3)))
	view.set_board(null)
	assert_eq(view.get_child_count(), 0)
	assert_true(view.fits_minimum())


func test_fit_and_resize_bounds() -> void:
	var view: BoardView = _view(BoardState.new(_level(2)))
	for rect: Vector2 in [
		Vector2(1080, 700),
		Vector2(1080, 1000),
		Vector2(1440, 900),
		Vector2(352, 280),
		Vector2(160, 120),
		Vector2(4, 2),
		Vector2.ZERO
	]:
		view.size = rect
		assert_eq(view.fits_minimum(), rect.x >= 352 and rect.y >= 280)
		for node: Node in view.get_children():
			var cell: GridCell = node as GridCell
			assert_almost_eq(cell.size.x, cell.size.y, 0.001)
			assert_lte(cell.size.x, float(Tokens.Layout.CELL_MAX))
			assert_gte(cell.position.x, -0.001)
			assert_gte(cell.position.y, -0.001)
			assert_lte(cell.position.x + cell.size.x, rect.x + 0.001)
			assert_lte(cell.position.y + cell.size.y, rect.y + 0.001)
		var start: GridCell = view.cell_node(Vector2i.ZERO)
		var end: GridCell = view.cell_node(Vector2i(4, 0))
		assert_almost_eq(start.position.x, rect.x - end.position.x - end.size.x, 0.001)
	view.size = Vector2(1000, 1000)
	assert_true(view.fits_minimum())
	assert_eq(view.cell_node(Vector2i.ZERO).size.x, float(Tokens.Layout.CELL_MAX))
	var first: GridCell = view.cell_node(Vector2i.ZERO)
	var second: GridCell = view.cell_node(Vector2i.RIGHT)
	assert_almost_eq(
		second.position.x - first.position.x - first.size.x, float(Tokens.Space.XS), 0.001
	)


func test_global_cell_position() -> void:
	var parent: Control = Control.new()
	parent.position = Vector2(31, 47)
	parent.scale = Vector2(1.2, 0.8)
	parent.rotation = 0.2
	add_child_autofree(parent)
	var view: BoardView = BoardView.new()
	view.position = Vector2(19, 23)
	view.size = Vector2(600, 700)
	parent.add_child(view)
	view.set_board(BoardState.new(_level()))
	var cell: GridCell = view.cell_node(Vector2i(2, 1))
	var expected: Vector2 = view.get_global_transform() * (cell.position + cell.size / 2.0)
	assert_almost_eq(view.cell_global_position(Vector2i(2, 1)), expected, Vector2.ONE * 0.001)
	assert_eq(view.cell_global_position(Vector2i(-1, -1)), Vector2.ZERO)


func test_maximum_sparse_grid_keeps_coordinate_offsets() -> void:
	var level: LevelData = LevelData.from_dict(
		{
			"id": "sparse",
			"letters": ["K", "O", "T", "L"],
			"bonus": [],
			"grid": {"w": 10, "h": 10},
			"words":
			[{"w": "KOT", "x": 7, "y": 9, "dir": "h"}, {"w": "LOT", "x": 9, "y": 7, "dir": "v"}]
		}
	)
	assert_not_null(level)
	var view: BoardView = _view(BoardState.new(level))
	assert_eq(view.get_child_count(), 5)
	assert_null(view.cell_node(Vector2i.ZERO))
	view.size = Vector2(712, 712)
	assert_true(view.fits_minimum())
	var corner: GridCell = view.cell_node(Vector2i(9, 9))
	assert_eq(corner.size, Vector2(64, 64))
	assert_eq(corner.position + corner.size, view.size)
	view.size = Vector2(71, 37)
	assert_false(view.fits_minimum())
	for node: Node in view.get_children():
		var cell: GridCell = node as GridCell
		assert_gte(cell.position.x, 0.0)
		assert_gte(cell.position.y, 0.0)
		assert_lte(cell.position.x + cell.size.x, view.size.x + 0.001)
		assert_lte(cell.position.y + cell.size.y, view.size.y + 0.001)


func test_gallery_and_cell_scene() -> void:
	var cell: GridCell = load("res://ui/components/GridCell.tscn").instantiate() as GridCell
	add_child_autofree(cell)
	assert_eq(cell.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var gallery: ScreenScaffold = (
		load("res://ui/gallery/board.tscn").instantiate() as ScreenScaffold
	)
	add_child_autofree(gallery)
	await get_tree().process_frame
	var boards: int = 0
	for node: Node in gallery.body.get_children():
		if node is BoardView:
			boards += 1
			assert_gt(node.get_child_count(), 0)
	assert_eq(boards, 2)
