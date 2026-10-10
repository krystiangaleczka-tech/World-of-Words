extends GutTest

const METRICS: Script = preload("res://features/debug/performance_metrics.gd")
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


var _inputs: int = 0
var _draws: int = 0


func test_all_events_and_real_draw_boundary() -> void:
	var metrics: RefCounted = METRICS.new()
	metrics.record_input(1000)
	metrics.record_input(3000)
	metrics.frame_post_draw(4000)
	assert_eq(metrics.snapshot().samples, 0, "no line draw, no consumption")
	metrics.mark_drawn()
	metrics.record_input(5000)
	metrics.frame_post_draw(11000)
	var stats: Dictionary = metrics.snapshot()
	assert_eq(stats.samples, 2)
	assert_eq(stats.pending, 1, "input after draw waits for the next drawn line")
	assert_eq(stats.mean_ms, 9.0)
	assert_eq(stats.max_ms, 10.0)
	assert_almost_eq(stats.fps, 1000000.0 / 7000.0, 0.01)
	metrics.frame_post_draw(15000)
	assert_eq(metrics.snapshot().pending, 1)
	metrics.mark_drawn()
	metrics.frame_post_draw(21000)
	assert_eq(metrics.snapshot().samples, 3)
	assert_eq(metrics.snapshot().max_ms, 16.0)
	assert_eq(metrics.snapshot().pending, 0)


func test_zero_overflow_wrap_and_foreground_reset() -> void:
	var metrics: RefCounted = METRICS.new()
	metrics.record_input(0)
	metrics.mark_drawn()
	metrics.frame_post_draw(0)
	assert_eq(metrics.snapshot().mean_ms, 0.0, "zero is available")
	for timestamp: int in METRICS.CAPACITY + 3:
		metrics.record_input(timestamp)
	assert_eq(metrics.snapshot().pending, METRICS.CAPACITY)
	assert_eq(metrics.snapshot().dropped, 3)
	metrics.mark_drawn()
	metrics.frame_post_draw(1000)
	assert_eq(metrics.snapshot().samples, METRICS.CAPACITY + 1)
	metrics.record_input(1100)
	metrics.mark_drawn()
	metrics.frame_post_draw(1200)
	assert_eq(metrics.snapshot().samples, METRICS.CAPACITY + 2, "ring wraps safely")
	metrics.reset()
	assert_eq(metrics.snapshot().samples, 0)
	assert_eq(metrics.snapshot().pending, 0)
	assert_eq(metrics.snapshot().dropped, 0)
	assert_eq(metrics.snapshot().mean_ms, -1.0)
	metrics.frame_post_draw(1000000)
	assert_eq(metrics.snapshot().fps, -1.0, "background gap excluded")
	metrics.frame_post_draw(1010000)
	assert_eq(metrics.snapshot().fps, 100.0)


func test_wheel_probes_keep_pointer_ownership() -> void:
	var wheel: LetterWheelView = LetterWheelView.new()
	wheel.size = Vector2(600, 600)
	add_child_autofree(wheel)
	wheel.set_letters(PackedStringArray(["K", "O", "T"]))
	wheel.configure_diagnostics(_probe_input, _probe_drawn)
	wheel.pointer_begin(0, Vector2(-100, -100))
	assert_eq(_inputs, 0, "miss rejected")
	wheel.pointer_begin(0, wheel.tile_position(0))
	assert_eq(_inputs, 1)
	wheel.pointer_begin(1, wheel.tile_position(1))
	wheel.pointer_move(1, wheel.tile_position(1))
	wheel.pointer_end(1)
	assert_eq(_inputs, 1, "secondary pointer ignored")
	wheel.pointer_move(0, wheel.tile_position(1))
	assert_eq(_inputs, 2)
	watch_signals(wheel)
	wheel.pointer_end(0, true)
	assert_eq(_inputs, 3)
	assert_false(wheel.is_dragging())
	assert_signal_not_emitted(wheel, "word_attempted")
	wheel.set_locked(true)
	wheel.pointer_begin(0, wheel.tile_position(0))
	assert_eq(_inputs, 3, "locked input ignored")
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	assert_gt(_draws, 0, "real CanvasItem draw invokes the installed probe")
	wheel.configure_diagnostics()
	wheel.set_locked(false)
	wheel.pointer_begin(0, wheel.tile_position(0))
	assert_eq(_inputs, 3, "detached observer")
	wheel.configure_diagnostics(_probe_input, _probe_drawn)
	wheel.set_locked(true)
	assert_eq(_inputs, 3, "layout/lock cancellation is not dispatched input")


