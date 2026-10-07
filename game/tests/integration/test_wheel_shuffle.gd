extends GutTest

var _previous_reduced_motion: bool


func before_each() -> void:
	_previous_reduced_motion = Tokens.reduced_motion
	Tokens.reduced_motion = false


func after_each() -> void:
	Tokens.reduced_motion = _previous_reduced_motion


func _wheel(letters: PackedStringArray = PackedStringArray()) -> LetterWheelView:
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2(600, 600)
	add_child_autofree(wheel)
	wheel.set_letters(letters if not letters.is_empty() else PackedStringArray(["K", "O", "T"]))
	return wheel


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 108
	return rng


func test_shuffle_preserves_identity_and_changes_layout() -> void:
	Tokens.reduced_motion = true
	var wheel: LetterWheelView = _wheel()
	var original: PackedVector2Array = PackedVector2Array()
	for tile_id: int in 3:
		original.append(wheel.tile_position(tile_id))
	assert_true(wheel.shuffle(_rng()))
	var order: PackedInt32Array = wheel.tile_order()
	assert_ne(order, PackedInt32Array([0, 1, 2]))
	for slot: int in order.size():
		assert_eq(wheel.tile_position(order[slot]), original[slot])
	var altered: PackedInt32Array = wheel.tile_order()
	altered[0] = 99
	assert_eq(wheel.tile_order(), order)
	wheel.pointer_begin(0, wheel.tile_position(order[0]))
	wheel.pointer_move(0, wheel.tile_position(order[1]))
	assert_eq(wheel.current_chain(), PackedInt32Array([order[0], order[1]]))
	wheel.pointer_end(0, true)


func test_reject_during_drag_lock_and_uniform() -> void:
	var wheel: LetterWheelView = _wheel()
	var rng: RandomNumberGenerator = _rng()
	assert_false(wheel.shuffle(null))
	wheel.pointer_begin(0, wheel.tile_position(0))
	assert_false(wheel.shuffle(rng))
	assert_eq(wheel.current_chain(), PackedInt32Array([0]))
	wheel.pointer_end(0, true)
	wheel.set_locked(true)
	assert_false(wheel.shuffle(rng))
	wheel.set_locked(false)
	assert_true(wheel.shuffle(rng))
	assert_true(wheel.is_locked())
	assert_false(wheel.shuffle(rng))
	wheel.pointer_begin(0, wheel.tile_position(0))
	assert_false(wheel.is_dragging())
	wheel.set_locked(true)
	get_tree().get_processed_tweens().back().custom_step(1.0)
	assert_true(wheel.is_locked())
	wheel.set_locked(false)
	assert_false(wheel.is_locked())
	wheel.set_letters(PackedStringArray(["A", "A", "A"]))
	assert_false(wheel.shuffle(rng))
	assert_eq(wheel.tile_order(), PackedInt32Array([0, 1, 2]))


func test_reduced_motion_and_reconfigure_unlock() -> void:
	var wheel: LetterWheelView = _wheel()
	var old_centers: PackedVector2Array = PackedVector2Array()
	for tile_id: int in 3:
		old_centers.append(wheel.tile_position(tile_id))
	assert_true(wheel.shuffle(_rng()))
	assert_true(wheel.is_locked())
	var moved_tile: int = -1
	for tile_id: int in 3:
		if old_centers[tile_id] != wheel.tile_position(tile_id):
			moved_tile = tile_id
			break
	assert_gte(moved_tile, 0)
	var tile: LetterTile = wheel.get_child(moved_tile) as LetterTile
	get_tree().get_processed_tweens().back().custom_step(Tokens.dur(Tokens.Motion.BASE) / 2.0)
	var mid_center: Vector2 = tile.position + tile.size / 2.0
	assert_almost_eq(
		mid_center.distance_to(wheel.size / 2.0),
		minf(wheel.size.x, wheel.size.y) * Tokens.Layout.WHEEL_RING_RATIO,
		0.01
	)
	assert_ne(mid_center, old_centers[moved_tile])
	assert_ne(mid_center, wheel.tile_position(moved_tile))
	var order: PackedInt32Array = wheel.tile_order()
	wheel.size = Vector2(700, 700)
	assert_false(wheel.is_locked())
	assert_eq(wheel.tile_order(), order)
	var expected_slots: PackedVector2Array = WheelGeometry.positions(
		order.size(), 700.0 * Tokens.Layout.WHEEL_RING_RATIO, wheel.size / 2.0
	)
	for slot: int in order.size():
		assert_eq(wheel.tile_position(order[slot]), expected_slots[slot])
	assert_true(wheel.shuffle(_rng()))
	wheel.set_letters(PackedStringArray(["L", "A", "S"]))
	assert_false(wheel.is_locked())
	assert_eq(wheel.tile_order(), PackedInt32Array([0, 1, 2]))
	Tokens.reduced_motion = true
	assert_true(wheel.shuffle(_rng()))
	assert_false(wheel.is_locked())
	wheel.pointer_begin(0, wheel.tile_position(wheel.tile_order()[0]))
	assert_true(wheel.is_dragging())
	wheel.pointer_end(0, true)
	wheel.queue_free()
	await get_tree().process_frame


func test_gallery_shuffle_button_uses_second_wheel() -> void:
	Tokens.reduced_motion = true
	var gallery: ScreenScaffold = (
		load("res://ui/gallery/wheel.tscn").instantiate() as ScreenScaffold
	)
	add_child_autofree(gallery)
	await get_tree().process_frame
	var first: LetterWheelView = gallery.body.get_child(1) as LetterWheelView
	var second: LetterWheelView = gallery.body.get_child(3) as LetterWheelView
	var button: IconButton = (
		gallery.body.get_child(gallery.body.get_child_count() - 1) as IconButton
	)
	assert_not_null(button)
	assert_eq(button.text, tr("level.hud.shuffle"))
	button.pressed.emit()
	assert_eq(first.tile_order(), PackedInt32Array([0, 1, 2]))
	assert_ne(second.tile_order(), PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7]))
