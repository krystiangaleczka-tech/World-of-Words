# gdlint: disable=max-public-methods
extends GutTest

const HOME: PackedScene = preload("res://features/home/home.tscn")
const SAVE: Script = preload("res://services/save.gd")
const NAV: Script = preload("res://services/nav.gd")


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-14T00:00:00Z", "0.1.0"
	)

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		document = JSON.parse_string(text)
		return OK


class FixtureConfig:
	extends "res://services/config.gd"
	var threshold: int = 10

	func get_int(key: StringName) -> int:
		return threshold if key == &"unlocks.journey_slot" else super.get_int(key)


class FixtureContent:
	extends "res://services/content.gd"
	var legacy: bool = false
	var unavailable: bool = false
	var language_override: String = ""

	func get_language() -> String:
		return super.get_language() if language_override.is_empty() else language_override

	func location_for_slot(slot: int) -> Dictionary:
		if legacy:
			return super.location_for_slot(slot)
		return {
			"id": "fixture",
			"name_key": "journey.location.fixture",
			"postcard": "postcards/fixture.webp"
		}

	func level_for_slot(slot: int) -> LevelData:
		return null if unavailable else super.level_for_slot(slot)


class NavigationIntent:
	extends Node
	var result: Error = OK
	var requests: Array[int] = []

	func go_to_level(slot: int) -> Error:
		requests.append(slot)
		return result

	func go_to_screen(screen: int) -> Error:
		requests.append(screen)
		return result


var _save: SAVE
var _config: FixtureConfig
var _content: FixtureContent
var _nav: NavigationIntent
var _storage: MemoryStorage
var _locale: String
var _pseudo: bool
var _low_mode: bool
var _translations: Array[Translation] = []


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_low_mode = OS.low_processor_usage_mode
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.set_locale("pl")
	_save = SAVE.new()
	_config = FixtureConfig.new()
	_content = FixtureContent.new()
	_nav = NavigationIntent.new()
	_storage = MemoryStorage.new()
	_storage.document.economy.coins = 240
	_storage.document.progress.by_lang.pl.current_slot = 2
	_storage.document.progress.by_lang.pl.highest_completed_slot = 1
	_storage.document.progress.by_lang.pl.completed_slot = 1
	_storage.document.progress.by_lang.pl.location_pieces = {"fixture": 2}
	for service: ServiceStub in [_save, _config, _content]:
		add_child_autofree(service)
		service.initialize(FixedClock.new())
	add_child_autofree(_nav)
	_save.configure(_storage)
	assert_eq(_save.load(), OK)
	assert_eq(_config.load(), OK)
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/content"), OK)
	for language: String in ["pl", "en"]:
		var translation: Translation = Translation.new()
		translation.set_locale(language)
		translation.add_message(
			&"journey.location.fixture", "Miejsce testowe" if language == "pl" else "Test location"
		)
		TranslationServer.add_translation(translation)
		_translations.append(translation)


func after_each() -> void:
	for translation: Translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	TranslationServer.pseudolocalization_enabled = _pseudo
	TranslationServer.set_locale(_locale)
	OS.low_processor_usage_mode = _low_mode


func _image() -> Texture2D:
	var image: Image = Image.create(80, 50, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _home(with_art: bool = true) -> HomeScreen:
	var screen: HomeScreen = HOME.instantiate() as HomeScreen
	var host: Control = Control.new()
	host.size = Vector2(1080, 1920)
	add_child_autofree(host)
	screen.configure(
		_save,
		_content,
		_config,
		_nav,
		func(_path: String) -> Texture2D: return _image() if with_art else null
	)
	host.add_child(screen)
	return screen


func _item(screen: HomeScreen, name: String) -> Control:
	return screen.body.get_node("Content/" + name) as Control


func _advance(slot: int) -> void:
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.current_slot = slot
	progress.by_lang.pl.highest_completed_slot = slot - 1
	progress.by_lang.pl.completed_slot = slot - 1
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)


func test_committed_values_and_postcard_render_without_save_mutation() -> void:
	var before: Dictionary = _save.committed_view()
	var screen: HomeScreen = _home()
	assert_eq((screen.top_bar.leading[0] as CurrencyPill).value, 240)
	assert_eq((_item(screen, "LocationTitle") as Label).text, "Miejsce testowe")
	var postcard: LocationPostcard = _item(screen, "Postcard") as LocationPostcard
	assert_eq(postcard.pieces_revealed, 2)
	assert_eq(postcard.pieces_total, 4)
	assert_eq(postcard.state, &"in_progress")
	assert_false(_item(screen, "State").visible)
	assert_eq(_save.committed_view(), before)
	assert_eq(_storage.document.economy.coins, 240)
	var primary_count: int = 0
	for child: Node in screen.find_children("*", "", true, false):
		if child is PrimaryButton and child.is_visible_in_tree():
			primary_count += 1
	assert_eq(primary_count, 1)


