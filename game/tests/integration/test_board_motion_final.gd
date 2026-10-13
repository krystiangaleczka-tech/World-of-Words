extends GutTest

var _motion: bool
var _board: BoardState
var _view: BoardView
var _word: Array[Vector2i]


func before_each() -> void:
	_motion = Tokens.reduced_motion
	Tokens.reduced_motion = false
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	var level: LevelData = LevelData.from_dict(data["levels"][1])
	_board = BoardState.new(level)
	_word = level.word_cells(0)
	_view = BoardView.new()
	_view.position = Vector2(100, 200)
	_view.size = Vector2(800, 700)
	add_child_autofree(_view)
	_view.set_board(_board)


func after_each() -> void:
	Tokens.reduced_motion = _motion


func _step(seconds: float) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(seconds)


func _settle() -> void:
	for phase: int in 4:
		_step(10)


func test_flight_atomic_stagger_landing_flash_and_passivity() -> void:
	var snapshot: Dictionary = _board.to_dict()
	assert_eq(_view.fly_word(_word, Vector2(500, 1100), _word), OK)
	assert_eq(_view.flight_state(), &"flying")
	var ghosts: Array[Node] = _view.find_children("FlightLetter*", "Label", true, false)
	assert_eq(ghosts.size(), _word.size())
	var first: Label = ghosts[0] as Label
	var second: Label = ghosts[1] as Label
	var start_first: Vector2 = first.position
	var start_second: Vector2 = second.position
	assert_almost_eq((first.get_global_transform() * (first.size / 2)).y, 1100.0, 0.01)
	for ghost: Label in ghosts:
		assert_eq(ghost.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_step(Tokens.dur(Tokens.Motion.STAGGER) / 2)
	assert_ne(first.position, start_first)
	assert_eq(second.position, start_second)
	assert_eq(_view.fly_word([Vector2i(99, 99)], Vector2.ZERO), ERR_INVALID_PARAMETER)
	assert_eq(_view.fly_word(_word, Vector2(INF, 0)), ERR_INVALID_PARAMETER)
	assert_eq(_view.find_children("FlightLetter*", "Label", true, false).size(), 3)
	_settle()
	assert_eq(_view.flight_state(), &"idle")
	assert_true(_view.find_children("FlightLetter*", "Label", true, false).is_empty())
	for cell: Vector2i in _word:
		assert_eq(_view.cell_node(cell).state, GridCell.State.FILLED)
		assert_eq(_view.cell_node(cell).scale, Vector2.ONE)
		assert_eq(_view.cell_node(cell).modulate, Color.WHITE)
	assert_eq_deep(_board.to_dict(), snapshot)


func test_landing_and_flash_reach_documented_peaks_and_restore() -> void:
	var cell: GridCell = _view.cell_node(_word[0])
	cell.prepare_landing()
	cell.land()
	_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	assert_almost_eq(cell.scale.x, Tokens.Layout.LANDING_SCALE, 0.001)
	_step(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(cell.scale, Vector2.ONE)
	cell.flash()
	_step(Tokens.dur(Tokens.Motion.BASE) / 2)
	assert_almost_eq(cell.modulate.r, Tokens.Layout.WORD_FLASH_SCALE, 0.001)
	_step(Tokens.dur(Tokens.Motion.BASE))
	assert_eq(cell.modulate, Color.WHITE)
	assert_eq(cell.state, GridCell.State.FILLED)
	cell.reveal(true)
	_settle()
	assert_false(cell.is_processing())


func test_replacement_resize_refresh_exit_and_reentry_settle_owned_work() -> void:
	_view.fly_word(_word, Vector2(500, 1100))
	var previous: Tween = get_tree().get_processed_tweens().back()
	_view.fly_word([_word[1]], Vector2(400, 1000))
	assert_false(previous.is_valid())
	assert_eq(_view.find_children("FlightLetter*", "Label", true, false).size(), 1)
	_view.size.x = 700
	assert_eq(_view.flight_state(), &"idle")
	assert_eq(_view.cell_node(_word[1]).modulate, Color.WHITE)
	_view.fly_word(_word, Vector2(500, 1100))
	_view.refresh()
	assert_eq(_view.flight_state(), &"idle")
	assert_eq(_view.cell_node(_word[0]).state, GridCell.State.EMPTY)
	_view.fly_word(_word, Vector2(500, 1100))
	remove_child(_view)
	assert_eq(_view.flight_state(), &"idle")
	add_child(_view)
	assert_eq(_view.fly_word(_word, Vector2(500, 1100)), OK)
	_view.set_board(null)
	assert_eq(_view.get_child_count(), 0)
	_settle()


func test_wave_waits_for_flight_is_bounded_and_finishes_once() -> void:
	watch_signals(_view)
	_view.fly_word(_word, Vector2(500, 1100))
	_view.play_wave()
	assert_signal_not_emitted(_view, "wave_finished")
	assert_lte(
		_view.wave_duration() + Tokens.dur(Tokens.Motion.SLOW), Tokens.dur(Tokens.Motion.CELEBRATE)
	)
	var elapsed: float = 0
	var tick: float = Tokens.dur(Tokens.Motion.STAGGER) / 10
	while _view.flight_state() == &"flying" or get_signal_emit_count(_view, "wave_finished") == 0:
		elapsed += tick
		_step(tick)
		if elapsed > Tokens.dur(Tokens.Motion.CELEBRATE):
			break
	assert_lte(
		elapsed + Tokens.dur(Tokens.Motion.SLOW), Tokens.dur(Tokens.Motion.CELEBRATE) + tick * 3
	)
	_settle()
	assert_signal_emit_count(_view, "wave_finished", 1)
	_step(10)
	assert_signal_emit_count(_view, "wave_finished", 1)
	for cell: Vector2i in _word:
		assert_eq(_view.cell_node(cell).state, GridCell.State.FILLED)
		assert_eq(_view.cell_node(cell).scale, Vector2.ONE)


func test_reduction_before_and_during_flight_and_wave() -> void:
	Tokens.reduced_motion = true
	assert_eq(_view.fly_word(_word, Vector2(500, 1100)), OK)
	assert_eq(_view.flight_state(), &"idle")
	assert_true(_view.find_children("FlightLetter*", "Label", true, false).is_empty())
	assert_eq(_view.cell_node(_word[0]).modulate.a, 0.0)
	_step(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(_view.cell_node(_word[0]).modulate, Color.WHITE)
	Tokens.reduced_motion = false
	watch_signals(_view)
	_view.fly_word(_word, Vector2(500, 1100))
	_view.play_wave()
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(_view.flight_state(), &"idle")
	assert_signal_emit_count(_view, "wave_finished", 1)
	for cell: Vector2i in _word:
		assert_eq(_view.cell_node(cell).scale, Vector2.ONE)
		assert_eq(_view.cell_node(cell).modulate, Color.WHITE)


func test_standalone_wave_resize_cancels_all_cells() -> void:
	_view.reveal_word(_word)
	_settle()
	_view.play_wave()
	var work: Array[Tween] = get_tree().get_processed_tweens()
	_step(Tokens.dur(Tokens.Motion.STAGGER))
	_view.size.x = 720
	for tween: Tween in work:
		assert_false(tween.is_valid())
	for cell: Vector2i in _word:
		assert_eq(_view.cell_node(cell).scale, Vector2.ONE)
		assert_eq(_view.cell_node(cell).state, GridCell.State.FILLED)


func _completed_fixture() -> LevelScreen:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	var screen: LevelScreen = (load("res://features/level/gallery.gd") as GDScript).new()
	viewport.add_child(screen)
	for frame: int in 3:
		await get_tree().process_frame
	var level: LevelData = screen.controller.get_board().get_level()
	for index: int in level.word_count():
		var tiles: PackedInt32Array = PackedInt32Array()
		for letter: String in level.word(index):
			tiles.append(level.get_letters().find(letter))
		screen.controller.submit(tiles)
	return screen


func test_completion_waits_for_wave_then_resize_and_exit_restore_layer() -> void:
	var screen: LevelScreen = await _completed_fixture()
	assert_true(screen.controller.is_complete())
	assert_false(screen.completion_layer.visible)
	_settle()
	assert_true(screen.completion_layer.visible)
	for frame: int in 3:
		await get_tree().process_frame
	var motion: Tween = get_tree().get_processed_tweens().back()
	motion.custom_step(Tokens.dur(Tokens.Motion.SLOW) / 4)
	assert_gt(screen.completion_layer.modulate.a, 0.0)
	assert_lt(screen.completion_layer.modulate.a, 1.0)
	(screen.get_parent() as SubViewport).size = Vector2i(1440, 1920)
	for frame: int in 3:
		await get_tree().process_frame
	assert_false(motion.is_valid())
	assert_eq(screen.completion_layer.modulate, Color.WHITE)
	assert_lte(
		screen.completion_layer.get_global_rect().end.y,
		screen.board_view.get_global_rect().position.y
	)
	var other: LevelScreen = await _completed_fixture()
	_settle()
	for frame: int in 3:
		await get_tree().process_frame
	var exiting: Tween = get_tree().get_processed_tweens().back()
	exiting.custom_step(Tokens.dur(Tokens.Motion.SLOW) / 4)
	other.get_parent().remove_child(other)
	assert_false(exiting.is_valid())
	assert_eq(other.completion_layer.modulate, Color.WHITE)
	other.free()


func test_exit_before_layer_sort_restores_opacity() -> void:
	var screen: LevelScreen = await _completed_fixture()
	_settle()
	assert_true(screen.completion_layer.visible)
	assert_eq(screen.completion_layer.modulate.a, 0.0)
	screen.get_parent().remove_child(screen)
	assert_eq(screen.completion_layer.modulate, Color.WHITE)
	screen.free()
