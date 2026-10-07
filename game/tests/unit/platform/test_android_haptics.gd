extends GutTest


func test_android_patterns_and_unknown() -> void:
	var calls: Array[Vector2] = []
	var vibrate: Callable = func(duration_ms: int, strength: float) -> void:
		calls.append(Vector2(duration_ms, strength))
	var adapter: HapticsAndroid = HapticsAndroid.new(vibrate)
	for pattern: String in ["tick", "soft", "success", "error", "unknown", ""]:
		adapter.play(pattern)
	assert_eq(
		calls,
		[
			Vector2(HapticsAndroid.TICK_DURATION_MS, HapticsAndroid.TICK_STRENGTH),
			Vector2(HapticsAndroid.SOFT_DURATION_MS, HapticsAndroid.SOFT_STRENGTH),
			Vector2(HapticsAndroid.SUCCESS_DURATION_MS, HapticsAndroid.SUCCESS_STRENGTH),
			Vector2(HapticsAndroid.ERROR_DURATION_MS, HapticsAndroid.ERROR_STRENGTH),
		]
	)
	for call: Vector2 in calls:
		assert_between(call.x, 1, HapticsAndroid.ERROR_DURATION_MS)
		assert_between(call.y, 0.0, 1.0)
