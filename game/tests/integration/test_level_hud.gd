extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _storage: MemoryStorage
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _bus: Node
var _locale: String
var _motion: bool


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
	_locale = TranslationServer.get_locale()
	_motion = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
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
	var section: Dictionary = _save.get_section(&"progress")
	section["by_lang"]["pl"]["current_slot"] = 2
	assert_eq(_save.set_section(&"progress", section), OK)
	assert_eq(_save.flush(), OK)


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Tokens.reduced_motion = _motion


func _scene(seed_value: int = 42) -> LevelScreen:
	var screen: LevelScreen = load("res://features/level/level.tscn").instantiate() as LevelScreen
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	screen.configure(_save, _content, 2, _bus)
	screen.configure_rng(rng)
	add_child_autofree(screen)
	return screen


func test_hud_labels_bonus_and_free_hint_completion() -> void:
	var screen: LevelScreen = _scene()
	assert_eq(screen.level_label.text, "Poziom: 2")
	assert_eq(screen.bonus_label.text, "Bonus: 0")
	assert_eq(screen.hint_button.text, "Podpowiedź • gratis")
	assert_eq(screen.debug_button.visible, OS.is_debug_build())
	var economy: Dictionary = _save.get_section(&"economy")
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 3, 2])))
	assert_eq(screen.bonus_label.text, "Bonus: 1")
	var writes: int = _storage.writes
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 3, 2])))
	assert_eq(screen.bonus_label.text, "Bonus: 1")
	assert_eq(_storage.writes, writes)
	watch_signals(_bus)
	for index: int in 6:
		assert_false(screen.hint_button.disabled)
		screen.hint_button.pressed.emit()
		assert_eq(screen.controller.get_board().revealed_cells().size(), index + 1)
	assert_true(screen.controller.is_complete())
	assert_true(screen.hint_button.disabled)
	assert_true(screen.shuffle_button.disabled)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 3)
	assert_eq_deep(_save.get_section(&"economy"), economy)
	assert_signal_emit_count(_bus, "level_completed", 1)
	writes = _storage.writes
	screen.hint_button.pressed.emit()
	screen.shuffle_button.pressed.emit()
	assert_eq(_storage.writes, writes)
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(Tokens.dur(Tokens.Motion.CELEBRATE) + 1.0)
	assert_eq(screen.board_view.cell_node(Vector2i.ZERO).state, GridCell.State.FILLED)


func test_shuffle_and_hint_guard_during_drag() -> void:
	var screen: LevelScreen = _scene()
	await get_tree().process_frame
	await get_tree().process_frame
	var snapshot: Dictionary = screen.controller.get_board().to_dict()
	var order: PackedInt32Array = screen.wheel.tile_order()
	var writes: int = _storage.writes
	screen.wheel.pointer_begin(1, screen.wheel.tile_position(0))
	assert_true(screen.hint_button.disabled)
	assert_true(screen.shuffle_button.disabled)
	screen.hint_button.pressed.emit()
	screen.shuffle_button.pressed.emit()
	assert_eq_deep(screen.controller.get_board().to_dict(), snapshot)
	assert_eq(screen.wheel.tile_order(), order)
	assert_eq(_storage.writes, writes)
	screen.wheel.pointer_end(1, true)
	assert_false(screen.hint_button.disabled)
	Tokens.reduced_motion = false
	screen.shuffle_button.pressed.emit()
	assert_true(screen.hint_button.disabled)
	assert_true(screen.shuffle_button.disabled)
	screen.hint_button.pressed.emit()
	assert_eq(_storage.writes, writes)
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(Tokens.Motion.BASE + 1.0)
	await get_tree().process_frame
	assert_false(screen.hint_button.disabled)
	var shuffled: PackedInt32Array = screen.wheel.tile_order()
	assert_ne(shuffled, order)
	Tokens.reduced_motion = true
	var second: LevelScreen = _scene()
	second.shuffle_button.pressed.emit()
	assert_eq(second.wheel.tile_order(), shuffled)
	assert_eq_deep(screen.controller.get_board().to_dict(), snapshot)
	assert_eq(_storage.writes, writes)


func test_hud_locale_and_persistence_failure() -> void:
	var screen: LevelScreen = _scene()
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(screen.level_label.text, "Level: 2")
	assert_eq(screen.hint_button.text, "Hint • free")
	assert_eq(screen.shuffle_button.text, "Shuffle")
	_storage.fail = true
	screen.hint_button.pressed.emit()
	assert_true(screen.status_label.visible)
	assert_eq(screen.status_label.text, "Progress was not saved. Try again.")
	var writes: int = _storage.writes
	await get_tree().process_frame
	assert_eq(_storage.writes, writes, "idle never retries persistence")
	TranslationServer.set_locale("pl")
	await get_tree().process_frame
	assert_eq(screen.status_label.text, "Nie zapisano postępu. Spróbuj ponownie.")
	_storage.fail = false
	var next_cell: Vector2i = HintLogic.next_cell(screen.controller.get_board())
	screen.hint_button.pressed.emit()
	assert_eq(screen.board_view.cell_node(next_cell).state, GridCell.State.EMPTY)
	assert_false(screen.status_label.visible)
	assert_eq(screen.controller.get_board().revealed_cells().size(), 1)
	assert_eq(_storage.writes, writes + 1)
	assert_eq(
		_storage.document["progress"]["by_lang"]["pl"]["level_state"]["revealed_cells"].size(), 1
	)
	for index: int in 4:
		screen.hint_button.pressed.emit()
	_storage.fail = true
	screen.hint_button.pressed.emit()
	assert_true(screen.controller.is_complete())
	assert_false(screen.hint_button.disabled, "failed completion can be retried")
	_storage.fail = false
	screen.hint_button.pressed.emit()
	assert_true(screen.hint_button.disabled)
	assert_eq(int(_storage.document["progress"]["by_lang"]["pl"]["current_slot"]), 3)
