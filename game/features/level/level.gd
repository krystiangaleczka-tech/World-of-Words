class_name LevelScreen
extends ScreenScaffold
## @api Playable P1 composition. Nav injects services and the requested slot before mounting.

signal navigation_requested(target: StringName)
signal shop_requested
signal powerup_requested(kind: StringName)

const ECONOMY_SCRIPT: Script = preload("res://services/economy.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")

var paid_tools_ui: LevelPaidTools
var p2_hud: LevelP2Hud
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
var _paid_progress: PROGRESS_SCRIPT
var _paid_port: AtomicProgressPort
var _p2_economy: ECONOMY_SCRIPT
var _p2_config: CONFIG_SCRIPT
var _navigation: Node
var _navigation_supplied: bool = false
var _continued: bool = false
var _postcard_pieces_before: int = 0
var _actions: BoxContainer
var _action_spacer: Control
var _rng: RandomNumberGenerator
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _slot: int = 0
var _event_bus: Node
var _area: Control
var _status_key: String = ""
var _completion_motion: Tween
var _completion_start_pending: bool = false
var _completion_host_size: Vector2 = Vector2.ZERO
var _completion_layout: StringName = &""
var _completion_waiting: bool = false
var _completion_rest: Vector2 = Vector2.ZERO
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
	_navigation_supplied = is_instance_valid(nav)
	if _navigation_supplied and nav.has_method("postcard_piece_count"):
		_postcard_pieces_before = nav.call("postcard_piece_count", _slot)


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
	progress = _paid_progress if _paid_progress != null else PROGRESS_SCRIPT.new()
	if _paid_progress == null:
		add_child(progress)
	_connect_runtime()
	_load_board()
	if p2_hud != null:
		level_label.get_parent().visible = false
		bonus_label.visible = false
		_actions.visible = false
		p2_hud.mount(self, _area, _save, _event_bus, _slot, hint_button, shuffle_button, _can_act)
		p2_hud.meter.minimum_size_changed.connect(_layout_play_area, CONNECT_DEFERRED)
		p2_hud.navigation_requested.connect(_p2_navigate)
		p2_hud.shop_requested.connect(_p2_shop)
		p2_hud.powerup_requested.connect(_p2_tool)
	if paid_tools_ui != null:
		status_label.remove_theme_font_size_override("font_size")
		status_label.remove_theme_color_override("font_color")
		status_label.theme_type_variation = &"Caption"
		var paid_error: Error = controller.configure_paid_tools(_save, _paid_port)
		if paid_error != OK:
			controller.configure(null, progress, _event_bus)
			progress.unbind_board()
			_set_status("level.tool.unavailable")
		paid_tools_ui.mount(self, controller)
	_refresh_hud()
	set_process(false)
	_layout_play_area()


## @api Explicit before-mount presentation opt-in; no paid operation or boot activation.
func configure_p2(economy: Node, config: Node) -> Error:
	if is_inside_tree() or p2_hud != null:
		return ERR_BUSY
	if not economy is ECONOMY_SCRIPT or not config is CONFIG_SCRIPT:
		return ERR_UNCONFIGURED
	if not is_instance_valid(_save) or not economy.atomic_save_matches(_save):
		return ERR_UNCONFIGURED
	var helper: LevelP2Hud = LevelP2Hud.new()
	var error: Error = helper.configure(economy, config)
	if error != OK:
		helper.free()
		return error
	p2_hud = helper
	_p2_economy = economy
	_p2_config = config
	add_child(helper)
	return OK


## @api Opt in only with the exact ready durable owners, before mounting this screen.
func configure_paid_tools(
	owner: PROGRESS_SCRIPT, port: AtomicProgressPort, monetization: Node = null, ios: bool = false
) -> Error:
	if is_inside_tree() or paid_tools_ui != null:
		return ERR_BUSY
	if (
		p2_hud == null
		or port == null
		or not port.certifies_tools(_save, owner, _p2_economy, _content, _p2_config)
	):
		return ERR_UNCONFIGURED
	if _slot != owner.current_slot():
		return ERR_INVALID_PARAMETER
	var helper: LevelPaidTools = LevelPaidTools.new()
	var error: Error = helper.configure(_save, _p2_economy, _p2_config, monetization, ios)
	if error != OK:
		helper.free()
		return error
	_paid_progress = owner
	_paid_port = port
	paid_tools_ui = helper
	add_child(helper)
	return OK