func _probe_input() -> void:
	_inputs += 1


func _probe_drawn() -> void:
	_draws += 1


func test_overlay_boot_navigation_focus_and_cleanup() -> void:
	var clock: FixedClock = FixedClock.new()
	var save: Node = SAVE_SCRIPT.new()
	var content: Node = CONTENT_SCRIPT.new()
	var nav: Node = NAV_SCRIPT.new()
	add_child_autofree(save)
	add_child_autofree(content)
	add_child_autofree(nav)
	save.initialize(clock)
	save.configure(MemoryStorage.new())
	nav.configure(save, Config, content)
	var host: Node = Node.new()
	add_child_autofree(host)
	assert_eq(nav.start(host, "res://tests/fixtures/content"), OK)
	TranslationServer.set_locale("pl")
	var original_copy: String = TranslationServer.translate("debug.performance.latency")
	var original_callbacks: int = (
		RenderingServer.get_signal_connection_list("frame_post_draw").size()
	)
	var overlay: CanvasLayer = OVERLAY.new()
	overlay.configure(clock, nav)
	host.add_child(overlay)
	assert_eq(
		RenderingServer.get_signal_connection_list("frame_post_draw").size(), original_callbacks + 1
	)
	await get_tree().process_frame
	var readout: Label = nav.mounted_screen().body.get_node("PerformanceReadout") as Label
	assert_true(readout.text.contains("Wejście→render"))
	assert_true(readout.text.contains("—"), "unavailable before input")
	var wheel: LetterWheelView = (nav.mounted_screen() as LevelScreen).wheel
	clock.now = 1000
	wheel.pointer_begin(0, wheel.tile_position(0))
	assert_eq(overlay.snapshot().pending, 1, "observer attaches to real mounted wheel")
	clock.now = 2000
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	assert_eq(overlay.snapshot().samples, 1, "real draw/post_draw consumes the observed event")
	assert_eq(overlay.snapshot().mean_ms, 1.0)
	TranslationServer.set_locale("en")
	assert_true(readout.text.contains("Input→render"))
	assert_true(readout.text.contains("Samples: 1"))
	assert_true(readout.text.contains("1.00/1.00 ms"))
	TranslationServer.set_locale("pl")
	assert_true(readout.text.contains("Próbki: 1"))
	overlay.set_foreground(false)
	assert_eq(overlay.snapshot().samples, 0)
	wheel.pointer_move(0, wheel.tile_position(1))
	assert_eq(overlay.snapshot().pending, 0)
	overlay.set_foreground(true)
	wheel.pointer_move(0, wheel.tile_position(2))
	assert_eq(overlay.snapshot().pending, 1)
	assert_eq(nav.go_home(), OK)
	assert_eq(overlay.snapshot().pending, 0)
	assert_eq(nav.go_to_level(1), OK)
	wheel = (nav.mounted_screen() as LevelScreen).wheel
	wheel.pointer_begin(0, wheel.tile_position(0))
	assert_eq(overlay.snapshot().pending, 1)
	host.remove_child(overlay)
	overlay.free()
	assert_eq(
		RenderingServer.get_signal_connection_list("frame_post_draw").size(), original_callbacks
	)
	assert_eq(
		TranslationServer.translate("debug.performance.latency"),
		original_copy,
		"overlay releases its independently owned translations"
	)
	assert_eq(nav.get_signal_connection_list("screen_changed").size(), 0)
	assert_false(wheel.is_locked())
	wheel.pointer_move(0, wheel.tile_position(1))
	assert_eq(wheel.current_chain(), PackedInt32Array([0, 1]))
	var boot: Node = load("res://services/nav/boot.tscn").instantiate()
	boot.content_root = "res://tests/fixtures/content"
	add_child_autofree(boot)
	assert_true(boot.has_node("PerformanceOverlay"), "real boot owns diagnostics")
	assert_eq(boot.get_node("PerformanceOverlay").snapshot().samples, 0)
