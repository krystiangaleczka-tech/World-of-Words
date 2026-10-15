extends GutTest

const HC: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")
var _locale: String
var _pseudo: bool
var _motion: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_motion = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	Tokens.reduced_motion = true


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _viewport() -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	return view


func _image() -> GradientTexture2D:
	var image: GradientTexture2D = GradientTexture2D.new()
	image.width = 300
	image.height = 200
	image.gradient = Gradient.new()
	return image


func _burst(view: SubViewport) -> RewardBurst:
	var burst: RewardBurst = RewardBurst.new()
	view.add_child(burst)
	return burst


func _card(view: SubViewport, total: int = 4, count: int = 0) -> LocationPostcard:
	var card: LocationPostcard = LocationPostcard.new()
	card.configure(_image(), total, count)
	card.size.x = 800
	view.add_child(card)
	return card


func _step(seconds: float) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(seconds)


func test_burst_atomic_validation_static_amount_and_parent_coordinates() -> void:
	var view: SubViewport = _viewport()
	var burst: RewardBurst = _burst(view)
	watch_signals(burst)
	assert_eq(burst.play(&"coins", 9223372036854775807, Vector2(250, 450)), OK)
	assert_eq(burst.position, Vector2(250, 450))
	assert_eq(burst.state, &"static")
	assert_eq(burst.accessibility_description, "9223372036854775807")
	assert_signal_emitted_with_parameters(burst, "finished", [&"coins", 9223372036854775807])
	assert_eq(burst.play(&"invalid", 1, Vector2.ZERO), ERR_INVALID_PARAMETER)
	assert_eq(burst.play(&"coins", -1, Vector2.ZERO), ERR_INVALID_PARAMETER)
	assert_eq(burst.play(&"coins", 1, Vector2(NAN, 0)), ERR_INVALID_PARAMETER)
	assert_eq(burst.position, Vector2(250, 450))
	assert_signal_emit_count(burst, "finished", 1)
	var parent: VBoxContainer = VBoxContainer.new()
	view.add_child(parent)
	var other: RewardBurst = RewardBurst.new()
	parent.add_child(other)
	assert_eq(other.play(&"coins", 1, Vector2.ZERO), ERR_INVALID_PARAMETER)


func test_burst_normal_particles_one_shot_life_and_exactly_once_completion() -> void:
	var view: SubViewport = _viewport()
	var burst: RewardBurst = _burst(view)
	Tokens.reduced_motion = false
	watch_signals(burst)
	burst.play(&"stars", 3, Vector2(300, 300))
	var particles: CPUParticles2D = (
		burst.find_children("*", "CPUParticles2D", true, false)[0] as CPUParticles2D
	)
	assert_true(particles.one_shot)
	assert_eq(particles.explosiveness, 1.0)
	assert_eq(particles.amount, 24)
	assert_almost_eq(particles.lifetime, float(Tokens.Motion.SLOW) / 1000, 0.0001)
	assert_true(particles.emitting)
	assert_eq(burst.state, &"playing")
	_step(Tokens.dur(Tokens.Motion.SLOW + Tokens.Motion.STAGGER))
	assert_eq(burst.state, &"idle")
	assert_false(burst.visible)
	assert_signal_emit_count(burst, "finished", 1)
	_step(Tokens.dur(Tokens.Motion.SLOW))
	assert_signal_emit_count(burst, "finished", 1)


func test_burst_replay_cancel_exit_reentry_and_live_reduction() -> void:
	var view: SubViewport = _viewport()
	var burst: RewardBurst = _burst(view)
	Tokens.reduced_motion = false
	watch_signals(burst)
	burst.play(&"coins", 25, Vector2.ZERO)
	burst.play(&"chest", 0, Vector2(200, 400))
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(burst.state, &"static")
	assert_signal_emitted_with_parameters(burst, "finished", [&"chest", 0])
	assert_signal_emit_count(burst, "finished", 1)
	var particles: CPUParticles2D = (
		burst.find_children("*", "CPUParticles2D", true, false)[0] as CPUParticles2D
	)
	assert_false(particles.visible)
	assert_false(particles.emitting)
	burst.cancel()
	assert_eq(burst.state, &"idle")
	Tokens.reduced_motion = false
	burst.play(&"stars", 1, Vector2.ZERO)
	view.remove_child(burst)
	_step(Tokens.dur(Tokens.Motion.SLOW + Tokens.Motion.STAGGER))
	assert_signal_emit_count(burst, "finished", 1)
	view.add_child(burst)
	Tokens.reduced_motion = true
	burst.play(&"postcard_piece", 1, Vector2.ZERO)
	assert_signal_emit_count(burst, "finished", 2)