func test_dirty_staging_remains_invisible_until_flush() -> void:
	var screen: HomeScreen = _home()
	var economy: Dictionary = _save.get_section(&"economy")
	economy.coins = 999
	assert_eq(_save.set_section(&"economy", economy), OK)
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.location_pieces.fixture = 4
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(screen.refresh(), OK)
	assert_eq((screen.top_bar.leading[0] as CurrencyPill).value, 240)
	assert_eq((_item(screen, "Postcard") as LocationPostcard).pieces_revealed, 2)
	assert_eq(_save.flush(), OK)
	assert_eq(screen.refresh(), OK)
	assert_eq((screen.top_bar.leading[0] as CurrencyPill).value, 999)
	assert_eq((_item(screen, "Postcard") as LocationPostcard).state, &"complete")


func test_topbar_balance_remains_visible_after_slot_translation_binding_and_locale_change() -> void:
	var screen: HomeScreen = _home()
	await get_tree().process_frame
	await get_tree().process_frame
	var coins: CurrencyPill = screen.top_bar.leading[0] as CurrencyPill
	assert_eq(coins.text, "240")
	assert_same(coins.icon, CurrencyPill.GLYPHS[&"coins"])
	var text_width: float = (
		coins
		. get_theme_font("font")
		. get_string_size(
			coins.text, HORIZONTAL_ALIGNMENT_LEFT, -1, coins.get_theme_font_size("font_size")
		)
		. x
	)
	var required_width: float = (
		coins.get_theme_stylebox("normal").get_minimum_size().x
		+ text_width
		+ minf(coins.icon.get_width(), coins.get_theme_constant("icon_max_width"))
		+ coins.get_theme_constant("h_separation")
	)
	assert_true(coins.size.x >= required_width, "number and glyph both fit the native button")
	assert_true(screen.top_bar.get_global_rect().encloses(coins.get_global_rect()))
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(coins.text, "240")
	assert_same(coins.icon, CurrencyPill.GLYPHS[&"coins"])


func test_play_rereads_new_committed_slot_and_suppresses_duplicate_intent() -> void:
	var screen: HomeScreen = _home()
	_advance(3)
	var play: PrimaryButton = _item(screen, "Play") as PrimaryButton
	play.pressed.emit()
	play.pressed.emit()
	assert_eq(_nav.requests, [3])
	assert_true(play.disabled)


func test_busy_route_retains_home_and_allows_retry() -> void:
	var screen: HomeScreen = _home()
	_nav.result = ERR_BUSY
	var play: PrimaryButton = _item(screen, "Play") as PrimaryButton
	play.pressed.emit()
	assert_false(play.disabled)
	assert_true(_item(screen, "State").visible)
	_nav.result = OK
	play.pressed.emit()
	assert_eq(_nav.requests, [2, 2])


func test_terminal_or_unavailable_content_disables_play_without_replay() -> void:
	_advance(4)
	var screen: HomeScreen = _home()
	var play: PrimaryButton = _item(screen, "Play") as PrimaryButton
	assert_true(play.disabled)
	assert_true(_item(screen, "State").visible)
	play.pressed.emit()
	assert_eq(_nav.requests, [])
	_advance(2)
	_content.unavailable = true
	assert_eq(screen.refresh(), ERR_FILE_NOT_FOUND)
	assert_true(play.disabled)
	assert_eq(_nav.requests, [])


func test_missing_art_and_legacy_content_keep_play_without_fake_art() -> void:
	var screen: HomeScreen = _home(false)
	assert_null(screen.background)
	assert_false(_item(screen, "Postcard").visible)
	assert_true(_item(screen, "State").visible)
	assert_eq((_item(screen, "Pieces") as Label).text, "Fragmenty: 2 / 4")
	assert_eq((_item(screen, "LocationTitle") as Label).text, "Miejsce testowe")
	assert_false((_item(screen, "Play") as PrimaryButton).disabled)
	_content.legacy = true
	assert_eq(screen.refresh(), OK)
	assert_eq((_item(screen, "LocationTitle") as Label).text, "Twoja podróż")
	assert_eq((_item(screen, "Pieces") as Label).text, "Fragmenty: 0 / 4")


func test_unbuilt_navigation_is_hidden_and_wallet_is_passive() -> void:
	var screen: HomeScreen = _home()
	assert_false(screen.bottom.visible)
	assert_false((screen.bottom as NavTab).implemented)
	assert_false((screen.top_bar.leading[0] as CurrencyPill).action_enabled)
	assert_true((screen.top_bar.trailing[0] as IconButton).disabled)
	assert_eq(screen.find_children("Daily", "", true, false).size(), 0)
	assert_eq(screen.find_children("Collection", "", true, false).size(), 0)


func test_existing_navigation_controls_emit_only_nav_intent_when_available() -> void:
	var screen: HomeScreen = _home()
	var settings: IconButton = screen.top_bar.trailing[0] as IconButton
	settings.disabled = false
	settings.pressed.emit()
	assert_eq(_nav.requests, [NAV.Screen.SETTINGS])
	screen = _home()
	var journey: NavTab = screen.bottom as NavTab
	journey.implemented = true
	journey.pressed.emit()
	journey.pressed.emit()
	assert_eq(_nav.requests, [NAV.Screen.SETTINGS, NAV.Screen.JOURNEY])


