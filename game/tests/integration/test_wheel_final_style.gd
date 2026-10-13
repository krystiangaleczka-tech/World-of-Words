extends GutTest

const HC: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")
var _locale: String
var _motion: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_motion = Tokens.reduced_motion


func after_each() -> void:
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)


func test_tile_theme_selection_and_live_reduction() -> void:
	Tokens.reduced_motion = false
	var tile: LetterTile = LetterTile.new()
	tile.theme = HC
	tile.size = Vector2.ONE * 200
	tile.letter = "Ź"
	add_child_autofree(tile)
	assert_eq(tile.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_same(tile.get_theme_font(&"font", &"TileLetter"), HC.get_font(&"font", &"TileLetter"))
	assert_eq(tile.get_theme_color(&"TILE_SELECTED", &"Palette"), Tokens.PaletteHC.TILE_SELECTED)
	tile.selected = true
	assert_true(tile.is_processing())
	assert_eq(tile.scale, Vector2.ONE)
	tile._process(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(tile.scale, Vector2.ONE * Tokens.Layout.TILE_SELECTED_SCALE)
	assert_false(tile.is_processing())
	tile.selected = false
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(tile.scale, Vector2.ONE)
	assert_false(tile.is_processing())
	tile.selected = true
	assert_eq(tile.scale, Vector2.ONE * Tokens.Layout.TILE_SELECTED_SCALE)
	tile.size = Vector2.ONE * 180
	assert_eq(tile.pivot_offset, tile.size / 2)
	remove_child(tile)
	assert_eq(tile.scale, Vector2.ONE)
	add_child(tile)


func test_wheel_lock_shuffle_backtrack_and_reentry() -> void:
	Tokens.reduced_motion = false
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.theme = HC
	wheel.size = Vector2.ONE * 600
	add_child_autofree(wheel)
	wheel.set_letters(PackedStringArray(["K", "O", "T"]))
	wheel.pointer_begin(0, wheel.tile_position(0))
	wheel.pointer_move(0, wheel.tile_position(1))
	wheel.pointer_move(0, wheel.tile_position(0))
	assert_eq(wheel.current_chain(), PackedInt32Array([0]))
	assert_false((wheel.get_child(1) as LetterTile).selected)
	wheel.set_locked(true)
	for tile: LetterTile in wheel.get_children():
		assert_true(tile.disabled)
		assert_false(tile.selected)
	wheel.set_locked(false)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 22
	assert_true(wheel.shuffle(rng))
	for tile: LetterTile in wheel.get_children():
		assert_true(tile.disabled)
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(1)
	assert_false(wheel.is_locked())
	for tile: LetterTile in wheel.get_children():
		assert_false(tile.disabled)
	assert_true(wheel.shuffle(rng))
	wheel.size = Vector2.ONE * 650
	assert_false(wheel.is_locked())
	for tile: LetterTile in wheel.get_children():
		assert_false(tile.disabled)
	remove_child(wheel)
	add_child(wheel)
	wheel.size = Vector2.ONE * 700
	assert_almost_eq(
		wheel.tile_position(0).distance_to(wheel.size / 2),
		700 * Tokens.Layout.WHEEL_RING_RATIO,
		0.01
	)


func test_preview_generated_surface_typography_copy_and_reentry() -> void:
	Tokens.reduced_motion = true
	var preview: WordPreview = WordPreview.new()
	preview.theme = HC
	preview.size = Vector2(936, 180)
	add_child_autofree(preview)
	assert_eq(preview.get_theme_font_size(&"font_size"), HC.get_font_size(&"font_size", &"Preview"))
	var surface: StyleBoxFlat = preview.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_eq(surface.bg_color.a, 0.0)
	preview.set_building("ZAŻÓŁĆ")
	assert_eq(surface.bg_color, Tokens.PaletteHC.SURFACE)
	assert_eq(surface.corner_radius_top_left, Tokens.Radius.FULL)
	preview.show_result(AttemptResult.new(AttemptResult.Kind.INVALID, "KOT"))
	assert_eq(preview.get_theme_color(&"font_color"), Tokens.PaletteHC.ERROR)
	var cue: Label = preview.get_node("Feedback") as Label
	assert_eq(cue.text.left(1), "×")
	assert_eq(cue.get_theme_font_size(&"font_size"), HC.get_font_size(&"font_size", &"Caption"))
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(cue.text, "× Not in our word list")
	preview.theme = preload("res://ui/theme/generated/theme_default_100.tres")
	await get_tree().process_frame
	assert_eq(preview.get_theme_color(&"font_color"), Tokens.Palette.ERROR)
	assert_eq(surface.bg_color, Tokens.Palette.SURFACE)
	preview.size.x = 200
	await get_tree().process_frame
	assert_gt(
		cue.size.y, cue.get_theme_font(&"font").get_height(cue.get_theme_font_size(&"font_size"))
	)
	assert_gte(preview.custom_minimum_size.y, cue.position.y + cue.size.y)
	remove_child(preview)
	add_child(preview)
	preview.size.x = 800
	assert_eq(cue.size.x, 800.0)
	preview.clear()
	assert_eq(surface.bg_color.a, 0.0)


func test_wrapped_caption_layout_keeps_new_result_motion() -> void:
	Tokens.reduced_motion = false
	var preview: WordPreview = WordPreview.new()
	preview.size = Vector2(220, 180)
	add_child_autofree(preview)
	for frame: int in 2:
		await get_tree().process_frame
	preview.show_result(AttemptResult.new(AttemptResult.Kind.INVALID, "KOT"))
	var motion: Tween = get_tree().get_processed_tweens().back()
	for frame: int in 2:
		await get_tree().process_frame
	assert_true(motion.is_valid(), "caption reshaping must preserve feedback animation")
	preview.clear()
	assert_false(motion.is_valid())
