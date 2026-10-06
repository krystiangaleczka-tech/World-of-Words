extends GutTest


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _visible(order: PackedInt32Array, letters: PackedStringArray) -> String:
	var text: String = ""
	for tile: int in order:
		text += letters[tile]
	return text


func _assert_permutation(result: PackedInt32Array, order: PackedInt32Array) -> void:
	var actual: PackedInt32Array = result.duplicate()
	var expected: PackedInt32Array = order.duplicate()
	actual.sort()
	expected.sort()
	assert_eq(actual, expected)


func test_preserves_tiles() -> void:
	var order: PackedInt32Array = [0, 1, 2, 3]
	var letters: PackedStringArray = ["D", "O", "M", "A"]
	var original_order: PackedInt32Array = order.duplicate()
	var original_letters: PackedStringArray = letters.duplicate()
	var result: PackedInt32Array = Shuffle.permute(order, letters, _rng(1))
	_assert_permutation(result, order)
	assert_eq(order, original_order)
	assert_eq(letters, original_letters)
	result[0] = -1
	assert_eq(order, original_order, "returned storage is independent of the input")


func test_differs_when_possible() -> void:
	for letters: PackedStringArray in [
		PackedStringArray(["D", "O", "M", "A"]),
		PackedStringArray(["A", "A", "B", "A"]),
	]:
		for order: PackedInt32Array in [
			PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([2, 0, 3, 1])
		]:
			for seed_value: int in range(1, 51):
				var result: PackedInt32Array = Shuffle.permute(order, letters, _rng(seed_value))
				_assert_permutation(result, order)
				assert_ne(_visible(result, letters), _visible(order, letters), str(seed_value))


func test_identical_letters_terminates() -> void:
	var order: PackedInt32Array = [0, 1, 2]
	var result: PackedInt32Array = Shuffle.permute(order, ["A", "A", "A"], _rng(7))
	_assert_permutation(result, order)
	assert_eq(_visible(result, ["A", "A", "A"]), "AAA")


func test_two_tiles_swap() -> void:
	for seed_value: int in range(1, 51):
		assert_eq(Shuffle.permute([0, 1], ["O", "D"], _rng(seed_value)), PackedInt32Array([1, 0]))
		assert_eq(Shuffle.permute([1, 0], ["O", "D"], _rng(seed_value)), PackedInt32Array([0, 1]))


func test_unlucky_rng_still_changes_visible_order() -> void:
	# Godot 4.7.2 seed 174 gives ten identity draws for a two-tile Fisher-Yates pass.
	assert_eq(Shuffle.permute([0, 1], ["O", "D"], _rng(174)), PackedInt32Array([1, 0]))


func test_deterministic() -> void:
	var order: PackedInt32Array = [3, 1, 0, 2]
	var letters: PackedStringArray = ["D", "O", "M", "A"]
	for seed_value: int in [1, 7, 174]:
		assert_eq(
			Shuffle.permute(order, letters, _rng(seed_value)),
			Shuffle.permute(order, letters, _rng(seed_value))
		)


func test_empty_single_and_invalid_inputs() -> void:
	assert_eq(Shuffle.permute([], [], _rng(1)), PackedInt32Array())
	assert_eq(Shuffle.permute([0], ["A"], _rng(1)), PackedInt32Array([0]))
	for order: PackedInt32Array in [
		PackedInt32Array([]),
		PackedInt32Array([0]),
		PackedInt32Array([0, 0]),
		PackedInt32Array([-1, 1]),
		PackedInt32Array([0, 2]),
		PackedInt32Array([0, 1, 2]),
	]:
		assert_eq(Shuffle.permute(order, ["O", "D"], _rng(1)), PackedInt32Array())
	assert_eq(Shuffle.permute([0, 1], ["O", "D"], null), PackedInt32Array())
