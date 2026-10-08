extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")

var _storage: MemoryStorage
var _save: SAVE_SCRIPT
var _content: LanguageContent
var _progress: PROGRESS_SCRIPT
var _completions: Array[int] = []


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)
	var failure: Error = OK
	var writes: int = 0

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		writes += 1
		if failure != OK:
			return failure
		document = JSON.parse_string(text)
		return OK


# Reuse immutable fixture geometry in two languages to test identical-ID isolation.
class LanguageContent:
	extends "res://services/content.gd"
	var language: String = "pl"

	func get_language() -> String:
		return language


func before_each() -> void:
	_storage = MemoryStorage.new()
	_save = _new_save()
	_content = LanguageContent.new()
	add_child_autofree(_content)
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/content"), OK)
	_progress = PROGRESS_SCRIPT.new()
	add_child_autofree(_progress)
	_progress.configure(_save, _content)
	_completions.clear()
	_progress.completed.connect(_on_completed)


func after_each() -> void:
	_progress.completed.disconnect(_on_completed)


func _new_save() -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(Clock.new())
	save.configure(_storage)
	assert_eq(save.load(), OK)
	return save


func _on_completed(slot: int) -> void:
	_completions.append(slot)
	assert_eq(
		int(_storage.document["progress"]["by_lang"][_content.language]["current_slot"]), slot + 1
	)


func _reload_board(slot: int) -> BoardState:
	var progress: PROGRESS_SCRIPT = PROGRESS_SCRIPT.new()
	add_child_autofree(progress)
	progress.configure(_new_save(), _content)
	return progress.restore_level(_content.level_for_slot(slot))


func test_word_and_background_roundtrip() -> void:
	assert_eq(_progress.complete_level(1), OK)
	var board: BoardState = BoardState.new(_content.level_for_slot(2))
	assert_eq(_progress.bind_board(board), OK)
	board.evaluate(PackedInt32Array([0, 1, 2]))
	assert_eq(_progress.save_level(board), OK)
	assert_eq_deep(_reload_board(2).to_dict(), board.to_dict())
	var writes: int = _storage.writes
	assert_eq(_progress.save_level(board), OK)
	assert_eq(_storage.writes, writes, "Unchanged snapshots do not write")
	board.evaluate(PackedInt32Array([0, 3, 2]))
	assert_eq(_progress.save_level(board), OK)
	assert_eq_deep(_reload_board(2).to_dict(), board.to_dict())
	assert_true(board.reveal_cell(Vector2i(2, 1)))
	_progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq_deep(_reload_board(2).to_dict(), board.to_dict())
	_progress.unbind_board()
	writes = _storage.writes
	assert_true(board.reveal_cell(Vector2i(2, 2)))
	_progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_storage.writes, writes, "Leaving disconnects background board persistence")
	assert_eq(_save.setting_changed.get_connections().size(), 0)


func test_completion_idempotence_and_language_isolation() -> void:
	assert_eq(_progress.complete_level(2), ERR_INVALID_PARAMETER)
	assert_eq(_progress.complete_level(0), ERR_INVALID_PARAMETER)
	assert_eq(
		_progress.save_level(BoardState.new(_content.level_for_slot(2))), ERR_INVALID_PARAMETER
	)
	assert_eq(_progress.save_level(null), ERR_INVALID_PARAMETER)
	var board: BoardState = BoardState.new(_content.level_for_slot(1))
	assert_eq(_progress.bind_board(board), OK)
	board.evaluate(PackedInt32Array([0, 1, 2]))
	_progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_completions, [1])
	var writes: int = _storage.writes
	assert_eq(_progress.complete_level(1), OK)
	assert_eq(_storage.writes, writes)
	assert_eq(_completions, [1])
	var polish: Dictionary = _save.get_section(&"progress")["by_lang"]["pl"]
	assert_null(polish["level_state"])
	assert_eq(polish["completed_slot"], 1)
	assert_eq(polish["highest_completed_slot"], 1)
	assert_eq(_save.set_setting(&"language", "en"), OK)
	assert_eq(_progress.complete_level(1), ERR_UNCONFIGURED)
	_content.language = "en"
	writes = _storage.writes
	_progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_storage.writes, writes, "Old-language binding must not complete the English board")
	assert_eq(_progress.current_slot(), 1)
	assert_eq(_progress.complete_level(1), OK)
	assert_eq_deep(_save.get_section(&"progress")["by_lang"]["pl"], polish)
	assert_eq(_progress.complete_level(2), OK)
	assert_eq(_progress.complete_level(3), OK)
	assert_eq(_progress.current_slot(), 4, "Next slot may exceed current content")
	assert_eq(_progress.complete_level(4), ERR_INVALID_PARAMETER)
	assert_eq(_save.debug_reset(), OK)
	assert_eq(_progress.current_slot(), 1)
	assert_eq(_progress.highest_completed_slot("pl"), 0)


