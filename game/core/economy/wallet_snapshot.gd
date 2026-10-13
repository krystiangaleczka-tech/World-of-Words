class_name WalletSnapshot
extends RefCounted
## @api Immutable wallet value. Operations return independent values or null on invalid requests.

const MAX_SAFE_COUNT: int = 9007199254740991
const KEYS: Array[String] = ["coins", "hint", "reveal"]
var _data: Dictionary = {"coins": 0, "items": {"hint": 0, "reveal": 0}}


## @api Strict wallet deserialization; integral JSON numbers become int.
static func from_dict(source: Dictionary) -> WalletSnapshot:
	if source.size() != 2 or not source.has("coins") or not source.get("items") is Dictionary:
		return null
	var items: Dictionary = source["items"]
	if items.size() != 2 or not items.has("hint") or not items.has("reveal"):
		return null
	for value: Variant in [source["coins"], items["hint"], items["reveal"]]:
		if not _count(value):
			return null
	var wallet: WalletSnapshot = WalletSnapshot.new()
	wallet._data = {
		"coins": int(source["coins"]),
		"items": {"hint": int(items["hint"]), "reveal": int(items["reveal"])}
	}
	return wallet


## @api Known flat int amounts, no negative or empty transaction.
static func valid_amounts(amounts: Dictionary) -> bool:
	var positive: bool = false
	for key: Variant in amounts:
		if (
			not key is String
			or key not in KEYS
			or not amounts[key] is int
			or not _count(amounts[key])
		):
			return false
		positive = positive or amounts[key] > 0
	return positive


## @api Independent serialization suitable for owner-controlled persistence.
func snapshot() -> Dictionary:
	return _data.duplicate(true)


## @api Validate the complete request before accepting any component.
func can_afford(amounts: Dictionary) -> bool:
	if not valid_amounts(amounts):
		return false
	for key: String in amounts:
		if _balance(key) < amounts[key]:
			return false
	return true


## @api Apply a grant without mutating this value; reject safe-integer overflow atomically.
func granted(amounts: Dictionary) -> WalletSnapshot:
	if not valid_amounts(amounts):
		return null
	for key: String in amounts:
		if _balance(key) > MAX_SAFE_COUNT - amounts[key]:
			return null
	return _apply(amounts, 1)


## @api Apply a spend without mutating this value; insufficient requests return null.
func spent(amounts: Dictionary) -> WalletSnapshot:
	return _apply(amounts, -1) if can_afford(amounts) else null


func _balance(key: String) -> int:
	return _data["coins"] if key == "coins" else _data["items"][key]


func _apply(amounts: Dictionary, direction: int) -> WalletSnapshot:
	var result: Dictionary = snapshot()
	for key: String in amounts:
		if key == "coins":
			result["coins"] += direction * amounts[key]
		else:
			result["items"][key] += direction * amounts[key]
	return from_dict(result)


static func _count(value: Variant) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= 0
		and value <= MAX_SAFE_COUNT
		and floorf(float(value)) == float(value)
	)
