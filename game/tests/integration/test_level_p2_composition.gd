extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const EVENTS: Script = preload("res://services/events.gd")
const SHOP: PackedScene = preload("res://features/level/level.tscn")
const FIXTURE: Script = preload("res://tests/integration/test_level_hud.gd")


class RaisedConfig:
	extends "res://services/config.gd"

	func get_int(key: StringName) -> int:
		return 50 if key == &"unlocks.shuffle_slot" else super.get_int(key)


var save: SAVE
var economy: ECONOMY
var config: CONFIG
var content: CONTENT
var bus: EVENTS
var storage: SaveStorage
var _locale: String
var _motion: bool
var _pseudo: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_motion = Tokens.reduced_motion
	_pseudo = TranslationServer.pseudolocalization_enabled
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	Tokens.reduced_motion = true
	save = SAVE.new()
	economy = ECONOMY.new()
	config = CONFIG.new()
	content = CONTENT.new()
	bus = EVENTS.new()
	for node: Node in [save, economy, config, content, bus]:
		add_child_autofree(node)
	save.initialize(Clock.new())
	economy.initialize(Clock.new())
	storage = FIXTURE.MemoryStorage.new()
	save.configure(storage)
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	assert_eq(content.load_manifest("pl"), OK)
	economy.configure(save, config, bus)


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _advance(slot: int) -> void:
	var data: Dictionary = save.get_section(&"progress")
	data.by_lang.pl.current_slot = slot
	assert_eq(save.set_section(&"progress", data), OK)
	assert_eq(save.flush(), OK)


func _view(dimensions: Vector2i = Vector2i(1080, 1920)) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = dimensions
	add_child_autofree(view)
	return view


func _screen(view: SubViewport, slot: int, p2: bool = true) -> LevelScreen:
	var screen: LevelScreen = SHOP.instantiate()
	screen.configure(save, content, slot, bus)
	if p2:
		assert_eq(screen.configure_p2(economy, config), OK)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	screen.configure_rng(rng)
	view.add_child(screen)
	return screen


func test_opt_in_validation_and_p1_default_keeps_free_hint() -> void:
	var screen: LevelScreen = SHOP.instantiate()
	assert_eq(screen.configure_p2(economy, config), ERR_UNCONFIGURED)
	screen.free()
	var view: SubViewport = _view()
	var p1: LevelScreen = _screen(view, 1, false)
	assert_null(p1.p2_hud)
	assert_eq(p1.hint_button.text_key, "level.hud.free_hint")
	assert_eq(p1.configure_p2(economy, config), ERR_BUSY)
	p1.hint_button.pressed.emit()
	assert_eq(p1.controller.get_board().revealed_cells().size(), 1)


func test_first_level_only_number_board_preview_and_wheel_even_after_unlocks() -> void:
	_advance(12)
	var screen: LevelScreen = _screen(_view(), 1)
	assert_false(screen.p2_hud.meter.visible)
	assert_false(screen.hint_button.visible)
	assert_false(screen.shuffle_button.visible)
	assert_false(screen.p2_hud.reveal.visible)
	assert_false(screen.p2_hud.home.is_inside_tree())
	assert_false(screen.p2_hud.settings.is_inside_tree())
	assert_false(screen.p2_hud.coins.is_inside_tree())
	assert_true(screen.p2_hud.number.is_inside_tree())
	assert_true(screen.wheel.visible)
	assert_false(screen.debug_button.is_visible_in_tree())


func test_unlock_boundaries_use_committed_progress_and_canonical_config() -> void:
	for feature: String in ["shuffle", "hint", "reveal", "journey", "bonus_meter"]:
		var threshold: int = config.get_int(StringName("unlocks." + feature + "_slot"))
		for unlocked: bool in [false, true]:
			_advance(threshold if unlocked else threshold - 1)
			var screen: LevelScreen = _screen(_view(), threshold)
			var control: Control = {
				"shuffle": screen.shuffle_button,
				"hint": screen.hint_button,
				"reveal": screen.p2_hud.reveal,
				"journey": screen.p2_hud.home,
				"bonus_meter": screen.p2_hud.meter
			}[feature]
			assert_eq(control.is_visible_in_tree(), unlocked, feature)
			screen.free()


func test_powerup_navigation_and_shop_are_intents_without_debit_or_reveal() -> void:
	_advance(12)
	var screen: LevelScreen = _screen(_view(), 12)
	watch_signals(screen)
	var before: Dictionary = save.committed_view()
	screen.hint_button.pressed.emit()
	screen.p2_hud.reveal.pressed.emit()
	screen.p2_hud.home.pressed.emit()
	screen.p2_hud.settings.pressed.emit()
	screen.p2_hud.coins.pressed.emit()
	assert_signal_emit_count(screen, "powerup_requested", 2)
	assert_signal_emit_count(screen, "navigation_requested", 2)
	assert_signal_emit_count(screen, "shop_requested", 1)
	assert_eq(screen.controller.get_board().revealed_cells().size(), 0)
	assert_eq_deep(save.committed_view(), before)


