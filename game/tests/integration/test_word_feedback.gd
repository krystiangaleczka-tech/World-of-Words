extends GutTest

var _locale: String = ""
var _reduced_motion: bool = false


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_reduced_motion = Tokens.reduced_motion


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Tokens.reduced_motion = _reduced_motion


func _preview() -> WordPreview:
	var preview: WordPreview = WordPreview.new()
	preview.size = Vector2(800, 128)
	add_child_autofree(preview)
	return preview


func test_result_cues_and_translations() -> void:
	Tokens.reduced_motion = true
	var preview: WordPreview = _preview()
	var cue: Label = preview.get_node("Feedback") as Label
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate("level.feedback.already_found"), "↻ Already found")
	var labels: PackedStringArray = [
		"✓ Found", "★ Bonus word", "↻ Already found", "× Not in our word list"
	]
	var colors: Array[Color] = [
		Tokens.Palette.PRIMARY,
		Tokens.Palette.BONUS,
		Tokens.Palette.TEXT_MUTED,
		Tokens.Palette.ERROR
	]
	for kind: int in AttemptResult.Kind.values():
		preview.show_result(AttemptResult.new(kind, "KOT"))
		assert_eq(preview.feedback_kind(), kind)
		assert_eq(preview.text, "KOT")
		assert_eq(cue.text, labels[kind])
		assert_eq(preview.get_theme_color("font_color"), colors[kind])
		assert_eq(cue.get_theme_color("font_color"), colors[kind])
	TranslationServer.set_locale("pl")
	await get_tree().process_frame
	assert_eq(cue.text, "× Brak na liście")
	preview.show_result(null)
	assert_eq(preview.feedback_kind(), -1)
	assert_eq(cue.text, "")
	for word: String in ["", "KO"]:
		preview.show_result(AttemptResult.new(AttemptResult.Kind.INVALID, word))
		assert_eq(preview.feedback_kind(), -1)
		assert_eq(preview.text, "")


func test_interrupted_and_reduced_motion_feedback() -> void:
	Tokens.reduced_motion = false
	var preview: WordPreview = _preview()
	preview.position = Vector2(20, 30)
	preview.show_result(AttemptResult.new(AttemptResult.Kind.LEVEL, "KOT"))
	var pop: Tween = get_tree().get_processed_tweens().back() as Tween
	assert_gt(preview.scale.x, 1.0)
	pop.custom_step(Tokens.dur(Tokens.Motion.FAST))
	preview.show_result(AttemptResult.new(AttemptResult.Kind.INVALID, "TOK"))
	assert_false(pop.is_valid())
	var shake: Tween = get_tree().get_processed_tweens().back() as Tween
	shake.custom_step(Tokens.dur(Tokens.Motion.FAST) / 2.0)
	assert_gt(preview.position.x, 20.0)
	preview.set_building("TO")
	assert_false(shake.is_valid())
	assert_almost_eq(preview.position.x, 20.0, 0.001)
	assert_eq(preview.scale, Vector2.ONE)
	assert_eq(preview.modulate, Color.WHITE)
	assert_eq(preview.feedback_kind(), -1)
	Tokens.reduced_motion = true
	preview.show_result(AttemptResult.new(AttemptResult.Kind.INVALID, "TOK"))
	assert_almost_eq(preview.position.x, 20.0, 0.001)
	assert_eq(preview.scale, Vector2.ONE)
	assert_eq(preview.modulate.a, 1.0)
	assert_eq((preview.get_node("Feedback") as Label).text.left(1), "×")
	preview.clear()
	assert_eq(preview.text, "")


func test_feedback_fades_and_clears_without_stale_callbacks() -> void:
	Tokens.reduced_motion = false
	var preview: WordPreview = _preview()
	preview.show_result(AttemptResult.new(AttemptResult.Kind.BONUS, "TOK"))
	var fade: Tween = get_tree().get_processed_tweens().back() as Tween
	var hold: float = Tokens.dur(Tokens.Motion.BASE) + Tokens.dur(Tokens.Motion.TOAST_HOLD)
	fade.custom_step(hold + Tokens.dur(Tokens.Motion.SLOW) / 2.0)
	assert_lt(preview.modulate.a, 1.0)
	preview.set_building("KO")
	assert_false(fade.is_valid())
	assert_eq(preview.text, "KO")
	assert_eq(preview.modulate.a, 1.0)
	preview.show_result(AttemptResult.new(AttemptResult.Kind.LEVEL, "KOT"))
	var done: Tween = get_tree().get_processed_tweens().back() as Tween
	done.custom_step(hold + Tokens.dur(Tokens.Motion.SLOW) + 1.0)
	assert_eq(preview.feedback_kind(), -1)
	assert_eq(preview.text, "")
	assert_eq(preview.scale, Vector2.ONE)
	assert_eq(preview.modulate.a, 1.0)


func test_translation_owners_unregister_independently() -> void:
	Tokens.reduced_motion = true
	var previous_pl: Translation = TranslationServer.get_translation_object("pl")
	var previous_en: Translation = TranslationServer.get_translation_object("en")
	var first: WordPreview = _preview()
	var second: WordPreview = _preview()
	first.show_result(AttemptResult.new(AttemptResult.Kind.LEVEL, "KOT"))
	second.show_result(AttemptResult.new(AttemptResult.Kind.BONUS, "TOK"))
	first.free()
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq((second.get_node("Feedback") as Label).text, "★ Bonus word")
	TranslationServer.set_locale("pl")
	await get_tree().process_frame
	assert_eq((second.get_node("Feedback") as Label).text, "★ Słowo bonusowe")
	second.free()
	assert_same(TranslationServer.get_translation_object("pl"), previous_pl)
	assert_same(TranslationServer.get_translation_object("en"), previous_en)


func test_gallery_demonstrates_all_result_states() -> void:
	var gallery: ScreenScaffold = (
		load("res://ui/gallery/wheel.tscn").instantiate() as ScreenScaffold
	)
	add_child_autofree(gallery)
	await get_tree().process_frame
	var kinds: Array[int] = []
	for row: Node in gallery.body.get_children():
		if not row is HBoxContainer:
			continue
		for child: Node in row.get_children():
			var sample: WordPreview = child as WordPreview
			kinds.append(sample.feedback_kind())
			assert_false((sample.get_node("Feedback") as Label).text.is_empty())
	assert_eq(
		kinds,
		[
			AttemptResult.Kind.LEVEL,
			AttemptResult.Kind.BONUS,
			AttemptResult.Kind.ALREADY_FOUND,
			AttemptResult.Kind.INVALID
		]
	)
