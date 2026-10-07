class_name HintLogic
extends RefCounted
## @api Deterministic free-hint selection; the caller owns mutation and persistence.


static func next_cell(board: BoardState) -> Vector2i:
	if board == null or board.is_complete():
		return Vector2i(-1, -1)
	var level: LevelData = board.get_level()
	var found: PackedStringArray = board.found_words()
	var revealed: Array[Vector2i] = board.revealed_cells()
	var shortest: int = 2147483647
	var target: int = -1
	for index: int in level.word_count():
		var word: String = level.word(index)
		if not found.has(word) and word.length() < shortest:
			shortest = word.length()
			target = index
	if target >= 0:
		for cell: Vector2i in level.word_cells(target):
			if cell not in revealed:
				return cell
	return Vector2i(-1, -1)
