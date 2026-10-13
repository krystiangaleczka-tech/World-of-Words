# gdlint: disable=max-public-methods
# P1/P2 compatibility APIs and the explicit typed owner boundary are separately scoped.
extends AtomicSaveOwner
## @api Owns per-language campaign progress and restoration from Save snapshots.

signal completed(slot: int)

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _bound_board: BoardState
var _bound_language: String = ""
var _pending: Dictionary[String, int] = {}
var _atomic_config: CONFIG_SCRIPT
var _intent: Dictionary = {}
var _approvals: Dictionary = {}


## @api Supply loaded Save and Content services before using campaign progress.
func configure(save: SAVE_SCRIPT, content: CONTENT_SCRIPT) -> void:
	if is_instance_valid(_save) and _save.writes_blocked():
		return
	unbind_board()
	_pending.clear()
	_save = save
	_content = content
	_atomic_config = null
	_intent.clear()
	_approvals.clear()


## @api Read live saved progress. Missing language starts at slot 1; unready services return 0.
func current_slot(language: String = "") -> int:
	if not _is_ready():
		return 0
	return int(_language_state(_save_language(language)).get("current_slot", 1))


## @api Read live highest completion; missing language or unready services returns 0.
func highest_completed_slot(language: String = "") -> int:
	if not _is_ready():
		return 0
	return int(_language_state(_save_language(language)).get("highest_completed_slot", 0))


## @api Restore matching content or return a fresh board for stale/invalid snapshots.
## Retired formable bonus credits survive; current content alone controls eligibility.
## Unready services or a level outside loaded campaign content return null.
func restore_level(level: LevelData) -> BoardState:
	if not _is_ready() or not _matches_content(level):
		return null
	var state: Dictionary = _language_state(_save_language())
	var snapshot: Variant = state.get("level_state")
	if level.get_slot() == current_slot() and snapshot is Dictionary:
		var restored: BoardState = BoardState.from_dict(level, snapshot, true)
		if restored != null:
			return restored
	return BoardState.new(level)


## @api Persist a meaningful board mutation synchronously; a failed flush remains retryable.
func save_level(board: BoardState) -> Error:
	if is_instance_valid(_save) and _save.writes_blocked():
		return ERR_BUSY
	if not _is_ready():
		return ERR_UNCONFIGURED
	if not _valid_board(board):
		return ERR_INVALID_PARAMETER
	var language: String = _save_language()
	var state: Dictionary = _language_state(language)
	if state.is_empty():
		state = SaveSchema.LANGUAGE_STATE.duplicate(true)
	var snapshot: Dictionary = board.to_dict()
	if state.get("level_state") != snapshot:
		state["level_state"] = snapshot
		var error: Error = _write_state(language, state)
		if error != OK:
			return error
	return _flush_pending(language)


## @api Advance exactly once; publish completion only after successful durable storage.
## After a failure retry this API even if another Save owner has already flushed the data.
func complete_level(slot: int) -> Error:
	if not _is_ready() or _save.writes_blocked():
		return ERR_BUSY if is_instance_valid(_save) and _save.writes_blocked() else ERR_UNCONFIGURED
	if slot < 1 or _content.level_for_slot(slot) == null:
		return ERR_INVALID_PARAMETER
	var language: String = _save_language()
	_discard_stale_pending(language)
	if slot <= highest_completed_slot():
		return _flush_pending(language) if _pending.has(language) else OK
	if slot != current_slot():
		return ERR_INVALID_PARAMETER
	if _pending.has(language):
		return _retry_completion(language, slot)
	return _advance(language, slot)


func _retry_completion(language: String, slot: int) -> Error:
	var retry: Error = _flush_pending(language)
	# Completion listeners run synchronously and may advance or switch language.
	if retry == OK and language != _save_language():
		return ERR_UNCONFIGURED
	return complete_level(slot) if retry == OK else retry


