extends ServiceStub
## @api Progress service contract. Save owns storage; Progress owns only its section.

## @api Completion notification (T-0112 emits only after a durable Save.flush).
signal completed(slot: int)

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")

var _save: SAVE_SCRIPT = null
var _content: CONTENT_SCRIPT = null


## @api Inject Save and Content. Neither loading nor writing happens here.
func configure(save: SAVE_SCRIPT, content: CONTENT_SCRIPT) -> void:
	_save = save
	_content = content


## @api Current campaign slot in a language; "" uses the saved language.
## Returns -1 if Save/Content are not ready or disagree on the active language.
func current_slot(language: String = "") -> int:
	if not _is_ready():
		return -1
	return int(_language_state(language).get("current_slot", 1))


## @api Highest completed slot in a language; absent languages start at zero.
## Returns -1 on a readiness error (distinct from a fresh language's zero).
func highest_completed_slot(language: String = "") -> int:
	if not _is_ready():
		return -1
	return int(_language_state(language).get("highest_completed_slot", 0))


## @api Restore the current content level, or start a fresh board for stale/bad state.
## The saved snapshot is left intact; T-0112 owns all persistence.
func restore_level(level: LevelData) -> BoardState:
	if not _is_ready() or not _matches_current_level(level):
		return null
	var snapshot: Variant = _language_state("").get("level_state")
	if snapshot is Dictionary:
		var restored: BoardState = BoardState.from_dict(level, snapshot)
		if restored != null:
			return restored
	return BoardState.new(level)


## @api Frozen write contract; T-0112 implements durability and mutation.
func save_level(board: BoardState) -> Error:
	if not _is_ready():
		return ERR_UNCONFIGURED
	if board == null or not _matches_current_level(board.get_level()):
		return ERR_INVALID_PARAMETER
	return ERR_UNAVAILABLE


## @api Frozen completion contract; T-0112 advances the slot and emits completed.
func complete_level(slot: int) -> Error:
	if not _is_ready():
		return ERR_UNCONFIGURED
	if slot != current_slot() or _content.level_for_slot(slot) == null:
		return ERR_INVALID_PARAMETER
	return ERR_UNAVAILABLE


func _is_ready() -> bool:
	if _save == null or _content == null:
		return false
	if not _save.is_loaded() or not _content.is_loaded():
		return false
	var selected_language: String = str(_save.get_setting(&"language"))
	return not selected_language.is_empty() and _content.get_language() == selected_language


func _language_state(language: String) -> Dictionary:
	var selected_language: String = (
		language if not language.is_empty() else str(_save.get_setting(&"language"))
	)
	var progress: Dictionary = _save.get_section(&"progress")
	var by_language: Dictionary = progress.get("by_lang", {})
	return by_language.get(selected_language, SaveSchema.LANGUAGE_STATE)


func _matches_current_level(level: LevelData) -> bool:
	if level == null or level.get_slot() != current_slot():
		return false
	var content_level: LevelData = _content.level_for_slot(level.get_slot())
	return content_level != null and content_level.get_id() == level.get_id()