func test_saved_completed_postcard_remains_complete_without_rewriting_earned_pieces() -> void:
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.postcards = ["fixture"]
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)
	var before: Dictionary = _save.committed_view()
	var screen: HomeScreen = _home()
	assert_eq((_item(screen, "Postcard") as LocationPostcard).state, &"complete")
	assert_eq(_save.committed_view(), before)
	assert_eq(before.sections.progress.by_lang.pl.location_pieces.fixture, 2)


func test_localized_slot_keys_are_independent_and_released_on_exit() -> void:
	var first: HomeScreen = _home()
	var first_play: PrimaryButton = _item(first, "Play") as PrimaryButton
	var first_key: StringName = StringName(first_play.sublabel_key)
	assert_eq(TranslationServer.translate(first_key), "Poziom: 2")
	_advance(3)
	var second: HomeScreen = _home()
	var second_key: StringName = StringName((_item(second, "Play") as PrimaryButton).sublabel_key)
	assert_eq(TranslationServer.translate(first_key), "Poziom: 2")
	assert_eq(TranslationServer.translate(second_key), "Poziom: 3")
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate(second_key), "Level: 3")
	assert_eq((_item(second, "LocationTitle") as Label).text, "Test location")
	TranslationServer.pseudolocalization_enabled = true
	assert_true(String(TranslationServer.translate(second_key)).contains("3"))
	TranslationServer.pseudolocalization_enabled = false
	first.free()
	assert_eq(TranslationServer.translate(first_key), first_key)
	assert_eq(TranslationServer.translate(second_key), "Level: 3")


func test_data_owner_unavailable_and_language_mismatch_fail_safely() -> void:
	var screen: HomeScreen = HOME.instantiate() as HomeScreen
	add_child_autofree(screen)
	assert_true((_item(screen, "Play") as PrimaryButton).disabled)
	assert_eq(screen.refresh(), ERR_UNCONFIGURED)
	screen = _home()
	_content.language_override = "en"
	assert_eq(screen.refresh(), ERR_UNAVAILABLE)
	assert_true((_item(screen, "Play") as PrimaryButton).disabled)


func test_real_nav_injects_owners_mounts_home_delivers_toast_and_plays_level() -> void:
	var nav: NAV = NAV.new()
	var host: Control = Control.new()
	host.size = Vector2(1080, 1920)
	add_child_autofree(nav)
	add_child_autofree(host)
	nav.initialize(FixedClock.new())
	nav.configure(_save, _config, _content)
	assert_eq(nav.configure_p2(Callable(), false), OK)
	assert_eq(nav.start(host, "res://tests/fixtures/content"), OK)
	assert_eq(nav.go_debug(), OK)
	assert_eq(nav.go_to_screen(NAV.Screen.HOME), ERR_UNAVAILABLE)
	# A committed fixture threshold override keeps this integration within its 3-slot pack.
	_config.threshold = 2
	assert_eq(nav.go_home(), OK)
	var screen: HomeScreen = nav.mounted_screen() as HomeScreen
	assert_not_null(screen)
	assert_eq((screen.top_bar.leading[0] as CurrencyPill).value, 240)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(nav.enqueue_toast("nav.toast.backup_restored"), OK)
	await get_tree().process_frame
	await get_tree().process_frame
	var toast: Toast = screen.find_child("*", true, false) as Toast
	for child: Node in screen.find_children("*", "", true, false):
		if child is Toast:
			toast = child as Toast
	assert_not_null(toast)
	assert_true(
		screen.body.get_global_rect().encloses(toast.get_global_rect()),
		"body %s toast %s" % [screen.body.get_global_rect(), toast.get_global_rect()]
	)
	(_item(screen, "Play") as PrimaryButton).pressed.emit()
	assert_eq(nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(nav.level_slot(), 2)
	await get_tree().process_frame


func test_safe_layout_hc130_pseudo_all_classes_fits_without_label_truncation() -> void:
	assert_eq(_save.set_setting(&"high_contrast", true), OK)
	assert_eq(_save.set_setting(&"text_scale", 2), OK)
	TranslationServer.pseudolocalization_enabled = true
	var screen: HomeScreen = _home()
	screen.debug_insets = Rect2(Vector2(24, 48), Vector2(24, 48))
	var sizes: Array[Vector2] = [Vector2(1080, 1920), Vector2(1080, 2340), Vector2(1440, 1920)]
	for index: int in sizes.size():
		var dimensions: Vector2 = sizes[index]
		(screen.get_parent() as Control).size = dimensions
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(screen.layout_class, [&"COMPACT", &"REGULAR", &"TABLET"][index])
		var play: PrimaryButton = _item(screen, "Play") as PrimaryButton
		assert_true(screen.body.get_global_rect().encloses(play.get_global_rect()))
		assert_true(play.size.y >= play.get_minimum_size().y)
		assert_true(
			screen.body.get_global_rect().encloses(screen.top_bar.get_global_rect()),
			"body %s bar %s" % [screen.body.get_global_rect(), screen.top_bar.get_global_rect()]
		)
