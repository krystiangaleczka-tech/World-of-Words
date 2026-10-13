class_name BoardView
extends Control
## @api Passive, coordinate-based crossword presentation; never mutates the board.

var _board: BoardState
var _cells: Dictionary[Vector2i, GridCell] = {}
var _fits: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## @api Replace all level geometry, including intersections only once. Null clears the view.
func set_board(board: BoardState) -> void:
	for node: GridCell in _cells.values():
		remove_child(node)
		node.queue_free()
	_cells.clear()
	_board = board
	if board != null and board.get_level() != null:
		var level: LevelData = board.get_level()
		for word_index: int in level.word_count():
			var coordinates: Array[Vector2i] = level.word_cells(word_index)
			for index: int in coordinates.size():
				var cell: Vector2i = coordinates[index]
				if _cells.has(cell):
					continue
				var node: GridCell = GridCell.new()
				node.letter = level.word(word_index)[index]
				_cells[cell] = node
				add_child(node)
	_layout_cells()
	refresh()


## @api Render a fresh snapshot. Revealed cells outside a found word are hint markers.
func refresh() -> void:
	if _board == null or _cells.is_empty():
		return
	var revealed: Array[Vector2i] = _board.revealed_cells()
	var found: PackedStringArray = _board.found_words()
	var level: LevelData = _board.get_level()
	for cell: Vector2i in _cells:
		_cells[cell].state = GridCell.State.HINTED if cell in revealed else GridCell.State.EMPTY
	for index: int in level.word_count():
		if level.word(index) in found:
			for cell: Vector2i in level.word_cells(index):
				_cells[cell].state = GridCell.State.FILLED


## @api Read a unique occupied cell; empty coordinates return null.
func cell_node(cell: Vector2i) -> GridCell:
	return _cells.get(cell)


## @api Canvas-global cell centre for letter landing effects; unknown cells return Vector2.ZERO.
func cell_global_position(cell: Vector2i) -> Vector2:
	var node: GridCell = cell_node(cell)
	return node.get_global_transform() * (node.size / 2.0) if node != null else Vector2.ZERO


## @api Present a word reveal, clearing hint markers on completed words.
func reveal_word(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		reveal_cell(cell, false)
	# AttemptResult lists only newly revealed cells, excluding existing hints.
	if _board == null:
		return
	var level: LevelData = _board.get_level()
	for index: int in level.word_count():
		if level.word(index) in _board.found_words():
			for cell: Vector2i in level.word_cells(index):
				if _cells[cell].state != GridCell.State.FILLED:
					_cells[cell].reveal(false)


## @api Present one reveal without changing gameplay state.
func reveal_cell(cell: Vector2i, hinted: bool) -> void:
	var node: GridCell = cell_node(cell)
	if node != null:
		node.reveal(hinted)


## @api Already-found feedback; unknown and unrevealed coordinates are ignored.
func highlight_word(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		var node: GridCell = cell_node(cell)
		if node != null:
			node.highlight()


## @api Completion wave ordered by grid diagonal, without blocking input.
func play_wave() -> void:
	for cell: Vector2i in _cells:
		_cells[cell].highlight((cell.x + cell.y) * Tokens.dur(Tokens.Motion.STAGGER))


## @api False when the available rect requires cells below the content minimum.
func fits_minimum() -> bool:
	return _fits


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cells()


func _layout_cells() -> void:
	_fits = true
	if _cells.is_empty():
		return
	var dimensions: Vector2 = Vector2(_board.get_level().grid_size())
	var gaps: Vector2 = dimensions - Vector2.ONE
	var minimum: Vector2 = dimensions * Tokens.Layout.CELL_MIN + gaps * Tokens.Space.XS
	var available: Vector2 = size.max(Vector2.ZERO)
	var shrink: float = minf(1.0, minf(available.x / minimum.x, available.y / minimum.y))
	var gap: float = Tokens.Space.XS * shrink
	var room: Vector2 = (available - gaps * gap) / dimensions
	var side: float = maxf(0.0, minf(Tokens.Layout.CELL_MAX, minf(room.x, room.y)))
	_fits = side >= Tokens.Layout.CELL_MIN
	var origin: Vector2 = (available - dimensions * side - gaps * gap) / 2.0
	for cell: Vector2i in _cells:
		_cells[cell].position = origin + Vector2(cell) * (side + gap)
		_cells[cell].size = Vector2.ONE * side


## @api Shared final layout. Empty for invalid inputs; tiny valid rectangles remain bounded.
static func play_area_rects(
	available: Vector2, layout: StringName, preview_height: float, actions_height: float = 0
) -> Dictionary[StringName, Rect2]:
	var result: Dictionary[StringName, Rect2] = {}
	if (
		layout not in [&"COMPACT", &"REGULAR", &"TABLET"]
		or not available.is_finite()
		or available.x <= 0
		or available.y <= 0
		or not is_finite(preview_height)
		or preview_height < 0
		or not is_finite(actions_height)
		or actions_height < 0
	):
		return result
	var width: float = minf(available.x, Tokens.Layout.MAX_CONTENT_WIDTH)
	var left: float = (available.x - width) / 2
	var gap: float = Tokens.Space.XS if layout == &"COMPACT" else Tokens.Space.S
	var overhead: float = preview_height + actions_height + gap * 3 + Tokens.Space.L * 2
	# Scale structural overhead only for impossible tiny hosts; normal classes use exact tokens.
	var compression: float = minf(1, available.y / maxf(overhead, 1))
	preview_height *= compression
	actions_height *= compression
	gap *= compression
	var padding: float = Tokens.Space.L * compression
	var ratio: float = (
		Tokens.Layout.WHEEL_COMPACT_RATIO
		if layout == &"COMPACT"
		else Tokens.Layout.WHEEL_WIDTH_RATIO
	)
	var diameter: float = minf(
		width, clampf(width * ratio, Tokens.Layout.WHEEL_MIN, Tokens.Layout.WHEEL_MAX)
	)
	diameter = maxf(
		0,
		minf(
			diameter,
			(
				available.y * (1 - Tokens.Layout.GRID_MIN_RATIO)
				- preview_height
				- actions_height
				- gap * 3
				- padding * 2
			)
		)
	)
	var board_height: float = maxf(
		0, available.y - diameter - preview_height - actions_height - gap * 3 - padding * 2
	)
	result[&"board"] = Rect2(Vector2(left, 0), Vector2(width, board_height))
	result[&"preview"] = Rect2(Vector2(left, board_height + gap), Vector2(width, preview_height))
	result[&"actions"] = Rect2(
		Vector2(left, board_height + preview_height + gap * 2), Vector2(width, actions_height)
	)
	result[&"wheel"] = Rect2(
		Vector2((available.x - diameter) / 2, available.y - padding - diameter),
		Vector2.ONE * diameter
	)
	return result
