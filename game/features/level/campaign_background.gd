class_name CampaignBackground
extends RefCounted
## Resolves decorative art without changing the campaign's location or progress records.

const CONTENT: Script = preload("res://services/content.gd")
const PREVIEW_DIR: String = "res://assets/art/qa-campaign"
const PREVIEW_CATALOG: String = PREVIEW_DIR + "/catalog.json"


static func for_level(content: CONTENT, slot: int) -> Texture2D:
	if not is_instance_valid(content) or slot < 1 or slot > content.slot_count():
		return null
	var postcard: String = content.location_for_slot(slot).get("postcard", "")
	if not postcard.is_empty():
		var directory: String = "res://content".path_join(content.get_language())
		var art: Texture2D = _texture_at(directory.path_join(postcard))
		if art != null:
			return art
	if not OS.is_debug_build() or not FileAccess.file_exists(PREVIEW_CATALOG):
		return null
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_CATALOG))
	var file: String = _preview_file(catalog, content.manifest_hash(), slot)
	return _texture_at(PREVIEW_DIR.path_join(file)) if not file.is_empty() else null


static func _preview_file(catalog: Variant, manifest_hash: String, slot: int) -> String:
	if not catalog is Dictionary or catalog.get("manifest_sha256") != manifest_hash:
		return ""
	var ranges: Variant = catalog.get("ranges")
	if not ranges is Array:
		return ""
	var previous_end: int = 0
	for entry: Variant in ranges:
		if not entry is Dictionary:
			return ""
		var end: Variant = entry.get("last")
		if not (end is float or end is int) or end != floorf(end) or end <= previous_end:
			return ""
		if slot <= end:
			var file: Variant = entry.get("image")
			if file is String and file == file.get_file() and file.get_extension() == "webp":
				return file
			return ""
		previous_end = int(end)
	return ""


static func _texture_at(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