func test_burst_reentrant_finished_preserves_replacement_and_copy_theme() -> void:
	var view: SubViewport = _viewport()
	var burst: RewardBurst = _burst(view)
	var events: Array[StringName] = []
	burst.finished.connect(
		func(kind: StringName, _amount: int) -> void:
			events.append(kind)
			if kind == &"coins":
				burst.play(&"stars", 3, Vector2(400, 700))
	)
	burst.play(&"coins", 25, Vector2.ZERO)
	assert_eq(events, [&"coins", &"stars"])
	assert_eq(burst.position, Vector2(400, 700))
	assert_eq(burst.state, &"static")
	burst.theme = HC
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	assert_eq(burst.accessibility_name, burst.tr("ui.reward.stars"))
	assert_eq(
		(burst.find_children("*", "TextureRect", true, false)[0] as TextureRect).modulate,
		Tokens.PaletteHC.BONUS
	)


func test_burst_passive_overlay_does_not_block_native_underlying_button() -> void:
	var view: SubViewport = _viewport()
	var button: Button = Button.new()
	button.position = Vector2(200, 200)
	button.size = Vector2(300, 144)
	view.add_child(button)
	var burst: RewardBurst = _burst(view)
	burst.play(&"coins", 25, button.get_global_rect().get_center())
	watch_signals(button)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		view.push_input(event)
	assert_signal_emit_count(button, "pressed", 1)
	for control: Control in burst.find_children("*", "Control", true, false):
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_postcard_atomic_config_all_states_and_completion_stamp() -> void:
	var view: SubViewport = _viewport()
	var card: LocationPostcard = _card(view)
	var image: Texture2D = card.texture
	assert_eq(card.state, &"locked")
	assert_eq(card.configure(null, 4, 2), ERR_INVALID_PARAMETER)
	assert_eq(card.configure(image, 0, 0), ERR_INVALID_PARAMETER)
	assert_eq(card.configure(image, 17, 0), ERR_INVALID_PARAMETER)
	assert_eq(card.configure(image, 4, 5), ERR_INVALID_PARAMETER)
	assert_eq(card.configure(image, 4, 2, &"large"), ERR_INVALID_PARAMETER)
	assert_same(card.texture, image)
	assert_eq(card.pieces_revealed, 0)
	card.configure(image, 4, 2)
	assert_eq(card.state, &"in_progress")
	card.configure(image, 4, 4)
	assert_eq(card.state, &"complete")
	assert_eq(card.accessibility_name, card.tr(LocationPostcard.COMPLETE_KEY))
	assert_eq(card.reveal_next(), ERR_ALREADY_IN_USE)
	assert_true((card.find_children("*", "TextureRect", true, false)[0] as TextureRect).visible)


func test_postcard_partition_covers_image_exactly_for_all_supported_counts() -> void:
	var view: SubViewport = _viewport()
	var card: LocationPostcard = _card(view)
	for total: int in range(1, 17):
		card.configure(card.texture, total, 0)
		var area: float = 0
		for index: int in total:
			var region: Rect2 = card.piece_region(index)
			assert_true(Rect2(0, 0, 1, 1).encloses(region))
			area += region.get_area()
			for previous: int in index:
				assert_false(region.intersects(card.piece_region(previous)))
		assert_almost_eq(area, 1.0, 0.00001)
	assert_eq(card.piece_region(-1), Rect2())
	assert_eq(card.piece_region(16), Rect2())


func test_postcard_ordered_interrupted_reveal_and_complete_endpoint() -> void:
	var view: SubViewport = _viewport()
	var card: LocationPostcard = _card(view, 3, 1)
	Tokens.reduced_motion = false
	assert_eq(card.reveal_next(), OK)
	assert_eq(card.pieces_revealed, 2)
	assert_eq(card.state, &"revealing")
	assert_eq(card.configure(null, 4, 0), ERR_INVALID_PARAMETER)
	assert_eq(card.state, &"revealing")
	assert_eq(card.reveal_next(), OK)
	assert_eq(card.pieces_revealed, 3)
	assert_eq(card.state, &"revealing")
	assert_false((card.find_children("*", "TextureRect", true, false)[0] as TextureRect).visible)
	_step(Tokens.dur(Tokens.Motion.BASE + Tokens.Motion.STAGGER))
	assert_eq(card.state, &"complete")
	assert_true((card.find_children("*", "TextureRect", true, false)[0] as TextureRect).visible)


