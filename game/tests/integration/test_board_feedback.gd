extends GutTest

var _reduced: bool
var _board: BoardState
var _view: BoardView
var _word: Array[Vector2i]


func before_each() -> void:
	_reduced = Tokens.reduced_motion
	Tokens.reduced_motion = false
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	var level: LevelData = LevelData.from_dict(pack["levels"][1])
	_board = BoardState.new(level)
	_word = level.word_cells(0)
	_view = BoardView.new()
	_view.size = Vector2(800, 700)
	add_child_autofree(_view)
	_view.set_board(_board)


func after_each() -> void:
	Tokens.reduced_motion = _reduced


func _finish_frame(seconds: float = 2.0) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(seconds)


func test_hint_then_word_fill_clears_marker() -> void:
	var cell: GridCell = _view.cell_node(_word[0])
	_view.reveal_cell(_word[0], true)
	assert_eq(cell.state, GridCell.State.HINTED)
	assert_lt(cell.scale.x, 1.0)
	var hint: Tween = get_tree().get_processed_tweens().back()
	hint.custom_step(Tokens.dur(Tokens.Motion.FAST))
	_view.reveal_word(_word)
	assert_false(hint.is_valid())
	assert_eq(cell.state, GridCell.State.FILLED)
	_finish_frame()
	for coordinate: Vector2i in _word:
		var filled: GridCell = _view.cell_node(coordinate)
		assert_eq(filled.state, GridCell.State.FILLED)
		assert_eq(filled.scale, Vector2.ONE)
		assert_eq(filled.modulate, Color.WHITE)
	assert_true(_board.revealed_cells().is_empty(), "Effects must not mutate gameplay")
	assert_eq(cell.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_view.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_repeated_highlight_and_reduced_motion() -> void:
	_view.reveal_word(_word)
	_finish_frame()
	var cell: GridCell = _view.cell_node(_word[0])
	_view.highlight_word([_word[0]])
	var first: Tween = get_tree().get_processed_tweens().back()
	first.custom_step(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(cell.state, GridCell.State.HIGHLIGHTED)
	assert_gt(cell.scale.x, 1.0)
	_view.highlight_word([_word[0]])
	assert_false(first.is_valid())
	assert_eq(cell.scale, Vector2.ONE)
	_finish_frame()
	assert_eq(cell.state, GridCell.State.FILLED)
	assert_eq(cell.scale, Vector2.ONE)
	_view.reveal_cell(Vector2i(2, 1), true)
	_view.highlight_word([Vector2i(2, 1)])
	_finish_frame()
	assert_eq(_view.cell_node(Vector2i(2, 1)).state, GridCell.State.HINTED)
	_view.highlight_word([_word[0]])
	var interrupted: Tween = get_tree().get_processed_tweens().back()
	Tokens.reduced_motion = true
	_view.highlight_word([_word[0]])
	assert_false(interrupted.is_valid())
	assert_eq(cell.state, GridCell.State.FILLED)
	_view.reveal_cell(_word[0], true)
	assert_eq(cell.state, GridCell.State.HINTED)
	assert_eq(cell.scale, Vector2.ONE)
	_view.reveal_word(_word)
	_view.play_wave()
	assert_eq(cell.state, GridCell.State.FILLED)
	assert_eq(cell.scale, Vector2.ONE)
	_view.highlight_word([Vector2i(0, 1), Vector2i(2, 3)])
	assert_eq(_view.cell_node(Vector2i(2, 3)).state, GridCell.State.EMPTY)


func test_attempt_delta_clears_previously_hinted_cells() -> void:
	_board.reveal_cell(_word[0])
	_view.reveal_cell(_word[0], true)
	_view.highlight_word([_word[0]])
	assert_eq(_view.cell_node(_word[0]).state, GridCell.State.HIGHLIGHTED)
	var result: AttemptResult = _board.evaluate(PackedInt32Array([0, 1, 2]))
	assert_false(_word[0] in result.cells_to_reveal)
	var snapshot: Dictionary = _board.to_dict()
	_view.reveal_word(result.cells_to_reveal)
	assert_eq(_view.cell_node(_word[0]).state, GridCell.State.FILLED)
	assert_eq_deep(_board.to_dict(), snapshot)


func test_refresh_replacement_and_exit_cancel_effects() -> void:
	_board.evaluate(PackedInt32Array([0, 1, 2]))
	_view.refresh()
	var before: Array[Tween] = get_tree().get_processed_tweens()
	_view.play_wave()
	var wave: Array[Tween] = get_tree().get_processed_tweens()
	_view.refresh()
	for tween: Tween in wave:
		if tween not in before:
			assert_false(tween.is_valid())
	assert_eq(_view.cell_node(_word[0]).state, GridCell.State.FILLED)
	_view.highlight_word(_word)
	var old: GridCell = _view.cell_node(_word[0])
	var effects: Array[Tween] = get_tree().get_processed_tweens()
	_view.set_board(null)
	for tween: Tween in effects:
		if tween not in before:
			assert_false(tween.is_valid())
	assert_eq(old.scale, Vector2.ONE)
	assert_eq(_view.get_child_count(), 0)
	await get_tree().process_frame


func test_wave_staggers_and_restores_base_states() -> void:
	_view.reveal_word(_word)
	_finish_frame()
	_view.play_wave()
	_finish_frame(Tokens.dur(Tokens.Motion.STAGGER) / 2.0)
	assert_gt(_view.cell_node(_word[0]).scale.x, 1.0)
	assert_eq(_view.cell_node(_word[2]).scale, Vector2.ONE)
	_finish_frame()
	for cell: Vector2i in _word:
		assert_eq(_view.cell_node(cell).state, GridCell.State.FILLED)
		assert_eq(_view.cell_node(cell).scale, Vector2.ONE)
