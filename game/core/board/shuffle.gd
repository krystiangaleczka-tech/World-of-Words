class_name Shuffle
extends RefCounted
## @api Pure tile-position permutation. Tile indices retain their original identity.

const MAX_ATTEMPTS: int = 10


## @api Return a permutation with different visible letters when possible, without mutating inputs.
## Invalid full-permutation input or a null RNG returns empty.
static func permute(
	order: PackedInt32Array, letters: PackedStringArray, rng: RandomNumberGenerator
) -> PackedInt32Array:
	if rng == null or order.size() != letters.size():
		return PackedInt32Array()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(letters.size())
	for tile: int in order:
		if tile < 0 or tile >= letters.size() or seen[tile] != 0:
			return PackedInt32Array()
		seen[tile] = 1
	var result: PackedInt32Array = order.duplicate()
	if result.size() < 2:
		return result
	var differs: bool = false
	for tile: int in order:
		if letters[tile] != letters[order[0]]:
			differs = true
			break
	for attempt: int in MAX_ATTEMPTS:
		result = order.duplicate()
		for slot: int in range(result.size() - 1, 0, -1):
			var other: int = rng.randi_range(0, slot)
			var tile: int = result[slot]
			result[slot] = result[other]
			result[other] = tile
		if not differs or _visible_differs(result, order, letters):
			return result
	# A one-position rotation changes every nonconstant cyclic letter sequence.
	for slot: int in order.size():
		result[slot] = order[(slot + 1) % order.size()]
	return result


static func _visible_differs(
	result: PackedInt32Array, order: PackedInt32Array, letters: PackedStringArray
) -> bool:
	for slot: int in order.size():
		if letters[result[slot]] != letters[order[slot]]:
			return true
	return false