func _advance(language: String, slot: int) -> Error:
	var state: Dictionary = _language_state(language)
	if state.is_empty():
		state = SaveSchema.LANGUAGE_STATE.duplicate(true)
	state["current_slot"] = slot + 1
	state["highest_completed_slot"] = slot
	state["completed_slot"] = maxi(int(state["completed_slot"]), slot)
	state["level_state"] = null
	var error: Error = _write_state(language, state)
	if error != OK:
		return error
	_pending[language] = slot
	return _flush_pending(language)


## @api Own a board only while its screen is active, for application-pause persistence.
func bind_board(board: BoardState) -> Error:
	if not _is_ready():
		return ERR_UNCONFIGURED
	if not _valid_board(board):
		return ERR_INVALID_PARAMETER
	unbind_board()
	_bound_board = board
	_bound_language = _save_language()
	_save.setting_changed.connect(_on_setting_changed)
	return OK


## @api Release screen state and disconnect its language-change listener.
func unbind_board() -> void:
	if is_instance_valid(_save) and _save.setting_changed.is_connected(_on_setting_changed):
		_save.setting_changed.disconnect(_on_setting_changed)
	_bound_board = null
	_bound_language = ""


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED or not _is_ready():
		return
	if _save.writes_blocked():
		return
	var language: String = _save_language()
	if _pending.has(language) and _flush_pending(language) != OK:
		return
	if (
		_bound_board == null
		or _bound_language != _save_language()
		or not _matches_content(_bound_board.get_level())
	):
		return
	if _bound_board.is_complete():
		complete_level(_bound_board.get_level().get_slot())
	else:
		save_level(_bound_board)


func _exit_tree() -> void:
	unbind_board()


func _on_setting_changed(key: StringName) -> void:
	if key == &"language":
		unbind_board()


func _valid_board(board: BoardState) -> bool:
	return (
		board != null
		and _matches_content(board.get_level())
		and board.get_level().get_slot() == current_slot()
	)


func _write_state(language: String, state: Dictionary) -> Error:
	var section: Dictionary = _save.get_section(&"progress")
	section["by_lang"][language] = state
	return _save.set_section(&"progress", section)


func _discard_stale_pending(language: String) -> void:
	if not _pending.has(language):
		return
	var state: Dictionary = _language_state(language)
	var slot: int = _pending[language]
	if state.get("current_slot", 1) != slot + 1 or state.get("highest_completed_slot", 0) != slot:
		_pending.erase(language)


func _flush_pending(language: String) -> Error:
	_discard_stale_pending(language)
	var error: Error = _save.flush()
	if error == OK and _pending.has(language):
		var slot: int = _pending[language]
		_pending.erase(language)
		completed.emit(slot)
	return error


func _is_ready() -> bool:
	return (
		is_instance_valid(_save)
		and _save.is_loaded()
		and is_instance_valid(_content)
		and _content.is_loaded()
		and _content.get_language() == str(_save.get_setting(&"language"))
	)


func _save_language(language: String = "") -> String:
	return str(_save.get_setting(&"language")) if language.is_empty() else language


func _language_state(language: String) -> Dictionary:
	return _save.get_section(&"progress")["by_lang"].get(language, {})


func _matches_content(level: LevelData) -> bool:
	if level == null:
		return false
	var expected: LevelData = _content.level_for_slot(level.get_slot())
	if expected == null or expected.get_id() != level.get_id():
		return false
	if expected.grid_size() != level.grid_size() or expected.get_letters() != level.get_letters():
		return false
	if expected.word_count() != level.word_count() or expected.bonus_words() != level.bonus_words():
		return false
	for index: int in expected.word_count():
		if (
			expected.word(index) != level.word(index)
			or expected.word_cells(index) != level.word_cells(index)
		):
			return false
	return true


## @api P2 remains unavailable until a real atomic coordinator and legacy policy are implemented.
## Contract stub is inert and does not replace P1 dependencies or pending state.
func configure_p2(
	_config: CONFIG_SCRIPT, _port: ProgressCommitPort, _events: EVENTS_SCRIPT
) -> Error:
	return ERR_UNAVAILABLE


## @api Must be true before using P2 views; contract stub never certifies readiness.
func p2_ready() -> bool:
	return false


