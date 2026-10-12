extends ScreenScaffold

var preview_sheet: Sheet
var preview_toast: Toast
var _content: VBoxContainer


func _ready() -> void:
	super._ready()
	for key: String in ["open", "busy", "info", "success", "error"]:
		var button: TextButton = TextButton.new()
		button.text_key = "gallery.overlays." + key
		body.add_child(button)
		button.pressed.connect(_show.bind(key))
	preview_sheet = Sheet.new()
	preview_sheet.title_key = "gallery.overlays.title"
	add_child(preview_sheet)
	_content = VBoxContainer.new()
	for line: int in Tokens.Space.S:
		var label: Label = CatalogSurface.label()
		label.text = tr("gallery.overlays.body")
		_content.add_child(label)
	var close: TextButton = TextButton.new()
	close.text_key = "gallery.overlays.close"
	_content.add_child(close)
	close.pressed.connect(_force_close)
	var replay: TextButton = TextButton.new()
	replay.text_key = "gallery.overlays.open"
	_content.add_child(replay)
	replay.pressed.connect(_replay)
	preview_sheet.configure_content(_content)
	preview_toast = Toast.new()
	add_child(preview_toast)


func _show(key: String) -> void:
	if key in ["open", "busy"]:
		preview_sheet.busy = key == "busy"
		preview_sheet.open()
	else:
		preview_toast.show_message("gallery.overlays." + key, StringName(key))


func _exit_tree() -> void:
	if is_instance_valid(_content):
		_content.queue_free()


func _force_close() -> void:
	preview_sheet.close(true)


func _replay() -> void:
	preview_sheet.close(true)
	preview_sheet.busy = false
	preview_sheet.open()
