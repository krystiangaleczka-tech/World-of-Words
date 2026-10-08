extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const NAV_SCRIPT: Script = preload("res://services/nav.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _storage: MemoryStorage
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _bus: Node


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)
	var fail: bool = false
	var writes: int = 0

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		writes += 1
		if fail:
			return ERR_FILE_CANT_WRITE
		document = JSON.parse_string(text)
		return OK


func before_each() -> void:
	_storage = MemoryStorage.new()
	_save = SAVE_SCRIPT.new()
	_content = CONTENT_SCRIPT.new()
	_bus = EVENTS_SCRIPT.new()
	add_child_autofree(_save)
	add_child_autofree(_content)
	add_child_autofree(_bus)
	_save.initialize(Clock.new())
	_save.configure(_storage)
	assert_eq(_save.load(), OK)
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/content"), OK)


func _slot(slot: int) -> void:
	var section: Dictionary = _save.get_section(&"progress")
	section["by_lang"]["pl"]["current_slot"] = slot
	assert_eq(_save.set_section(&"progress", section), OK)
	assert_eq(_save.flush(), OK)


func _new_scene() -> LevelScreen:
	var screen: LevelScreen = load("res://features/level/level.tscn").instantiate() as LevelScreen
	return screen


func _scene(slot: int = 1) -> LevelScreen:
	var screen: LevelScreen = _new_scene()
	screen.configure(_save, _content, slot, _bus)
	add_child_autofree(screen)
	return screen


func test_nav_mounts_injected_playable_level() -> void:
	_slot(2)
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var nav: NAV_SCRIPT = NAV_SCRIPT.new()
	add_child_autofree(config)
	add_child_autofree(nav)
	var host: Control = Control.new()
	add_child_autofree(host)
	nav.configure(_save, config, _content)
	assert_eq(nav.start(host, "res://tests/fixtures/content"), OK)
	var screen: LevelScreen = nav.mounted_screen() as LevelScreen
	assert_not_null(screen)
	assert_eq(screen.controller.get_board().get_level().get_slot(), 2)
	assert_eq(screen.wheel.tile_order().size(), 4)
	assert_eq(screen.progress.current_slot(), 2)
	assert_not_same(screen.progress, Progress)
	assert_false(screen.wheel.is_locked())
	assert_true(screen.status_label.text.is_empty())


func test_submit_persists_before_effects_and_completion() -> void:
	_slot(2)
	var screen: LevelScreen = _scene(2)
	watch_signals(_bus)
	watch_signals(screen.controller)
	var observed: Array[String] = []
	var found: Callable = func(word: String) -> void:
		var state: Dictionary = _storage.document["progress"]["by_lang"]["pl"]
		if word == "DOM":
			assert_true("DOM" in state["level_state"]["found_words"])
			assert_eq(screen.board_view.cell_node(Vector2i.ZERO).state, GridCell.State.FILLED)
		else:
			assert_eq(int(state["current_slot"]), 3)
			assert_null(state["level_state"])
		observed.append(word)
	_bus.connect("word_found", found)
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	var writes: int = _storage.writes
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_eq(_storage.writes, writes)
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 3, 2])))
	assert_eq(screen.controller.get_board().bonus_words().size(), 1)
	_storage.fail = true
	assert_null(screen.controller.submit(PackedInt32Array([2, 1, 0, 3])))
	assert_signal_emitted(screen.controller, "persistence_failed")
	assert_signal_not_emitted(_bus, "level_completed")
	assert_eq(observed, ["DOM"])
	_storage.fail = false
	assert_not_null(screen.controller.submit(PackedInt32Array([2, 1, 0, 3])))
	assert_eq(observed, ["DOM", "MODA"])
	assert_signal_emit_count(_bus, "level_completed", 1)
	assert_true(screen.wheel.is_locked())
	writes = _storage.writes
	assert_null(screen.controller.submit(PackedInt32Array([2, 1, 0, 3])))
	assert_eq(_storage.writes, writes)
	assert_signal_emit_count(_bus, "level_completed", 1)
	_bus.disconnect("word_found", found)


func test_scene_resume_and_cancel() -> void:
	_slot(2)
	var first: LevelScreen = _scene(2)
	assert_not_null(first.controller.submit(PackedInt32Array([0, 1, 2])))
	var snapshot: Dictionary = first.controller.get_board().to_dict()
	watch_signals(_bus)
	var writes: int = _storage.writes
	first.wheel.pointer_begin(1, first.wheel.tile_position(0))
	first.wheel.pointer_move(1, first.wheel.tile_position(3))
	first.wheel.pointer_move(1, first.wheel.tile_position(2))
	first.wheel.pointer_end(1, true)
	assert_eq(_storage.writes, writes)
	assert_signal_not_emitted(_bus, "bonus_found")
	assert_signal_emit_count(_bus, "tile_touched", 3)
	first.free()
	assert_eq(_save.setting_changed.get_connections().size(), 0)
	var second: LevelScreen = _scene(2)
	assert_eq_deep(second.controller.get_board().to_dict(), snapshot)
	assert_eq(second.board_view.cell_node(Vector2i.ZERO).state, GridCell.State.FILLED)
	assert_null(second.controller.submit(PackedInt32Array([0, 1])))
	assert_eq(_storage.writes, writes)


func test_responsive_scene_layout() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	var screen: LevelScreen = _new_scene()
	screen.configure(_save, _content, 1, _bus)
	viewport.add_child(screen)
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		viewport.size = dimensions
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(screen.board_view.fits_minimum())
		assert_lte(screen.wheel.size.x, float(Tokens.Layout.WHEEL_MAX))
		assert_lte(screen.board_view.size.x, float(Tokens.Layout.MAX_CONTENT_WIDTH))
		assert_lte(
			screen.board_view.position.y + screen.board_view.size.y, screen.preview.position.y
		)
		assert_lte(
			screen.preview.position.y + screen.preview.size.y, screen.wheel.position.y + 0.001
		)
		assert_gte(screen.wheel.global_position.x, float(Tokens.Space.M))
		assert_lte(
			screen.wheel.global_position.y + screen.wheel.size.y,
			dimensions.y - Tokens.Space.M + 0.001
		)
