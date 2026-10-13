class_name ProgressSaveAdapter
extends RefCounted
## @api Lossless committed-domain adaptation. No grants, mutation or inferred local stars.

const CONTENT_SCRIPT: Script = preload("res://services/content.gd")


static func domain(state: Dictionary) -> Dictionary:
	var source: Dictionary = SaveSchema.LANGUAGE_STATE if state.is_empty() else state
	return {
		"current_slot": source.current_slot,
		"stars": source.stars,
		"location_stars": source.location_stars.duplicate(true),
		"location_pieces": source.location_pieces.duplicate(true),
		"completed_locations": source.postcards.duplicate(true),
		"unlocked": source.unlocked.duplicate(true)
	}


static func metadata(content: CONTENT_SCRIPT) -> Dictionary:
	var locations: Array[Dictionary] = []
	var slot: int = 1
	while slot <= content.slot_count():
		var location: Dictionary = content.location_for_slot(slot)
		if location.is_empty() or location.first != slot or location.last < slot:
			return {}
		locations.append(location)
		slot = int(location.last) + 1
	return {"slots": content.slot_count(), "regions": content.regions(), "locations": locations}


static func read(
	view: Dictionary, language: String, content: CONTENT_SCRIPT, rules: ProgressRules
) -> Dictionary:
	if view.get("error") != OK:
		return _result(ERR_UNAVAILABLE, "needs_migration")
	if not is_instance_valid(content) or not content.is_loaded() or rules == null:
		return _result(ERR_UNAVAILABLE, "unavailable")
	if language != content.get_language() or language != view.sections.settings.language:
		return _result(ERR_UNAVAILABLE, "unavailable")
	var state: Dictionary = view.sections.progress.by_lang.get(language, SaveSchema.LANGUAGE_STATE)
	if not _markers_valid(state, content.slot_count()):
		return _result(ERR_UNAVAILABLE, "needs_migration")
	var snapshot: Dictionary = domain(state)
	if ProgressLedger.from_snapshot(snapshot, rules, metadata(content)) == null:
		return _result(ERR_UNAVAILABLE, "needs_migration")
	if not _board_valid(state, content):
		return _result(ERR_UNAVAILABLE, "needs_migration")
	return _result(OK, "committed", snapshot)


static func completion(
	view: Dictionary, language: String, content: CONTENT_SCRIPT, rules: ProgressRules
) -> Dictionary:
	var result: Dictionary = read(view, language, content, rules)
	if result.error != OK:
		return {}
	var before: Dictionary = result.snapshot
	var ledger: ProgressLedger = ProgressLedger.from_snapshot(before, rules, metadata(content))
	var delta: Dictionary = ledger.complete(before.current_slot)
	if delta.is_empty():
		return {}
	var candidate: Dictionary = ledger.snapshot()
	# Ledger derives threshold features; only the persisted baseline determines newly stored IDs.
	var unlocked: Array[String] = []
	for feature: String in candidate.unlocked:
		if not before.unlocked.has(feature):
			unlocked.append(feature)
	delta.unlocked = unlocked
	return {"snapshot": candidate, "delta": delta}


static func _markers_valid(state: Dictionary, slots: int) -> bool:
	return (
		state.current_slot >= 1
		and state.current_slot <= slots + 1
		and state.highest_completed_slot == state.current_slot - 1
		and state.completed_slot >= 0
		and state.completed_slot <= state.highest_completed_slot
	)


static func _board_valid(state: Dictionary, content: CONTENT_SCRIPT) -> bool:
	if state.level_state == null:
		return true
	var level: LevelData = content.level_for_slot(state.current_slot)
	return level != null and BoardState.from_dict(level, state.level_state, true) != null


static func _result(error: Error, state: String, snapshot: Dictionary = {}) -> Dictionary:
	return {"error": error, "state": state, "snapshot": snapshot.duplicate(true), "receipt": {}}
