extends GutTest

var _motion: bool
var _locale: String


func before_each() -> void:
	_motion = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	Tokens.reduced_motion = false
	TranslationServer.set_locale("en")


func after_each() -> void:
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)


func _viewport() -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	return view


func _preview(view: SubViewport) -> WordPreview:
	var preview: WordPreview = WordPreview.new()
	preview.position = Vector2(100, 900)
	preview.size = Vector2(600, 180)
	view.add_child(preview)
	return preview


func _target(view: SubViewport) -> Control:
	var target: Control = Control.new()
	target.position = Vector2(700, 100)
	target.size = Vector2(160, 160)
	view.add_child(target)
	return target


func _step(seconds: float) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(seconds)


func _settle() -> void:
	for phase: int in 4:
		_step(10)


func test_bonus_native_ghost_movement_scale_passivity_and_arrival_once() -> void:
	var view: SubViewport = _viewport()
	var target: Control = _target(view)
	var preview: WordPreview = _preview(view)
	preview.show_result(AttemptResult.new(AttemptResult.Kind.BONUS, "KOT"))
	watch_signals(preview)
	assert_eq(preview.fly_bonus(target), OK)
	var ghost: Label = preview.get_node("BonusFlight") as Label
	assert_true(ghost.visible)
	assert_eq(ghost.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var origin: Vector2 = ghost.get_global_transform() * (ghost.size / 2)
	var landing: Vector2 = target.get_global_transform() * (target.size / 2)
	assert_eq(preview.text, "")
	assert_eq(preview.fly_bonus(preview), ERR_INVALID_PARAMETER)
	assert_eq(preview.fly_bonus(ghost), ERR_INVALID_PARAMETER)
	assert_eq(ghost.get_global_transform() * (ghost.size / 2), origin)
	_step(Tokens.dur(Tokens.Motion.BASE) / 2)
	assert_almost_eq(
		(ghost.get_global_transform() * (ghost.size / 2)).x, (origin.x + landing.x) / 2, 0.01
	)
	assert_almost_eq(
		(ghost.get_global_transform() * (ghost.size / 2)).y, (origin.y + landing.y) / 2, 0.01
	)
	assert_almost_eq(ghost.scale.x, (1 + Tokens.Layout.BONUS_FLIGHT_SCALE) / 2, 0.001)
	_step(Tokens.dur(Tokens.Motion.BASE) / 2 + 0.001)
	assert_false(ghost.visible)
	assert_signal_emitted_with_parameters(preview, "bonus_arrived", [target])
	_settle()
	assert_signal_emit_count(preview, "bonus_arrived", 1)


func test_bonus_replacement_reentrant_arrival_removed_target_and_reentry() -> void:
	var view: SubViewport = _viewport()
	var preview: WordPreview = _preview(view)
	var target: Control = _target(view)
	preview.show_result(AttemptResult.new(AttemptResult.Kind.BONUS, "KOT"))
	preview.fly_bonus(target)
	var previous: Tween = get_tree().get_processed_tweens().back()
	preview.fly_bonus(target)
	assert_false(previous.is_valid())
	preview.bonus_arrived.connect(
		func(_target_node: Control) -> void:
			preview.show_result(AttemptResult.new(AttemptResult.Kind.LEVEL, "TOK")),
		CONNECT_ONE_SHOT
	)
	_step(Tokens.dur(Tokens.Motion.BASE) + 0.001)
	assert_eq(preview.text, "TOK")
	assert_eq(preview.feedback_kind(), AttemptResult.Kind.LEVEL)
	preview.show_result(AttemptResult.new(AttemptResult.Kind.BONUS, "KOT"))
	preview.fly_bonus(target)
	watch_signals(preview)
	target.free()
	await get_tree().process_frame
	assert_eq(preview.text, "KOT")
	assert_false((preview.get_node("BonusFlight") as Label).visible)
	assert_signal_not_emitted(preview, "bonus_arrived")
	var replacement: Control = _target(view)
	preview.fly_bonus(replacement)
	view.remove_child(preview)
	assert_eq(preview.text, "KOT")
	view.add_child(preview)
	assert_eq(preview.fly_bonus(replacement), OK)
	_settle()
	assert_signal_emit_count(preview, "bonus_arrived", 1)


func test_bonus_reduction_before_during_and_height_resize_settle_once() -> void:
	var view: SubViewport = _viewport()
	var preview: WordPreview = _preview(view)
	var target: Control = _target(view)
	watch_signals(preview)
	Tokens.reduced_motion = true
	preview.show_result(AttemptResult.new(AttemptResult.Kind.BONUS, "KOT"))
	preview.fly_bonus(target)
	assert_signal_emit_count(preview, "bonus_arrived", 1)
	assert_eq(preview.text, "KOT")
	Tokens.reduced_motion = false
	preview.fly_bonus(target)
	preview.size.y += 100
	assert_signal_emit_count(preview, "bonus_arrived", 2)
	assert_eq(preview.text, "KOT")
	preview.fly_bonus(target)
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_signal_emit_count(preview, "bonus_arrived", 3)
	assert_eq(preview.text, "KOT")
	assert_eq(preview.scale, Vector2.ONE)
	_step(10)
	assert_signal_emit_count(preview, "bonus_arrived", 3)


func test_already_target_two_peaks_restores_and_meter_replaces_generic_pulse() -> void:
	var view: SubViewport = _viewport()
	var preview: WordPreview = _preview(view)
	var target: Control = _target(view)
	target.scale = Vector2(1.2, 0.9)
	preview.show_result(AttemptResult.new(AttemptResult.Kind.ALREADY_FOUND, "KOT"))
	assert_eq(preview.pulse_already_target(target), OK)
	_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	assert_almost_eq(target.scale.x, 1.2 * Tokens.Action.ALREADY_SCALE, 0.001)
	_step(Tokens.dur(Tokens.Motion.FAST))
	assert_almost_eq(target.scale.x, 1.2 * Tokens.Action.ALREADY_SCALE, 0.001)
	preview.set_building("KO")
	assert_eq(target.scale, Vector2(1.2, 0.9))
	assert_eq(target.pivot_offset, Vector2.ZERO)
	var meter: BonusMeter = BonusMeter.new()
	meter.configure(5, 10)
	view.add_child(meter)
	for frame: int in 2:
		await get_tree().process_frame
	preview.show_result(AttemptResult.new(AttemptResult.Kind.ALREADY_FOUND, "KOT"))
	preview.pulse_already_target(target)
	_step(Tokens.dur(Tokens.Motion.FAST) / 4)
	assert_gt(target.scale.x, 1.2)
	assert_eq(preview.pulse_already_target(meter), OK)
	assert_eq(target.scale, Vector2(1.2, 0.9))
	assert_eq(meter.state, &"already")
	_settle()


func test_invalid_tint_three_cycle_shake_fade_and_live_reduction() -> void:
	var preview: WordPreview = _preview(_viewport())
	preview.theme = preload("res://ui/theme/generated/theme_hc_130.tres")
	preview.show_result(AttemptResult.new(AttemptResult.Kind.INVALID, "KOT"))
	var origin: float = preview.position.x
	_step(Tokens.dur(Tokens.Motion.BASE) / 12)
	assert_gt(absf(preview.position.x - origin), 1.0)
	assert_lte(absf(preview.position.x - origin), float(Tokens.Layout.SHAKE_OFFSET) + 0.01)
	_step(Tokens.dur(Tokens.Motion.BASE))
	assert_eq(preview.get_theme_color(&"font_color"), Tokens.PaletteHC.ERROR)
	assert_almost_eq(preview.position.x, origin, 0.001)
	_step(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(preview.text, "")
	preview.show_result(AttemptResult.new(AttemptResult.Kind.INVALID, "TOK"))
	_step(Tokens.dur(Tokens.Motion.FAST) / 4)
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(preview.position.x, origin)
	assert_eq(preview.modulate, Color.WHITE)
	assert_eq((preview.get_node("Feedback") as Label).text.left(1), "×")
	assert_eq(preview.get_theme_color(&"font_color"), Tokens.PaletteHC.ERROR)


func test_short_release_is_silent_and_cancel_never_emits_it() -> void:
	var view: SubViewport = _viewport()
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2.ONE * 600
	view.add_child(wheel)
	wheel.set_letters(PackedStringArray(["K", "O", "T"]))
	watch_signals(wheel)
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.pointer_move(0, wheel.tile_position(1))
	wheel.pointer_end(0)
	assert_signal_emitted_with_parameters(wheel, "short_released", [PackedInt32Array([0, 1])])
	assert_signal_not_emitted(wheel, "word_attempted")
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.pointer_end(0, true)
	assert_signal_emit_count(wheel, "short_released", 1)
	var preview: WordPreview = _preview(view)
	preview.set_building("KO")
	assert_eq(preview.fade_short(), OK)
	_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	assert_lt(preview.modulate.a, 1.0)
	assert_eq(preview.feedback_kind(), -1)
	_step(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(preview.text, "")
	assert_eq(preview.modulate, Color.WHITE)


func test_hint_reveal_order_full_intersection_flash_and_reduction() -> void:
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/content/pl/packs/c-0001-0003.json")
	)
	var level: LevelData = LevelData.from_dict(data["levels"][1])
	var board: BoardState = BoardState.new(level)
	var view: BoardView = BoardView.new()
	view.size = Vector2(800, 700)
	_viewport().add_child(view)
	view.set_board(board)
	var word: Array[Vector2i] = level.word_cells(0)
	board.reveal_cell(word[0])
	view.reveal_cell(word[0], true)
	_settle()
	var result: AttemptResult = board.evaluate(PackedInt32Array([0, 1, 2]))
	view.reveal_word(result.cells_to_reveal)
	assert_almost_eq(view.cell_node(word[0]).scale.x, Tokens.Layout.HINT_START_SCALE, 0.001)
	_step(Tokens.dur(Tokens.Motion.STAGGER))
	assert_gt(view.cell_node(word[0]).scale.x, Tokens.Layout.HINT_START_SCALE)
	assert_almost_eq(view.cell_node(word[1]).scale.x, Tokens.Layout.HINT_START_SCALE, 0.001)
	_settle()
	view.cell_node(word[0]).state = GridCell.State.FILLED
	view.reveal_word([word[1], word[2]])
	_step(Tokens.dur(Tokens.Motion.STAGGER) * 2 + Tokens.dur(Tokens.Motion.BASE) + 0.001)
	_step(Tokens.dur(Tokens.Motion.BASE) / 2)
	assert_gt(
		view.cell_node(word[0]).modulate.r,
		1.0,
		"Already filled member participates in whole-word flash"
	)
	Tokens.reduced_motion = true
	await get_tree().process_frame
	for cell: Vector2i in word:
		assert_eq(view.cell_node(cell).modulate, Color.WHITE)
		assert_eq(view.cell_node(cell).scale, Vector2.ONE)
	var detached: GridCell = GridCell.new()
	detached.reveal(true)
	assert_eq(detached.state, GridCell.State.HINTED)
	detached.free()
