extends GutTest

const POSTCARD: Script = preload("res://features/journey/postcard.gd")
const JOURNEY: Script = preload("res://features/journey/journey.gd")
const NAV: Script = preload("res://services/nav.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const CATALOG: Script = preload("res://tests/fixtures/journey/catalog.gd")
const PATH: String = "user://t0246-postcard.json"
const FIXTURE: String = "res://tests/fixtures/content"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class PostcardConfig:
	extends "res://services/config.gd"
	var capacity: int = 4

	func get_int(key: StringName) -> int:
		if key == &"unlocks.journey_slot":
			return 2
		return capacity if key == &"meta.postcard.pieces" else super.get_int(key)


class LookupContent:
	extends "res://tests/fixtures/journey/catalog.gd"
	var during_lookup: Callable

	func location_for_slot(slot: int) -> Dictionary:
		if during_lookup.is_valid():
			during_lookup.call()
		return super.location_for_slot(slot)


class FailureStorage:
	extends SaveStorage
	var fail: bool = false

	func checkpoint(_step: StringName) -> Error:
		return ERR_BUSY if fail else OK


var _save: SAVE
var _content: CONTENT
var _config: CONFIG
var _nav: NAV
var _host: Control
var _storage: FailureStorage
var _old_locale: String
var _old_motion: bool
var _old_low: bool
var _old_pseudo: bool
var _pseudo_settings: Dictionary = {}
var _fact_copy: Translation


func before_each() -> void:
	_clean()
	_old_locale = TranslationServer.get_locale()
	_old_motion = Tokens.reduced_motion
	_old_low = OS.low_processor_usage_mode
	_old_pseudo = TranslationServer.pseudolocalization_enabled
	for key: String in GalleryShell.OPTIONS:
		var path: String = GalleryShell.PSEUDO + key
		_pseudo_settings[path] = (
			ProjectSettings.get_setting(path) if ProjectSettings.has_setting(path) else null
		)
		ProjectSettings.set_setting(path, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	TranslationServer.set_locale("pl")
	Tokens.reduced_motion = true
	_save = SAVE.new()
	_content = LookupContent.new()
	_config = PostcardConfig.new()
	_host = Control.new()
	_host.size = Vector2(1080, 1920)
	for node: Node in [_save, _content, _config, _host]:
		add_child_autofree(node)
	for service: ServiceStub in [_save, _content, _config]:
		service.initialize(FixedClock.new())
	_storage = FailureStorage.new(PATH)
	_save.configure(_storage, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(_save.load(), OK)
	assert_eq(_content.load_manifest("pl", FIXTURE), OK)
	assert_eq(_config.load(), OK)
	_write(2, {"harbor": 4, "market": 2, "hill": 0})
	_restart()
	assert_eq(_nav.go_to_screen(NAV.Screen.JOURNEY), OK)


func after_each() -> void:
	if is_instance_valid(_nav):
		_nav.free()
	await get_tree().process_frame
	if _fact_copy != null:
		TranslationServer.remove_translation(_fact_copy)
		_fact_copy = null
	for path: String in _pseudo_settings:
		ProjectSettings.set_setting(path, _pseudo_settings[path])
	_pseudo_settings.clear()
	TranslationServer.reload_pseudolocalization()
	TranslationServer.pseudolocalization_enabled = _old_pseudo
	TranslationServer.set_locale(_old_locale)
	Tokens.reduced_motion = _old_motion
	OS.low_processor_usage_mode = _old_low
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func _restart(animated: bool = false) -> void:
	if is_instance_valid(_nav):
		_nav.free()
	_nav = NAV.new()
	add_child_autofree(_nav)
	_nav.initialize(FixedClock.new())
	_nav.configure(_save, _config, _content)
	_nav.configure_screens(_factory)
	assert_eq(_nav.configure_p2(func() -> Error: return OK, animated), OK)
	assert_eq(_nav.start(_host, FIXTURE), OK)


func _factory(screen: int) -> Node:
	if screen == NAV.Screen.POSTCARD:
		var postcard: ScreenScaffold = POSTCARD.new()
		postcard.configure_art(func(_location: Dictionary) -> Texture2D: return _art())
		return postcard
	var path: String = NAV.SCENES.get(screen, "")
	return (load(path) as PackedScene).instantiate() if not path.is_empty() else null


func _art() -> Texture2D:
	var image: GradientTexture2D = GradientTexture2D.new()
	image.width = 600
	image.height = 400
	image.gradient = Gradient.new()
	return image


func _write(slot: int, pieces: Dictionary) -> void:
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.current_slot = slot
	progress.by_lang.pl.highest_completed_slot = slot - 1
	progress.by_lang.pl.completed_slot = slot - 1
	progress.by_lang.pl.level_state = null
	progress.by_lang.pl.stars = 7
	progress.by_lang.pl.location_pieces = pieces.duplicate(true)
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)


func _node(node_name: String) -> Node:
	return _nav.mounted_screen().find_child(node_name, true, false)


func _footer(card: Card) -> PrimaryButton:
	for node: Node in card.find_children("*", "Button", true, false):
		if node is PrimaryButton and node.visible:
			return node as PrimaryButton
	return null


func _complete_board(screen: LevelScreen) -> void:
	for attempt: int in 100:
		if screen.controller.is_complete():
			break
		assert_true(screen.controller.hint())
	assert_true(screen.controller.is_complete())


func test_native_journey_footer_selects_location_and_back_preserves_journey() -> void:
	_fact_copy = Translation.new()
	_fact_copy.locale = "pl"
	_fact_copy.add_message("location.harbor.fact", "To przystań z podróży pokazowej.")
	TranslationServer.add_translation(_fact_copy)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	var journey: ScreenScaffold = JOURNEY.new()
	journey.configure(_save, _content, _config, _nav)
	viewport.add_child(journey)
	for frame: int in 5:
		await get_tree().process_frame
	var card: Card = journey.find_child("Location_harbor", true, false)
	var footer: PrimaryButton = _footer(card)
	assert_not_null(footer)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = footer.get_global_rect().get_center()
	click.pressed = true
	viewport.push_input(click, true)
	click.pressed = false
	viewport.push_input(click, true)
	assert_eq(_nav.current_screen(), NAV.Screen.POSTCARD)
	assert_eq(_nav.level_slot(), 1)
	assert_eq(_node("Location").text, "Przystań")
	assert_eq(_node("Fact").text, "To przystań z podróży pokazowej.")
	assert_eq(_nav.handle_back(), OK)
	assert_eq(_nav.current_screen(), NAV.Screen.JOURNEY)


func test_history_keeps_selection_without_replaying_and_same_destination_is_inert() -> void:
	assert_eq(_nav.go_to_postcard(1), OK)
	var original: Node = _nav.mounted_screen()
	assert_eq(_nav.go_to_postcard(1, true), OK)
	assert_eq(_nav.mounted_screen(), original)
	assert_eq(_nav.go_to_postcard(2), OK)
	assert_eq(_nav.level_slot(), 2)
	assert_eq(_nav.handle_back(), OK)
	assert_eq(_nav.level_slot(), 1)
	assert_false(_node("RevealFeedback").visible)
	assert_eq(_nav.handle_back(), OK)
	assert_eq(_nav.current_screen(), NAV.Screen.JOURNEY)


func test_invalid_locked_and_failed_leave_preserve_screen_and_route_context() -> void:
	var original: Node = _nav.mounted_screen()
	assert_eq(_nav.go_to_postcard(0), ERR_INVALID_PARAMETER)
	assert_eq(_nav.go_to_postcard(3), ERR_INVALID_PARAMETER)
	assert_eq(_nav.mounted_screen(), original)
	_storage.fail = true
	assert_eq(_save.set_setting(&"sfx_volume", 0.5), ERR_BUSY)
	assert_eq(_nav.go_to_postcard(1), ERR_BUSY)
	assert_eq(_nav.mounted_screen(), original)
	assert_eq(_nav.level_slot(), 2)
	_storage.fail = false
	assert_eq(_nav.go_to_postcard(1), OK)


func test_postcard_validation_rejects_reentrant_location_callbacks() -> void:
	var attempts: Array[int] = []
	_content.during_lookup = func() -> void: attempts.append(_nav.go_to_postcard(2))
	assert_eq(_nav.go_to_postcard(1), OK)
	assert_gt(attempts.size(), 0)
	for error: int in attempts:
		assert_eq(error, ERR_BUSY)
	assert_eq(_nav.current_screen(), NAV.Screen.POSTCARD)
	assert_eq(_nav.level_slot(), 1)
	_content.during_lookup = Callable()
	assert_eq(_nav.go_to_level(2), OK)
	_complete_board(_nav.mounted_screen() as LevelScreen)
	attempts.clear()
	_content.during_lookup = func() -> void: attempts.append(_nav.go_to_postcard(1))
	assert_eq(_nav.continue_campaign(2, 2), OK)
	assert_gt(attempts.size(), 0)
	for error: int in attempts:
		assert_eq(error, ERR_BUSY)
	assert_eq(_nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_nav.level_slot(), 3)
	_content.during_lookup = Callable()


func test_continue_restores_partial_board_at_current_saved_slot_not_selected_location() -> void:
	var board: BoardState = BoardState.new(_content.level_for_slot(2))
	var cell: Vector2i = board.get_level().word_cells(0)[0]
	board.reveal_cell(cell)
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.level_state = board.to_dict()
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)
	assert_eq(_nav.go_to_postcard(1), OK)
	_node("Continue").pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_nav.level_slot(), 2)
	var level: LevelScreen = _nav.mounted_screen()
	assert_true(level.controller.get_board().revealed_cells().has(cell))
	assert_eq(_nav.go_to_postcard(1), OK)
	_write(3, {"harbor": 4, "market": 2, "hill": 0})
	_node("Continue").pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_nav.level_slot(), 3, "Continue re-reads progress changed while postcard was open")


