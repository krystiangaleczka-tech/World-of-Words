extends GutTest

const CREDITS: Script = preload("res://services/settings_credits.gd")


func test_catalog_has_exact_stable_ids_and_nonempty_notices() -> void:
	var expected: Array[StringName] = [
		&"godot",
		&"godot-copyrights",
		&"godot-licenses",
		&"inter",
		&"lucide",
		&"audio",
		&"pl-sources"
	]
	var entries: Array[Dictionary] = CREDITS.entries()
	assert_eq(entries.size(), expected.size())
	for i: int in entries.size():
		assert_eq(entries[i].size(), 2)
		assert_eq(entries[i]["id"], expected[i])
		assert_true(entries[i]["notice"] is String)
		assert_false(String(entries[i]["notice"]).is_empty())


func test_engine_legal_data_is_complete_and_verbatim() -> void:
	var entries: Array[Dictionary] = CREDITS.entries()
	assert_eq(entries[0]["notice"], Engine.get_license_text())
	assert_eq(JSON.parse_string(entries[1]["notice"]), Engine.get_copyright_info())
	var licenses: Dictionary = Engine.get_license_info()
	assert_gt(licenses.size(), 0)
	for name: String in licenses:
		assert_string_contains(entries[2]["notice"], name + "\n" + String(licenses[name]))


func test_font_and_icon_notices_are_unmodified() -> void:
	var entries: Array[Dictionary] = CREDITS.entries()
	var font: Resource = load("res://assets/fonts/font_license.tres")
	var icons: Resource = load("res://assets/icons/icon_license.tres")
	assert_eq(entries[3]["notice"], font.get_meta(&"ofl_notice"))
	assert_eq(entries[4]["notice"], icons.get_meta(&"license_notice"))
	assert_string_contains(entries[3]["notice"], "SIL OPEN FONT LICENSE")
	assert_string_contains(entries[4]["notice"], "ISC License")
	assert_string_contains(entries[4]["notice"], "Cole Bemis")


func test_embedded_audio_and_content_match_canonical_files() -> void:
	var entries: Array[Dictionary] = CREDITS.entries()
	assert_eq(
		entries[5]["notice"], FileAccess.get_file_as_string("res://assets/audio/p1/NOTICE.md")
	)
	assert_eq(entries[6]["notice"], FileAccess.get_file_as_string("res://content/NOTICE"))
	assert_string_contains(entries[5]["notice"], "CC0-1.0")
	assert_string_contains(entries[6]["notice"], "Words selected and processed")
	assert_string_contains(entries[6]["notice"], "Frequency evidence selected and processed")
	assert_string_contains(entries[6]["notice"], "Morfeusz SGJP dictionary copyright")
	assert_string_contains(entries[6]["notice"], "Morfeusz engine BSD 2-Clause notice")
	assert_string_contains(entries[6]["notice"], "THIS SOFTWARE IS PROVIDED")


func test_snapshot_mutation_cannot_change_later_catalogs() -> void:
	var original: Array[Dictionary] = CREDITS.entries()
	var changed: Array[Dictionary] = CREDITS.entries()
	changed[0]["notice"] = "tampered"
	changed[3].clear()
	changed.remove_at(6)
	assert_eq(CREDITS.entries(), original)
	assert_eq(Engine.get_license_text(), original[0]["notice"])
