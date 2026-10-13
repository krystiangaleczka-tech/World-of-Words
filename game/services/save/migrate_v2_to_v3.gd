class_name MigrateV2ToV3
extends RefCounted
## Pure additive P2 upgrade; legacy compatibility fields and extension values survive.

const ADDED: Dictionary = {
	"meta": ["coach_marks_seen", "onboarding_step"],
	"economy": ["bonus_counter"],
	"monetization": ["last_interstitial_time", "last_purchase_slot", "consent_state"]
}


static func migrate(source: Dictionary) -> Dictionary:
	var version: Variant = source.get("schema_version")
	if not (version is int or version is float) or version != 2:
		return {}
	for section: StringName in SaveSchemaV3.SECTIONS:
		if not source.get(str(section)) is Dictionary:
			return {}
		for field: String in SaveSchemaV3.TEMPLATE[str(section)]:
			if field not in ADDED.get(str(section), []) and not source[str(section)].has(field):
				return {}
	if not source["progress"].get("by_lang") is Dictionary:
		return {}
	var result: Dictionary = source.duplicate(true)
	result["schema_version"] = 3
	for section: String in ADDED:
		for field: String in ADDED[section]:
			if not result[section].has(field):
				var value: Variant = SaveSchemaV3.TEMPLATE[section][field]
				result[section][field] = (
					value.duplicate(true) if value is Dictionary or value is Array else value
				)
	for language: Variant in result["progress"]["by_lang"]:
		var state: Variant = result["progress"]["by_lang"][language]
		if not state is Dictionary:
			return {}
		for field: String in SaveSchemaV3.LANGUAGE_STATE:
			if field in ["postcards", "unlocked"]:
				if not state.has(field):
					state[field] = []
			elif not state.has(field):
				return {}
	var bonus: Variant = source["progress"]["bonus_meter"]
	if source["economy"].has("bonus_counter") and source["economy"]["bonus_counter"] != bonus:
		return {}
	result["economy"]["bonus_counter"] = bonus
	var coaches: Variant = source["progress"]["coach_marks_seen"]
	if source["meta"].has("coach_marks_seen") and source["meta"]["coach_marks_seen"] != coaches:
		return {}
	result["meta"]["coach_marks_seen"] = coaches.duplicate(true) if coaches is Array else coaches
	var previous: Variant = source["monetization"]["last_interstitial"]
	if source["monetization"].has("last_interstitial_time"):
		if (
			(previous is int or previous is float)
			and source["monetization"]["last_interstitial_time"] != previous
		):
			return {}
	else:
		result["monetization"]["last_interstitial_time"] = (
			previous if previous is int or previous is float else null
		)
	var cap: Variant = result["monetization"]["shop_coins_ads"]
	if cap is Dictionary and not _canonical_cap(cap):
		result["monetization"]["shop_coins_ads"] = {"date": null, "count": 0}
		if not cap.is_empty():
			result["monetization"]["shop_coins_ads"]["legacy"] = cap.duplicate(true)
	return result if SaveSchemaV3.is_valid(result) else {}


static func _canonical_cap(cap: Dictionary) -> bool:
	if not cap.has("date") or not cap.has("count"):
		return false
	var count: Variant = cap["count"]
	return (
		(count is int or count is float)
		and is_finite(float(count))
		and count >= 0
		and count <= 9007199254740991
		and floorf(float(count)) == float(count)
		and (cap["date"] == null or (cap["date"] is String and not cap["date"].is_empty()))
	)
