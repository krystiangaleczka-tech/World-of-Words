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
			reveal_word(level.word_cells(index))


## @api Read a unique occupied cell; empty coordinates return null.
func cell_node(cell: Vector2i) -> GridCell:
	return _cells.get(cell)


## @api Canvas-global cell centre for letter landing effects; unknown cells return Vector2.ZERO.
func cell_global_position(cell: Vector2i) -> Vector2:
	var node: GridCell = cell_node(cell)
	return node.get_global_transform() * (node.size / 2.0) if node != null else Vector2.ZERO


## @api Present a word reveal. Motion is added by T-0114.
func reveal_word(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		reveal_cell(cell, false)


## @api Present one reveal without changing gameplay state.
func reveal_cell(cell: Vector2i, hinted: bool) -> void:
	var node: GridCell = cell_node(cell)
	if node != null:
		node.state = GridCell.State.HINTED if hinted else GridCell.State.FILLED


## @api Static completion highlight; T-0114 adds the timed wave and reset.
func play_wave() -> void:
	for node: GridCell in _cells.values():
		if node.state != GridCell.State.EMPTY:
			node.state = GridCell.State.HIGHLIGHTED


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