func test_postcard_reduction_before_during_config_exit_reentry_and_copy() -> void:
	var view: SubViewport = _viewport()
	var card: LocationPostcard = _card(view, 2, 0)
	assert_eq(card.reveal_next(), OK)
	assert_eq(card.state, &"in_progress")
	Tokens.reduced_motion = false
	card.reveal_next()
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(card.state, &"complete")
	Tokens.reduced_motion = false
	card.configure(card.texture, 4, 0)
	card.reveal_next()
	view.remove_child(card)
	_step(Tokens.dur(Tokens.Motion.BASE + Tokens.Motion.STAGGER))
	assert_eq(card.pieces_revealed, 1)
	view.add_child(card)
	assert_eq(card.state, &"in_progress")
	card.theme = HC
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	assert_eq(card.accessibility_name, card.tr(LocationPostcard.PROGRESS_KEY))
	assert_eq((card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, Tokens.PaletteHC.SURFACE)


func test_postcard_aspect_resize_thumbnail_and_passive_descendants() -> void:
	var view: SubViewport = _viewport()
	var card: LocationPostcard = _card(view)
	for frame: int in 3:
		await get_tree().process_frame
	var art: Control = card.find_children("*", "Control", true, false)[1] as Control
	assert_almost_eq(art.size.x / art.size.y, 1.5, 0.05)
	card.size.x = 600
	for frame: int in 3:
		await get_tree().process_frame
	assert_almost_eq(art.size.x / art.size.y, 1.5, 0.05)
	card.configure(card.texture, 4, 2, &"thumb")
	for frame: int in 3:
		await get_tree().process_frame
	assert_almost_eq(art.size.x / art.size.y, 1.5, 0.05)
	card.size.x = 800
	for frame: int in 3:
		await get_tree().process_frame
	assert_almost_eq(art.size.x / art.size.y, 1.5, 0.05)
	var portrait: GradientTexture2D = _image()
	portrait.width = 10
	portrait.height = 1000
	card.configure(portrait, 4, 1)
	for frame: int in 3:
		await get_tree().process_frame
	assert_almost_eq(art.size.x / art.size.y, 0.01, 0.00001)
	card.configure(_image(), 4, 1, &"thumb")
	assert_eq(card.preset, &"thumb")
	assert_eq(card.size_flags_horizontal, Control.SIZE_SHRINK_CENTER)
	for control: Control in card.find_children("*", "Control", true, false):
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_reward_css_count_and_angle_are_unitless() -> void:
	var css: String = CeramicThemeGenerator.css_text()
	assert_true(css.contains("--Reward-PARTICLE_COUNT: 24;"))
	assert_true(css.contains("--Reward-SPREAD_DEGREES: 180"))
	assert_false(css.contains("--Reward-PARTICLE_COUNT: calc(24 * var(--Token-unit))"))


func test_rewards_gallery_inventory_scroll_and_large_pseudo_fit() -> void:
	var gallery: GalleryShell = load("res://ui/gallery/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	assert_eq(gallery.configure(&"COMPACT", &"PSEUDO", true, 130, true, true, &"Rewards"), OK)
	for frame: int in 5:
		await get_tree().process_frame
	var screen: ScreenScaffold = gallery.preview_screen()
	assert_eq(screen.find_children("*", "RewardBurst", true, false).size(), 4)
	var kinds: GridContainer = (
		screen.find_children("*", "GridContainer", true, false)[0] as GridContainer
	)
	assert_eq(kinds.columns, 2)
	for button: TextButton in kinds.get_children():
		assert_gte(button.size.x, screen.body.size.x / 2 - Tokens.Space.S)
	assert_eq(screen.find_children("*", "LocationPostcard", true, false).size(), 7)
	var scroll: ScrollContainer = (
		screen.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	)
	assert_true(scroll.get_v_scroll_bar().visible)
	var burst: RewardBurst = screen.find_children("*", "RewardBurst", true, false)[0] as RewardBurst
	assert_true(scroll.is_ancestor_of(burst))
	var first_button: TextButton = kinds.get_child(0) as TextButton
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = first_button.get_screen_transform() * (first_button.size / 2)
		get_viewport().push_input(event, true)
	assert_eq(burst.position, (burst.get_parent() as Control).size / 2)
	var before: float = burst.get_global_transform_with_canvas().origin.y
	scroll.scroll_vertical = 400
	await get_tree().process_frame
	assert_lt(burst.get_global_transform_with_canvas().origin.y, before)
	for card: LocationPostcard in screen.find_children("*", "LocationPostcard", true, false):
		assert_lte(card.size.x, screen.body.size.x)
	gallery.free()


func test_full_postcard_light_frame_and_shadow_refresh_when_switching_presets() -> void:
	var card: LocationPostcard = _card(_viewport(), 4, 2)
	for mode: StringName in [&"full", &"thumb", &"full"]:
		assert_eq(card.configure(card.texture, 4, 2, mode), OK)
		var panel: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(
			panel.content_margin_left, float(Tokens.Space.S if mode == &"full" else Tokens.Space.M)
		)
		assert_eq(panel.content_margin_right, panel.content_margin_left)
		assert_eq(
			panel.shadow_size, Tokens.Elevation.LOW if mode == &"full" else Tokens.Elevation.MID
		)
		assert_eq(card.pieces_revealed, 2)
		assert_eq(card.state, &"in_progress")


func test_full_caption_stays_centred_beside_stamp_or_lock() -> void:
	var card: LocationPostcard = _card(_viewport(), 4, 0)
	var caption: Label = card.find_children("*", "Label", true, false)[0] as Label
	for revealed: int in [0, 2, 4]:
		assert_eq(card.configure(card.texture, 4, revealed), OK)
		for frame: int in 3:
			await get_tree().process_frame
		assert_almost_eq(
			caption.get_global_rect().get_center().x, card.get_global_rect().get_center().x, 0.5
		)
	assert_eq(card.configure(card.texture, 4, 4, &"thumb"), OK)
	for frame: int in 3:
		await get_tree().process_frame
	assert_eq(caption.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_almost_eq(
		caption.get_global_rect().end.x, card.get_global_rect().end.x - Tokens.Space.M, 0.5
	)
