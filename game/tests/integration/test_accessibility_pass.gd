extends GutTest

const FIXTURE: Script = preload("res://tests/integration/test_level_tutorial.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONTENT: Script = preload("res://services/content.gd")
const EVENTS: Script = preload("res://services/events.gd")
var save: SAVE
var content: CONTENT
var bus: EVENTS
var storage: FIXTURE.Storage
var locale: String
var motion: bool


func before_each() -> void:
	locale = TranslationServer.get_locale()
	motion = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
	Tokens.reduced_motion = true
	save = SAVE.new()
	content = CONTENT.new()
	bus = EVENTS.new()
	for node: Node in [save, content, bus]:
		add_child_autofree(node)
	storage = FIXTURE.Storage.new()
	save.initialize(Clock.new())
	save.configure(storage)
	assert_eq(save.load(), OK)
	assert_eq(content.load_manifest("pl"), OK)


func after_each() -> void:
	TranslationServer.set_locale(locale)
	Tokens.reduced_motion = motion


func _screen(slot: int = 1) -> LevelScreen:
	var host: LevelScreen = load("res://features/level/level.tscn").instantiate()
	host.configure(save, content, slot, bus)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 293
	host.configure_rng(rng)
	add_child_autofree(host)
	return host


func test_catalog_names_keys_touch_minimum_and_focus_in_both_locales() -> void:
	var catalog: LocaleCatalog = LocaleCatalog.new()
	assert_eq(catalog.register_all(), OK)
	for language: String in ["pl", "en"]:
		TranslationServer.set_locale(language)
		for width: int in [1080, 1200, 1440]:
			for mode: String in ["default_100", "hc_130"]:
				var icon: IconButton = IconButton.new()
				icon.configure_icon(preload("res://assets/icons/shuffle.svg"), "level.hud.shuffle")
				var nav: NavTab = NavTab.new()
				nav.configure(preload("res://assets/icons/route.svg"), "home.nav.journey")
				var toggle: Toggle = Toggle.new()
				toggle.configure(true, "ui.toggle.on")
				var slider: CatalogSlider = CatalogSlider.new()
				slider.configure(0.5, "settings.sound.music")
				var hint: HintButton = HintButton.new()
				hint.configure(&"hint", 3, 100)
				var currency: CurrencyPill = CurrencyPill.new()
				currency.action_enabled = true
				var controls: Array[Control] = [icon, nav, toggle, slider, hint, currency]
				var keys: Array[String] = [
					"level.hud.shuffle",
					"home.nav.journey",
					"ui.toggle.on",
					"settings.sound.music",
					"ui.hint.hint",
					"ui.currency.coins"
				]
				for index: int in controls.size():
					var control: Control = controls[index]
					var host: Control = Control.new()
					host.size = Vector2(width, 1920)
					host.theme = load("res://ui/theme/generated/theme_%s.tres" % mode)
					add_child(host)
					host.add_child(control)
					await wait_process_frames(2)
					assert_ne(tr(keys[index]), keys[index])
					assert_eq(control.accessibility_name, tr(keys[index]))
					assert_gte(
						control.get_combined_minimum_size().x, float(Tokens.Touch.MIN_TARGET)
					)
					assert_gte(
						control.get_combined_minimum_size().y, float(Tokens.Touch.MIN_TARGET)
					)
					assert_eq(control.focus_mode, Control.FOCUS_ALL)
					if control == currency:
						currency.action_enabled = false
						assert_eq(currency.focus_mode, Control.FOCUS_NONE)
						assert_true(currency.disabled)
						assert_eq(currency.accessibility_name, tr(keys[index]))
						currency.action_enabled = true
						assert_eq(currency.focus_mode, Control.FOCUS_ALL)
					host.free()
	catalog.unregister()


func test_summary_updates_on_committed_bonus_hint_word_and_language_without_read_writes() -> void:
	var host: LevelScreen = _screen()
	assert_eq(host.accessibility_name, "Poziom")
	assert_eq(host.accessibility_description, "Poziom: 1. Słowa: 0 / 1. Bonus: 0. Litery: K O T.")
	assert_not_null(host.controller.submit(PackedInt32Array([0, 2, 1])))
	assert_true(host.accessibility_description.contains("Bonus: 1"))
	assert_true(host.controller.hint())
	assert_true(host.accessibility_description.contains("Słowa: 0 / 1"))
	assert_not_null(host.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_true(host.accessibility_description.contains("Słowa: 1 / 1"))
	var writes: int = storage.writes
	TranslationServer.set_locale("en")
	await wait_process_frames(2)
	assert_eq(host.accessibility_name, "Level")
	assert_true(host.accessibility_description.contains("Words: 1 / 1"))
	assert_eq(storage.writes, writes)
	assert_eq(host.focus_mode, Control.FOCUS_NONE)


func test_summary_restores_bonus_and_handles_missing_content() -> void:
	var host: LevelScreen = _screen()
	host.controller.submit(PackedInt32Array([0, 2, 1]))
	host.free()
	host = _screen()
	assert_true(host.accessibility_description.contains("Bonus: 1"))
	var missing: LevelScreen = _screen(content.slot_count() + 1)
	assert_eq(missing.accessibility_description, missing.tr("level.state.missing_content"))
