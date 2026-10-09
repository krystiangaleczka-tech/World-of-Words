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
var level_label: Label
var bonus_label: Label
var hint_button: HintButton
var shuffle_button: IconButton
var debug_button: IconButton
var completion_layer: VBoxContainer
var completion_title: Label
var continue_button: PrimaryButton
var _navigation: Node
var _continued: bool = false
var _actions: BoxContainer
var _action_spacer: Control
var _rng: RandomNumberGenerator
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


## @api Inject reproducible shuffle randomness before mounting.
func configure_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


## @api Inject the navigation owner before mounting.
func configure_navigation(nav: Node) -> void:
	_navigation = nav


func _ready() -> void:
	super._ready()
	_copy.register()
	_create_hud()
	_create_completion()
	status_label = Label.new()
	status_label.name = "Status"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", Tokens.Type.CAPTION)
	status_label.add_theme_color_override("font_color", Tokens.Palette.TEXT)
	body.add_child(status_label)
	_area = Control.new()
	_area.name = "PlayArea"
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_area)
	board_view = BoardView.new()
	_area.add_child(board_view)
	preview = WordPreview.new()
	_area.add_child(preview)
	_area.add_child(_actions)
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
	_refresh_hud()
	set_process(false)
	_layout_play_area()


func _create_hud() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Tokens.Space.S)
	body.add_child(header)
	level_label = Label.new()
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.add_theme_font_size_override("font_size", Tokens.Type.SUBTITLE)
	level_label.add_theme_color_override("font_color", Tokens.Palette.TEXT)
	header.add_child(level_label)
	debug_button = IconButton.new()
	debug_button.text_key = "level.hud.debug"
	debug_button.visible = OS.is_debug_build()
	header.add_child(debug_button)
	debug_button.pressed.connect(_on_debug)
	bonus_label = Label.new()
	bonus_label.add_theme_font_size_override("font_size", Tokens.Type.CAPTION)
	bonus_label.add_theme_color_override("font_color", Tokens.Palette.TEXT)
	body.add_child(bonus_label)
	_actions = BoxContainer.new()
	_actions.add_theme_constant_override("separation", Tokens.Space.S)
	shuffle_button = IconButton.new()
	shuffle_button.text_key = "level.hud.shuffle"
	_actions.add_child(shuffle_button)
	_action_spacer = Control.new()
	_action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(_action_spacer)
	hint_button = HintButton.new()
	hint_button.text_key = "level.hud.free_hint"
	_actions.add_child(hint_button)
	shuffle_button.pressed.connect(_on_shuffle)
	hint_button.pressed.connect(_on_hint)


func _create_completion() -> void:
	completion_layer = VBoxContainer.new()
	completion_layer.name = "Completion"
	completion_layer.add_theme_constant_override("separation", Tokens.Space.S)
	completion_layer.visible = false
	body.add_child(completion_layer)
	completion_title = Label.new()
	completion_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	completion_title.add_theme_font_size_override("font_size", Tokens.Type.SUBTITLE)
	completion_title.add_theme_color_override("font_color", Tokens.Palette.TEXT)
	completion_layer.add_child(completion_title)
	continue_button = PrimaryButton.new()
	continue_button.text_key = "level.complete.continue"
	completion_layer.add_child(continue_button)
	continue_button.pressed.connect(_on_continue)


func _show_completion() -> void:
	completion_layer.visible = true
	var terminal: bool = _slot >= _content.slot_count()
	completion_title.text = tr("level.complete.terminal" if terminal else "level.complete.title")
	continue_button.disabled = terminal or _continued
	if not terminal:
		_content.level_for_slot(_slot + 1)
	_refresh_actions()
	_layout_play_area.call_deferred()


func _on_continue() -> void:
	if not completion_layer.visible or continue_button.disabled or _continued:
		return
	continue_button.disabled = true
	var error: Error = ERR_UNAVAILABLE
	if (
		_content.level_for_slot(_slot + 1) != null
		and is_instance_valid(_navigation)
		and _navigation.has_method("go_to_level")
	):
		_continued = true
		error = _navigation.call("go_to_level", _slot + 1)
	if error != OK:
		_continued = false
		continue_button.disabled = false
		_set_status("level.complete.retry")


func _refresh_hud() -> void:
	var board: BoardState = controller.get_board() if controller != null else null
	level_label.text = tr("level.hud.level_n") % _slot
	bonus_label.text = (
		tr("level.hud.bonus_count") % (board.bonus_words().size() if board != null else 0)
	)
	_refresh_actions()