func test_terminal_never_replays_and_view_reads_only_committed_values_without_writes() -> void:
	_write(4, {"harbor": 4, "market": 2, "hill": 0})
	assert_eq(_nav.go_to_postcard(2), OK)
	assert_true(_node("Continue").disabled)
	assert_eq(_node("Status").text, "Wszystkie dostępne poziomy ukończone.")
	var primary: String = FileAccess.get_file_as_string(PATH)
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.stars = 99
	progress.by_lang.pl.location_pieces.market = 3
	assert_eq(_save.set_section(&"progress", progress), OK)
	_nav.mounted_screen().refresh()
	assert_eq(_node("Stars").value, 7)
	assert_eq(_node("Postcard").pieces_revealed, 2)
	_node("Continue").pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.POSTCARD)
	assert_eq(FileAccess.get_file_as_string(PATH), primary)


func test_missing_art_fact_and_invalid_services_have_translated_fallbacks() -> void:
	var preview: ScreenScaffold = POSTCARD.new()
	preview.configure(_save, _content, _config, _nav, 2, true)
	_host.add_child(preview)
	await get_tree().process_frame
	assert_true(preview.find_child("MissingArt", true, false).visible)
	assert_false(preview.find_child("RevealFeedback", true, false).visible)
	assert_eq(preview.find_child("Credits", true, false).text, "Pocztówka: 2 / 4")
	TranslationServer.pseudolocalization_enabled = true
	await get_tree().process_frame
	assert_eq(
		preview.find_child("Fact", true, false).text, preview.tr("postcard.main.fact_pending")
	)
	for missing: int in 3:
		var unavailable: ScreenScaffold = POSTCARD.new()
		unavailable.configure(
			null if missing == 0 else _save,
			null if missing == 1 else _content,
			null if missing == 2 else _config,
			_nav,
			1
		)
		_host.add_child(unavailable)
		assert_true(unavailable.find_child("Continue", true, false).disabled)
	_config.capacity = LocationPostcard.MAX_PIECES + 1
	preview.refresh()
	assert_true(preview.find_child("Continue", true, false).disabled)
	_config.capacity = 4
	assert_eq(_save.set_setting(&"language", "en"), OK)
	assert_eq(_save.flush(), OK)
	preview.refresh()
	assert_true(preview.find_child("Continue", true, false).disabled)


