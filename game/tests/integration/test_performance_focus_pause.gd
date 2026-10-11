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


func _observe(at: int) -> void:
	_clock.now = at
	_wheel().pointer_begin(0, _wheel().tile_position(0))
	_clock.now = at + 1000
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	assert_eq(_overlay.snapshot().samples, 1)


func _background_input(at: int) -> void:
	_clock.now = at
	_wheel().pointer_end(0, true)
	_wheel().pointer_begin(0, _wheel().tile_position(1))
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	assert_eq(_overlay.snapshot().pending, 0)
	assert_eq(_overlay.snapshot().samples, 0)
	assert_eq(_overlay.snapshot().frame_intervals, 0)
	_wheel().pointer_end(0, true)


func test_pause_then_focus_in_requires_resume() -> void:
	await _observe(1000)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _background_input(10000000)
	assert_eq(_records.size(), 1)
	assert_eq(_records[0].reason, "background")
	assert_eq(_records[0].schema_version, 1)
	assert_eq(_records[0].stats.samples, 1)
	assert_eq(_records[0].stats.mean_ms, 1.0)
	var closed_record: Dictionary = _records[0].duplicate(true)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _observe(20000000)
	assert_eq(_overlay.snapshot().fps, -1.0, "first frame excludes background gap")
	assert_eq(_overlay.snapshot().frame_intervals, 0)
	assert_eq(_records[0], closed_record, "closed record remains stable")


func test_focus_out_then_resume_requires_focus_in() -> void:
	await _observe(1000)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _background_input(10000000)
	assert_eq(_records.size(), 1)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _observe(20000000)
	assert_eq(_overlay.snapshot().fps, -1.0)
	assert_eq(_records[0].stats.mean_ms, 1.0)


func test_overlapping_notifications_close_once_in_both_orders() -> void:
	var orders: Array[PackedInt32Array] = [
		PackedInt32Array(
			[
				Node.NOTIFICATION_APPLICATION_PAUSED,
				Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
				Node.NOTIFICATION_APPLICATION_RESUMED,
				Node.NOTIFICATION_APPLICATION_FOCUS_IN
			]
		),
		PackedInt32Array(
			[
				Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
				Node.NOTIFICATION_APPLICATION_PAUSED,
				Node.NOTIFICATION_APPLICATION_FOCUS_IN,
				Node.NOTIFICATION_APPLICATION_RESUMED
			]
		),
	]
	for index: int in range(orders.size()):
		var closed_before: int = _records.size()
		await _observe(1000 + index * 30000000)
		_overlay.notification(orders[index][0])
		_overlay.notification(orders[index][1])
		_overlay.notification(orders[index][2])
		await _background_input(10000000 + index * 30000000)
		assert_eq(_records.size(), closed_before + 1)
		_overlay.notification(orders[index][3])
		await _observe(20000000 + index * 30000000)
		assert_eq(_overlay.snapshot().fps, -1.0)
		_wheel().pointer_end(0, true)
		# Reset explicitly between independent notification sequences.
		_overlay.set_foreground(false)
		assert_eq(_records.size(), closed_before + 2)
		_overlay.set_foreground(true)


func test_duplicates_preserve_pending_history_and_explicit_override() -> void:
	_wheel().pointer_begin(0, _wheel().tile_position(0))
	_overlay.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(_overlay.snapshot().pending, 1)
	_clock.now = 1000
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	_clock.now = 6000
	RenderingServer.force_draw(false)
	assert_eq(_overlay.snapshot().frame_intervals, 1)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(_overlay.snapshot().samples, 1)
	assert_eq(_overlay.snapshot().frame_intervals, 1, "duplicates preserve frame history")
	_overlay.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_records.size(), 1)
	await _background_input(10000000)
	_overlay.set_foreground(true)
	await _observe(20000000)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _background_input(30000000)
	assert_eq(_records.size(), 2, "explicit override does not clear platform pause")
	_overlay.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _observe(40000000)


func test_teardown_disconnects_after_notification_transitions() -> void:
	var callbacks: int = RenderingServer.get_signal_connection_list("frame_post_draw").size()
	await _observe(1000)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_overlay.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_host.remove_child(_overlay)
	_overlay.free()
	assert_eq(_records.size(), 1, "inactive exit does not re-emit the closed window")
	assert_eq(_nav.get_signal_connection_list("screen_changed").size(), 0)
	assert_eq(RenderingServer.get_signal_connection_list("frame_post_draw").size(), callbacks - 1)
	_wheel().pointer_end(0, true)
	_wheel().pointer_begin(0, _wheel().tile_position(1))
	assert_eq(_wheel().current_chain(), PackedInt32Array([1]))
