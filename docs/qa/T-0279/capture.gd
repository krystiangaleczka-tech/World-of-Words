extends SceneTree
## Native production controls/owners with explicitly labelled fixture content and Fake prices.

const PATH: String = "user://t0279-native.json"
const ROOT: String = "res://../docs/qa/T-0279"
var _serial: int = 0


class OfferClock:
	extends Clock
	var now: int = 0

	func monotonic_msec() -> int:
		return now


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	Tokens.reduced_motion = true
	for key: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + key, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	for layout: String in ["COMPACT", "REGULAR", "TABLET"]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				await _case(layout, pseudo, hc)
	print("T-0279 native screenshots: ", _serial)
	quit()


func _case(layout: String, pseudo: bool, hc: bool) -> void:
	var fixture: Script = load("res://tests/integration/test_paid_tool_transactions.gd")
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var owner: Node = Node.new()
	root.add_child(owner)
	var save: Node = load("res://services/save.gd").new()
	var progress: Node = load("res://services/progress.gd").new()
	var economy: Node = load("res://services/economy.gd").new()
	var content: Node = load("res://services/content.gd").new()
	var config: Node = fixture.ToolConfig.new()
	var bus: Node = load("res://services/events.gd").new()
	var service: Node = load("res://services/monetization.gd").new()
	for node: Node in [save, progress, economy, content, config, bus, service]:
		owner.add_child(node)
	var clock: Clock = fixture.FixedClock.new()
	save.initialize(clock)
	progress.initialize(clock)
	economy.initialize(clock)
	service.initialize(clock)
	var disk: SaveStorage = fixture.InterruptedStorage.new(PATH)
	save.configure(disk, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert(config.load() == OK)
	assert(content.load_manifest("pl", fixture.ROOT) == OK)
	progress.configure(save, content)
	assert(progress.configure_atomic(config) == OK)
	economy.configure(save, config, bus)
	var port: RefCounted = load("res://services/progress/atomic_progress_port.gd").new()
	assert(port.configure(save, progress, economy) == OK)
	assert(save.load() == OK)
	assert(progress.configure_p2(config, port, bus) == OK)
	var first: BoardState = BoardState.new(content.level_for_slot(1))
	assert(progress.bind_board(first) == OK)
	for index: int in first.get_level().word_count():
		for cell: Vector2i in first.get_level().word_cells(index):
			first.reveal_cell(cell)
	assert(progress.complete_level(1) == OK)
	var section: Dictionary = save.get_section(&"economy")
	section.coins = 500
	section.items = {"hint": 0, "reveal": 0}
	assert(save.set_section(&"economy", section) == OK)
	assert(save.flush() == OK)
	var consent: ConsentFake = ConsentFake.new()
	consent.set_outcome(&"request_info", &"not_required")
	var ads: AdsFake = AdsFake.new()
	ads.set_outcome(&"initialize", &"ready")
	ads.set_outcome(&"load_rewarded", &"ready")
	ads.set_outcome(&"show_rewarded", &"reward", false)
	assert(service.configure(save, config, bus, consent, ads, false) == OK)
	var store: IapFake = IapFake.new()
	store.set_products([
		{"id": "nc.remove_forced_ads.v1", "restorable": true, "price": "12,99 zł"},
		{"id": "c.coins_s.v1", "restorable": false, "price": "4,99 zł"}
	])
	store.set_outcome(&"query_products", &"ready")
	assert(service.configure_iap(economy, store) == OK)
	assert(service.start_session() == OK)
	var view: SubViewport = SubViewport.new()
	view.size = {"COMPACT": Vector2i(1080, 1920), "REGULAR": Vector2i(1080, 2340), "TABLET": Vector2i(1440, 1920)}[layout]
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	owner.add_child(view)
	var screen: Control = load("res://features/level/level.tscn").instantiate()
	screen.theme = load("res://ui/theme/generated/theme_hc_130.tres" if hc else "res://ui/theme/generated/theme_default_100.tres")
	screen.configure(save, content, 2, bus)
	assert(screen.configure_p2(economy, config) == OK)
	assert(screen.configure_paid_tools(progress, port, service) == OK)
	var offer_clock: Clock = OfferClock.new()
	assert(screen.configure_offer_clock(offer_clock) == OK)
	view.add_child(screen)
	await _settle()
	var prefix: String = "%s_%s_%s" % [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
	offer_clock.now = 45000
	screen.stuck_offer.refresh()
	await _shot(view, prefix, "stuck_offer")
	assert(screen.stuck_offer.caption.visible)
	assert(screen.hint_button.highlighted)
	assert(not screen.paid_tools_ui.modal_open())

	owner.free()


func _settle() -> void:
	for frame: int in range(6):
		await process_frame


func _shot(view: SubViewport, prefix: String, state: String) -> void:
	await _settle()
	RenderingServer.force_draw(false)
	assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path(ROOT.path_join("tools_%s_%s.png" % [prefix, state]))) == OK)
	_serial += 1
