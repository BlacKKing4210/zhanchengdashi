extends Node

const MainApp = preload("res://scripts/app/main.gd")

const OUTPUT_PATH = "res://output/qa/F-ZC-AUTH-001/account_identity_v2.png"
const DEMO_USER_ID = "U-1786700000-ABCDEF1234"
const DEMO_USERNAME = "薄荷汽水"

var app: Node2D
var capture_viewport: SubViewport


func _ready() -> void:
	var absolute_output = ProjectSettings.globalize_path(OUTPUT_PATH)
	var make_dir_error = DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	if make_dir_error != OK:
		push_error("Unable to create account identity capture directory: %s" % error_string(make_dir_error))
		get_tree().quit(1)
		return

	OnlineRoom.current_user_id = DEMO_USER_ID
	OnlineRoom.current_account_name = DEMO_USER_ID
	OnlineRoom.current_username = DEMO_USERNAME
	OnlineRoom.current_avatar_id = "animal_fox"
	OnlineRoom.current_identity_revision = 3
	OnlineRoom.current_identity_complete = true
	OnlineRoom.current_account_has_password = true
	OnlineRoom.current_account_is_generated = true
	OnlineRoom.current_auto_password_local = false

	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(720, 1280)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.transparent_bg = false
	add_child(capture_viewport)
	app = MainApp.new()
	capture_viewport.add_child(app)
	await get_tree().process_frame
	app.set("account_center_open", true)
	app.set("account_switch_open", false)
	app.set("account_manual_login_open", false)
	app.call("_remember_account_password", DEMO_USER_ID, "account-v2-demo-password")
	app.call("_sync_account_identity_editor", true)
	app.call("_set_account_fields_visible", true)
	app.call("_layout", Vector2(720, 1280))
	app.call("_update_account_fields_layout")
	app.set_process(false)
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	var save_error = image.save_png(absolute_output)
	if save_error != OK:
		push_error("Unable to save account identity capture: %s" % error_string(save_error))
		get_tree().quit(1)
		return
	print("ACCOUNT_IDENTITY_V2_CAPTURE_PASS: %s" % absolute_output)
	app.queue_free()
	capture_viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
