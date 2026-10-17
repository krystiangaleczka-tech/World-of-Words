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
var _bound_lineage: int = -1
var _pending: Dictionary[String, int] = {}
var _atomic_config: CONFIG_SCRIPT
var _intent: Dictionary = {}
var _approvals: Dictionary = {}
var _p2_port: ProgressCommitPort
var _p2_config: CONFIG_SCRIPT
var _p2_events: EVENTS_SCRIPT
var _p2_request: Dictionary = {}
var _p2_published: Dictionary = {}
var _p2_busy: bool = false
var _p2_notifying: bool = false
var _p2_dispatching: bool = false
var _p2_diagnostic: String = "unavailable"


## @api Supply loaded Save and Content services before using campaign progress.
func configure(save: SAVE_SCRIPT, content: CONTENT_SCRIPT) -> void:
	if _p2_busy or _p2_notifying or (is_instance_valid(_save) and _save.writes_blocked()):
		return
	if _save != save:
		_p2_published.clear()
	_p2_port = null
	_p2_config = null
	_p2_events = null
	_p2_request.clear()
	_p2_diagnostic = "unavailable"
	unbind_board()
	_pending.clear()
	_save = save
	_content = content
	_atomic_config = null
	_intent.clear()
	_approvals.clear()


## @api Read live saved progress. Missing language starts at slot 1; unready services return 0.
func current_slot(language: String = "") -> int:
	if _p2_port != null:
		return int(language_progress(language).get("current_slot", 0))
	if not _is_ready():
		return 0
	return int(_language_state(_save_language(language)).get("current_slot", 1))


## @api Read live highest completion; missing language or unready services returns 0.
func highest_completed_slot(language: String = "") -> int:
	if _p2_port != null:
		if language_progress(language).is_empty():
			return 0
		var state: Dictionary = _save.committed_view().sections.progress.by_lang.get(
			_save_language(language), {}
		)
		return int(state.get("highest_completed_slot", 0))
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
	if _p2_port != null:
		return _complete_p2(slot)
	return _complete_p1(slot)


func _complete_p1(slot: int) -> Error:
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
	if _p2_port != null and (_p2_busy or _save.writes_blocked()):
		return ERR_BUSY
	if not _is_ready():
		return ERR_UNCONFIGURED
	if not _valid_board(board):
		return ERR_INVALID_PARAMETER
	unbind_board()
	_bound_board = board
	_bound_language = _save_language()
	_bound_lineage = int(_save.committed_view().get("lineage", -1))
	_save.setting_changed.connect(_on_setting_changed)
	return OK


## @api Release screen state and disconnect its language-change listener.
func unbind_board() -> void:
	if is_instance_valid(_save) and _save.setting_changed.is_connected(_on_setting_changed):
		_save.setting_changed.disconnect(_on_setting_changed)
	_bound_board = null
	_bound_language = ""
	_bound_lineage = -1


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED or not _is_ready():
		return
	if _p2_port != null and not _p2_request.is_empty():
		complete_level(int(_p2_request.context.slot))
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
		and (
			_p2_port == null
			or board != _bound_board
			or _bound_lineage == _save.committed_view().lineage
		)
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


## @api Explicit activation only after the real coordinator and historical adaptation certify it.
func configure_p2(config: CONFIG_SCRIPT, port: ProgressCommitPort, events: EVENTS_SCRIPT) -> Error:
	if not _real_port(port):
		return ERR_UNAVAILABLE
	if _p2_busy or _p2_notifying or not _p2_request.is_empty() or atomic_has_pending():
		return ERR_BUSY
	if (
		not is_instance_valid(_save)
		or not _save.is_loaded()
		or _save.writes_blocked()
		or config != _atomic_config
		or not is_instance_valid(config)
		or not is_instance_valid(events)
		or not _is_ready()
	):
		return ERR_UNAVAILABLE
	if not port.certifies(_save, self):
		return ERR_UNAVAILABLE
	var result: Dictionary = port.read_committed(_save_language(), _p2_context())
	_p2_diagnostic = "needs_migration" if result.state == "needs_migration" else "unavailable"
	if (
		result.error != OK
		or not port.is_available()
		or ProgressSnapshot.from_dict(result.snapshot) == null
	):
		return ERR_UNAVAILABLE
	_p2_port = port
	_p2_config = config
	_p2_events = events
	_p2_diagnostic = "ready"
	return OK


func p2_ready() -> bool:
	return p2_state() == "ready"


