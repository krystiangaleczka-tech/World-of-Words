extends GutTest

const HC: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")


func test_generated_cell_palette_font_and_native_states() -> void:
	var cell: GridCell = GridCell.new()
	cell.theme = HC
	cell.size = Vector2.ONE * Tokens.Layout.CELL_MAX
	cell.letter = "Ź"
	add_child_autofree(cell)
	assert_same(cell.get_theme_font(&"font", &"TileLetter"), HC.get_font(&"font", &"TileLetter"))
	for key: StringName in [&"CELL_EMPTY", &"CELL_HINTED", &"CELL_FILLED", &"TEXT", &"STROKE"]:
		assert_eq(cell.get_theme_color(key, &"Palette"), HC.get_color(key, &"Palette"))
	for state: GridCell.State in GridCell.State.values():
		cell.state = state
		assert_eq(cell.state, state)
		assert_eq(cell.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	cell.theme = preload("res://ui/theme/generated/theme_default_100.tres")
	await get_tree().process_frame
	assert_eq(cell.get_theme_color(&"CELL_HINTED", &"Palette"), Tokens.Palette.CELL_HINTED)


func test_three_class_geometry_ratios_padding_caps_and_grid_share() -> void:
	for layout: StringName in [&"COMPACT", &"REGULAR", &"TABLET"]:
		var size: Vector2 = Vector2(1080, 2200) if layout != &"TABLET" else Vector2(1440, 2200)
		var rectangles: Dictionary[StringName, Rect2] = BoardView.play_area_rects(
			size, layout, 162, 144
		)
		var board: Rect2 = rectangles[&"board"]
		var wheel: Rect2 = rectangles[&"wheel"]
		var ratio: float = (
			Tokens.Layout.WHEEL_COMPACT_RATIO
			if layout == &"COMPACT"
			else Tokens.Layout.WHEEL_WIDTH_RATIO
		)
		assert_almost_eq(wheel.size.x, minf(Tokens.Layout.WHEEL_MAX, 1080 * ratio), 0.01)
		assert_eq(board.size.x, 1080.0)
		assert_eq(board.position.x, (size.x - 1080) / 2)
		assert_almost_eq(wheel.position.y + wheel.size.y, size.y - Tokens.Space.L, 0.001)
		assert_gte(board.size.y, size.y * Tokens.Layout.GRID_MIN_RATIO)
		assert_gt(wheel.position.y, rectangles[&"actions"].end.y)
		assert_false(board.intersects(rectangles[&"preview"]))
		assert_false(rectangles[&"preview"].intersects(rectangles[&"actions"]))
		assert_false(rectangles[&"actions"].intersects(wheel))
	var constrained: Dictionary[StringName, Rect2] = BoardView.play_area_rects(
		Vector2(936, 1300), &"COMPACT", 180, 144
	)
	assert_lt(constrained[&"wheel"].size.x, 936 * Tokens.Layout.WHEEL_COMPACT_RATIO)
	assert_gte(constrained[&"board"].size.y, 1300 * Tokens.Layout.GRID_MIN_RATIO - 0.01)


func test_invalid_and_tiny_geometry_remains_bounded() -> void:
	for available: Vector2 in [Vector2.ZERO, Vector2(-1, 1), Vector2(INF, 100), Vector2(100, NAN)]:
		assert_true(BoardView.play_area_rects(available, &"COMPACT", 100).is_empty())
	assert_true(BoardView.play_area_rects(Vector2(100, 100), &"UNKNOWN", 100).is_empty())
	assert_true(BoardView.play_area_rects(Vector2(100, 100), &"TABLET", -1).is_empty())
	assert_true(BoardView.play_area_rects(Vector2(100, 100), &"TABLET", 100, INF).is_empty())
	for available: Vector2 in [Vector2(1, 1), Vector2(160, 120), Vector2(936, 600)]:
		var rectangles: Dictionary[StringName, Rect2] = BoardView.play_area_rects(
			available, &"COMPACT", 200, 300
		)
		for rect: Rect2 in rectangles.values():
			assert_gte(rect.position.x, -0.001)
			assert_gte(rect.position.y, -0.001)
			assert_gte(rect.size.x, 0.0)
			assert_gte(rect.size.y, 0.0)
			assert_lte(rect.end.x, available.x + 0.001)
			assert_lte(rect.end.y, available.y + 0.001)


func test_populated_screen_survives_impossible_host_then_recovers() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	var screen: LevelScreen = (load("res://features/level/gallery.gd") as GDScript).new()
	viewport.add_child(screen)
	for frame: int in 3:
		await get_tree().process_frame
	assert_gt(screen.wheel.tile_order().size(), 0)
	var host: Control = screen.wheel.get_parent() as Control
	host.size = Vector2(936, 100)
	assert_false(screen.wheel.visible)
	assert_gt(screen.wheel.size.x, 0.0)
	host.size = Vector2(936, 1300)
	assert_true(screen.wheel.visible)
	assert_gt(screen.wheel.size.x, 0.0)
	screen.queue_free()