func _p2_navigate(target: StringName) -> void:
	if paid_tools_ui == null or (not controller.paid_locked() and not paid_tools_ui.modal_open()):
		navigation_requested.emit(target)


func _p2_shop() -> void:
	if paid_tools_ui == null:
		shop_requested.emit()
	elif not controller.paid_locked():
		paid_tools_ui.open_shop()


func _p2_tool(kind: StringName) -> void:
	if paid_tools_ui == null:
		powerup_requested.emit(kind)
	else:
		paid_tools_ui.use_tool(kind)


func _enter_tree() -> void:
	super._enter_tree()
	if p2_hud != null and controller != null:
		_resume_p2.call_deferred()


func _resume_p2() -> void:
	if not is_inside_tree():
		return
	_copy.register()
	_connect_runtime()
	if _slot == progress.current_slot():
		progress.bind_board(controller.get_board())
	_layout_play_area()


func _connect_runtime() -> void:
	if (
		p2_hud != null
		and is_instance_valid(p2_hud.meter)
		and not p2_hud.meter.minimum_size_changed.is_connected(_layout_play_area)
	):
		p2_hud.meter.minimum_size_changed.connect(_layout_play_area, CONNECT_DEFERRED)
	if not board_view.wave_finished.is_connected(_on_wave_finished):
		board_view.wave_finished.connect(_on_wave_finished)
	if not body.sort_children.is_connected(_start_completion_motion):
		body.sort_children.connect(_start_completion_motion)
	if not _area.resized.is_connected(_layout_play_area):
		_area.resized.connect(_layout_play_area)
	if not preview.minimum_size_changed.is_connected(_layout_play_area):
		preview.minimum_size_changed.connect(_layout_play_area)
	if not layout_class_changed.is_connected(_on_layout_class_changed):
		layout_class_changed.connect(_on_layout_class_changed)
	if not controller.state_changed.is_connected(_on_state_changed):
		controller.state_changed.connect(_on_state_changed)
	if not controller.result_ready.is_connected(_on_result):
		controller.result_ready.connect(_on_result)
	if not controller.completed.is_connected(_on_completed):
		controller.completed.connect(_on_completed)
	if not controller.persistence_failed.is_connected(_on_persistence_failed):
		controller.persistence_failed.connect(_on_persistence_failed)
	if not wheel.chain_changed.is_connected(_on_chain):
		wheel.chain_changed.connect(_on_chain)
	if not wheel.word_attempted.is_connected(_on_attempt):
		wheel.word_attempted.connect(_on_attempt)
	if not wheel.short_released.is_connected(_on_short_release):
		wheel.short_released.connect(_on_short_release)
	if not wheel.tile_added.is_connected(_on_tile):
		wheel.tile_added.connect(_on_tile)
	if not continue_button.pressed.is_connected(_on_continue):
		continue_button.pressed.connect(_on_continue)
	if not hint_button.pressed.is_connected(_on_hint):
		hint_button.pressed.connect(_on_hint)
	if not shuffle_button.pressed.is_connected(_on_shuffle):
		shuffle_button.pressed.connect(_on_shuffle)
	if not debug_button.pressed.is_connected(_on_debug):
		debug_button.pressed.connect(_on_debug)


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
	continue_button.disabled = (terminal and not _new_postcard_piece()) or _continued
	if not terminal:
		_content.level_for_slot(_slot + 1)
	_refresh_actions()
	_layout_play_area.call_deferred()