func p2_state() -> String:
	if _p2_port == null:
		return _p2_diagnostic
	if not _p2_bindings_valid():
		return "unavailable"
	var result: Dictionary = _p2_port.read_committed(_save_language(), _p2_context())
	if result.state == "needs_migration":
		return "needs_migration"
	return "ready" if result.error == OK and _p2_port.is_available() else "unavailable"


## @api Persisted copied language domain only. No derived unlock writes or migration rewards.
func language_progress(language: String = "") -> Dictionary:
	if _p2_port == null or not _p2_bindings_valid():
		return {}
	var result: Dictionary = _p2_port.read_committed(_save_language(language), _p2_context())
	return result.snapshot.duplicate(true) if result.error == OK else {}


func stars(language: String = "") -> int:
	return int(language_progress(language).get("stars", 0))


func is_feature_unlocked(feature: StringName, language: String = "") -> bool:
	return language_progress(language).get("unlocked", []).has(str(feature))


## @api Campaign endpoint and durable postcard credits are independent.
func location_state(id: StringName, language: String = "") -> Dictionary:
	var snapshot: Dictionary = language_progress(language)
	if snapshot.is_empty():
		return {}
	for location: Dictionary in ProgressSaveAdapter.metadata(_content).locations:
		if location.id == str(id):
			return {
				"metadata": location.duplicate(true),
				"stars": int(snapshot.location_stars.get(str(id), 0)),
				"pieces": int(snapshot.location_pieces.get(str(id), 0)),
				"piece_count": _atomic_rules().piece_count(),
				"campaign_complete": snapshot.current_slot > location.last,
				"postcard_complete": snapshot.completed_locations.has(str(id))
			}
	return {}


func region_state(id: StringName, language: String = "") -> Dictionary:
	var snapshot: Dictionary = language_progress(language)
	if snapshot.is_empty():
		return {}
	for region: Dictionary in _content.regions():
		if region.id == str(id):
			var count: int = 0
			for location: Dictionary in ProgressSaveAdapter.metadata(_content).locations:
				if location.region == str(id):
					count += int(snapshot.location_stars.get(location.id, 0))
			return {
				"metadata": region.duplicate(true),
				"stars": count,
				"unlocked": snapshot.current_slot >= region.first,
				"campaign_complete": snapshot.current_slot > region.last
			}
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
	if (
		_bound_board == null
		or not _bound_board.is_complete()
		or not _valid_board(_bound_board)
		or _bound_lineage != _save.committed_view().lineage
	):
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


## @api Read-only identity check for the exact P2 content/config/port bindings.
func tool_context_matches(
	content: CONTENT_SCRIPT, config: CONFIG_SCRIPT, port: ProgressCommitPort
) -> bool:
	return (
		_content == content
		and _atomic_config == config
		and _p2_config == config
		and _p2_port == port
		and p2_ready()
	)


