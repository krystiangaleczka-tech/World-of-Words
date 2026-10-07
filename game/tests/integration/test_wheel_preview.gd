extends GutTest


func _wheel() -> LetterWheelView:
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2(600, 600)
	add_child_autofree(wheel)
	wheel.set_letters(PackedStringArray(["K", "O", "T"]))
	watch_signals(wheel)
	return wheel


func test_line_tracks_pointer_and_backtrack() -> void:
	var wheel: LetterWheelView = _wheel()
	assert_eq(wheel.line_point_count(), 0)
	wheel.pointer_begin(0, wheel.tile_position(0))
	assert_eq(wheel.line_point_count(), 2)
	wheel.pointer_move(0, wheel.tile_position(1))
	assert_eq(wheel.line_point_count(), 3)
	assert_eq(wheel.line_point(0), wheel.tile_position(0))
	assert_eq(wheel.line_point(1), wheel.tile_position(1))
	# The endpoint follows even movement below drag slop, without a changed-chain signal.
	var near: Vector2 = wheel.tile_position(1) + Vector2.ONE
	wheel.pointer_move(0, near)
	assert_eq(wheel.line_point(2), near)
	wheel.pointer_move(1, Vector2.ZERO)
	assert_eq(wheel.line_point(2), near)
	wheel.pointer_move(0, Vector2(300, 300))
	assert_eq(wheel.line_point(2), Vector2(300, 300))
	assert_signal_emit_count(wheel, "chain_changed", 2)
	wheel.pointer_move(0, wheel.tile_position(0))
	assert_eq(wheel.line_point_count(), 2)
	assert_eq(wheel.line_point(1), wheel.tile_position(0))
	wheel.pointer_end(0, true)
	assert_eq(wheel.line_point_count(), 0)
	assert_eq(wheel.line_point(0), Vector2.ZERO)
	assert_eq(wheel.line_point(-1), Vector2.ZERO)


func test_preview_building_and_clear() -> void:
	var preview: WordPreview = (
		load("res://ui/components/WordPreview.tscn").instantiate() as WordPreview
	)
	add_child_autofree(preview)
	preview.set_building("KOT")
	assert_eq(preview.text, "KOT")
	preview.set_building("ZAŻÓŁĆ")
	assert_eq(preview.text, "ZAŻÓŁĆ")
	assert_eq(preview.get_theme_font_size("font_size"), Tokens.Type.PREVIEW)
	assert_eq(preview.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	preview.clear()
	assert_eq(preview.text, "")
	preview.show_result(AttemptResult.new(AttemptResult.Kind.LEVEL, "KOT"))
	assert_eq(preview.text, "KOT")
	preview.show_result(null)
	assert_eq(preview.text, "")


func test_eight_tile_line_clears_on_lock_resize_and_release() -> void:
	var wheel: LetterWheelView = _wheel()
	wheel.set_letters(PackedStringArray(["K", "O", "L", "O", "R", "O", "W", "O"]))
	wheel.pointer_begin(0, wheel.tile_position(0))
	for index: int in range(1, 8):
		wheel.pointer_move(0, wheel.tile_position(index))
	assert_eq(wheel.line_point_count(), 9)
	for index: int in 8:
		assert_eq(wheel.line_point(index), wheel.tile_position(index))
	wheel.pointer_end(0)
	assert_eq(wheel.line_point_count(), 0)
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.set_locked(true)
	assert_eq(wheel.line_point_count(), 0)
	wheel.set_locked(false)
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.size = Vector2(800, 800)
	assert_eq(wheel.line_point_count(), 0)
	await get_tree().process_frame


func test_gallery_updates_only_the_corresponding_preview() -> void:
	var gallery: ScreenScaffold = (
		load("res://ui/gallery/wheel.tscn").instantiate() as ScreenScaffold
	)
	add_child_autofree(gallery)
	await get_tree().process_frame
	var first: LetterWheelView = gallery.body.get_child(1) as LetterWheelView
	var second: LetterWheelView = gallery.body.get_child(3) as LetterWheelView
	var first_preview: WordPreview = gallery.body.get_child(0) as WordPreview
	var second_preview: WordPreview = gallery.body.get_child(2) as WordPreview
	first.pointer_begin(0, first.tile_position(0))
	first.pointer_move(0, first.tile_position(1))
	assert_eq(first_preview.text, "KO")
	assert_eq(second_preview.text, "")
	second.pointer_begin(1, second.tile_position(1))
	second.pointer_move(1, second.tile_position(3))
	assert_eq(second_preview.text, "OO")
	assert_eq(first_preview.text, "KO")
	first.pointer_end(0, true)
	second.pointer_end(1, true)
	assert_eq(first_preview.text, "")
	assert_eq(second_preview.text, "")
