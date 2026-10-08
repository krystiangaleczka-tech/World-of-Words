extends ScreenScaffold
## Provisional catalog: shared intersections, irregular outlines and every cell state.


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
