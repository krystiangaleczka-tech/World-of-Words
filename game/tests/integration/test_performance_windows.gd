extends GutTest

const OVERLAY: Script = preload("res://features/debug/performance_overlay.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const NAV_SCRIPT: Script = preload("res://services/nav.gd")


class FixedClock:
	extends Clock
	var now: int = 0

	func monotonic_usec() -> int:
		return now


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		document = JSON.parse_string(text)
		return OK


var _clock: FixedClock
var _nav: Node
var _host: Node
var _overlay: CanvasLayer
var _records: Array[Dictionary] = []


func before_each() -> void:
	_clock = FixedClock.new()
	var save: Node = SAVE_SCRIPT.new()
	var content: Node = CONTENT_SCRIPT.new()
	_nav = NAV_SCRIPT.new()
	_host = Node.new()
	for node: Node in [save, content, _nav, _host]:
		add_child_autofree(node)
	save.initialize(_clock)
	save.configure(MemoryStorage.new())
	_nav.configure(save, Config, content)
	assert_eq(_nav.start(_host, "res://tests/fixtures/content"), OK)
	_overlay = OVERLAY.new()
	_overlay.configure(_clock, _nav)
	_overlay.window_closed.connect(_closed)
	_host.add_child(_overlay)
	_records.clear()


func _closed(record: Dictionary) -> void:
	_records.append(record)


func _wheel() -> LetterWheelView:
	return (_nav.mounted_screen() as LevelScreen).wheel


func _observe_input() -> void:
	_clock.now = 1000
	_wheel().pointer_begin(0, _wheel().tile_position(0))
	_clock.now = 2000
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	assert_eq(_overlay.snapshot().samples, 1)


func test_navigation_exports_before_reset_with_stable_snapshot() -> void:
	await _observe_input()
	assert_eq(_nav.go_home(), OK)
	assert_eq(_records.size(), 1)
	assert_eq(_records[0].schema_version, 1)
	assert_eq(_records[0].reason, "navigation")
	assert_eq(_records[0].stats.samples, 1)
	assert_eq(_records[0].stats.mean_ms, 1.0)
	assert_eq(_records[0].stats.p95_ms, 1.0)
	assert_eq(_records[0].stats.latency_window_samples, 1)
	assert_eq(_records[0].stats.frame_budget_usec, 16667)
	assert_eq(_overlay.snapshot().samples, 0)
	assert_eq(_nav.go_home(), OK)
	assert_eq(_records.size(), 1, "Home frames cannot become level windows")
	assert_eq(_nav.go_to_level(1), OK)
	await _observe_input()
	assert_eq(_records[0].stats.samples, 1, "later observations don't mutate prior record")
	assert_eq(_nav.go_home(), OK)
	assert_eq(_records.size(), 2)


func test_background_and_duplicate_foreground_notifications() -> void:
	await _observe_input()
	_overlay.set_foreground(true)
	assert_eq(_overlay.snapshot().samples, 1, "duplicate foreground preserves history")
	_overlay.set_foreground(false)
	assert_eq(_records.size(), 1)
	assert_eq(_records[0].reason, "background")
	assert_eq(_records[0].stats.samples, 1)
	assert_eq(_overlay.snapshot().samples, 0)
	_overlay.set_foreground(false)
	_clock.now = 10000000
	_wheel().pointer_move(0, _wheel().tile_position(1))
	RenderingServer.force_draw(false)
	assert_eq(_overlay.snapshot().pending, 0)
	assert_eq(_overlay.snapshot().frame_intervals, 0)
	assert_eq(_records.size(), 1)
	_wheel().pointer_end(0, true)
	_overlay.set_foreground(true)
	_wheel().pointer_begin(0, _wheel().tile_position(2))
	assert_eq(_overlay.snapshot().pending, 1)
	_overlay.set_foreground(true)
	assert_eq(_overlay.snapshot().pending, 1, "duplicate foreground cannot drop pending input")
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	assert_eq(_overlay.snapshot().samples, 1)
	assert_eq(_overlay.snapshot().fps, -1.0, "first foreground frame excludes background gap")
	_overlay.set_foreground(false)
	assert_eq(_records.size(), 2)


func test_exit_exports_pending_once_and_disconnects() -> void:
	var callbacks: int = RenderingServer.get_signal_connection_list("frame_post_draw").size()
	_wheel().pointer_begin(0, _wheel().tile_position(0))
	_host.remove_child(_overlay)
	assert_eq(_records.size(), 1)
	assert_eq(_records[0].reason, "exit")
	assert_eq(_records[0].stats.pending, 1)
	assert_eq(_records[0].stats.samples, 0)
	assert_eq(_records[0].stats.p95_ms, -1.0)
	_overlay.free()
	assert_eq(_records.size(), 1)
	assert_eq(_nav.get_signal_connection_list("screen_changed").size(), 0)
	assert_eq(RenderingServer.get_signal_connection_list("frame_post_draw").size(), callbacks - 1)
	_wheel().pointer_move(0, _wheel().tile_position(1))
	assert_eq(_wheel().current_chain(), PackedInt32Array([0, 1]))


func test_empty_background_navigation_and_exit_emit_nothing() -> void:
	_overlay.set_foreground(false)
	_overlay.set_foreground(false)
	assert_eq(_records.size(), 0)
	assert_eq(_nav.go_home(), OK)
	assert_eq(_records.size(), 0)
	_host.remove_child(_overlay)
	_overlay.free()
	assert_eq(_records.size(), 0)