func test_flush_failure_retry_and_no_premature_signal() -> void:
	var board: BoardState = BoardState.new(_content.level_for_slot(1))
	board.reveal_cell(Vector2i.ZERO)
	_storage.failure = ERR_FILE_CANT_WRITE
	assert_eq(_progress.save_level(board), ERR_FILE_CANT_WRITE)
	assert_true(_reload_board(1).revealed_cells().is_empty())
	_storage.failure = OK
	assert_eq(_progress.save_level(board), OK)
	assert_eq_deep(_reload_board(1).to_dict(), board.to_dict())
	_storage.failure = ERR_FILE_CANT_WRITE
	assert_eq(_progress.complete_level(1), ERR_FILE_CANT_WRITE)
	assert_eq(_progress.current_slot(), 2, "Failed write stays dirty in Save for retry")
	assert_eq(_completions, [])
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 1)
	assert_eq(_progress.complete_level(1), ERR_FILE_CANT_WRITE)
	assert_eq(_completions, [])
	_storage.failure = OK
	assert_eq(_progress.complete_level(1), OK)
	assert_eq(_completions, [1])
	var writes: int = _storage.writes
	assert_eq(_progress.complete_level(1), OK)
	assert_eq(_storage.writes, writes)
	assert_eq(_completions, [1])
	_storage.failure = ERR_FILE_CANT_WRITE
	assert_eq(_progress.complete_level(2), ERR_FILE_CANT_WRITE)
	_storage.failure = OK
	assert_eq(_save.debug_reset(), OK)
	assert_eq(_progress.complete_level(1), OK)
	assert_eq(_completions, [1, 1], "Reset discards the old pending completion of slot 2")


func test_pending_completion_survives_unbinding_and_another_save_owner_flush() -> void:
	assert_eq(_progress.bind_board(BoardState.new(_content.level_for_slot(1))), OK)
	_storage.failure = ERR_FILE_CANT_WRITE
	assert_eq(_progress.complete_level(1), ERR_FILE_CANT_WRITE)
	_progress.unbind_board()
	_storage.failure = OK
	assert_eq(_save.flush(), OK)
	assert_eq(_completions, [], "Only Progress publishes its domain completion")
	var writes: int = _storage.writes
	_progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_completions, [1])
	assert_eq(_storage.writes, writes)
	assert_eq(_progress.complete_level(1), OK)
	assert_eq(_completions, [1])


func test_retry_listener_cannot_complete_next_slot_twice() -> void:
	_storage.failure = ERR_FILE_CANT_WRITE
	assert_eq(_progress.complete_level(1), ERR_FILE_CANT_WRITE)
	_storage.failure = OK
	var advance: Callable = func(slot: int) -> void:
		if slot == 1:
			assert_eq(_progress.complete_level(2), OK)
	_progress.completed.connect(advance)
	var writes: int = _storage.writes
	assert_eq(_progress.complete_level(2), OK)
	assert_eq(_completions, [1, 2])
	assert_eq(_storage.writes, writes + 2)
	_progress.completed.disconnect(advance)
