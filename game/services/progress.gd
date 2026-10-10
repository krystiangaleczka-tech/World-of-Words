extends ServiceStub
## @api Owns per-language campaign progress and restoration from Save snapshots.

signal completed(slot: int)

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")

var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _bound_board: BoardState
var _bound_language: String = ""
var _pending: Dictionary[String, int] = {}


## @api Supply loaded Save and Content services before using campaign progress.
func configure(save: SAVE_SCRIPT, content: CONTENT_SCRIPT) -> void:
	unbind_board()
	_pending.clear()
	_save = save
	_content = content


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
	if not _is_ready():
		return ERR_UNCONFIGURED
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
