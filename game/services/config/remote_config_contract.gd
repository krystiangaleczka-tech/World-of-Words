class_name RemoteConfigContract
extends RefCounted
## @api Pure validation and stable assignment; fetching/persistence belong to T-0255.

const VERSION: int = 1
const MAX_EXPERIMENTS: int = 32


## @api Bucket is deterministic on both platforms and independent of local clock.
static func bucket(install_id: String, experiment_id: String) -> int:
	if install_id.is_empty() or experiment_id.is_empty():
		return -1
	return posmod((install_id + experiment_id).hash(), 100)


## @api Unknown values are returned for logging. Known disallowed/invalid values are rejected.
## An invalid envelope or experiment rejects the full remote candidate.
static func validate(
	document: Dictionary, registry: ConfigRegistry, install_id: String
) -> Dictionary:
	if (
		registry == null
		or install_id.is_empty()
		or document.get("version") != VERSION
		or not document.get("values") is Dictionary
		or not document.get("experiments") is Array
	):
		return {}
	var experiments: Array = document["experiments"]
	if experiments.size() > MAX_EXPERIMENTS:
		return {}
	var result: Dictionary = {
		"overrides": {}, "unknown": [], "rejected": [], "buckets": {}, "assignments": {}
	}
	var values: Dictionary = document["values"]
	for raw_key: Variant in values:
		if not raw_key is String:
			return {}
		var key: String = raw_key
		if not registry.has_key(StringName(key)):
			result["unknown"].append(key)
			continue
		var definition: Dictionary = registry.definition(StringName(key))
		if not definition["remote"] or not _matches(values[raw_key], definition):
			result["rejected"].append(key)
			continue
		result["overrides"][key] = values[raw_key]
	var seen: Dictionary = {}
	for raw_experiment: Variant in experiments:
		if not raw_experiment is Dictionary:
			return {}
		var experiment: Dictionary = raw_experiment
		if not experiment.get("id") is String or not experiment.get("variants") is Array:
			return {}
		if experiment["id"].is_empty():
			return {}
		var name: String = experiment["id"]
		if seen.has(name):
			return {}
		seen[name] = true
		var variants: Array = experiment["variants"]
		if variants.is_empty() or variants.size() > 100:
			return {}
		var total: int = 0
		var variant_ids: Dictionary = {}
		var selected: String = ""
		var draw: int = bucket(install_id, name)
		for entry: Variant in variants:
			if not entry is Dictionary:
				return {}
			var variant: Dictionary = entry
			if not variant.get("id") is String or not variant.get("weight") is int:
				return {}
			if (
				variant["id"].is_empty()
				or variant["weight"] < 1
				or variant["weight"] > 100
				or variant_ids.has(variant["id"])
			):
				return {}
			var weight: int = variant["weight"]
			var variant_id: String = variant["id"]
			variant_ids[variant_id] = true
			total += weight
			if selected.is_empty() and draw < total:
				selected = variant_id
		if total != 100 or selected.is_empty():
			return {}
		result["buckets"][name] = draw
		result["assignments"][name] = selected
	result["unknown"].sort()
	result["rejected"].sort()
	return result


## @api Keep the last valid candidate on timeout, network failure or bad JSON.
## The caller persists only a validated new candidate and never waits at boot.
static func select_snapshot(
	candidate: Dictionary, cached: Dictionary, registry: ConfigRegistry, install_id: String
) -> Dictionary:
	var fresh: Dictionary = validate(candidate, registry, install_id)
	if not fresh.is_empty():
		return {"source": "remote", "effective": fresh}
	var previous: Dictionary = validate(cached, registry, install_id)
	if not previous.is_empty():
		return {"source": "cache", "effective": previous}
	return {"source": "defaults", "effective": {}}


static func _matches(value: Variant, definition: Dictionary) -> bool:
	match definition["type"]:
		"int":
			if not value is int:
				return false
		"float":
			if not value is float:
				return false
		"bool":
			return value is bool
		"string":
			return value is String
		_:
			return false
	var bounds: Variant = definition["range"]
	if bounds == null:
		return true
	return bounds is Array and bounds.size() == 2 and value >= bounds[0] and value <= bounds[1]
