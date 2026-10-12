extends GutTest

const SHEET_SCENE: PackedScene = preload("res://ui/components/Sheet.tscn")
const HC: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")
var _locale: String
var _pseudo: bool
var _motion: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_motion = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	Tokens.reduced_motion = true


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _viewport() -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	return viewport


func _sheet(viewport: SubViewport) -> Sheet:
	var sheet: Sheet = SHEET_SCENE.instantiate()
	sheet.title_key = "gallery.overlays.title"
	viewport.add_child(sheet)
	return sheet


func _content(rows: int = 3) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	add_child_autofree(column)
	remove_child(column)
	for row: int in rows:
		var label: Label = CatalogSurface.label()
		label.text = tr("gallery.overlays.body")
		column.add_child(label)
	return column


func _click(viewport: SubViewport, point: Vector2) -> void:
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		viewport.push_input(event)


func _action(viewport: SubViewport, name: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = true
	viewport.push_input(event)


func _toast(viewport: SubViewport) -> Toast:
	var toast: Toast = load("res://ui/components/Toast.tscn").instantiate()
	viewport.add_child(toast)
	return toast


func test_content_atomic_replacement_exit_and_reentry() -> void:
	var viewport: SubViewport = _viewport()
	var sheet: Sheet = _sheet(viewport)
	var first: VBoxContainer = _content()
	var second: VBoxContainer = _content()
	assert_eq(sheet.configure_content(first), OK)
	var parent: Node = first.get_parent()
	assert_eq(sheet.configure_content(null), ERR_INVALID_PARAMETER)
	assert_eq(sheet.configure_content(sheet), ERR_INVALID_PARAMETER)
	var foreign: Control = Control.new()
	viewport.add_child(foreign)
	assert_eq(sheet.configure_content(foreign), ERR_ALREADY_IN_USE)
	assert_same(first.get_parent(), parent)
	assert_eq(sheet.configure_content(second), OK)
	assert_null(first.get_parent())
	assert_true(is_instance_valid(first))
	viewport.remove_child(sheet)
	assert_null(second.get_parent())
	viewport.add_child(sheet)
	assert_same(second.get_parent(), parent)
	assert_eq(sheet.open(), OK)
	assert_eq(sheet.state, &"open")


func test_single_sheet_busy_and_nondismissible_replacement() -> void:
	var viewport: SubViewport = _viewport()
	var first: Sheet = _sheet(viewport)
	var second: Sheet = _sheet(viewport)
	assert_eq(first.open(), OK)
	first.busy = true
	assert_eq(second.open(), ERR_BUSY)
	assert_false(second.visible)
	assert_true(first.handle_back())
	assert_eq(first.state, &"open")
	first.busy = false
	first.dismissible = false
	assert_eq(second.open(), ERR_BUSY)
	assert_false(first.close())
	first.dismissible = true
	watch_signals(first)
	assert_eq(second.open(), OK)
	assert_eq(first.state, &"closed")
	assert_eq(second.state, &"open")
	assert_signal_emit_count(first, "dismissed", 1)
	assert_true(second.close(true))
	assert_false(second.handle_back())


func test_native_scrim_blocks_underlying_and_close_button_back() -> void:
	var viewport: SubViewport = _viewport()
	var sheet: Sheet = _sheet(viewport)
	var underlying: TextButton = TextButton.new()
	underlying.text_key = "gallery.overlays.open"
	underlying.position = Vector2(40, 40)
	viewport.add_child(underlying)
	sheet.configure_content(_content())
	await get_tree().process_frame
	watch_signals(sheet)
	watch_signals(underlying)
	sheet.open()
	await get_tree().process_frame
	_click(viewport, underlying.position + underlying.size / 2)
	assert_signal_emit_count(underlying, "pressed", 0)
	assert_signal_emitted_with_parameters(sheet, "dismissed", [&"scrim"])
	sheet.open()
	await get_tree().process_frame
	var close: IconButton = sheet.find_children("*", "IconButton", true, false)[0] as IconButton
	_click(viewport, close.get_global_rect().get_center())
	assert_signal_emitted_with_parameters(sheet, "dismissed", [&"button"])
	sheet.open()
	_action(viewport, &"ui_cancel")
	assert_eq(sheet.state, &"closed")
	sheet.open()
	sheet.busy = true
	sheet.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(sheet.state, &"open")
	assert_true(close.loading)
	sheet.busy = false
	sheet.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(sheet.state, &"closed")


func test_header_gesture_short_up_secondary_and_cancel() -> void:
	var viewport: SubViewport = _viewport()
	var sheet: Sheet = _sheet(viewport)
	sheet.open()
	await get_tree().process_frame
	var header: HBoxContainer = (
		sheet.find_children("*", "HBoxContainer", true, false)[0] as HBoxContainer
	)
	for end: float in [-100.0, float(Tokens.Space.S), float(Tokens.Space.L * 2)]:
		var down: InputEventScreenTouch = InputEventScreenTouch.new()
		down.index = 3
		down.pressed = true
		down.position = Vector2(Tokens.Space.M, Tokens.Space.M)
		header.gui_input.emit(down)
		var other: InputEventScreenTouch = InputEventScreenTouch.new()
		other.index = 4
		other.pressed = false
		other.position = Vector2(Tokens.Space.M, Tokens.Space.L * 4)
		header.gui_input.emit(other)
		assert_eq(sheet.state, &"open")
		var up: InputEventScreenTouch = InputEventScreenTouch.new()
		up.index = 3
		up.position = down.position + Vector2(0, end)
		header.gui_input.emit(up)
		assert_eq(sheet.state, &"closed" if end > Tokens.Space.L else &"open")
		if sheet.state == &"closed":
			sheet.open()
	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.index = 1
	down.pressed = true
	header.gui_input.emit(down)
	var up: InputEventScreenTouch = InputEventScreenTouch.new()
	up.index = 1
	up.position.y = Tokens.Space.L * 3
	up.canceled = true
	header.gui_input.emit(up)
	assert_eq(sheet.state, &"open")


func test_focus_trap_native_tab_disabled_and_restore() -> void:
	var viewport: SubViewport = _viewport()
	var outside: TextButton = TextButton.new()
	outside.text_key = "gallery.overlays.open"
	viewport.add_child(outside)
	outside.grab_focus()
	var sheet: Sheet = _sheet(viewport)
	var content: VBoxContainer = _content(0)
	var buttons: Array[TextButton] = []
	for i: int in 3:
		var button: TextButton = TextButton.new()
		button.text_key = "gallery.overlays.close"
		button.disabled = i == 1
		content.add_child(button)
		buttons.append(button)
	sheet.configure_content(content)
	sheet.open()
	await get_tree().process_frame
	var close: Control = viewport.gui_get_focus_owner()
	assert_true(sheet.is_ancestor_of(close))
	_action(viewport, &"ui_focus_next")
	assert_same(viewport.gui_get_focus_owner(), buttons[0])
	_action(viewport, &"ui_focus_next")
	assert_same(viewport.gui_get_focus_owner(), buttons[2])
	outside.grab_focus()
	assert_true(
		(
			sheet.is_ancestor_of(viewport.gui_get_focus_owner())
			or viewport.gui_get_focus_owner() == sheet
		)
	)
	_action(viewport, &"ui_focus_prev")
	assert_false(viewport.gui_get_focus_owner() == buttons[1])
	sheet.close()
	assert_same(viewport.gui_get_focus_owner(), outside)


func test_safe_cap_scroll_theme_locale_and_live_reduction() -> void:
	var viewport: SubViewport = _viewport()
	var scaffold: ScreenScaffold = load("res://ui/components/ScreenScaffold.tscn").instantiate()
	scaffold.size = Vector2(viewport.size)
	scaffold.debug_insets = Rect2(32, 64, 48, 96)
	viewport.add_child(scaffold)
	var sheet: Sheet = SHEET_SCENE.instantiate()
	sheet.title_key = "gallery.overlays.title"
	sheet.theme = HC
	scaffold.add_child(sheet)
	sheet.configure_content(_content(30))
	for frame: int in 4:
		await get_tree().process_frame
	sheet.open()
	for frame: int in 4:
		await get_tree().process_frame
	var panel: PanelContainer = sheet.get_node("Panel") as PanelContainer
	var safe: Rect2 = scaffold.body.get_global_rect()
	assert_lte(panel.size.y, safe.size.y * Tokens.Layout.SHEET_MAX_RATIO)
	assert_lte(panel.size.x, float(Tokens.Layout.MAX_CONTENT_WIDTH))
	assert_almost_eq(panel.get_global_rect().end.y, safe.end.y, 1.0)
	assert_true(
		(sheet.find_child("Scroll", true, false) as ScrollContainer).get_v_scroll_bar().visible
	)
	assert_eq(
		(panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, Tokens.PaletteHC.SURFACE
	)
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	sheet.title_key = "gallery.overlays.title"
	assert_eq(sheet.accessibility_name, sheet.tr(sheet.title_key))
	Tokens.reduced_motion = false
	sheet.close()
	sheet.open()
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(sheet.state, &"open")
	scaffold.size = Vector2(1440, 1920)
	viewport.size = Vector2i(1440, 1920)
	await get_tree().process_frame
	assert_lte(panel.size.x, float(Tokens.Layout.MAX_CONTENT_WIDTH))


func test_toast_atomic_replacement_hold_and_timeout() -> void:
	var viewport: SubViewport = _viewport()
	var first: Toast = _toast(viewport)
	var second: Toast = _toast(viewport)
	assert_eq(first.show_message("gallery.overlays.info"), OK)
	var timer: Timer = first.find_children("*", "Timer", true, false)[0] as Timer
	assert_almost_eq(timer.wait_time, float(Tokens.Motion.TOAST_HOLD) / 1000.0, 0.00001)
	assert_gt(timer.time_left, 0.0)
	assert_eq(first.show_message("", &"error"), ERR_INVALID_PARAMETER)
	assert_eq(first.show_message("gallery.overlays.error", &"urgent"), ERR_INVALID_PARAMETER)
	assert_eq(first.text_key, "gallery.overlays.info")
	assert_true(first.visible)
	assert_eq(second.show_message("gallery.overlays.success", &"success"), OK)
	assert_false(first.visible)
	assert_true(timer.is_stopped())
	assert_true(second.visible)
	var next_timer: Timer = second.find_children("*", "Timer", true, false)[0] as Timer
	next_timer.timeout.emit()
	assert_false(second.visible)
	assert_true(next_timer.is_stopped())


func test_toast_passivity_anchor_wrap_locale_and_reentry() -> void:
	var viewport: SubViewport = _viewport()
	var anchor: Control = Control.new()
	anchor.position = Vector2(40, 1400)
	anchor.size = Vector2(400, 100)
	viewport.add_child(anchor)
	var toast: Toast = _toast(viewport)
	toast.theme = HC
	assert_eq(toast.show_message("gallery.overlays.body", &"error", null, anchor), OK)
	for frame: int in 4:
		await get_tree().process_frame
	assert_lte(toast.position.y + toast.size.y, anchor.position.y)
	for node: Control in toast.find_children("*", "Control", true, false):
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(node.focus_mode, Control.FOCUS_NONE)
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var texture: TextureRect = (
		toast.find_children("*", "TextureRect", true, false)[0] as TextureRect
	)
	assert_same(texture.texture, Toast.GLYPHS[&"error"])
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	toast.show_message("gallery.overlays.body", &"success")
	assert_eq(toast.accessibility_name, toast.tr(toast.text_key))
	viewport.remove_child(toast)
	assert_false(toast.visible)
	viewport.add_child(toast)
	assert_eq(toast.show_message("gallery.overlays.info"), OK)
	assert_true(toast.visible)


func test_overlay_gallery_inventory() -> void:
	var gallery: GalleryShell = load("res://ui/gallery/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	assert_eq(gallery.configure(&"COMPACT", &"PSEUDO", true, 130, true, true, &"Overlays"), OK)
	await get_tree().process_frame
	assert_eq(gallery.preview_screen().find_children("*", "Sheet", true, false).size(), 1)
	assert_eq(gallery.preview_screen().find_children("*", "Toast", true, false).size(), 1)
	gallery.free()


func test_reentrant_sheet_open_is_rejected_during_replacement() -> void:
	var viewport: SubViewport = _viewport()
	var first: Sheet = _sheet(viewport)
	var second: Sheet = _sheet(viewport)
	var results: Array[Error] = []
	var spawned: Array[Sheet] = []
	first.dismissed.connect(
		func(_reason: StringName) -> void:
			var incoming: Sheet = _sheet(viewport)
			incoming.busy = true
			spawned.append(incoming)
			results.append(incoming.open())
	)
	first.open()
	assert_eq(second.open(), OK)
	assert_eq(results, [ERR_BUSY])
	assert_eq(spawned[0].state, &"closed")
	assert_eq(second.state, &"open")


func test_toast_nested_owner_bounds_and_resize() -> void:
	var viewport: SubViewport = _viewport()
	var parent: Control = Control.new()
	parent.position = Vector2(120, 200)
	parent.size = Vector2(500, 900)
	viewport.add_child(parent)
	var toast: Toast = Toast.new()
	parent.add_child(toast)
	toast.show_message("gallery.overlays.body")
	for frame: int in 4:
		await get_tree().process_frame
	assert_lte(toast.size.x, parent.size.x)
	assert_true(Rect2(Vector2.ZERO, parent.size).encloses(toast.get_rect()))
	parent.size = Vector2(400, 700)
	for frame: int in 4:
		await get_tree().process_frame
	assert_lte(toast.size.x, parent.size.x)
	assert_true(Rect2(Vector2.ZERO, parent.size).encloses(toast.get_rect()))


func test_native_header_touch_swipe_and_cancel() -> void:
	var viewport: SubViewport = _viewport()
	var sheet: Sheet = _sheet(viewport)
	sheet.open()
	await get_tree().process_frame
	var header: HBoxContainer = (
		sheet.find_children("*", "HBoxContainer", true, false)[0] as HBoxContainer
	)
	for canceled: bool in [true, false]:
		var point: Vector2 = (
			header.get_global_rect().position + Vector2(Tokens.Space.M, Tokens.Space.M)
		)
		var down: InputEventScreenTouch = InputEventScreenTouch.new()
		down.pressed = true
		down.index = 6
		down.position = point
		viewport.push_input(down)
		var up: InputEventScreenTouch = InputEventScreenTouch.new()
		up.index = 6
		up.position = point + Vector2(0, Tokens.Space.L * 2)
		up.canceled = canceled
		viewport.push_input(up)
		assert_eq(sheet.state, &"open" if canceled else &"closed")


func test_focus_callback_cannot_interrupt_open_transaction() -> void:
	var viewport: SubViewport = _viewport()
	var first: Sheet = _sheet(viewport)
	var second: Sheet = _sheet(viewport)
	var results: Array[Error] = []
	var callback: Callable = func(_focused: Control) -> void:
		if results.is_empty():
			results.append(second.open())
	viewport.gui_focus_changed.connect(callback)
	assert_eq(first.open(), OK)
	assert_eq(results, [ERR_BUSY])
	assert_eq(first.state, &"open")
	assert_true(first.visible)
	assert_eq(second.state, &"closed")
	viewport.gui_focus_changed.disconnect(callback)
