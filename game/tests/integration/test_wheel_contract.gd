extends GutTest


func test_wheel_public_contract() -> void:
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2(600, 600)
	add_child_autofree(wheel)
	wheel.set_letters(PackedStringArray(["K", "O", "T"]))
	assert_eq(wheel.get_child_count(), 3)
	assert_lt(wheel.tile_position(0).y, 300.0)
	assert_false(wheel.is_dragging())
	assert_true(wheel.current_chain().is_empty())
	wheel.set_locked(true)
	assert_true(wheel.is_locked())
	wheel.set_letters(PackedStringArray(["K"]))
	assert_eq(wheel.get_child_count(), 0)
