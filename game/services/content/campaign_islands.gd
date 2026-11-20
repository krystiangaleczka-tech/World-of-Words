class_name CampaignIslands
extends RefCounted
## Optional illustrated map for the exact staged QA campaign.

const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const ART_DIRECTORY: String = "res://assets/art/qa-campaign"
const CATALOG: String = ART_DIRECTORY + "/islands.json"
const ISLAND_COUNT: int = 4
const VIEWS_PER_ISLAND: int = 3


class Island:
	var first: int
	var last: int
	var name_key: String
	var marker: Texture2D
	var backgrounds: Array[Texture2D] = []


var islands: Array[Island] = []


static func load_for(content: CONTENT_SCRIPT) -> CampaignIslands:
	if not OS.is_debug_build() or not content.is_loaded() or not FileAccess.file_exists(CATALOG):
		return null
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not catalog is Dictionary or catalog.get("manifest_sha256") != content.manifest_hash():
		return null
	var rows: Variant = catalog.get("islands")
	if not rows is Array or rows.size() != ISLAND_COUNT:
		return null
	var result: CampaignIslands = CampaignIslands.new()
	var next_slot: int = 1
	var used: Dictionary[String, bool] = {}
	for row: Variant in rows:
		var island: Island = _read_island(row, next_slot, content.slot_count(), used)
		if island == null:
			return null
		result.islands.append(island)
		next_slot = island.last + 1
	return result if next_slot == content.slot_count() + 1 else null


func background_for_slot(slot: int) -> Texture2D:
	for island: Island in islands:
		if slot >= island.first and slot <= island.last:
			var index: int = (slot - island.first) % island.backgrounds.size()
			return island.backgrounds[index]
	return null


static func _read_island(
	row: Variant, first: int, slot_count: int, used: Dictionary[String, bool]
) -> Island:
	if not row is Dictionary:
		return null
	var last: Variant = row.get("last")
	var key: Variant = row.get("name_key")
	var views: Variant = row.get("backgrounds")
	if (
		not (last is float or last is int)
		or last < first
		or last > slot_count
		or last != floorf(last)
		or not key is String
		or not key.begins_with("home.islands.")
		or not views is Array
		or views.size() != VIEWS_PER_ISLAND
	):
		return null
	var marker: Texture2D = _read_art(row.get("marker"), used)
	if marker == null:
		return null
	var island: Island = Island.new()
	island.first = first
	island.last = int(last)
	island.name_key = key
	island.marker = marker
	for file: Variant in views:
		var texture: Texture2D = _read_art(file, used)
		if texture == null:
			return null
		island.backgrounds.append(texture)
	return island


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
