extends SceneTree
## Native UI evidence. Fake prices, never live offers or store approval.

const PATH: String = "user://t0274-capture.json"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1800000000

	func monotonic_msec() -> int:
		return 1000000


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
				await _shot(layout, pseudo, hc)
	quit()


func _shot(layout: String, pseudo: bool, hc: bool) -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var viewport: SubViewport = SubViewport.new()
	viewport.size = {
		"COMPACT": Vector2i(1080, 1920),
		"REGULAR": Vector2i(1080, 2340),
		"TABLET": Vector2i(1440, 1920)
	}[layout]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var owners: Node = Node.new()
	viewport.add_child(owners)
	var save: Node = load("res://services/save.gd").new()
	var config: Node = load("res://services/config.gd").new()
	var economy: Node = load("res://services/economy.gd").new()
	var events: Node = load("res://services/events.gd").new()
	var service: Node = load("res://services/monetization.gd").new()
	for node: Node in [save, config, economy, events, service]:
		owners.add_child(node)
	var clock: FixedClock = FixedClock.new()
	save.initialize(clock)
	economy.initialize(clock)
	service.initialize(clock)
	save.configure(
		SaveStorage.new(PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert(save.load() == OK)
	assert(config.load() == OK)
	economy.configure(save, config, events)
	var store: IapFake = IapFake.new()
	store.set_products(
		[
			{"id": "nc.remove_forced_ads.v1", "restorable": true, "price": "12,99 zł"},
			{"id": "c.coins_s.v1", "restorable": false, "price": "4,99 zł"}
		]
	)
	store.set_outcome(&"query_products", &"ready")
	var ads: AdsFake = AdsFake.new()
	ads.set_outcome(&"initialize", &"ready")
	var consent: ConsentFake = ConsentFake.new()
	consent.set_outcome(&"request_info", &"not_required")
	assert(service.configure(save, config, events, consent, ads, false) == OK)
	assert(service.configure_iap(economy, store) == OK)
	assert(service.before_next_level(6) == OK)
	var screen: ScreenScaffold = ScreenScaffold.new()
	screen.theme = load(
		(
			"res://ui/theme/generated/theme_hc_130.tres"
			if hc
			else "res://ui/theme/generated/theme_default_100.tres"
		)
	)
	viewport.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shop: Control = load("res://features/shop/shop.tscn").instantiate()
	assert(shop.configure(service, true) == OK)
	screen.add_child(shop)
	assert(shop.open() == OK)
	for position: String in ["top", "bottom"]:
		var scroll: ScrollContainer = shop.find_child("Scroll", true, false)
		scroll.scroll_vertical = 0 if position == "top" else 100000
		for frame: int in range(5):
			await process_frame
		if position == "bottom":
			scroll.scroll_vertical = 100000
			await process_frame
		RenderingServer.force_draw(false)
		var filename: String = ProjectSettings.globalize_path(
			(
				"res://../docs/qa/T-0274/shop_%s_%s_%s_%s.png"
				% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100", position]
			)
		)
		assert(viewport.get_texture().get_image().save_png(filename) == OK)
	viewport.free()
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
