extends Node

const MainApp = preload("res://scripts/app/main.gd")
const BoardRules = preload("res://scripts/app/systems/board_rules.gd")

var app: Node
var capture_viewport: SubViewport


func _ready() -> void:
	capture_viewport = SubViewport.new()
	capture_viewport.size = _target_size()
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.transparent_bg = false
	add_child(capture_viewport)
	app = MainApp.new()
	capture_viewport.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	var target_screen = OS.get_environment("ZC_RENDER_CLARITY_SCREEN").to_lower()
	if target_screen == "battle":
		app.set("battle_mode", "classic")
		app.set("screen", "battle")
		app.call("_reset_battle")
		var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
		var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
		app.call("_spawn_unit", BoardRules.PLAYER, player_base, "rabbit", false, 0, {"skill_triggers_enabled": false})
		app.call("_spawn_unit", BoardRules.ENEMY, enemy_base, "wolf", false, 0, {"skill_triggers_enabled": false})
	else:
		target_screen = "lobby"
		app.set("screen", "lobby")
	app.set_process(false)
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	if image.get_size() != capture_viewport.size:
		_fail("Expected %s capture, got %s." % [str(capture_viewport.size), str(image.get_size())])
		return
	var output_path = OS.get_environment("ZC_RENDER_CLARITY_CAPTURE")
	if output_path.is_empty():
		_fail("ZC_RENDER_CLARITY_CAPTURE must name the output PNG.")
		return
	var output_dir = output_path.get_base_dir()
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		_fail("Unable to create capture directory: %s" % error_string(make_dir_error))
		return
	var save_error = image.save_png(output_path)
	if save_error != OK:
		_fail("Unable to save rendering clarity capture: %s" % error_string(save_error))
		return
	print("RENDERING_CLARITY_CAPTURE_PASS screen=%s viewport=%s scale=%.4f path=%s" % [
		target_screen,
		str(image.get_size()),
		float(app.get("canvas_scale")),
		output_path,
	])
	_cleanup_and_quit(0)


func _target_size() -> Vector2i:
	var requested = OS.get_environment("ZC_RENDER_CLARITY_SIZE")
	var parts = requested.to_lower().split("x", false)
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		var width = int(parts[0])
		var height = int(parts[1])
		if width > 0 and height > 0:
			return Vector2i(width, height)
	return Vector2i(540, 960)


func _fail(message: String) -> void:
	push_error(message)
	_cleanup_and_quit(1)


func _cleanup_and_quit(code: int) -> void:
	if app != null:
		app.queue_free()
	if capture_viewport != null:
		capture_viewport.queue_free()
	get_tree().quit(code)
