extends SceneTree
## Smoke test for the staged Android Debug resource pack in a fresh user data directory.

const EXPECTED: Dictionary[int, String] = {
	1: "river.webp",
	2052: "river.webp",
	2053: "orchard.webp",
	4039: "orchard.webp",
	4040: "lake.webp",
	6026: "lake.webp",
	6027: "foothills.webp",
	10000: "foothills.webp",
}

var _boot_transition_done: bool = false


func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	var nav: Node = root.get_node("Nav")
	nav.transition_finished.connect(func() -> void: _boot_transition_done = true, CONNECT_ONE_SHOT)
	var boot: Node = (load("res://services/nav/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	var save: Node = root.get_node("Save")
	var content: Node = root.get_node("Content")
	if not _check(content.slot_count() == 10000 and nav.level_slot() == 1, "Ranked cold boot"):
		return
	if not _check(save.set_setting(&"reduced_motion", true) == OK, "Set reduced motion"):
		return
	if not _boot_transition_done:
		await nav.transition_finished
	var level: Node = nav.mounted_screen()
	if not _check(_has_background(level, EXPECTED[1]), "River backdrop on the initial screen"):
		return
	if not _check(save.set_setting(&"high_contrast", true) == OK, "Enable high contrast"):
		return
	await process_frame
	var art: TextureRect = level.get(&"_art") as TextureRect
	if not _check(not art.visible, "High contrast hides the background art"):
		return
	if not _check(save.set_setting(&"high_contrast", false) == OK, "Restore normal contrast"):
		return
	await process_frame
	if not _check(art.visible and _has_background(level, EXPECTED[1]), "Background restored"):
		return
	var board: RefCounted = level.controller.get_board()
	var puzzle: RefCounted = board.get_level()
	var answer: String = puzzle.word(0)
	_swipe(level.wheel, puzzle, answer)
	if not _check(answer in board.found_words(), "Touch input reached the illustrated level"):
		return
	var state: Dictionary = save.committed_view().sections.progress.by_lang.pl
	if not _check(state.current_slot == 2 and state.stars == 1, "The first level still saves"):
		return
	for slot: int in EXPECTED:
		if not _check(nav.go_to_level(slot) == OK, "Navigate to %d" % slot):
			return
		await process_frame
		if not _check(
			_has_background(nav.mounted_screen(), EXPECTED[slot]), "Artwork at %d" % slot
		):
			return
	print("Validated all artwork transitions, contrast, touch input, and saving")
	quit()


func _has_background(level: Node, file: String) -> bool:
	if level == null:
		return false
	var art: TextureRect = level.get(&"_art") as TextureRect
	return (
		art != null
		and art.visible
		and art.texture != null
		and art.texture.resource_path == "res://assets/art/qa-campaign/" + file
		and art.mouse_filter == Control.MOUSE_FILTER_IGNORE
	)


func _swipe(wheel: Control, puzzle: RefCounted, answer: String) -> void:
	var used: PackedInt32Array = []
	var positions: PackedVector2Array = []
	for letter: String in answer:
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
