class_name PaidToolPlan
extends RefCounted
## @api Detached deterministic tool plan; never changes or completes the caller's board.


static func after(board: BoardState, kind: StringName) -> BoardState:
	if board == null or board.get_level() == null or board.is_complete():
		return null
	if kind not in [&"hint", &"reveal"]:
		return null
	var candidate: BoardState = BoardState.from_dict(board.get_level(), board.to_dict(), true)
	if candidate == null:
		return null
	if kind == &"hint":
		return candidate if candidate.reveal_cell(HintLogic.next_cell(candidate)) else null
	var word: String = HintLogic.reveal_word(candidate)
	for index: int in candidate.get_level().word_count():
		if candidate.get_level().word(index) == word:
			for cell: Vector2i in candidate.get_level().word_cells(index):
				candidate.reveal_cell(cell)
			return candidate
	return null
