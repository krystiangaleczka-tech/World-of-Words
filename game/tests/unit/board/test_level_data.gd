extends GutTest


func _level() -> Dictionary:
	return {
		"id": "pl-c-000002",
		"slot": 2.0,
		"letters": ["D", "O", "M", "A"],
		"words":
		[
			{"w": "DOM", "x": 0.0, "y": 0.0, "dir": "h"},
			{"w": "MODA", "x": 2.0, "y": 0.0, "dir": "v"},
		],
		"bonus": ["DAM", "ODA"],
		"grid": {"w": 3.0, "h": 4.0},
		"difficulty": 0.0,
		"pipeline": "0.0.0",
	}


func test_valid_level_exposes_game_fields() -> void:
	var level: LevelData = LevelData.from_dict(_level())
	assert_not_null(level)
	assert_eq(level.get_id(), "pl-c-000002")
	assert_eq(level.get_slot(), 2)
	assert_eq(level.tile_count(), 4)
	assert_eq(level.tile_letter(2), "M")
	assert_eq(level.tile_letter(4), "")
	assert_eq(level.word_count(), 2)
	assert_eq(level.word(1), "MODA")
	assert_eq(level.word(2), "")
	assert_eq(level.bonus_words(), PackedStringArray(["DAM", "ODA"]))
	assert_eq(level.grid_size(), Vector2i(3, 4))


func test_word_cells_follow_direction() -> void:
	var level: LevelData = LevelData.from_dict(_level())
	assert_eq(
		level.word_cells(0), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	)
	assert_eq(
		level.word_cells(1),
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)] as Array[Vector2i]
	)
	assert_eq(level.word_cells(5), [] as Array[Vector2i])


func test_daily_level_has_slot_zero() -> void:
	var data: Dictionary = _level()
	data["id"] = "pl-d-000001"
	data.erase("slot")
	assert_eq(LevelData.from_dict(data).get_slot(), 0)


func test_repeated_letters_are_distinct_tiles() -> void:
	var data: Dictionary = _level()
	data["letters"] = ["A", "L", "A", "S"]
	data["words"] = [{"w": "ALA", "x": 0.0, "y": 0.0, "dir": "h"}]
	var level: LevelData = LevelData.from_dict(data)
	assert_eq(level.spell(PackedInt32Array([0, 1, 2])), "ALA")
	assert_eq(level.spell(PackedInt32Array([2, 1, 0])), "ALA")


func test_spell_rejects_reused_or_unknown_tiles() -> void:
	var level: LevelData = LevelData.from_dict(_level())
	assert_eq(level.spell(PackedInt32Array([0, 1, 2])), "DOM")
	assert_eq(level.spell(PackedInt32Array([0, 1, 0])), "")
	assert_eq(level.spell(PackedInt32Array([0, 4])), "")
	assert_eq(level.spell(PackedInt32Array([-1])), "")
	assert_eq(level.spell(PackedInt32Array()), "")


func test_getters_return_copies() -> void:
	var level: LevelData = LevelData.from_dict(_level())
	var letters: PackedStringArray = level.get_letters()
	letters[0] = "X"
	var bonus: PackedStringArray = level.bonus_words()
	bonus.append("XXX")
	var cells: Array[Vector2i] = level.word_cells(0)
	cells.clear()
	assert_eq(level.tile_letter(0), "D")
	assert_eq(level.bonus_words().size(), 2)
	assert_eq(level.word_cells(0).size(), 3)


func test_rejects_missing_or_mistyped_fields() -> void:
	for field: String in ["id", "letters", "words", "bonus", "grid"]:
		var data: Dictionary = _level()
		data.erase(field)
		assert_null(LevelData.from_dict(data), "missing " + field)
	var cases: Dictionary = {
		"id": "",
		"slot": 0.0,
		"letters": "DOMA",
		"words": [],
		"bonus": [1.0],
		"grid": {"w": 3.5, "h": 4.0},
	}
	for field: String in cases:
		var data: Dictionary = _level()
		data[field] = cases[field]
		assert_null(LevelData.from_dict(data), "bad " + field)


func test_rejects_bad_letters() -> void:
	for letters: Array in [
		["A", "B"], ["A", "B", "C", "D", "E", "F", "G", "H", "I"], ["A", "BC", "D"]
	]:
		var data: Dictionary = _level()
		data["letters"] = letters
		assert_null(LevelData.from_dict(data), str(letters))


func test_rejects_bad_placements() -> void:
	var placements: Array[Dictionary] = [
		{"w": "DOM", "x": 0.0, "y": 0.0, "dir": "d"},
		{"w": "DOM", "x": 1.0, "y": 0.0, "dir": "h"},
		{"w": "DOM", "x": 0.0, "y": 2.0, "dir": "v"},
		{"w": "DOM", "x": -1.0, "y": 0.0, "dir": "h"},
		{"w": "DOM", "x": 0.5, "y": 0.0, "dir": "h"},
		{"w": "DO", "x": 0.0, "y": 0.0, "dir": "h"},
		{"x": 0.0, "y": 0.0, "dir": "h"},
	]
	for placement: Dictionary in placements:
		var data: Dictionary = _level()
		data["words"] = [placement]
		assert_null(LevelData.from_dict(data), str(placement))


func test_rejects_conflicting_shared_cell() -> void:
	var data: Dictionary = _level()
	data["words"][1] = {"w": "ODA", "x": 2.0, "y": 0.0, "dir": "v"}
	assert_null(LevelData.from_dict(data))


func test_rejects_grid_out_of_range() -> void:
	for grid: Dictionary in [{"w": 0.0, "h": 4.0}, {"w": 3.0, "h": 11.0}, {"w": 3.0}]:
		var data: Dictionary = _level()
		data["grid"] = grid
		assert_null(LevelData.from_dict(data), str(grid))
