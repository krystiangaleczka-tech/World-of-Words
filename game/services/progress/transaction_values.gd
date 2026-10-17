class_name ProgressTransactionValues
extends RefCounted
## Internal transaction values only; Progress alone registers and certifies authority.


static func request(
	view: Dictionary,
	language: String,
	board: BoardState,
	content_version: int,
	manifest_hash: String
) -> Dictionary:
	var state: Dictionary = view.sections.progress.by_lang.get(language, SaveSchema.LANGUAGE_STATE)
	var before: BoardState = (
		BoardState.new(board.get_level())
		if state.level_state == null
		else BoardState.from_dict(board.get_level(), state.level_state, true)
	)
	if before == null or not forward(before.to_dict(), board):
		return {}
	var previous: Dictionary = before.to_dict()
	var after: Dictionary = board.to_dict()
	if previous == after:
		return {}
	var request: Dictionary = {
		"operation_id":
		(
			"campaign_checkpoint:%s:%d:%s:%s"
			% [
				language,
				board.get_level().get_slot(),
				AtomicRequest.hash_value(previous),
				AtomicRequest.hash_value(after)
			]
		),
		"kind": "campaign_checkpoint",
		"language": language,
		"checkpoint": {"before": previous, "after": after},
		"context":
		{
			"content_version": content_version,
			"manifest_hash": manifest_hash,
			"level_id": board.get_level().get_id(),
			"slot": board.get_level().get_slot(),
			"expected_current_slot": state.current_slot,
			"expected_highest_completed_slot": state.highest_completed_slot,
			"board_hash": AtomicRequest.hash_value(after),
			"expected_progress_hash": AtomicRequest.hash_value(ProgressSaveAdapter.domain(state))
		},
		"progress_candidate": ProgressSaveAdapter.domain(state),
		"economy_commands": [],
		"delta": {}
	}
	if not AtomicRequest.valid(request):
		return {}
	return request


static func forward(before: Dictionary, board: BoardState) -> bool:
	var after: Dictionary = board.to_dict()
	if BoardState.from_dict(board.get_level(), after, true) == null:
		return false
	for key: String in ["found_words", "bonus_words", "revealed_cells"]:
		for value: Variant in before[key]:
			if value not in after[key]:
				return false
	for word: String in after.bonus_words:
		if word not in before.bonus_words and word not in board.get_level().bonus_words():
			return false
	return true


static func valid_completion_counts(delta: Dictionary, receipt: Dictionary) -> bool:
	return (
		(delta.slot is int or delta.slot is float)
		and (delta.stars is int or delta.stars is float)
		and delta.slot == receipt.slot
		and delta.stars == 1
	)


static func valid_ids(values: Variant, persisted: Array) -> bool:
	if not ProgressSnapshot.valid_ids(values):
		return false
	for id: String in values:
		if not persisted.has(id):
			return false
	return true


static func unchanged(view: Dictionary, language: String, board: BoardState) -> bool:
	var state: Dictionary = view.sections.progress.by_lang.get(language, SaveSchema.LANGUAGE_STATE)
	var snapshot: Dictionary = (
		BoardState.new(board.get_level()).to_dict()
		if state.level_state == null
		else state.level_state
	)
	return snapshot == board.to_dict()
