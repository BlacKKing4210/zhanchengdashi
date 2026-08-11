extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

const OUTPUT_PATH = "res://output/qa/F-ZC-001-speed-feedback/speed_feedback_hidden_720x1280.png"

var app: Node


func _ready() -> void:
	var output_dir = ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		_fail("Unable to create speed feedback QA output: %s" % error_string(make_dir_error))
		return

	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	app.call("_layout", get_viewport().get_visible_rect().size)
	var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	app.call("_spawn_unit", BoardRules.PLAYER, player_base, "horse")
	var units: Array = app.get("units")
	if units.is_empty():
		_fail("Unable to spawn speed feedback QA animal.")
		return
	var unit_index = units.size() - 1
	var unit: Dictionary = units[unit_index]
	unit["pos"] = app.call("_hex_center", player_base) + Vector2(0.0, -180.0)
	unit["tile"] = app.call("_tile_at_world", unit["pos"])
	units[unit_index] = unit
	app.set("units", units)
	app.set("selected_unit_id", -1)
	app.set("effects", [])
	app.call("_add_aura_speed", BoardRules.PLAYER, Vector2.ZERO, 1.20, true)
	app.call("_add_aura_speed_flat", BoardRules.PLAYER, Vector2.ZERO, 20.0, true)
	app.call("_show_unit_value_feedback", unit_index, "attack", 1.0)
	var effects: Array = app.get("effects")
	effects.append({
		"kind": "unit_value",
		"stat": "speed",
		"unit_id": int(unit.get("id", -1)),
		"pos": Vector2(unit["pos"]) + Vector2(0, -34),
		"amount": 7490.0,
		"suffix": "",
		"time": 0.9,
		"duration": 0.9,
	})
	app.set("effects", effects)
	app.set_process(false)
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	if image.get_size() != Vector2i(720, 1280):
		_fail("Expected 720x1280 capture, got %s." % image.get_size())
		return
	var output_path = ProjectSettings.globalize_path(OUTPUT_PATH)
	var save_error = image.save_png(output_path)
	if save_error != OK:
		_fail("Unable to save speed feedback QA capture: %s" % error_string(save_error))
		return
	print("SPEED_FEEDBACK_CAPTURE_PASS: %s" % output_path)
	app.queue_free()
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	if app != null:
		app.queue_free()
	get_tree().quit(1)
