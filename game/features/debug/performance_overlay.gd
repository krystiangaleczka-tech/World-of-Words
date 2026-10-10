extends CanvasLayer
## Debug-only observer; no gameplay decisions or physical touch latency claims.

const METRICS: Script = preload("res://features/debug/performance_metrics.gd")
const PL: Translation = preload("res://locale/debug.pl.translation")
const EN: Translation = preload("res://locale/debug.en.translation")

var _metrics: RefCounted = METRICS.new()
var _clock: Clock
var _navigation: Node
var _wheel: LetterWheelView
var _label: Label
var _timer: Timer
var _active: bool = true
var _translations: Array[Translation] = []


func configure(clock: Clock, navigation: Node) -> void:
	_clock = clock
	_navigation = navigation


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	for source: Translation in [PL, EN]:
		var copy: Translation = source.duplicate() as Translation
		_translations.append(copy)
		TranslationServer.add_translation(copy)
	_label = Label.new()
	_label.name = "PerformanceReadout"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", Tokens.Type.CAPTION)
	_label.add_theme_color_override("font_color", Tokens.Palette.TEXT_MUTED)
	add_child(_label)
	_timer = Timer.new()
	_timer.wait_time = Tokens.Motion.SLOW / 1000.0
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	_timer.start()
	_navigation.screen_changed.connect(_screen_changed)
	RenderingServer.frame_post_draw.connect(_post_draw)
	_screen_changed(0)


func _screen_changed(_screen: int) -> void:
	_detach()
	_metrics.reset()
	_label.reparent(self)
	var screen: LevelScreen = _navigation.mounted_screen() as LevelScreen
	if screen != null:
		_wheel = screen.wheel
		_label.reparent(screen.body)
		screen.body.move_child(_label, 2)
	_attach()
	_refresh()


func _attach() -> void:
	if _active and is_instance_valid(_wheel):
		_wheel.configure_diagnostics(_probe_input, _probe_drawn)


func _detach() -> void:
	if is_instance_valid(_wheel):
		_wheel.configure_diagnostics()
	_wheel = null


func _probe_input() -> void:
	_metrics.record_input(_clock.monotonic_usec())


func _probe_drawn() -> void:
	_metrics.mark_drawn()


func _post_draw() -> void:
	if _active:
		_metrics.frame_post_draw(_clock.monotonic_usec())


## @api Foreground transition starts a separate sample window.
func set_foreground(active: bool) -> void:
	_active = active
	_metrics.reset()
	if is_instance_valid(_wheel):
		_wheel.configure_diagnostics()
	_attach()
	_refresh()


## @api Diagnostic snapshot; called by the refresh timer or tests, not input/frame paths.
func snapshot() -> Dictionary:
	return _metrics.snapshot()


func _refresh() -> void:
	if not is_instance_valid(_label):
		return
	var stats: Dictionary = snapshot()
	var unavailable: String = tr("debug.performance.unavailable")
	_label.text = (
		"%s\n%s\n%s"
		% [
			tr("debug.performance.fps") % ("%.1f" % stats.fps if stats.fps >= 0 else unavailable),
			(
				tr("debug.performance.latency")
				% [
					"%.2f" % stats.mean_ms if stats.mean_ms >= 0 else unavailable,
					"%.2f" % stats.max_ms if stats.max_ms >= 0 else unavailable,
				]
			),
			tr("debug.performance.coverage") % [stats.samples, stats.pending, stats.dropped],
		]
	)
	_label.visible = _active and is_instance_valid(_wheel)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_foreground(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_foreground(true)
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()


func _exit_tree() -> void:
	_detach()
	if is_instance_valid(_label):
		_label.queue_free()
	if is_instance_valid(_navigation) and _navigation.screen_changed.is_connected(_screen_changed):
		_navigation.screen_changed.disconnect(_screen_changed)
	if RenderingServer.frame_post_draw.is_connected(_post_draw):
		RenderingServer.frame_post_draw.disconnect(_post_draw)
	if is_instance_valid(_timer) and _timer.timeout.is_connected(_refresh):
		_timer.timeout.disconnect(_refresh)
	for copy: Translation in _translations:
		TranslationServer.remove_translation(copy)
	_translations.clear()