func _on_continue() -> void:
	if not completion_layer.visible or continue_button.disabled or _continued:
		return
	continue_button.disabled = true
	var error: Error = ERR_UNAVAILABLE
	if is_instance_valid(_navigation) and _navigation.has_method("continue_campaign"):
		_continued = true
		error = _navigation.call("continue_campaign", _slot, _postcard_pieces_before)
	elif (
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
	if p2_hud != null:
		p2_hud.refresh()


func _can_act() -> bool:
	if (
		paid_tools_ui != null
		and controller != null
		and (controller.paid_locked() or paid_tools_ui.modal_open())
	):
		return false
	if p2_hud != null and not p2_hud.bindings_ready():
		return false
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
	if p2_hud != null and is_instance_valid(p2_hud.reveal):
		p2_hud.reveal.disabled = not enabled


func _on_hint() -> void:
	if not _can_act():
		return
	if p2_hud != null:
		if hint_button.is_visible_in_tree():
			_p2_tool(&"hint")
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
		if p2_hud == null:
			controller.hint()
	elif wheel.shuffle(_rng):
		if is_instance_valid(_event_bus) and _event_bus.has_signal("shuffle_performed"):
			_event_bus.emit_signal("shuffle_performed", _slot)
		set_process(wheel.is_locked())
	_refresh_hud()


func _process(_delta: float) -> void:
	_refresh_actions()
	if (
		Tokens.reduced_motion
		and (_completion_waiting or _completion_start_pending or _completion_motion != null)
	):
		_completion_waiting = false
		_completion_start_pending = false
		if _completion_motion != null:
			_completion_motion.kill()
			_completion_motion = null
			completion_layer.position = _completion_rest
		completion_layer.visible = true
		completion_layer.modulate = Color.WHITE
	if (
		not _completion_waiting
		and _completion_motion == null
		and (not wheel.is_locked() or controller.is_complete())
	):
		set_process(false)


func _on_debug() -> void:
	var target: Node = _navigation if _navigation_supplied else Nav
	if OS.is_debug_build() and is_instance_valid(target) and target.has_method("go_debug"):
		target.call("go_debug")


func _load_board() -> void:
	if _save == null or _content == null or not _save.is_loaded():
		_set_status("level.state.missing_content")
		wheel.set_locked(true)
		return
	if _paid_progress == null:
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
	var diagnostic_play: bool = OS.is_debug_build() and _slot != progress.current_slot()
	controller.configure(board, progress, _event_bus, not diagnostic_play)
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	board_view.set_board(board)
	wheel.set_letters(board.get_level().get_letters(), _rng)
	if _slot == progress.current_slot():
		progress.bind_board(board)
	wheel.set_locked(board.is_complete())
	_set_status("")
	if terminal_resume:
		_show_completion()


func _on_attempt(tiles: PackedInt32Array) -> void:
	controller.submit(tiles)


func _on_short_release(tiles: PackedInt32Array) -> void:
	var board: BoardState = controller.get_board()
	if board != null:
		preview.set_building(board.get_level().spell(tiles))
		preview.fade_short()


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
	if paid_tools_ui != null and controller.paid_feedback_active():
		board_view.set_board(controller.get_board())
	else:
		board_view.refresh()
	wheel.set_locked(controller.is_complete())
	_refresh_hud()


func _on_result(result: AttemptResult) -> void:
	preview.show_result(result)
	if result.kind == AttemptResult.Kind.LEVEL:
		var whole_word: Array[Vector2i] = []
		var level: LevelData = controller.get_board().get_level()
		for index: int in level.word_count():
			if level.word(index) == result.word:
				whole_word = level.word_cells(index)
				break
		board_view.fly_word(
			result.cells_to_reveal, preview.get_global_transform() * (preview.size / 2), whole_word
		)
	elif result.kind == AttemptResult.Kind.BONUS:
		preview.fly_bonus(bonus_label)
	elif result.kind == AttemptResult.Kind.ALREADY_FOUND:
		var level: LevelData = controller.get_board().get_level()
		for index: int in level.word_count():
			if level.word(index) == result.word:
				board_view.highlight_word(level.word_cells(index))
		if result.word in controller.get_board().bonus_words():
			preview.pulse_already_target(bonus_label)


func _on_completed() -> void:
	wheel.set_locked(true)
	if Tokens.reduced_motion:
		_show_completion()
	else:
		_completion_waiting = true
		completion_title.text = tr(
			"level.complete.terminal" if _slot >= _content.slot_count() else "level.complete.title"
		)
		continue_button.disabled = (
			(_slot >= _content.slot_count() and not _new_postcard_piece()) or _continued
		)
		if _slot < _content.slot_count():
			_content.level_for_slot(_slot + 1)
		set_process(true)
	board_view.play_wave()


func _on_persistence_failed(_error: Error) -> void:
	_set_status("level.state.persistence_failed")
	_refresh_actions()


func _set_status(key: String) -> void:
	_status_key = key
	status_label.text = tr(key) if not key.is_empty() else ""
	status_label.visible = not key.is_empty()


func _layout_play_area() -> void:
	if not is_inside_tree():
		return
	if (
		_completion_motion != null
		and (
			get_viewport_rect().size != _completion_host_size or layout_class != _completion_layout
		)
	):
		_completion_motion.kill()
		_completion_motion = null
		completion_layer.position = _completion_rest
		completion_layer.modulate = Color.WHITE
		body.queue_sort()
	var available: Vector2 = _area.size
	if available.x <= 0 or available.y <= 0:
		return
	var width: float = minf(available.x, Tokens.Layout.MAX_CONTENT_WIDTH)
	_actions.vertical = (
		(
			shuffle_button.get_combined_minimum_size().x
			+ hint_button.get_combined_minimum_size().x
			+ Tokens.Space.S
		)
		> width
	)
	_action_spacer.visible = not _actions.vertical
	var bonus_height: float = (
		p2_hud.meter.get_combined_minimum_size().y + Tokens.Space.S
		if p2_hud != null and is_instance_valid(p2_hud.meter) and p2_hud.meter.visible
		else 0.0
	)
	var rectangles: Dictionary[StringName, Rect2] = BoardView.play_area_rects(
		available - Vector2(0, bonus_height),
		layout_class,
		preview.get_combined_minimum_size().y,
		0 if p2_hud != null else _actions.get_combined_minimum_size().y
	)
	if rectangles.is_empty() or rectangles[&"wheel"].size.x <= 0:
		wheel.visible = false
		return
	for key: StringName in [&"preview", &"actions", &"wheel"]:
		if rectangles.has(key):
			rectangles[key].position.y += bonus_height
	wheel.visible = true
	board_view.position = rectangles[&"board"].position
	board_view.size = rectangles[&"board"].size
	preview.position = rectangles[&"preview"].position
	preview.size = rectangles[&"preview"].size
	_actions.position = rectangles[&"actions"].position
	_actions.size = rectangles[&"actions"].size
	wheel.position = rectangles[&"wheel"].position
	wheel.size = rectangles[&"wheel"].size
	if p2_hud != null and is_instance_valid(p2_hud.reveal):
		p2_hud.layout(available, rectangles[&"wheel"], rectangles[&"board"])


func _on_layout_class_changed(_value: StringName) -> void:
	_layout_play_area()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(p2_hud):
		p2_hud.dispose()
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
	super._exit_tree()
	if (
		p2_hud != null
		and is_instance_valid(p2_hud.meter)
		and p2_hud.meter.minimum_size_changed.is_connected(_layout_play_area)
	):
		p2_hud.meter.minimum_size_changed.disconnect(_layout_play_area)
	_completion_waiting = false
	_completion_start_pending = false
	if body.sort_children.is_connected(_start_completion_motion):
		body.sort_children.disconnect(_start_completion_motion)
	if _completion_motion != null:
		_completion_motion.kill()
		_completion_motion = null
		completion_layer.position = _completion_rest
		completion_layer.modulate = Color.WHITE
	if is_instance_valid(completion_layer):
		completion_layer.modulate = Color.WHITE
	if is_instance_valid(board_view) and board_view.wave_finished.is_connected(_on_wave_finished):
		board_view.wave_finished.disconnect(_on_wave_finished)
	if is_instance_valid(preview) and preview.minimum_size_changed.is_connected(_layout_play_area):
		preview.minimum_size_changed.disconnect(_layout_play_area)
	if layout_class_changed.is_connected(_on_layout_class_changed):
		layout_class_changed.disconnect(_on_layout_class_changed)
	if is_instance_valid(continue_button):
		continue_button.pressed.disconnect(_on_continue)
	if is_instance_valid(hint_button):
		hint_button.pressed.disconnect(_on_hint)
		shuffle_button.pressed.disconnect(_on_shuffle)
		debug_button.pressed.disconnect(_on_debug)
	if is_instance_valid(progress) and (controller == null or not controller.paid_pending()):
		progress.unbind_board()
	if is_instance_valid(_area) and _area.resized.is_connected(_layout_play_area):
		_area.resized.disconnect(_layout_play_area)
	if is_instance_valid(wheel):
		wheel.chain_changed.disconnect(_on_chain)
		wheel.word_attempted.disconnect(_on_attempt)
		wheel.short_released.disconnect(_on_short_release)
		wheel.tile_added.disconnect(_on_tile)
	if is_instance_valid(controller):
		controller.state_changed.disconnect(_on_state_changed)
		controller.result_ready.disconnect(_on_result)
		controller.completed.disconnect(_on_completed)
		controller.persistence_failed.disconnect(_on_persistence_failed)
	_copy.unregister()


func _on_wave_finished() -> void:
	if not _completion_waiting:
		return
	_completion_waiting = false
	_show_completion()
	if not Tokens.reduced_motion:
		completion_layer.modulate.a = 0
		_completion_start_pending = true
		body.queue_sort()


func _start_completion_motion() -> void:
	if _completion_motion != null and not _completion_start_pending:
		_completion_rest = completion_layer.position
		_slide_completion(
			clampf(
				_completion_motion.get_total_elapsed_time() / Tokens.dur(Tokens.Motion.SLOW), 0, 1
			)
		)
		return
	if not _completion_start_pending or not is_inside_tree() or not completion_layer.visible:
		return
	_completion_start_pending = false
	if Tokens.reduced_motion:
		completion_layer.modulate = Color.WHITE
		return
	if _completion_motion != null:
		_completion_motion.kill()
	_completion_rest = completion_layer.position
	_completion_host_size = get_viewport_rect().size
	_completion_layout = layout_class
	_completion_motion = create_tween().set_parallel(true).set_trans(Tokens.Ease.OUT.x).set_ease(
		Tokens.Ease.OUT.y
	)
	_slide_completion(0)
	_completion_motion.tween_property(
		completion_layer, "modulate:a", 1.0, Tokens.dur(Tokens.Motion.SLOW)
	)
	_completion_motion.tween_method(_slide_completion, 0.0, 1.0, Tokens.dur(Tokens.Motion.SLOW))
	_completion_motion.chain().tween_callback(_finish_completion_motion)
	set_process(true)


func _slide_completion(progress_value: float) -> void:
	completion_layer.position = _completion_rest + Vector2(0, Tokens.Space.L * (1 - progress_value))


func _finish_completion_motion() -> void:
	_completion_motion = null
	completion_layer.position = _completion_rest
	completion_layer.modulate = Color.WHITE


## @api Persist the current campaign board before Nav destroys its screen or backgrounds.
func prepare_navigation() -> Error:
	if controller != null and controller.paid_locked():
		return ERR_BUSY
	if (
		paid_tools_ui != null
		and (
			paid_tools_ui.reward_busy() or (paid_tools_ui.modal_open() and paid_tools_ui.sheet.busy)
		)
	):
		return ERR_BUSY
	if controller == null or progress == null:
		return ERR_UNCONFIGURED
	var board: BoardState = controller.get_board()
	if board == null:
		return ERR_UNCONFIGURED
	if (
		board.get_level().get_slot() != progress.current_slot()
		and not progress.atomic_has_pending()
	):
		return OK
	return (
		progress.complete_level(board.get_level().get_slot())
		if board.is_complete()
		else progress.save_level(board)
	)


func _new_postcard_piece() -> bool:
	return (
		is_instance_valid(_navigation)
		and _navigation.has_method("postcard_piece_count")
		and _navigation.has_method("home_unlocked")
		and _navigation.call("home_unlocked")
		and _navigation.call("postcard_piece_count", _slot) > _postcard_pieces_before
	)


func paid_bindings_ready() -> bool:
	return (
		_paid_port != null
		and _paid_port.certifies_tools(_save, _paid_progress, _p2_economy, _content, _p2_config)
	)


func show_paid_status(key: String) -> void:
	_set_status(key)


func refresh_paid_hud() -> void:
	_refresh_hud()