## @api Register a detached paid candidate against this owner's current bound durable board.
func paid_tool_request(
	board: BoardState, kind: StringName, commands: Array[Dictionary]
) -> Dictionary:
	if (
		not atomic_available()
		or _save.writes_blocked()
		or atomic_has_pending()
		or board == null
		or board != _bound_board
		or not _valid_board(board)
		or kind not in [&"hint", &"reveal"]
	):
		return {}
	var view: Dictionary = _save.committed_view()
	var language: String = _save_language()
	var state: Dictionary = view.sections.progress.by_lang.get(language, SaveSchema.LANGUAGE_STATE)
	var slot: int = board.get_level().get_slot()
	if (
		slot < _atomic_config.get_int(StringName("unlocks." + str(kind) + "_slot"))
		or view.lineage != _bound_lineage
	):
		return {}
	var saved: BoardState = (
		BoardState.new(board.get_level())
		if state.level_state == null
		else BoardState.from_dict(board.get_level(), state.level_state, true)
	)
	if (
		saved == null
		or AtomicRequest.hash_value(saved.to_dict()) != AtomicRequest.hash_value(board.to_dict())
	):
		return {}
	var candidate: BoardState = PaidToolPlan.after(board, kind)
	if candidate == null:
		return {}
	var change: Dictionary = (
		ProgressSaveAdapter.completion(view, language, _content, _atomic_rules())
		if candidate.is_complete()
		else {"snapshot": ProgressSaveAdapter.domain(state), "delta": {}}
	)
	if change.is_empty():
		return {}
	var before: Dictionary = board.to_dict()
	var request: Dictionary = {
		"operation_id":
		"paid_tool:%s:%d:%s:%s" % [language, slot, kind, AtomicRequest.hash_value(before)],
		"kind": "paid_tool",
		"language": language,
		"tool": {"kind": str(kind), "before": before, "after": candidate.to_dict()},
		"context":
		{
			"content_version": _content.content_version(),
			"manifest_hash": _content.manifest_hash(),
			"level_id": board.get_level().get_id(),
			"slot": slot,
			"expected_current_slot": state.current_slot,
			"expected_highest_completed_slot": state.highest_completed_slot,
			"board_hash": AtomicRequest.hash_value(candidate.to_dict()),
			"expected_progress_hash": AtomicRequest.hash_value(ProgressSaveAdapter.domain(state))
		},
		"progress_candidate": change.snapshot,
		"economy_commands": commands.duplicate(true),
		"delta": change.delta
	}
	_intent = {
		"request": request.duplicate(true),
		"board": candidate,
		"before": board,
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
	var partial: bool = (
		request.kind == "paid_tool" and not (_intent.board as BoardState).is_complete()
	)
	var change: Dictionary = (
		{
			"snapshot":
			ProgressSaveAdapter.domain(
				view.sections.progress.by_lang.get(request.language, SaveSchema.LANGUAGE_STATE)
			),
			"delta": {}
		}
		if partial
		else ProgressSaveAdapter.completion(view, request.language, _content, _atomic_rules())
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
	if partial:
		state.level_state = request.tool.after.duplicate(true)
	else:
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
		and (board.is_complete() or request.kind == "paid_tool")
		and _paid_intent_valid(request)
		and _is_ready()
		and _matches_content(board.get_level())
		and request.language == _save_language()
		and board.get_level().get_slot() == request.context.slot
		and request.context.content_version == _content.content_version()
		and request.context.manifest_hash == _content.manifest_hash()
		and request.context.board_hash == AtomicRequest.hash_value(board.to_dict())
	)


func _paid_intent_valid(request: Dictionary) -> bool:
	if request.kind != "paid_tool":
		return true
	var before: BoardState = _intent.get("before")
	if before == null or before != _bound_board or not _valid_board(before):
		return false
	if before.to_dict() != request.tool.before:
		return false
	var candidate: BoardState = PaidToolPlan.after(before, StringName(request.tool.kind))
	return candidate != null and candidate.to_dict() == request.tool.after


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


func _complete_p2(slot: int) -> Error:
	if _p2_busy or _p2_notifying:
		return ERR_BUSY
	if not _p2_request.is_empty():
		if slot != _p2_request.context.slot:
			return ERR_BUSY
		return _run_p2_request()
	if not p2_ready():
		return ERR_UNAVAILABLE
	if _save.writes_blocked():
		return ERR_BUSY
	return _start_p2_request(slot)


func _start_p2_request(slot: int) -> Error:
	if slot < 1 or _content.level_for_slot(slot) == null:
		return ERR_INVALID_PARAMETER
	if slot <= highest_completed_slot():
		return OK
	if (
		slot != current_slot()
		or _bound_board == null
		or not _bound_board.is_complete()
		or _bound_lineage != _save.committed_view().lineage
	):
		return ERR_INVALID_PARAMETER
	var commands: Array[Dictionary] = _p2_port.completion_commands(_save_language(), slot)
	_p2_request = completion_request(commands)
	return ERR_INVALID_DATA if _p2_request.is_empty() else _run_p2_request()


func _run_p2_request() -> Error:
	var request: Dictionary = _p2_request.duplicate(true)
	_p2_busy = true
	var result: Dictionary = _p2_port.transact(request)
	if result.error == OK:
		if not _matches_completion_receipt(result.receipt, request):
			_p2_busy = false
			return ERR_INVALID_DATA
		if not _p2_request.is_empty():
			accept_commit(result.receipt)
		_p2_request.clear()
	elif result.state == "rejected":
		_p2_request.clear()
	_p2_busy = false
	return result.error


## @api Durable owner-issued notification only; never advances data or applies an economic command.
func accept_commit(receipt: Dictionary) -> Error:
	if _p2_port == null:
		return ERR_UNAVAILABLE
	if (
		_p2_notifying
		or (is_instance_valid(_save) and _save.receipt_publishing() and not _p2_dispatching)
	):
		return ERR_BUSY
	if (
		not is_instance_valid(_save)
		or not _save.validates_receipt(receipt)
		or not _valid_p2_receipt(receipt)
	):
		return ERR_INVALID_DATA
	if not _save.receipt_publishing():
		return _save.publish_receipt(receipt)
	var key: String = "%d:%s" % [receipt.lineage, receipt.operation_id]
	if _p2_published.has(key):
		return OK
	_p2_published[key] = true
	if not _p2_request.is_empty() and receipt.request_hash == AtomicRequest.hash_value(_p2_request):
		_p2_request.clear()
	_p2_notifying = true
	if not receipt.delta.is_empty():
		_publish_p2_effects(receipt)
	_p2_notifying = false
	return OK


# Only the private Save coordinator enters this after the complete Economy batch.
func _accept_coordinated_commit(receipt: Dictionary) -> Error:
	if not is_instance_valid(_save) or not _save.receipt_publishing() or _p2_dispatching:
		return ERR_BUSY
	_p2_dispatching = true
	var error: Error = accept_commit(receipt)
	_p2_dispatching = false
	return error


func _publish_p2_effects(receipt: Dictionary) -> void:
	var delta: Dictionary = receipt.delta
	if _is_ready() and receipt.language == _save_language():
		completed.emit(int(receipt.slot))
	if not is_instance_valid(_p2_events):
		return
	_p2_events.stars_earned.emit(receipt.language, int(receipt.slot), int(delta.stars))
	for id: String in delta.piece_delta:
		_p2_events.postcard_piece_revealed.emit(receipt.language, id, int(delta.piece_delta[id]))
	for id: String in delta.completed_locations:
		_p2_events.location_complete.emit(receipt.language, id)
	for feature: String in delta.unlocked:
		_p2_events.feature_unlocked.emit(receipt.language, StringName(feature), int(receipt.slot))


func _p2_bindings_valid() -> bool:
	return (
		is_instance_valid(_save)
		and _save.is_loaded()
		and _is_ready()
		and _p2_config == _atomic_config
		and is_instance_valid(_p2_config)
		and is_instance_valid(_p2_events)
		and _p2_port.certifies(_save, self)
	)


func _p2_context() -> Dictionary:
	return {
		"content_version": _content.content_version(), "manifest_hash": _content.manifest_hash()
	}


func _valid_p2_receipt(receipt: Dictionary) -> bool:
	if receipt.delta.is_empty() and receipt.operation_id.begins_with("paid_tool:"):
		var partial: ProgressSnapshot = ProgressSnapshot.from_dict(receipt.committed_snapshot)
		return partial != null and partial.snapshot().current_slot == receipt.slot
	return _valid_completion_receipt(receipt)


func _valid_completion_receipt(receipt: Dictionary) -> bool:
	var delta: Dictionary = receipt.delta
	if not AtomicRequest.closed(
		delta,
		["slot", "stars", "piece_delta", "completed_locations", "unlocked", "regions_unlocked"]
	):
		return false
	var snapshot: ProgressSnapshot = ProgressSnapshot.from_dict(receipt.committed_snapshot)
	if snapshot == null or not _delta_counts_valid(delta, receipt):
		return false
	var data: Dictionary = snapshot.snapshot()
	if (
		data.current_slot != receipt.slot + 1
		or not delta.piece_delta is Dictionary
		or not ProgressSnapshot.valid_ids(delta.regions_unlocked)
	):
		return false
	for field: String in ["completed_locations", "unlocked"]:
		if not _delta_ids_valid(delta[field], data[field]):
			return false
	for id: Variant in delta.piece_delta:
		var count: Variant = delta.piece_delta[id]
		if (
			not ProgressSnapshot.valid_id(id)
			or not (count is int or count is float)
			or count < 1
			or count > data.location_pieces.get(id, 0)
			or floorf(float(count)) != float(count)
		):
			return false
	return true


func _delta_counts_valid(delta: Dictionary, receipt: Dictionary) -> bool:
	return (
		(delta.slot is int or delta.slot is float)
		and (delta.stars is int or delta.stars is float)
		and delta.slot == receipt.slot
		and delta.stars == 1
	)


func _delta_ids_valid(values: Variant, persisted: Array) -> bool:
	if not ProgressSnapshot.valid_ids(values):
		return false
	for id: String in values:
		if not persisted.has(id):
			return false
	return true


func _matches_completion_receipt(receipt: Dictionary, request: Dictionary) -> bool:
	return (
		_save.validates_receipt(receipt)
		and receipt.get("operation_id") == request.operation_id
		and receipt.get("request_hash") == AtomicRequest.hash_value(request)
		and receipt.get("language") == request.language
		and receipt.get("slot") == request.context.slot
	)


static func _real_port(port: ProgressCommitPort) -> bool:
	if port == null:
		return false
	var script: Script = port.get_script()
	while script != null:
		if script.resource_path == "res://services/progress/atomic_progress_port.gd":
			return true
		script = script.get_base_script()
	return false
