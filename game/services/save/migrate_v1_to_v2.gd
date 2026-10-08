class_name MigrateV1ToV2
extends RefCounted
## Pure version upgrade. SaveSchema validates structure; BoardState validates against content later.


static func migrate(source: Dictionary) -> Dictionary:
	var version: Variant = source.get("schema_version")
	if not (version is int or version is float) or version != 1:
		return {}
	if not source.get("progress") is Dictionary:
		return {}
	var languages: Variant = source["progress"].get("by_lang")
	if not languages is Dictionary:
		return {}
	var result: Dictionary = source.duplicate(true)
	for language: Variant in languages:
		var state: Variant = result["progress"]["by_lang"][language]
		if not state is Dictionary or not state.has("completed_slot"):
			return {}
		state["highest_completed_slot"] = state["completed_slot"]
	result["schema_version"] = 2
	return result