func _can_act() -> bool:
	return (
		is_instance_valid(wheel)
		and controller.get_board() != null
		and not completion_layer.visible
		and not wheel.is_locked()
		and not wheel.is_dragging()
		and (not controller.is_complete() or _status_key == "level.state.persistence_failed")
	)


func _refresh_actions() -> void:
	var enabled: bool = _can_act()
	hint_button.disabled = not enabled
	shuffle_button.disabled = not enabled


func _on_hint() -> void:
	if not _can_act():
		return
	var cell: Vector2i = HintLogic.next_cell(controller.get_board())
	if controller.hint() and cell in controller.get_board().revealed_cells():
		var node: GridCell = board_view.cell_node(cell)
		if node != null and node.state != GridCell.State.FILLED:
			board_view.reveal_cell(cell, true)
	_refresh_hud()


func _on_shuffle() -> void:
	if not _can_act():
		return
	if _status_key == "level.state.persistence_failed":
		controller.hint()
	elif wheel.shuffle(_rng):
		set_process(wheel.is_locked())
	_refresh_hud()


func _process(_delta: float) -> void:
	_refresh_actions()
	if not wheel.is_locked():
		set_process(false)


func _on_debug() -> void:
	if OS.is_debug_build():
		Nav.go_debug()


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
	var terminal_resume: bool = (
		_slot == _content.slot_count() and progress.current_slot() > _content.slot_count()
	)
	if terminal_resume:
		for index: int in board.get_level().word_count():
			for cell: Vector2i in board.get_level().word_cells(index):
				board.reveal_cell(cell)
	controller.configure(board, progress, _event_bus)
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = hash(board.get_level().get_id())
	board_view.set_board(board)
	wheel.set_letters(board.get_level().get_letters())
	if _slot == progress.current_slot():
		progress.bind_board(board)
	wheel.set_locked(board.is_complete())
	_set_status("")
	if terminal_resume:
		_show_completion()


func _on_attempt(tiles: PackedInt32Array) -> void:
	controller.submit(tiles)


func _on_chain(tiles: PackedInt32Array) -> void:
	_refresh_actions()
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
	_refresh_hud()


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
	_show_completion()


func _on_persistence_failed(_error: Error) -> void:
	_set_status("level.state.persistence_failed")
	_refresh_actions()


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
	_actions.vertical = (
		(
			shuffle_button.get_combined_minimum_size().x
			+ hint_button.get_combined_minimum_size().x
			+ Tokens.Space.S
		)
		> width
	)
	_action_spacer.visible = not _actions.vertical
	var actions_height: float = _actions.get_combined_minimum_size().y
	var gaps: float = Tokens.Space.S * 3.0
	var diameter: float = minf(
		width, clampf(width * ratio, Tokens.Layout.WHEEL_MIN, Tokens.Layout.WHEEL_MAX)
	)
	diameter = maxf(
		0.0,
		minf(
			diameter,
			(
				available.y * (1.0 - Tokens.Layout.GRID_MIN_RATIO)
				- preview_height
				- actions_height
				- gaps
			)
		)
	)
	var board_height: float = maxf(
		0.0, available.y - diameter - preview_height - actions_height - gaps
	)
	if diameter <= 0:
		return
	board_view.position = Vector2(left, 0)
	board_view.size = Vector2(width, board_height)
	preview.position = Vector2(left, board_height + Tokens.Space.S)
	preview.size = Vector2(width, preview_height)
	_actions.position = Vector2(left, preview.position.y + preview_height + Tokens.Space.S)
	_actions.size = Vector2(width, actions_height)
	wheel.position = Vector2((available.x - diameter) / 2.0, available.y - diameter)
	wheel.size = Vector2.ONE * diameter


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(status_label):
		_set_status(_status_key)
		_refresh_hud()
		if completion_layer.visible:
			completion_title.text = tr(
				(
					"level.complete.terminal"
					if _slot >= _content.slot_count()
					else "level.complete.title"
				)
			)
		_layout_play_area.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(continue_button):
		continue_button.pressed.disconnect(_on_continue)
	if is_instance_valid(hint_button):
		hint_button.pressed.disconnect(_on_hint)
		shuffle_button.pressed.disconnect(_on_shuffle)
		debug_button.pressed.disconnect(_on_debug)
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