## @api Committed domain view for one language; empty while unavailable.
func language_progress(_language: String = "") -> Dictionary:
	return {}


## @api Committed per-language star total; unavailable is zero, not an inferred legacy grant.
func stars(_language: String = "") -> int:
	return 0


## @api Previously committed or newly durable feature ID; unavailable is false.
func is_feature_unlocked(_feature: StringName, _language: String = "") -> bool:
	return false


## @api Copied committed location/card state; no pack loading or legacy backfill in the stub.
func location_state(_id: StringName, _language: String = "") -> Dictionary:
	return {}


## @api Copied committed region state; empty before P2 readiness.
func region_state(_id: StringName, _language: String = "") -> Dictionary:
	return {}


func atomic_has_pending() -> bool:
	return not _pending.is_empty()


## @api Explicit owner preparation only; does not enable the P2 service or rewire P1.
func configure_atomic(config: CONFIG_SCRIPT) -> Error:
	if atomic_has_pending() or (is_instance_valid(_save) and _save.writes_blocked()):
		return ERR_BUSY
	if not is_instance_valid(config):
		return ERR_UNCONFIGURED
	_atomic_config = config
	_intent.clear()
	_approvals.clear()
	return OK if _atomic_rules() != null else ERR_UNCONFIGURED


func atomic_available() -> bool:
	return (
		_is_ready()
		and _save.migration_state() == "ready"
		and _atomic_rules() != null
		and (
			(
				ProgressSaveAdapter
				. read(_save.committed_view(), _save_language(), _content, _atomic_rules())
				. error
			)
			== OK
		)
	)


## @api Build one intent from the current completed bound board; commands are only a proposal.
func completion_request(commands: Array[Dictionary]) -> Dictionary:
	if not atomic_available() or _save.writes_blocked() or atomic_has_pending():
		return {}
	if _bound_board == null or not _bound_board.is_complete() or not _valid_board(_bound_board):
		return {}
	var view: Dictionary = _save.committed_view()
	var language: String = _save_language()
	var slot: int = _bound_board.get_level().get_slot()
	var before: Dictionary = view.sections.progress.by_lang.get(language, SaveSchema.LANGUAGE_STATE)
	var change: Dictionary = ProgressSaveAdapter.completion(
		view, language, _content, _atomic_rules()
	)
	if change.is_empty():
		return {}
	var request: Dictionary = {
		"operation_id": "campaign_complete:%s:%d" % [language, slot],
		"kind": "campaign_complete",
		"language": language,
		"context":
		{
			"content_version": _content.content_version(),
			"manifest_hash": _content.manifest_hash(),
			"level_id": _bound_board.get_level().get_id(),
			"slot": slot,
			"expected_current_slot": before.current_slot,
			"expected_highest_completed_slot": before.highest_completed_slot,
			"board_hash": AtomicRequest.hash_value(_bound_board.to_dict()),
			"expected_progress_hash": AtomicRequest.hash_value(ProgressSaveAdapter.domain(before))
		},
		"progress_candidate": change.snapshot,
		"economy_commands": commands.duplicate(true),
		"delta": change.delta
	}
	if not AtomicRequest.valid(request):
		return {}
	_intent = {
		"request": request.duplicate(true),
		"board": _bound_board,
		"config": _atomic_values(),
		"lineage": view.lineage,
		"revision": view.revision
	}
	return request.duplicate(true)