func test_reduced_reveal_is_committed_one_shot_and_complete_stamp_settles() -> void:
	assert_eq(_nav.go_to_postcard(1, true), OK)
	var burst: RewardBurst = _node("RevealFeedback")
	watch_signals(burst)
	for frame: int in 2:
		await get_tree().process_frame
	assert_eq(_node("Postcard").pieces_revealed, 4)
	assert_eq(_node("Postcard").state, &"complete")
	assert_true(_node("Complete").visible)
	assert_eq(burst.state, &"static")
	assert_signal_emit_count(burst, "finished", 1)
	_nav.mounted_screen().refresh()
	assert_signal_emit_count(burst, "finished", 1)
	assert_eq(_nav.handle_back(), OK)
	assert_eq(_nav.go_to_postcard(1), OK)
	for frame: int in 2:
		await get_tree().process_frame
	assert_false(_node("RevealFeedback").visible)


func test_normal_reveal_waits_for_transition_rejects_reentry_and_finishes() -> void:
	Tokens.reduced_motion = false
	_restart(true)
	await _nav.transition_finished
	assert_eq(_nav.go_to_postcard(1, true), OK)
	assert_eq(_nav.go_to_postcard(2), ERR_BUSY)
	await _nav.screen_changed
	var burst: RewardBurst = _node("RevealFeedback")
	watch_signals(burst)
	assert_eq(_node("Postcard").pieces_revealed, 3)
	assert_false(_node("RevealFeedback").visible)
	await _nav.transition_finished
	for frame: int in 2:
		await get_tree().process_frame
	assert_eq(_node("Postcard").pieces_revealed, 4)
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(Tokens.dur(Tokens.Motion.SLOW) + Tokens.dur(Tokens.Motion.FAST))
	await get_tree().process_frame
	assert_eq(_node("Postcard").state, &"complete")
	assert_true(_node("Complete").visible)
	assert_signal_emit_count(burst, "finished", 1)


