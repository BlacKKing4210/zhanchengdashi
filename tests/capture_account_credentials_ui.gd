extends Node

const MainApp = preload("res://scripts/app/main.gd")

const OUTPUT_DIR = "res://temp/qa/F-ZC-AUTH-001"
const DEMO_ACCOUNT = "ProducerAccount"
const DEMO_PASSWORD = "safe-password-demo"

var app: Node2D
var capture_viewport: SubViewport


func _ready() -> void:
	var output_dir = ProjectSettings.globalize_path(OUTPUT_DIR)
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		push_error("Unable to create account UI capture directory: %s" % error_string(make_dir_error))
		get_tree().quit(1)
		return

	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(720, 1280)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(capture_viewport)
	app = MainApp.new()
	capture_viewport.add_child(app)
	await get_tree().process_frame
	OnlineRoom.current_user_id = "U-ACCOUNT-UI-DEMO"
	OnlineRoom.current_account_name = DEMO_ACCOUNT
	OnlineRoom.current_account_has_password = true
	app.set("account_center_open", true)
	app.set("account_switch_open", false)
	app.set("account_manual_login_open", false)
	app.call("_remember_account_password", DEMO_ACCOUNT, DEMO_PASSWORD)
	app.call("_set_account_fields_visible", false)
	app.call("_layout", Vector2(720, 1280))
	app.set_process(false)
	await _capture(output_dir.path_join("account_credentials_masked.png"))

	app.call("_handle_account_center_tap", (app.call("_account_password_view_rect") as Rect2).get_center())
	await _capture(output_dir.path_join("account_credentials_revealed.png"))
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		app.call("_handle_account_center_tap", (app.call("_account_password_copy_rect") as Rect2).get_center())
		await _capture(output_dir.path_join("account_credentials_copy.png"))
		app.call("_clear_account_clipboard_if_unchanged")

	print("ACCOUNT_CREDENTIALS_UI_CAPTURE_PASS: %s" % output_dir)
	app.queue_free()
	get_tree().quit(0)


func _capture(path: String) -> void:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	var save_error = image.save_png(path)
	if save_error != OK:
		push_error("Unable to save account UI capture %s: %s" % [path, error_string(save_error)])
		get_tree().quit(1)
