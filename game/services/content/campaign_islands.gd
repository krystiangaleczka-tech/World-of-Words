class_name CampaignIslands
extends RefCounted
## Optional illustrated map for the exact staged QA campaign.

const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const ART_DIRECTORY: String = "res://assets/art/qa-campaign"
const CATALOG: String = ART_DIRECTORY + "/islands.json"
const VIEWS_PER_ISLAND: int = 3


class IslandArt:
	var name_key: String
	var marker: Texture2D
	var backgrounds: Array[Texture2D] = []


class Island:
	var first: int
	var last: int
	var theme: IslandArt


var islands: Array[Island] = []


static func load_for(content: CONTENT_SCRIPT) -> CampaignIslands:
	if not OS.is_debug_build() or not content.is_loaded() or not FileAccess.file_exists(CATALOG):
		return null
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not catalog is Dictionary or catalog.get("manifest_sha256") != content.manifest_hash():
		return null
	var rows: Variant = catalog.get("themes")
	if not rows is Array or rows.size() < 2:
		return null
	var themes: Array[IslandArt] = []
	var used: Dictionary[String, bool] = {}
	for row: Variant in rows:
		var theme: IslandArt = _read_theme(row, used)
		if theme == null:
			return null
		themes.append(theme)
	return _partition(catalog, content.slot_count(), themes)


func background_for_slot(slot: int) -> Texture2D:
	var index: int = index_for_slot(slot)
	if index == -1:
		return null
	var island: Island = islands[index]
	var backgrounds: Array[Texture2D] = island.theme.backgrounds
	return backgrounds[(slot - island.first) % backgrounds.size()]


func index_for_slot(slot: int) -> int:
	for index: int in islands.size():
		var island: Island = islands[index]
		if slot >= island.first and slot <= island.last:
			return index
	return -1


static func _partition(
	catalog: Dictionary, slots: int, themes: Array[IslandArt]
) -> CampaignIslands:
	var opening: Variant = catalog.get("opening_ends")
	var span: Variant = catalog.get("island_span")
	if not opening is Array or not _is_slot_count(span, slots):
		return null
	var result: CampaignIslands = CampaignIslands.new()
	var first: int = 1
	for last: Variant in opening:
		if not _is_slot_count(last, slots) or last < first:
			return null
		result._append_island(first, int(last), themes)
		first = int(last) + 1
	while first <= slots:
		var last: int = mini(first + int(span) - 1, slots)
		result._append_island(first, last, themes)
		first = last + 1
	return result


func _append_island(first: int, last: int, themes: Array[IslandArt]) -> void:
	var island: Island = Island.new()
	island.first = first
	island.last = last
	island.theme = themes[islands.size() % themes.size()]
	islands.append(island)


static func _is_slot_count(value: Variant, maximum: int) -> bool:
	return (
		(value is float or value is int)
		and value >= 1
		and value <= maximum
		and value == floorf(value)
	)


static func _read_theme(row: Variant, used: Dictionary[String, bool]) -> IslandArt:
	if not row is Dictionary:
		return null
	var key: Variant = row.get("name_key")
	var views: Variant = row.get("backgrounds")
	if (
		not key is String
		or not key.begins_with("home.islands.")
		or not views is Array
		or views.size() != VIEWS_PER_ISLAND
	):
		return null
	var marker: Texture2D = _read_art(row.get("marker"), used)
	if marker == null:
		return null
	var theme: IslandArt = IslandArt.new()
	theme.name_key = key
	theme.marker = marker
	for file: Variant in views:
		var texture: Texture2D = _read_art(file, used)
		if texture == null:
			return null
		theme.backgrounds.append(texture)
	return theme


static func _read_art(file: Variant, used: Dictionary[String, bool]) -> Texture2D:
	if not file is String or file != file.get_file() or file.get_extension() != "webp":
		return null
	var path: String = ART_DIRECTORY.path_join(file)
	if used.has(path) or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture != null:
		used[path] = true
	return texture
