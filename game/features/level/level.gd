class_name LevelScreen
extends ScreenScaffold
## @api Playable P1 composition. Nav injects services and the requested slot before mounting.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")

var controller: LevelController
var board_view: BoardView
var wheel: LetterWheelView
var preview: WordPreview
var progress: PROGRESS_SCRIPT
var status_label: Label
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _slot: int = 0
var _event_bus: Node
var _area: Control
var _status_key: String = ""
var _copy: LevelCopy = LevelCopy.new()


func configure(
	save: SAVE_SCRIPT, content: CONTENT_SCRIPT, slot: int, event_bus: Node = null
) -> void:
	_save = save
	_content = content
	_slot = slot
	_event_bus = event_bus if event_bus != null else Events


func _ready() -> void:
	super._ready()
	_copy.register()
	status_label = Label.new()
	status_label.name = "Status"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", Tokens.Type.CAPTION)
	body.add_child(status_label)
	_area = Control.new()
	_area.name = "PlayArea"
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_area)
	board_view = BoardView.new()
	_area.add_child(board_view)
	preview = WordPreview.new()
	_area.add_child(preview)
	wheel = LetterWheelView.new()
	wheel.size = Vector2.ONE * Tokens.Layout.WHEEL_MIN
	_area.add_child(wheel)
	controller = LevelController.new()
	add_child(controller)
	progress = PROGRESS_SCRIPT.new()
	add_child(progress)
	_area.resized.connect(_layout_play_area)
	controller.state_changed.connect(_on_state_changed)
	controller.result_ready.connect(_on_result)
	controller.completed.connect(_on_completed)
	controller.persistence_failed.connect(_on_persistence_failed)
	wheel.chain_changed.connect(_on_chain)
	wheel.word_attempted.connect(_on_attempt)
	wheel.tile_added.connect(_on_tile)
	_load_board()
	_layout_play_area()


func _load_board() -> void:
	if _save == null or _content == null or not _save.is_loaded():
		_set_status("level.state.missing_content")
		wheel.set_locked(true)
		return
	progress.configure(_save, _content)
	var board: BoardState = progress.restore_level(_content.level_for_slot(_slot))
	if board == null:
		_set_status("level.state.missing_content")
		wheel.set_locked(true)
		return
	controller.configure(board, progress, _event_bus)
	board_view.set_board(board)
	wheel.set_letters(board.get_level().get_letters())
	if _slot == progress.current_slot():
		progress.bind_board(board)
	wheel.set_locked(board.is_complete())
	_set_status("")


func _on_attempt(tiles: PackedInt32Array) -> void:
	controller.submit(tiles)


func _on_chain(tiles: PackedInt32Array) -> void:
	var board: BoardState = controller.get_board()
	if board != null:
		preview.set_building(board.get_level().spell(tiles))


func _on_tile(index: int) -> void:
	if is_instance_valid(_event_bus) and _event_bus.has_signal("tile_touched"):
		_event_bus.emit_signal("tile_touched", index)


func _on_state_changed() -> void:
	_set_status("")
	board_view.refresh()
	wheel.set_locked(controller.is_complete())


func _on_result(result: AttemptResult) -> void:
	preview.show_result(result)
	if result.kind == AttemptResult.Kind.LEVEL:
		board_view.reveal_word(result.cells_to_reveal)
	elif result.kind == AttemptResult.Kind.ALREADY_FOUND:
		var level: LevelData = controller.get_board().get_level()
		for index: int in level.word_count():
			if level.word(index) == result.word:
				board_view.highlight_word(level.word_cells(index))


func _on_completed() -> void:
	wheel.set_locked(true)
	board_view.play_wave()


func _on_persistence_failed(_error: Error) -> void:
	_set_status("level.state.persistence_failed")


func _set_status(key: String) -> void:
	_status_key = key
	status_label.text = tr(key) if not key.is_empty() else ""
	status_label.visible = not key.is_empty()


func _layout_play_area() -> void:
	var available: Vector2 = _area.size
	if available.x <= 0 or available.y <= 0:
		return
	var width: float = minf(available.x, Tokens.Layout.MAX_CONTENT_WIDTH)
	var left: float = (available.x - width) / 2.0
	var ratio: float = (
		Tokens.Layout.WHEEL_COMPACT_RATIO
		if layout_class == &"COMPACT"
		else Tokens.Layout.WHEEL_WIDTH_RATIO
	)
	var preview_height: float = preview.get_combined_minimum_size().y
	var gaps: float = Tokens.Space.S * 2.0
	var diameter: float = minf(
		width, clampf(width * ratio, Tokens.Layout.WHEEL_MIN, Tokens.Layout.WHEEL_MAX)
	)
	diameter = maxf(
		0.0,
		minf(diameter, available.y * (1.0 - Tokens.Layout.GRID_MIN_RATIO) - preview_height - gaps)
	)
	var board_height: float = maxf(0.0, available.y - diameter - preview_height - gaps)
	if diameter <= 0:
		return
	board_view.position = Vector2(left, 0)
	board_view.size = Vector2(width, board_height)
	preview.position = Vector2(left, board_height + Tokens.Space.S)
	preview.size = Vector2(width, preview_height)
	wheel.position = Vector2((available.x - diameter) / 2.0, available.y - diameter)
	wheel.size = Vector2.ONE * diameter


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(status_label):
		_set_status(_status_key)


func _exit_tree() -> void:
	if is_instance_valid(progress):
		progress.unbind_board()
	if is_instance_valid(_area) and _area.resized.is_connected(_layout_play_area):
		_area.resized.disconnect(_layout_play_area)
	if is_instance_valid(wheel):
		wheel.chain_changed.disconnect(_on_chain)
		wheel.word_attempted.disconnect(_on_attempt)
		wheel.tile_added.disconnect(_on_tile)
	if is_instance_valid(controller):
		controller.state_changed.disconnect(_on_state_changed)
		controller.result_ready.disconnect(_on_result)
		controller.completed.disconnect(_on_completed)
		controller.persistence_failed.disconnect(_on_persistence_failed)
	_copy.unregister()