func test_exit_before_deferred_reveal_is_safe_and_reentry_does_not_replay() -> void:
	var preview: ScreenScaffold = POSTCARD.new()
	preview.configure_art(func(_location: Dictionary) -> Texture2D: return _art())
	preview.configure(_save, _content, _config, _nav, 1, true)
	_host.add_child(preview)
	_host.remove_child(preview)
	await get_tree().process_frame
	_host.add_child(preview)
	for frame: int in 2:
		await get_tree().process_frame
	assert_false(preview.find_child("RevealFeedback", true, false).visible)
	assert_eq(preview.find_child("Postcard", true, false).pieces_revealed, 4)


func test_real_level_continue_routes_new_durable_credit_and_back_cannot_replay() -> void:
	assert_eq(_nav.go_to_level(2), OK)
	var level: LevelScreen = _nav.mounted_screen()
	_write(2, {"harbor": 4, "market": 3, "hill": 0})
	_complete_board(level)
	assert_eq(_save.committed_view().sections.progress.by_lang.pl.current_slot, 3)
	level.continue_button.pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.POSTCARD)
	assert_eq(_nav.level_slot(), 2)
	var current: Node = _nav.mounted_screen()
	_storage.fail = true
	assert_eq(_save.set_setting(&"sfx_volume", 0.5), ERR_BUSY)
	assert_eq(_nav.handle_back(), ERR_BUSY)
	assert_eq(_nav.mounted_screen(), current)
	_storage.fail = false
	assert_eq(_nav.handle_back(), OK)
	assert_eq(_nav.current_screen(), NAV.Screen.HOME)


func test_real_level_without_new_credits_chains_and_terminal_credit_opens_postcard() -> void:
	assert_eq(_nav.go_to_level(2), OK)
	var level: LevelScreen = _nav.mounted_screen()
	_complete_board(level)
	level.continue_button.pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_nav.level_slot(), 3)
	level = _nav.mounted_screen()
	_write(3, {"harbor": 4, "market": 2, "hill": 1})
	_complete_board(level)
	assert_false(level.continue_button.disabled)
	level.continue_button.pressed.emit()
	assert_eq(_nav.current_screen(), NAV.Screen.POSTCARD)
	assert_eq(_nav.level_slot(), 3)
	assert_true(_node("Continue").disabled)


func test_three_safe_layouts_hc130_pseudo35_continue_and_pointer_scroll() -> void:
	TranslationServer.pseudolocalization_enabled = true
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = dimensions
		add_child_autofree(viewport)
		var preview: ScreenScaffold = POSTCARD.new()
		preview.configure_art(
			func(_location: Dictionary) -> Texture2D:
				var portrait: GradientTexture2D = _art() as GradientTexture2D
				portrait.height = 1200
				return portrait
		)
		preview.configure(_save, _content, _config, _nav, 2)
		preview.debug_insets = Rect2(Vector2(24, 48), Vector2(24, 48))
		preview.theme = load("res://ui/theme/generated/theme_hc_130.tres") as Theme
		viewport.add_child(preview)
		for frame: int in 6:
			await get_tree().process_frame
		var scroll: ScrollContainer = preview.find_child("Content", true, false)
		var column: VBoxContainer = preview.find_child("Column", true, false)
		var button: PrimaryButton = preview.find_child("Continue", true, false)
		assert_lte(column.size.x, scroll.size.x)
		assert_true(preview.body.get_global_rect().encloses(scroll.get_global_rect()))
		var origin: Vector2 = scroll.get_global_rect().position + Vector2.ONE * Tokens.Space.L
		var touch: InputEventMouseButton = InputEventMouseButton.new()
		touch.button_index = MOUSE_BUTTON_LEFT
		touch.button_mask = MOUSE_BUTTON_MASK_LEFT
		touch.position = origin
		touch.pressed = true
		viewport.push_input(touch, true)
		for step: int in [1, 2]:
			var drag: InputEventMouseMotion = InputEventMouseMotion.new()
			drag.button_mask = MOUSE_BUTTON_MASK_LEFT
			drag.position = origin + Vector2.UP * Tokens.Touch.MIN_TARGET * step
			drag.relative = Vector2.UP * Tokens.Touch.MIN_TARGET
			viewport.push_input(drag, true)
		assert_gt(scroll.scroll_vertical, 0)
		touch.pressed = false
		touch.button_mask = 0
		viewport.push_input(touch, true)
		scroll.ensure_control_visible(button)
		for frame: int in 2:
			await get_tree().process_frame
		assert_true(scroll.get_global_rect().encloses(button.get_global_rect()))
