extends GutTest


func _wheel() -> LetterWheelView:
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2(600, 600)
	add_child_autofree(wheel)
	wheel.set_letters(PackedStringArray(["K", "O", "T", "A"]))
	watch_signals(wheel)
	return wheel


func test_owner_backtrack_and_release() -> void:
	var wheel: LetterWheelView = _wheel()
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.pointer_begin(1, wheel.tile_position(3))
	wheel.pointer_move(1, wheel.tile_position(2))
	wheel.pointer_end(1)
	assert_eq(wheel.current_chain(), PackedInt32Array([0]))
	wheel.pointer_move(0, wheel.tile_position(1))
	wheel.pointer_move(0, wheel.tile_position(2))
	wheel.pointer_move(0, wheel.tile_position(0))
	assert_eq(wheel.current_chain(), PackedInt32Array([0, 1, 2]))
	wheel.pointer_move(0, wheel.tile_position(1))
	assert_eq(wheel.current_chain(), PackedInt32Array([0, 1]))
	wheel.pointer_move(0, wheel.tile_position(3))
	wheel.pointer_end(0)
	assert_signal_emitted_with_parameters(wheel, "word_attempted", [PackedInt32Array([0, 1, 3])])
	assert_signal_emit_count(wheel, "tile_added", 4)
	assert_false(wheel.is_dragging())


func test_outside_short_cancel_lock() -> void:
	var wheel: LetterWheelView = _wheel()
	wheel.pointer_begin(0, Vector2.ZERO)
	wheel.pointer_move(0, wheel.tile_position(0))
	assert_false(wheel.is_dragging())
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.pointer_end(0)
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.pointer_move(0, wheel.tile_position(1))
	wheel.pointer_move(0, wheel.tile_position(2))
	wheel.pointer_end(0, true)
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.set_locked(true)
	assert_true(wheel.current_chain().is_empty())
	wheel.pointer_begin(0, wheel.tile_position(1))
	assert_false(wheel.is_dragging())
	wheel.set_locked(false)
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.notification(NOTIFICATION_APPLICATION_PAUSED)
	assert_false(wheel.is_dragging())
	assert_signal_not_emitted(wheel, "word_attempted")


func test_gui_touch_and_mouse_paths() -> void:
	var wheel: LetterWheelView = _wheel()
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 7
	touch.pressed = true
	touch.position = wheel.tile_position(0)
	wheel._gui_input(touch)
	assert_true(wheel.is_dragging())
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 7
	for index: int in [1, 2]:
		drag.position = wheel.tile_position(index)
		wheel._gui_input(drag)
	touch.pressed = false
	touch.canceled = true
	wheel._gui_input(touch)
	assert_signal_not_emitted(wheel, "word_attempted")
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = wheel.tile_position(0)
	wheel._gui_input(mouse)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	for index: int in [1, 2]:
		motion.position = wheel.tile_position(index)
		wheel._gui_input(motion)
	mouse.pressed = false
	wheel._gui_input(mouse)
	assert_signal_emit_count(wheel, "word_attempted", 1)


func test_slop_repeated_letters_and_reconfigure() -> void:
	var wheel: LetterWheelView = _wheel()
	wheel.set_letters(PackedStringArray(["A", "A", "A", "A", "A", "A", "A", "A"]))
	wheel.pointer_begin(0, wheel.tile_position(0))
	for step: int in range(1, Tokens.Touch.DRAG_SLOP):
		wheel.pointer_move(0, wheel.tile_position(0) + Vector2(step, 0))
	assert_signal_emit_count(wheel, "chain_changed", 1)
	for index: int in range(1, 8):
		wheel.pointer_move(0, wheel.tile_position(index))
	assert_eq(wheel.current_chain(), PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7]))
	var copy: PackedInt32Array = wheel.current_chain()
	copy[0] = 7
	assert_eq(wheel.current_chain()[0], 0)
	wheel.size = Vector2(800, 800)
	assert_false(wheel.is_dragging())
	assert_signal_not_emitted(wheel, "word_attempted")
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.set_letters(PackedStringArray(["K", "O", "T"]))
	assert_false(wheel.is_dragging())


func test_viewport_routes_touch_release_outside() -> void:
	# Isolate GUI picking from the GUT runner's own overlay controls.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2(600, 600)
	viewport.add_child(wheel)
	wheel.set_letters(PackedStringArray(["K", "O", "T"]))
	watch_signals(wheel)
	await get_tree().process_frame
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = wheel.tile_position(0)
	viewport.push_input(touch)
	assert_true(wheel.is_dragging())
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 0
	for index: int in [1, 2]:
		drag.position = wheel.tile_position(index)
		viewport.push_input(drag)
	touch.position = Vector2(1000, 1000)
	touch.pressed = false
	viewport.push_input(touch)
	assert_false(wheel.is_dragging())
	assert_signal_emitted_with_parameters(wheel, "word_attempted", [PackedInt32Array([0, 1, 2])])

	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = wheel.tile_position(0)
	viewport.push_input(mouse)
	assert_true(wheel.is_dragging())
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	for index: int in [1, 2]:
		motion.position = wheel.tile_position(index)
		viewport.push_input(motion)
	mouse.position = Vector2(1000, 1000)
	mouse.pressed = false
	viewport.push_input(mouse)
	assert_false(wheel.is_dragging())
	assert_signal_emit_count(wheel, "word_attempted", 2)
