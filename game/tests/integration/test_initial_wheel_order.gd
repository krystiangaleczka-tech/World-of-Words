extends GutTest


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _wheel(letters: PackedStringArray, seed_value: int) -> LetterWheelView:
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2(600, 600)
	add_child_autofree(wheel)
	wheel.set_letters(letters, _rng(seed_value))
	return wheel


func test_seeded_initial_order_is_reproducible_and_varied() -> void:
	var letters: PackedStringArray = PackedStringArray(["K", "O", "T"])
	var first: LetterWheelView = _wheel(letters, 42)
	var repeated: LetterWheelView = _wheel(letters, 42)
	assert_eq(first.tile_order(), repeated.tile_order())
	assert_ne(first.tile_order(), PackedInt32Array([0, 1, 2]))
	var orders: Dictionary = {}
	for seed_value: int in 12:
		var wheel: LetterWheelView = _wheel(letters, seed_value)
		var order: PackedInt32Array = wheel.tile_order()
		orders[str(order)] = true
		order.sort()
		assert_eq(order, PackedInt32Array([0, 1, 2]))
	assert_gt(orders.size(), 1)
	assert_eq(letters, PackedStringArray(["K", "O", "T"]))


func test_duplicate_tiles_keep_identity_and_input_is_ready_immediately() -> void:
	var letters: PackedStringArray = PackedStringArray(["A", "A", "T", "K"])
	var tween_count: int = get_tree().get_processed_tweens().size()
	var wheel: LetterWheelView = _wheel(letters, 10)
	assert_false(wheel.is_locked())
	assert_false(wheel.is_dragging())
	assert_eq(get_tree().get_processed_tweens().size(), tween_count)
	var order: PackedInt32Array = wheel.tile_order()
	var visible_change: bool = false
	for slot: int in order.size():
		visible_change = visible_change or letters[order[slot]] != letters[slot]
	assert_true(visible_change)
	for index: int in letters.size():
		var tile: LetterTile = wheel.get_child(index) as LetterTile
		assert_eq(tile.index, index)
		assert_eq(tile.letter, letters[index])
	wheel.pointer_begin(1, wheel.tile_position(0))
	wheel.pointer_move(1, wheel.tile_position(1))
	assert_eq(wheel.current_chain(), PackedInt32Array([0, 1]))
	wheel.pointer_end(1, true)


func test_null_invalid_and_uniform_initialization() -> void:
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2(600, 600)
	add_child_autofree(wheel)
	wheel.set_letters(PackedStringArray(["K", "O", "T"]))
	assert_eq(wheel.tile_order(), PackedInt32Array([0, 1, 2]))
	wheel.set_letters(PackedStringArray(["K"]), _rng(1))
	assert_true(wheel.tile_order().is_empty())
	assert_eq(wheel.get_child_count(), 0)
	wheel.set_letters(PackedStringArray(["A", "A", "A"]), _rng(1))
	var order: PackedInt32Array = wheel.tile_order()
	order.sort()
	assert_eq(order, PackedInt32Array([0, 1, 2]))
	assert_false(wheel.is_locked())
