extends GutTest


func test_named_patterns_record_in_order() -> void:
	var fake: HapticsFake = HapticsFake.new()
	var patterns: PackedStringArray = ["tick", "soft", "success", "error", "tick"]
	for pattern: String in patterns:
		fake.play(pattern)
	assert_eq(fake.calls.entries.size(), patterns.size())
	for index: int in patterns.size():
		assert_eq(fake.calls.entries[index], {"method": "play", "arguments": [patterns[index]]})


func test_disabled_and_reenabled() -> void:
	var fake: HapticsFake = HapticsFake.new()
	var logs: Array[String] = []
	var logger: Callable = func(message: String) -> void: logs.append(message)
	fake.play("tick")
	fake.configure(false, logger)
	for pattern: String in ["tick", "soft", "success", "error"]:
		fake.play(pattern)
	assert_eq(fake.calls.entries.size(), 1)
	assert_true(logs.is_empty())
	fake.configure(true, logger)
	fake.play("soft")
	assert_eq(fake.calls.entries.size(), 2)
	assert_eq(fake.calls.entries[0]["arguments"], ["tick"])
	assert_eq(fake.calls.entries[1]["arguments"], ["soft"])


func test_unknown_patterns_are_noops() -> void:
	var fake: HapticsFake = HapticsFake.new()
	var logs: Array[String] = []
	fake.configure(true, func(message: String) -> void: logs.append(message))
	fake.play("")
	fake.play("unsupported")
	assert_true(fake.calls.entries.is_empty())
	assert_true(logs.is_empty())


func test_debug_logger_receives_enabled_patterns() -> void:
	var fake: HapticsFake = HapticsFake.new()
	var logs: Array[String] = []
	fake.configure(true, func(message: String) -> void: logs.append(message))
	for pattern: String in ["tick", "soft", "success", "error"]:
		fake.play(pattern)
	var expected: Array[String] = []
	if OS.is_debug_build():
		(
			expected
			. assign(
				[
					"HapticsFake.play: tick",
					"HapticsFake.play: soft",
					"HapticsFake.play: success",
					"HapticsFake.play: error",
				]
			)
		)
	assert_eq(logs, expected)
	fake.configure(true)
	fake.play("tick")
	assert_eq(fake.calls.entries.size(), 5, "default logger keeps recording without errors")
	assert_eq(logs, expected, "configure replaces the prior injected logger")
