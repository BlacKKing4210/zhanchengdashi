extends Node

const MainApp = preload("res://scripts/app/main.gd")

var app: Node2D
var capture_viewport: SubViewport


func _ready() -> void:
	var capture_path = OS.get_environment("ZC_ACCOUNT_AVATAR_CAPTURE")
	if capture_path.is_empty():
		push_error("ZC_ACCOUNT_AVATAR_CAPTURE is required")
		get_tree().quit(1)
		return
	var make_dir_error = DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
	if make_dir_error != OK:
		push_error("Unable to create account avatar capture directory: %s" % error_string(make_dir_error))
		get_tree().quit(1)
		return

	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(720, 1280)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.transparent_bg = false
	add_child(capture_viewport)
	app = MainApp.new()
	capture_viewport.add_child(app)
	await get_tree().process_frame
	OnlineRoom.current_user_id = "U-AVATAR-PICKER-DEMO"
	OnlineRoom.current_account_name = "AvatarDemo"
	OnlineRoom.current_username = "林地制作人"
	OnlineRoom.current_avatar_id = "animal_cat"
	OnlineRoom.current_identity_revision = 2
	OnlineRoom.current_identity_complete = true
	OnlineRoom.current_account_has_password = true
	app.set("account_center_open", true)
	app.set("account_switch_open", false)
	app.set("account_manual_login_open", false)
	app.set("card_counts", {"cat": 1, "fox": 1, "rabbit": 1, "elephant": 1})
	app.call("_sync_account_identity_editor", true)
	app.call("_set_account_fields_visible", true)
	app.call("_layout", Vector2(720, 1280))
	app.set_process(false)
	app.call("_handle_account_center_tap", (app.call("_account_avatar_entry_rect") as Rect2).get_center())
	await get_tree().process_frame
	var picker = app.get("account_avatar_picker")
	if picker != null:
		for button in picker.get("tile_buttons"):
			if not bool(button.get_meta("unlocked", true)):
				button.pressed.emit()
				break
	await get_tree().process_frame
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	var save_error = image.save_png(capture_path)
	if save_error != OK:
		push_error("Unable to save account avatar capture: %s" % error_string(save_error))
		get_tree().quit(1)
		return
	print("ACCOUNT_AVATAR_PICKER_CAPTURE_PASS: %s" % capture_path)
	app.queue_free()
	capture_viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
