extends SceneTree
## Actual opt-in P2 scene, injected Save/Economy/Content fixture owners.

const PATH: String = "user://t0276-native.json"


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
				await _shot(layout, pseudo, hc, 12)
	await _shot("COMPACT", false, false, 1)
	quit()


func _shot(layout: String, pseudo: bool, hc: bool, slot: int) -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var view: SubViewport = SubViewport.new()
	view.size = {
		"COMPACT": Vector2i(1080, 1920),
		"REGULAR": Vector2i(1080, 2340),
		"TABLET": Vector2i(1440, 1920)
	}[layout]
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var save: Node = load("res://services/save.gd").new()
	var config: Node = load("res://services/config.gd").new()
	var economy: Node = load("res://services/economy.gd").new()
	var events: Node = load("res://services/events.gd").new()
	var content: Node = load("res://services/content.gd").new()
	for node: Node in [save, config, economy, events, content]:
		view.add_child(node)
	save.initialize(Clock.new())
	economy.initialize(Clock.new())
	save.configure(
		SaveStorage.new(PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert(save.load() == OK)
	assert(config.load() == OK)
	assert(content.load_manifest("pl") == OK)
	var progress: Dictionary = save.get_section(&"progress")
	progress.by_lang.pl.current_slot = 12
	assert(save.set_section(&"progress", progress) == OK)
	assert(save.flush() == OK)
	economy.configure(save, config, events)
	assert(economy.grant(&"test_fixture", {"coins": 1000, "hint": 3, "reveal": 1}) == OK)
	var screen: Control = load("res://features/level/level.tscn").instantiate()
	screen.configure(save, content, slot, events)
	assert(screen.configure_p2(economy, config) == OK)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	screen.configure_rng(rng)
	screen.theme = load(
		(
			"res://ui/theme/generated/theme_hc_130.tres"
			if hc
			else "res://ui/theme/generated/theme_default_100.tres"
		)
	)
	view.add_child(screen)
	for frame: int in range(6):
		await process_frame
	RenderingServer.force_draw(false)
	var filename: String = ProjectSettings.globalize_path(
		(
			"res://../docs/qa/T-0276/level_%s_%s_%s_%s.png"
			% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100", slot]
		)
	)
	assert(view.get_texture().get_image().save_png(filename) == OK)
	view.free()
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