func test_live_wallet_and_reentry_have_one_subscription_and_native_intent() -> void:
	_advance(12)
	var view: SubViewport = _view()
	var screen: LevelScreen = _screen(view, 12)
	assert_eq(economy.grant(&"test", {"coins": 123, "hint": 2, "reveal": 3}), OK)
	assert_eq(screen.p2_hud.coins.value, 123)
	assert_eq(screen.hint_button.count, 2)
	assert_eq(screen.p2_hud.reveal.count, 3)
	view.remove_child(screen)
	view.add_child(screen)
	await get_tree().process_frame
	watch_signals(screen)
	screen.hint_button.grab_focus()
	for down: bool in [true, false]:
		var action: InputEventAction = InputEventAction.new()
		action.action = &"ui_accept"
		action.pressed = down
		view.push_input(action)
	assert_signal_emit_count(screen, "powerup_requested", 1)
	assert_eq(economy.grant(&"test", {"coins": 1}), OK)
	assert_eq(screen.p2_hud.coins.value, 124)
	assert_eq(screen.controller.get_board().revealed_cells().size(), 0)


func test_native_layout_matrix_keeps_each_corner_clear_of_all_tile_hit_circles() -> void:
	_advance(12)
	for option: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + option, GalleryShell.OPTIONS[option])
	TranslationServer.reload_pseudolocalization()
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				var view: SubViewport = _view(dimensions)
				var screen: LevelScreen = SHOP.instantiate()
				screen.configure(save, content, 12, bus)
				assert_eq(screen.configure_p2(economy, config), OK)
				screen.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				view.add_child(screen)
				for frame: int in range(4):
					await get_tree().process_frame
				assert_lte(
					screen.board_view.get_global_rect().end.y,
					screen.p2_hud.meter.get_global_rect().position.y
				)
				assert_lte(
					screen.p2_hud.meter.get_global_rect().end.y,
					screen.preview.get_global_rect().position.y
				)
				for leading: Control in screen.p2_hud.bar.leading:
					for trailing: Control in screen.p2_hud.bar.trailing:
						assert_false(
							leading.get_global_rect().intersects(trailing.get_global_rect()),
							"header slot overlap"
						)
				for button: Control in [
					screen.shuffle_button, screen.hint_button, screen.p2_hud.reveal
				]:
					assert_gte(button.size.x, float(Tokens.Touch.MIN_TARGET))
					assert_gte(button.size.y, float(Tokens.Touch.MIN_TARGET))
					var rect: Rect2 = button.get_global_rect()
					assert_true(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(rect))
					var radius: float = (
						screen.wheel.size.x
						* Tokens.Layout.TILE_RADIUS_RATIO
						* Tokens.Touch.TILE_HIT_RATIO
					)
					for tile: int in screen.wheel.tile_order():
						var center: Vector2 = (
							screen.wheel.get_global_transform() * screen.wheel.tile_position(tile)
						)
						var closest: Vector2 = center.clamp(rect.position, rect.end)
						assert_gte(center.distance_to(closest), radius, "button/tile overlap")
				screen.free()


func test_missing_config_and_changed_owner_binding_fail_closed_before_mount() -> void:
	var screen: LevelScreen = SHOP.instantiate()
	screen.configure(save, content, 12, bus)
	var unloaded: CONFIG = CONFIG.new()
	assert_eq(screen.configure_p2(economy, unloaded), ERR_UNCONFIGURED)
	unloaded.free()
	assert_eq(screen.configure_p2(economy, config), OK)
	var other: SAVE = SAVE.new()
	add_child_autofree(other)
	other.initialize(Clock.new())
	other.configure(FIXTURE.MemoryStorage.new())
	assert_eq(other.load(), OK)
	screen.configure(other, content, 12, bus)
	_view().add_child(screen)
	assert_false(screen.p2_hud.bar.visible)
	assert_false(screen.hint_button.visible)
	watch_signals(screen)
	screen.hint_button.pressed.emit()
	assert_signal_emit_count(screen, "powerup_requested", 0)


func test_recorded_unlock_survives_a_raised_config_threshold() -> void:
	_advance(2)
	var section: Dictionary = save.get_section(&"progress")
	section.by_lang.pl.unlocked = ["shuffle"]
	assert_eq(save.set_section(&"progress", section), OK)
	assert_eq(save.flush(), OK)
	var raised: RaisedConfig = RaisedConfig.new()
	add_child_autofree(raised)
	assert_eq(raised.load(), OK)
	assert_gt(raised.get_int(&"unlocks.shuffle_slot"), 2)
	var screen: LevelScreen = SHOP.instantiate()
	screen.configure(save, content, 2, bus)
	assert_eq(screen.configure_p2(economy, raised), OK)
	_view().add_child(screen)
	assert_true(screen.shuffle_button.is_visible_in_tree())
	assert_false(screen.hint_button.is_visible_in_tree())
