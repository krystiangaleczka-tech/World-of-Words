extends ScreenScaffold
## Synthetic typography and maximum-geometry samples; never uses production services.


func _ready() -> void:
	super._ready()
	for entry: Array in [
		["Pangram", "gallery.samples.pangram", &"Title"],
		["Restore", "gallery.samples.restore", &"Body"],
		["Numeric", "gallery.samples.numeric", &"Numeric"],
		["WheelLabel", "gallery.samples.wheel", &"Caption"]
	]:
		var label: Label = Label.new()
		label.name = entry[0]
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = tr(entry[1])
		label.theme_type_variation = entry[2]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.name = "EightLetterWheel"
	wheel.size = Vector2.ONE * Tokens.Layout.WHEEL_MIN
	wheel.custom_minimum_size = Vector2.ONE * Tokens.Layout.WHEEL_MIN
	body.add_child(wheel)
	wheel.set_letters(PackedStringArray(["Z", "A", "Ż", "Ó", "Ł", "Ć", "G", "Ę"]))
	var caption: Label = Label.new()
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.text = tr("gallery.samples.grid")
	caption.theme_type_variation = &"Caption"
	body.add_child(caption)
	var board: BoardView = BoardView.new()
	board.name = "MaxGrid"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2.ONE * Tokens.Layout.CELL_MIN * LevelData.MAX_GRID
	body.add_child(board)
	var level: LevelData = LevelData.from_dict(
		{
			"id": "gallery-max-grid",
			"letters": ["K", "O", "T"],
			"bonus": [],
			"grid": {"w": LevelData.MAX_GRID, "h": LevelData.MAX_GRID},
			"words":
			[
				{"w": "KOT", "x": 0, "y": 0, "dir": "h"},
				{"w": "TOK", "x": LevelData.MAX_GRID - 3, "y": LevelData.MAX_GRID - 1, "dir": "h"}
			]
		}
	)
	board.set_board(BoardState.new(level))