func prepare_completion(transaction: SaveTransaction) -> ProgressPrepared:
	var rejected: ProgressPrepared = ProgressPrepared.new()
	if not atomic_context_valid(transaction):
		rejected.error = ERR_INVALID_DATA
		return rejected
	for value: ProgressPrepared in _approvals:
		if validates_prepared(value, transaction):
			return value
	_approvals.clear()
	var request: Dictionary = transaction.request()
	var view: Dictionary = transaction.committed_view()
	var change: Dictionary = ProgressSaveAdapter.completion(
		view, request.language, _content, _atomic_rules()
	)
	if (
		change.is_empty()
		or change.snapshot != request.progress_candidate
		or change.delta != request.delta
	):
		rejected.error = ERR_INVALID_DATA
		return rejected
	var section: Dictionary = view.sections.progress.duplicate(true)
	var state: Dictionary = (
		section.by_lang.get(request.language, SaveSchema.LANGUAGE_STATE).duplicate(true)
	)
	for field: String in ["current_slot", "stars", "location_stars", "location_pieces", "unlocked"]:
		state[field] = change.snapshot[field]
	state.postcards = change.snapshot.completed_locations
	state.highest_completed_slot = request.context.slot
	state.completed_slot = maxi(int(state.completed_slot), int(request.context.slot))
	state.level_state = null
	section.by_lang[request.language] = state
	var value: ProgressPrepared = ProgressPrepared.new()
	value.error = OK
	_approvals[value] = {
		"transaction": transaction,
		"save": _save,
		"hash": AtomicRequest.hash_value(request),
		"payload":
		{
			"section": section.duplicate(true),
			"delta": change.delta.duplicate(true),
			"notifications": []
		}
	}
	return value


func validates_prepared(value: RefCounted, transaction: SaveTransaction) -> bool:
	return (
		value is ProgressPrepared
		and value.error == OK
		and _approvals.has(value)
		and _approvals[value].save == _save
		and _approvals[value].transaction == transaction
		and atomic_context_valid(transaction)
		and _approvals[value].hash == AtomicRequest.hash_value(transaction.request())
	)


func prepared_payload(value: RefCounted, transaction: SaveTransaction) -> Dictionary:
	return (
		_approvals[value].payload.duplicate(true) if validates_prepared(value, transaction) else {}
	)


func atomic_context_valid(transaction: SaveTransaction) -> bool:
	if (
		not is_instance_valid(_save)
		or not _save.validates_transaction(transaction)
		or _intent.is_empty()
	):
		return false
	var request: Dictionary = transaction.request()
	var view: Dictionary = transaction.committed_view()
	var board: BoardState = _intent.board
	return (
		request == _intent.request
		and view.lineage == _intent.lineage
		and view.revision == _intent.revision
		and _atomic_values() == _intent.config
		and board != null
		and board.is_complete()
		and _is_ready()
		and _matches_content(board.get_level())
		and request.language == _save_language()
		and board.get_level().get_slot() == request.context.slot
		and request.context.content_version == _content.content_version()
		and request.context.manifest_hash == _content.manifest_hash()
		and request.context.board_hash == AtomicRequest.hash_value(board.to_dict())
	)


func _atomic_rules() -> ProgressRules:
	return ProgressRules.from_config(_atomic_values())


func _atomic_values() -> Dictionary:
	if not is_instance_valid(_atomic_config):
		return {}
	var keys: Array[String] = [
		"meta.stars.per_level", "meta.postcard.pieces", "meta.postcard.piece_star_cost"
	]
	for feature: String in ProgressRules.FEATURES:
		keys.append("unlocks." + feature + "_slot")
	var values: Dictionary = {}
	for key: String in keys:
		if not _atomic_config.has_key(StringName(key)):
			return {}
		values[key] = _atomic_config.get_int(StringName(key))
	return values


func atomic_save_matches(save: SAVE_SCRIPT) -> bool:
	return is_instance_valid(_save) and _save == save


## @api Explicit adapter read for the real port; ordinary P2 reads remain inactive.
func read_atomic(language: String, context: Dictionary) -> Dictionary:
	var unavailable: Dictionary = {
		"error": ERR_UNAVAILABLE, "state": "unavailable", "snapshot": {}, "receipt": {}
	}
	if not is_instance_valid(_save) or not _save.is_loaded() or _atomic_rules() == null:
		return unavailable
	if not is_instance_valid(_content) or not _content.is_loaded():
		return unavailable
	if not AtomicRequest.closed(context, ["content_version", "manifest_hash"]):
		return unavailable
	if (
		not context.content_version is int
		or context.content_version != _content.content_version()
		or context.manifest_hash != _content.manifest_hash()
	):
		return unavailable
	return ProgressSaveAdapter.read(_save.committed_view(), language, _content, _atomic_rules())
