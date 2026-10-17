# gdlint: disable=max-public-methods
extends GutTest

var _path: PackedVector2Array = PackedVector2Array(
	[Vector2(100, 100), Vector2(300, 100), Vector2(300, 300)]
)
var _reduced: bool
var _locale: String
var _pseudo: bool


func before_each() -> void:
	_reduced = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	Tokens.reduced_motion = false


func after_each() -> void:
	Tokens.reduced_motion = _reduced
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo


func sample(loop: bool = true) -> TutorialHand:
	var hand: TutorialHand = TutorialHand.new()
	assert_eq(hand.configure(_path, loop), OK)
	add_child_autofree(hand)
	return hand


func test_validation_copy_and_invalid_replacement_preserve_active_motion() -> void:
	var hand: TutorialHand = TutorialHand.new()
	assert_eq(hand.play(), ERR_UNCONFIGURED)
	var path: PackedVector2Array = _path.duplicate()
	assert_eq(hand.configure(path), OK)
	path[0] = Vector2.ZERO
	assert_eq(hand.points, _path)
	var copy: PackedVector2Array = hand.points
	copy[0] = Vector2.ZERO
	assert_eq(hand.points, _path)
	add_child_autofree(hand)
	var motion: Tween = get_tree().get_processed_tweens().back()
	for bad: PackedVector2Array in [
		PackedVector2Array(),
		PackedVector2Array([Vector2.ONE]),
		PackedVector2Array([Vector2.ZERO, Vector2(INF, 0)]),
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	]:
		assert_eq(hand.configure(bad, false), ERR_INVALID_PARAMETER)
		assert_eq(hand.points, _path)
		assert_eq(hand.state, &"playing")
		assert_true(motion.is_valid())
	assert_eq(hand.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(hand.focus_mode, Control.FOCUS_NONE)


func test_motion_uses_each_segment_end_pause_and_nonloop_endpoint() -> void:
	var hand: TutorialHand = sample(false)
	watch_signals(hand)
	var motion: Tween = get_tree().get_processed_tweens().back()
	motion.pause()
	motion.custom_step(Tokens.dur(Tokens.Motion.SLOW) / 2)
	assert_almost_eq(hand.hand_position.x, 200.0, 0.1)
	assert_almost_eq(hand.hand_position.y, 100.0, 0.1)
	motion.custom_step(Tokens.dur(Tokens.Motion.SLOW) / 2)
	assert_almost_eq(hand.hand_position.x, 300.0, 0.1)
	motion.custom_step(Tokens.dur(Tokens.Motion.SLOW))
	assert_almost_eq(hand.hand_position.y, 300.0, 0.1)
	motion.custom_step(Tokens.dur(Tokens.Motion.BASE) / 2)
	assert_eq(hand.state, &"playing")
	assert_signal_not_emitted(hand, "cycle_finished")
	motion.custom_step(Tokens.dur(Tokens.Motion.BASE))
	assert_eq(hand.state, &"finished")
	assert_eq(hand.hand_position, _path[-1])
	assert_false(hand.is_processing())
	assert_signal_emit_count(hand, "cycle_finished", 1)


func test_loop_replacement_and_explicit_replay_kill_previous_tweens() -> void:
	var hand: TutorialHand = sample()
	watch_signals(hand)
	var first: Tween = get_tree().get_processed_tweens().back()
	first.pause()
	first.custom_step(
		(
			Tokens.dur(Tokens.Motion.SLOW) * 2
			+ Tokens.dur(Tokens.Motion.BASE)
			+ Tokens.dur(Tokens.Motion.FAST)
		)
	)
	assert_signal_emit_count(hand, "cycle_finished", 1)
	assert_eq(hand.state, &"playing")
	assert_eq(hand.configure(PackedVector2Array([Vector2.ZERO, Vector2(50, 50)])), OK)
	assert_false(first.is_valid())
	var replacement: Tween = get_tree().get_processed_tweens().back()
	assert_eq(hand.play(), OK)
	assert_false(replacement.is_valid())
	hand.cancel()
	assert_eq(hand.state, &"hidden")
	assert_false(hand.visible)
	assert_false(hand.is_processing())


func test_first_touch_fades_once_and_resize_cannot_reshow_dismissed_hand() -> void:
	var hand: TutorialHand = sample()
	var play: Tween = get_tree().get_processed_tweens().back()
	hand.hide_for_touch()
	assert_false(play.is_valid())
	assert_eq(hand.state, &"hiding")
	var fade: Tween = get_tree().get_processed_tweens().back()
	fade.pause()
	fade.custom_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	assert_almost_eq(hand.modulate.a, 0.5, 0.1)
	hand.hide_for_touch()
	assert_true(fade.is_valid())
	fade.custom_step(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(hand.state, &"hidden")
	assert_false(hand.visible)
	hand.size = Vector2(500, 500)
	assert_eq(hand.configure(_path), OK)
	assert_eq(hand.state, &"hidden")
	assert_false(hand.visible)


func test_reduced_motion_static_arrow_before_and_during_motion_has_no_idle_work() -> void:
	Tokens.reduced_motion = true
	var hand: TutorialHand = sample()
	assert_eq(hand.state, &"static")
	assert_true(hand.visible)
	assert_false(hand.is_processing())
	hand.hide_for_touch()
	assert_eq(hand.state, &"hidden")
	Tokens.reduced_motion = false
	assert_eq(hand.play(), OK)
	var motion: Tween = get_tree().get_processed_tweens().back()
	Tokens.reduced_motion = true
	await wait_process_frames(2)
	assert_eq(hand.state, &"static")
	assert_false(motion.is_valid())
	assert_false(hand.is_processing())
	hand.theme = load("res://ui/theme/generated/theme_hc_130.tres")
	await wait_process_frames(1)
	assert_eq(hand.state, &"static")


func test_exit_cancels_and_retained_entry_requires_explicit_play() -> void:
	var parent: Node = Node.new()
	add_child_autofree(parent)
	var hand: TutorialHand = TutorialHand.new()
	hand.configure(_path)
	parent.add_child(hand)
	var motion: Tween = get_tree().get_processed_tweens().back()
	parent.remove_child(hand)
	assert_false(motion.is_valid())
	assert_eq(hand.state, &"hidden")
	parent.add_child(hand)
	await wait_process_frames(2)
	assert_eq(hand.state, &"hidden")
	assert_eq(hand.play(), OK)
	assert_eq(hand.state, &"playing")


func gallery(dimensions: Vector2i = Vector2i(1080, 1920)) -> Control:
	assert_eq(GalleryShell.PAGES[&"Tutorial"], "res://ui/gallery/tutorial.tscn")
	var view: SubViewport = SubViewport.new()
	view.size = dimensions
	add_child_autofree(view)
	var page: Control = (load("res://ui/gallery/tutorial.tscn") as PackedScene).instantiate()
	view.add_child(page)
	return page


func test_native_swipe_reaches_real_wheel_through_hand_overlay() -> void:
	var page: Control = gallery()
	await wait_process_frames(4)
	var wheel: LetterWheelView = page.get("wheel")
	var hand: TutorialHand = page.get("hand")
	watch_signals(wheel)
	var view: SubViewport = page.get_parent()
	var first: Vector2 = wheel.get_global_transform() * wheel.tile_position(0)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = first
	view.push_input(touch)
	assert_eq(hand.state, &"hiding")
	for index: int in [1, 2]:
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.index = 0
		drag.position = wheel.get_global_transform() * wheel.tile_position(index)
		view.push_input(drag)
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = wheel.get_global_transform() * wheel.tile_position(2)
	touch.pressed = false
	view.push_input(touch)
	assert_signal_emitted_with_parameters(wheel, "word_attempted", [PackedInt32Array([0, 1, 2])])


func test_twelve_case_gallery_geometry_and_hidden_relayout() -> void:
	Tokens.reduced_motion = true
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.set_locale("pl")
				TranslationServer.pseudolocalization_enabled = pseudo
				var page: Control = gallery(dimensions)
				page.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				await wait_process_frames(3)
				var hand: TutorialHand = page.get("hand")
				assert_eq(hand.state, &"static")
				var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(dimensions))
				assert_true(bounds.encloses((page.get("wheel") as Control).get_global_rect()))
				assert_true(bounds.encloses((page.get("caption") as Label).get_global_rect()))
				hand.hide_for_touch()
				page.size = Vector2(dimensions)
				await wait_process_frames(2)
				assert_eq(hand.state, &"hidden")
				page.get_parent().free()


func test_touch_before_deferred_retained_play_keeps_hand_hidden() -> void:
	var parent: Node = Node.new()
	add_child_autofree(parent)
	var hand: TutorialHand = TutorialHand.new()
	hand.configure(_path)
	parent.add_child(hand)
	parent.remove_child(hand)
	assert_eq(hand.play(), OK)
	parent.add_child(hand)
	hand.hide_for_touch()
	await wait_process_frames(2)
	assert_eq(hand.state, &"hidden")
	assert_false(hand.visible)
	assert_false(hand.is_processing())


func test_gallery_retained_layout_and_native_touch_remain_connected_once() -> void:
	var page: Control = gallery()
	await wait_process_frames(3)
	var view: SubViewport = page.get_parent()
	view.remove_child(page)
	view.size = Vector2i(1440, 1920)
	view.add_child(page)
	await wait_process_frames(4)
	var hand: TutorialHand = page.get("hand")
	assert_eq(hand.state, &"hidden")
	assert_eq(hand.play(), OK)
	var wheel: LetterWheelView = page.get("wheel")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = wheel.get_global_transform() * wheel.tile_position(0)
	view.push_input(touch)
	assert_eq(hand.state, &"hiding")
	assert_true(Rect2(Vector2.ZERO, Vector2(view.size)).encloses(wheel.get_global_rect()))


func test_actual_gallery_shell_can_select_translated_tutorial_scene() -> void:
	TranslationServer.set_locale("pl")
	var shell: GalleryShell = GalleryShell.new()
	add_child_autofree(shell)
	assert_eq(shell.configure(&"COMPACT", &"PL", false, 100, false, false, &"Tutorial"), OK)
	await wait_process_frames(2)
	assert_eq(shell.preview_viewport().get_child_count(), 1)
	assert_true(shell.preview_screen().get("hand") is TutorialHand)
	assert_eq(shell.tr("gallery.page.tutorial"), "Samouczek")
