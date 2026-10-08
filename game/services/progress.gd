extends ServiceStub
## @api Owns per-language campaign progress and restoration from Save snapshots.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")

var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT


## @api Supply loaded Save and Content services before using campaign progress.
func configure(save: SAVE_SCRIPT, content: CONTENT_SCRIPT) -> void:
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
## Unready services or a level outside loaded campaign content return null.
func restore_level(level: LevelData) -> BoardState:
	if not _is_ready() or not _matches_content(level):
		return null
	var state: Dictionary = _language_state(_save_language())
	var snapshot: Variant = state.get("level_state")
	if level.get_slot() == current_slot() and snapshot is Dictionary:
		var restored: BoardState = BoardState.from_dict(level, snapshot)
		if restored != null:
			return restored
	return BoardState.new(level)


## @api Persistence implementation arrives in T-0112.
func save_level(_board: BoardState) -> Error:
	return ERR_UNAVAILABLE if _is_ready() else ERR_UNCONFIGURED


## @api Durable completion implementation arrives in T-0112.
func complete_level(_slot: int) -> Error:
	return ERR_UNAVAILABLE if _is_ready() else ERR_UNCONFIGURED


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
