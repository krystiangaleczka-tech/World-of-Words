extends SceneTree
## Run with the exported Android Debug resources and a fresh user data directory.

const SAMPLE_BACKGROUNDS: Dictionary[int, String] = {
	2: "river-watermill.webp",
	3: "river-stone-bridge.webp",
	4: "river.webp",
	25: "river.webp",
	26: "orchard.webp",
	50: "orchard.webp",
	51: "lake.webp",
	75: "lake.webp",
	76: "foothills.webp",
	100: "foothills.webp",
	101: "river.webp",
	150: "river-watermill.webp",
	151: "orchard.webp",
	10000: "orchard-path.webp",
}

var _transition_done: bool = false


func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	var nav: Node = root.get_node("Nav")
	var save: Node = root.get_node("Save")
	var content: Node = root.get_node("Content")
	nav.transition_finished.connect(func() -> void: _transition_done = true, CONNECT_ONE_SHOT)
	root.add_child((load("res://services/nav/boot.tscn") as PackedScene).instantiate())
	if not _check(content.slot_count() == 10000 and _has_map(nav), "Launch on the first map page"):
		return
	if not _check(save.set_setting(&"reduced_motion", true) == OK, "Set test motion preference"):
		return
	OS.low_processor_usage_mode = false
	if not _transition_done:
		await nav.transition_finished
	if not _verify_pages(nav):
		return
	if "resume" in OS.get_cmdline_user_args():
		_button(nav, "Play").pressed.emit()
		if _check(
			nav.level_slot() == 2 and _art_matches(nav, SAMPLE_BACKGROUNDS[2]), "Resume Level 2"
		):
			print("Restarted on the map and resumed the saved Level 2 artwork")
			quit()
		return
	_button(nav, "Settings").pressed.emit()
	if not _check(nav.current_screen() == nav.Screen.SETTINGS, "Settings opens from map"):
		return
	if not _check(nav.handle_back() == OK and _has_map(nav), "Settings returns to map"):
		return
	_button(nav, "NextIslandPage").pressed.emit()
	_button(nav, "Play").pressed.emit()
	if not _check(nav.level_slot() == 1 and _art_matches(nav, "river.webp"), "Play starts Level 1"):
		return
	var level: Node = nav.mounted_screen()
	if not _check(level.p2_hud.home.is_visible_in_tree(), "Map button is available on Level 1"):
		return
	level.p2_hud.home.pressed.emit()
	if not _check(_has_map(nav), "Level 1 map button returns to the illustrated map"):
		return
	_button(nav, "Play").pressed.emit()
	level = nav.mounted_screen()
	await process_frame
	var puzzle: RefCounted = level.controller.get_board().get_level()
	_swipe(level.wheel, puzzle)
	await process_frame
	var state: Dictionary = save.committed_view().sections.progress.by_lang.pl
	if not _check(state.current_slot == 2 and state.stars == 1, "Touch solve saves Level 1"):
		return
	level.continue_button.pressed.emit()
	if not _check(
		nav.level_slot() == 2 and _art_matches(nav, SAMPLE_BACKGROUNDS[2]),
		"Continue changes the view within the first island"
	):
		return
	if not _check(nav.handle_back() == OK and _has_map(nav), "Android Back returns to the map"):
		return
	for slot: int in SAMPLE_BACKGROUNDS:
		if not _check(nav.go_to_level(slot) == OK, "Open Level %d" % slot):
			return
		if not _check(_art_matches(nav, SAMPLE_BACKGROUNDS[slot]), "Background at Level %d" % slot):
			return
	if not _verify_ranges(content):
		return
	print("Verified the map, touch solve, return routes, and artwork across all island boundaries")
	quit()


func _has_map(nav: Node) -> bool:
	var screen: Node = nav.mounted_screen()
	if nav.current_screen() != nav.Screen.HOME or screen == null:
		return false
	var grid: GridContainer = screen.find_child("IslandMap", true, false) as GridContainer
	return grid != null and grid.get_child_count() == 4


func _verify_pages(nav: Node) -> bool:
	var screen: Node = nav.mounted_screen()
	var grid: GridContainer = screen.find_child("IslandMap", true, false) as GridContainer
	var number: Label = screen.find_child("IslandPage", true, false) as Label
	var next: Button = _button(nav, "NextIslandPage")
	var previous: Button = _button(nav, "PreviousIslandPage")
	if not _check(
		(
			previous.disabled
			and number.text.ends_with("1 / 51")
			and _range_text(grid, 0).ends_with("1–25")
			and _range_text(grid, 3).ends_with("76–100")
		),
		"First page contains the four opening islands"
	):
		return false
	next.pressed.emit()
	if not _check(
		_range_text(grid, 0).ends_with("101–150") and _range_text(grid, 3).ends_with("251–300"),
		"Second page contains the first four longer islands"
	):
		return false
	for page: int in range(2, 51):
		next.pressed.emit()
	if not _check(
		(
			next.disabled
			and number.text.ends_with("51 / 51")
			and grid.get_child_count() == 2
			and _range_text(grid, 1).ends_with("9951–10000")
		),
		"Last page provides exactly the final two islands"
	):
		return false
	for page: int in range(50):
		previous.pressed.emit()
	return _check(previous.disabled and number.text.ends_with("1 / 51"), "Return to the first page")


func _range_text(grid: GridContainer, index: int) -> String:
	return (grid.get_child(index).get_node("IslandRange") as Label).text


func _verify_ranges(content: Node) -> bool:
	var script: Script = load("res://services/content/campaign_islands.gd") as Script
	var map: RefCounted = script.load_for(content)
	if not _check(map != null and map.islands.size() == 202, "Campaign has 202 islands"):
		return false
	var previous: Texture2D
	for slot: int in range(1, 10001):
		var expected_index: int = (
			floori(float(slot - 1) / 25) if slot <= 100 else 4 + floori(float(slot - 101) / 50)
		)
		var background: Texture2D = map.background_for_slot(slot)
		var level: RefCounted = content.level_for_slot(slot)
		if not _check(
			(
				map.index_for_slot(slot) == expected_index
				and background != null
				and background != previous
				and level != null
				and level.get_slot() == slot
			),
			"Valid slot, island and changing art at %d" % slot
		):
			return false
		previous = background
	return true


func _art_matches(nav: Node, file: String) -> bool:
	var texture: Texture2D = nav.mounted_screen().background
	return texture != null and texture.resource_path.get_file() == file


func _button(nav: Node, node_name: String) -> Button:
	return nav.mounted_screen().find_child(node_name, true, false) as Button


func _swipe(wheel: Control, puzzle: RefCounted) -> void:
	var used: PackedInt32Array = []
	var positions: PackedVector2Array = []
	for letter: String in puzzle.word(0):
		for tile: int in puzzle.tile_count():
			if puzzle.tile_letter(tile) == letter and tile not in used:
				used.append(tile)
				positions.append(
					wheel.get_global_transform_with_canvas() * wheel.tile_position(tile)
				)
				break
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = positions[0]
	root.push_input(touch, true)
	for index: int in range(1, positions.size()):
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.position = positions[index]
		root.push_input(drag, true)
	var release: InputEventScreenTouch = InputEventScreenTouch.new()
	release.position = positions[-1]
	root.push_input(release, true)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
