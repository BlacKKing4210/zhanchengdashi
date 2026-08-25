extends Node

const MainApp = preload("res://scripts/app/main.gd")

var app: Node2D
var capture_viewport: SubViewport


func _ready() -> void:
	var capture_path = OS.get_environment("ZC_GM_PANEL_CAPTURE")
	if capture_path.is_empty():
		push_error("ZC_GM_PANEL_CAPTURE is required")
		get_tree().quit(1)
		return
	var make_dir_error = DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
	if make_dir_error != OK:
		push_error("Unable to create GM panel capture directory: %s" % error_string(make_dir_error))
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
	OnlineRoom.current_user_id = ""
	OnlineRoom.current_account_name = ""
	app.set("screen", "battle")
	app.set("battle_mode", "classic")
	app.set("online_match_id", "")
	app.set("pause_open", false)
	app.call("_reset_battle")
	app.set_process(false)
	if not bool(app.call("_toggle_gm_panel")):
		push_error("Unable to open the runtime GM panel in the debug capture")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	var save_error = image.save_png(capture_path)
	if save_error != OK:
		push_error("Unable to save GM panel capture: %s" % error_string(save_error))
		get_tree().quit(1)
		return
	print("RUNTIME_GM_PANEL_CAPTURE_PASS: %s" % capture_path)
	app.queue_free()
	capture_viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
