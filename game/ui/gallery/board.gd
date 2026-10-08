extends ScreenScaffold
## Provisional catalog: shared intersections, irregular outlines and every cell state.

var _views: Array[BoardView] = []
var _levels: Array[LevelData] = []
var _demo: Tween


func _ready() -> void:
	super._ready()
	var samples: HBoxContainer = HBoxContainer.new()
	samples.alignment = BoxContainer.ALIGNMENT_CENTER
	samples.add_theme_constant_override("separation", Tokens.Space.XS)
	body.add_child(samples)
	var letters: PackedStringArray = PackedStringArray(["Ą", "Ć", "Ł", "Ź"])
	for state: int in GridCell.State.values():
		var cell: GridCell = GridCell.new()
		cell.letter = letters[state]
		cell.state = state as GridCell.State
		cell.custom_minimum_size = Vector2.ONE * Tokens.Layout.CELL_MAX
		samples.add_child(cell)
	for data: Dictionary in [
		{
			"id": "gallery-dom",
			"letters": ["D", "O", "M", "A"],
			"bonus": [],
			"grid": {"w": 3, "h": 4},
			"words":
			[{"w": "DOM", "x": 0, "y": 0, "dir": "h"}, {"w": "MODA", "x": 2, "y": 0, "dir": "v"}]
		},
		{
			"id": "gallery-las",
			"letters": ["L", "A", "S", "K", "A"],
			"bonus": [],
			"grid": {"w": 5, "h": 4},
			"words":
			[{"w": "LASKA", "x": 0, "y": 0, "dir": "h"}, {"w": "SALA", "x": 2, "y": 0, "dir": "v"}]
		}
	]:
		var level: LevelData = LevelData.from_dict(data)
		var board: BoardState = BoardState.new(level)
		board.evaluate(PackedInt32Array(range(level.word(0).length())))
		board.reveal_cell(level.word_cells(1)[1])
		var view: BoardView = BoardView.new()
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(view)
		view.set_board(board)
		_views.append(view)
		_levels.append(level)
	replay_feedback()


## @api Repeat hint, word reveal, already-found pulse and completion wave in the gallery.
func replay_feedback() -> void:
	if _demo != null and _demo.is_valid():
		_demo.kill()
	_demo = create_tween().set_loops()
	for action: Callable in [_demo_hint, _demo_word, _demo_highlight, _demo_wave]:
		_demo.tween_callback(action)
		_demo.tween_interval(float(Tokens.Motion.CELEBRATE) / 1000.0)


func _demo_hint() -> void:
	for index: int in _views.size():
		_views[index].refresh()
		_views[index].reveal_cell(_levels[index].word_cells(1)[1], true)


func _demo_word() -> void:
	for index: int in _views.size():
		_views[index].reveal_word(_levels[index].word_cells(1))


func _demo_highlight() -> void:
	for index: int in _views.size():
		_views[index].highlight_word(_levels[index].word_cells(1))


func _demo_wave() -> void:
	for view: BoardView in _views:
		view.play_wave()


func _exit_tree() -> void:
	if _demo != null and _demo.is_valid():
		_demo.kill()
