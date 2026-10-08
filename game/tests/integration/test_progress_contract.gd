extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		document = JSON.parse_string(text)
		return OK


func _save(loaded: bool = true) -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(Clock.new())
	save.configure(MemoryStorage.new())
	if loaded:
		assert_eq(save.load(), OK)
	return save


func _content() -> CONTENT_SCRIPT:
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	add_child_autofree(content)
	assert_eq(content.load_manifest("pl", "res://tests/fixtures/content"), OK)
	return content


func _progress(save: SAVE_SCRIPT, content: CONTENT_SCRIPT) -> PROGRESS_SCRIPT:
	var progress: PROGRESS_SCRIPT = PROGRESS_SCRIPT.new()
	add_child_autofree(progress)
	progress.configure(save, content)
	return progress


func test_language_defaults_and_isolation() -> void:
	var save: SAVE_SCRIPT = _save()
	var progress: PROGRESS_SCRIPT = _progress(save, _content())
	assert_eq(progress.current_slot(), 1)
	assert_eq(progress.highest_completed_slot(), 0)
	assert_eq(progress.current_slot("en"), 1)
	assert_eq(progress.highest_completed_slot("en"), 0)
	var section: Dictionary = save.get_section(&"progress")
	section["by_lang"]["pl"]["current_slot"] = 3
	section["by_lang"]["pl"]["highest_completed_slot"] = 2
	section["by_lang"]["en"] = SaveSchema.LANGUAGE_STATE.duplicate(true)
	section["by_lang"]["en"]["current_slot"] = 8
	section["by_lang"]["en"]["highest_completed_slot"] = 7
	assert_eq(save.set_section(&"progress", section), OK)
	assert_eq(progress.current_slot(), 3)
	assert_eq(progress.highest_completed_slot(), 2)
	assert_eq(progress.current_slot("en"), 8)
	assert_eq(progress.highest_completed_slot("en"), 7)
	assert_eq(progress.current_slot("de"), 1)
	assert_eq(save.debug_reset(), OK)
	assert_eq(progress.current_slot(), 1)
	assert_eq(progress.highest_completed_slot("en"), 0)


func test_restore_matching_or_stale_snapshot() -> void:
	var save: SAVE_SCRIPT = _save()
	var content: CONTENT_SCRIPT = _content()
	var progress: PROGRESS_SCRIPT = _progress(save, content)
	var level: LevelData = content.level_for_slot(1)
	var board: BoardState = BoardState.new(level)
	assert_true(board.reveal_cell(Vector2i.ZERO))
	var section: Dictionary = save.get_section(&"progress")
	section["by_lang"]["pl"]["level_state"] = board.to_dict()
	section["extension"] = {"preserved": true}
	assert_eq(save.set_section(&"progress", section), OK)
	assert_eq_deep(progress.restore_level(level).to_dict(), board.to_dict())
	for change: Dictionary in [{"level_id": "stale"}, {"found_words": ["UNKNOWN"]}]:
		var changed: Dictionary = section.duplicate(true)
		changed["by_lang"]["pl"]["level_state"].merge(change, true)
		assert_eq(save.set_section(&"progress", changed), OK)
		assert_eq_deep(progress.restore_level(level).to_dict(), BoardState.new(level).to_dict())
		assert_eq_deep(save.get_section(&"progress"), changed)
	assert_eq_deep(
		progress.restore_level(content.level_for_slot(2)).to_dict(),
		BoardState.new(content.level_for_slot(2)).to_dict()
	)


func test_readiness_rejects_unloaded_save_and_content_mismatch() -> void:
	var save: SAVE_SCRIPT = _save(false)
	var content: CONTENT_SCRIPT = _content()
	var progress: PROGRESS_SCRIPT = _progress(save, content)
	assert_eq(progress.current_slot(), 0)
	assert_null(progress.restore_level(content.level_for_slot(1)))
	assert_eq(progress.save_level(null), ERR_UNCONFIGURED)
	assert_eq(progress.complete_level(1), ERR_UNCONFIGURED)
	assert_eq(save.load(), OK)
	assert_eq(save.set_setting(&"language", "en"), OK)
	assert_eq(progress.current_slot(), 0)
	assert_null(progress.restore_level(content.level_for_slot(1)))
	assert_eq(progress.save_level(null), ERR_UNCONFIGURED)
	assert_eq(save.set_setting(&"language", "pl"), OK)
	assert_null(progress.restore_level(null))
	var raw: Dictionary = (
		JSON
		. parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
		)["levels"][0]
	)
	raw["id"] = "foreign"
	assert_null(progress.restore_level(LevelData.from_dict(raw)))
