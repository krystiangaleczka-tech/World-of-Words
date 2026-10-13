class_name MigrateV3ToV4
extends RefCounted
## Pure additive upgrade. Historical credits stay unallocated; reserved collisions stay v3.


static func migrate(source: Dictionary) -> Dictionary:
	if not SaveSchemaV3.is_valid(source) or source["meta"].has("atomic"):
		return {}
	var result: Dictionary = source.duplicate(true)
	result["schema_version"] = 4
	result["meta"]["atomic"] = {"lineage": 0, "revision": 0, "processed": {}}
	for language: String in result["progress"]["by_lang"]:
		var state: Dictionary = result["progress"]["by_lang"][language]
		if not state.has("location_stars"):
			state["location_stars"] = {}
	return result if SaveSchema.is_valid(result) else {}
