class_name ContentCatalog
extends RefCounted
## @api Validated copied manifest metadata; legacy campaigns have virtual campaign records.

var _slots: int = 0
var _regions: Array[Dictionary] = []
var _locations: Array[Dictionary] = []
var _landmarks: Dictionary[int, bool] = {}


static func from_manifest(manifest: Dictionary) -> ContentCatalog:
	var slots: int = _count(manifest.get("slots"))
	if slots == 0:
		return null
	var present: int = 0
	for key: String in ["regions", "locations", "landmarks"]:
		present += int(manifest.has(key))
	var result: ContentCatalog = ContentCatalog.new()
	result._slots = slots
	if present == 0:
		result._regions = [{"id": "campaign", "name_key": "", "first": 1, "last": slots}]
		result._locations = [
			{
				"id": "campaign",
				"region": "campaign",
				"name_key": "",
				"first": 1,
				"last": slots,
				"postcard": "",
				"pieces": 0
			}
		]
		return result
	if present != 3 or not manifest["landmarks"] is Array:
		return null
	result._regions = _records(manifest["regions"], false)
	result._locations = _records(manifest["locations"], true)
	if not _partition(result._regions, slots) or not _partition(result._locations, slots):
		return null
	for location: Dictionary in result._locations:
		var region: Dictionary = result.region_for_slot(location["first"])
		if location["region"] != region["id"] or location["last"] > region["last"]:
			return null
	for value: Variant in manifest["landmarks"]:
		if not value is Dictionary or value.size() != 2:
			return null
		var slot: int = _count(value.get("slot"))
		if (
			slot < 1
			or slot > slots
			or result._landmarks.has(slot)
			or not value.get("landmark") is bool
		):
			return null
		result._landmarks[slot] = value["landmark"]
	return result


## @api Independent ordered regions; legacy region uses campaign as a virtual ID.
func regions() -> Array[Dictionary]:
	return _regions.duplicate(true)


## @api Return copied metadata without loading a level pack.
func location_for_slot(slot: int) -> Dictionary:
	return _lookup(_locations, slot)


## @api Return copied region metadata without loading a level pack.
func region_for_slot(slot: int) -> Dictionary:
	return _lookup(_regions, slot)


## @api Missing sparse records and out-of-range slots are ordinary non-landmarks.
func is_landmark(slot: int) -> bool:
	return slot > 0 and slot <= _slots and _landmarks.get(slot, false)


func _lookup(records: Array[Dictionary], slot: int) -> Dictionary:
	if slot < 1 or slot > _slots:
		return {}
	for record: Dictionary in records:
		if record["first"] <= slot and slot <= record["last"]:
			return record.duplicate(true)
	return {}


static func _records(value: Variant, location: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var ids: Dictionary[String, bool] = {}
	for entry: Variant in value:
		if not entry is Dictionary or entry.size() != (7 if location else 4):
			return []
		var id: Variant = entry.get("id")
		var name: Variant = entry.get("name_key")
		var first: int = _count(entry.get("first"))
		var last: int = _count(entry.get("last"))
		var kind: String = "location" if location else "region"
		if (
			not _matches(id, "^[a-z][a-z0-9-]*$")
			or ids.has(id)
			or not _matches(name, "^journey\\." + kind + "\\.[a-z][a-z0-9_]*$")
			or first < 1
			or last < first
		):
			return []
		var record: Dictionary = entry.duplicate(true)
		record["first"] = first
		record["last"] = last
		if location:
			if (
				not _matches(entry.get("region"), "^[a-z][a-z0-9-]*$")
				or not _matches(entry.get("postcard"), "^postcards/[a-z0-9_-]+\\.webp$")
				or _count(entry.get("pieces")) < 1
			):
				return []
			record["pieces"] = _count(entry["pieces"])
		ids[id] = true
		result.append(record)
	return result


static func _partition(records: Array[Dictionary], slots: int) -> bool:
	var next: int = 1
	for record: Dictionary in records:
		if record["first"] != next:
			return false
		next = record["last"] + 1
	return not records.is_empty() and next == slots + 1


static func _matches(value: Variant, pattern: String) -> bool:
	if not value is String or value.contains("\n"):
		return false
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	return regex.search(value) != null


static func _count(value: Variant) -> int:
	if (
		not (value is int or value is float)
		or not is_finite(float(value))
		or value < 1
		or value > 9007199254740991
		or floorf(float(value)) != float(value)
	):
		return 0
	return int(value)
