extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var shell: GalleryShell = GalleryShell.new()
	root.add_child(shell)
	for layout: StringName in [&"COMPACT", &"REGULAR", &"TABLET"]:
		for language: StringName in [&"PL", &"PSEUDO"]:
			for hc: bool in [false, true]:
				var percent: int = 130 if hc else 100
				assert(
					shell.configure(layout, language, hc, percent, true, true, &"Overlays") == OK
				)
				await process_frame
				await process_frame
				var screen: ScreenScaffold = shell.preview_screen()
				var toast: Toast = screen.get("preview_toast")
				toast.process_mode = Node.PROCESS_MODE_DISABLED
				var key: String = (
					"nav.toast.purchases_restored" if hc else "nav.toast.backup_restored"
				)
				assert(toast.show_message(key, &"success" if hc else &"info") == OK)
				await process_frame
				RenderingServer.force_draw(false)
				assert(toast.visible)
				var image: Image = shell.preview_viewport().get_texture().get_image()
				var path: String = (
					"/workspace/scratch/T-0243-captures/%s-%s-%s%d.png"
					% [layout, language, "hc" if hc else "default", percent]
				)
				assert(image.save_png(path) == OK)
				print("CAPTURE ", path, " ", image.get_size())
	root.remove_child(shell)
	shell.queue_free()
	await process_frame
	quit()
