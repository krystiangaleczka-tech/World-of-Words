extends SceneTree
## Actual opt-in Level/Home; real owners with isolated injected memory storage.

class Storage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		document = JSON.parse_string(text)
		return OK


var count: int = 0


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	for key: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + key, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	for layout: String in ["COMPACT", "REGULAR", "TABLET"]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				for feature: String in ["shuffle", "bonus", "hint", "journey", "reveal"]:
					await _case(layout, pseudo, hc, feature)
	print("T-0292 native screenshots: ", count)
	quit()


func _case(layout: String, pseudo: bool, hc: bool, feature: String) -> void:
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	Tokens.reduced_motion = false
	var view: SubViewport = SubViewport.new()
	view.size = {"COMPACT": Vector2i(1080,1920),"REGULAR":Vector2i(1080,2340),"TABLET":Vector2i(1440,1920)}[layout]
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var save: Node = load("res://services/save.gd").new()
	var config: Node = load("res://services/config.gd").new()
	var economy: Node = load("res://services/economy.gd").new()
	var events: Node = load("res://services/events.gd").new()
	var content: Node = load("res://services/content.gd").new()
	var nav: Node = Node.new()
	for node: Node in [save,config,economy,events,content,nav]:
		view.add_child(node)
	save.initialize(Clock.new())
	save.configure(Storage.new())
	assert(save.load() == OK)
	assert(config.load() == OK)
	assert(content.load_manifest("pl") == OK)
	economy.initialize(Clock.new())
	economy.configure(save,config,events)
	assert(save.configure_onboarding(events) == OK)
	assert(save.complete_tutorial() == OK)
	for other: String in ["shuffle","bonus","hint","journey","reveal"]:
		if other != feature:
			assert(save.mark_coach_seen(StringName(other)) == OK)
	var slot: int = {"shuffle":2,"bonus":5,"hint":7,"journey":10,"reveal":12}[feature]
	var progress: Dictionary = save.get_section(&"progress")
	progress.by_lang.pl.current_slot = slot
	assert(save.set_section(&"progress",progress) == OK)
	assert(save.flush() == OK)
	var page: Control = (load("res://features/home/home.tscn" if feature == "journey" else "res://features/level/level.tscn") as PackedScene).instantiate()
	if feature == "journey":
		page.configure(save,content,config,nav)
		assert(page.configure_coaches(events,func() -> bool: return false) == OK)
	else:
		page.configure(save,content,slot,events)
		assert(page.configure_p2(economy,config) == OK)
		assert(page.configure_coaches(func() -> bool: return false) == OK)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 292
		page.configure_rng(rng)
	page.theme = load("res://ui/theme/generated/theme_hc_130.tres" if hc else "res://ui/theme/generated/theme_default_100.tres")
	view.add_child(page)
	await _settle()
	if feature == "bonus":
		var level: LevelData = page.controller.get_board().get_level()
		assert(page.controller.submit(_spell(level,level.bonus_words()[0])) != null)
		await _settle()
	assert(page.coaches.active_feature() == StringName(feature))
	assert(feature in save.onboarding_snapshot().seen)
	await _shot(view,page,layout,pseudo,hc,feature,"active")
	if layout == "COMPACT" and pseudo and hc:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = 6
		touch.pressed = true
		touch.position = Vector2.ONE * Tokens.Space.XS
		view.push_input(touch,true)
		touch.pressed = false
		view.push_input(touch,true)
		await _settle()
		assert(page.coaches.active_feature() == &"")
		await _shot(view,page,layout,pseudo,hc,feature,"dismissed")
	view.free()


func _spell(level: LevelData, word: String) -> PackedInt32Array:
	var tiles: PackedInt32Array = PackedInt32Array()
	for character: String in word:
		for index: int in level.tile_count():
			if level.tile_letter(index) == character and index not in tiles:
				tiles.append(index)
				break
	return tiles


func _shot(view: SubViewport, page: Control, layout: String, pseudo: bool, hc: bool, feature: String, state: String) -> void:
	await _settle()
	var bounds: Rect2 = Rect2(Vector2.ZERO,Vector2(view.size))
	if feature == "journey":
		var target: Control = page.find_child("Journey",true,false)
		assert(bounds.encloses(target.get_global_rect()))
		assert(bounds.encloses(page.coach_caption.get_global_rect()))
		assert(not target.get_global_rect().intersects(page.coach_caption.get_global_rect()))
	else:
		for child: Node in page.wheel.get_parent().get_children():
			if child is Label and child.theme_type_variation == &"Caption":
				assert(bounds.encloses(child.get_global_rect()))
				assert(not child.get_global_rect().intersects(page.wheel.get_global_rect()))
	RenderingServer.force_draw(false)
	var filename: String = "res://../docs/qa/T-0292/coach_%s_%s_%s_%s_%s.png" % [feature,layout,"PSEUDO" if pseudo else "PL","hc130" if hc else "default100",state]
	assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path(filename)) == OK)
	count += 1


func _settle() -> void:
	for frame: int in range(6):
		await process_frame
