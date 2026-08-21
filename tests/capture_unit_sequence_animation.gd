extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const UnitMotionFeedback = preload("res://scripts/app/systems/unit_motion_feedback.gd")
const UnitSequenceAnimation = preload("res://scripts/app/systems/unit_sequence_animation.gd")

var app: Node
var capture_viewport: SubViewport
var output_dir = ""
var failures = 0


func _ready() -> void:
	print("FOX_SEQUENCE_CAPTURE_STAGE: ready")
	output_dir = OS.get_environment("ZC_FOX_SEQUENCE_CAPTURE_DIR")
	if output_dir.is_empty():
		_fail("ZC_FOX_SEQUENCE_CAPTURE_DIR must name the output directory.")
		_finish()
		return
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		_fail("Unable to create capture directory: %s" % error_string(make_dir_error))
		_finish()
		return

	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(720, 1280)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.transparent_bg = false
	add_child(capture_viewport)
	app = MainApp.new()
	capture_viewport.add_child(app)
	print("FOX_SEQUENCE_CAPTURE_STAGE: app_added")
	await get_tree().process_frame
	await get_tree().process_frame
	print("FOX_SEQUENCE_CAPTURE_STAGE: app_initialized")
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	app.call("_spawn_unit", BoardRules.PLAYER, player_base, "fox", false, 0, {"skill_triggers_enabled": false})
	app.call("_spawn_unit", BoardRules.PLAYER, player_base, "rabbit", false, 0, {"skill_triggers_enabled": false})
	_position_units()
	app.set_process(false)

	_set_motion_state("")
	print("FOX_SEQUENCE_CAPTURE_STAGE: idle")
	await _capture("fox_sequence_idle_rabbit_generic.png")
	_set_motion_state("move")
	print("FOX_SEQUENCE_CAPTURE_STAGE: move")
	await _capture("fox_sequence_move_rabbit_generic.png")
	_set_motion_state("attack")
	print("FOX_SEQUENCE_CAPTURE_STAGE: attack")
	await _capture("fox_sequence_attack_rabbit_generic.png")

	var status = UnitSequenceAnimation.manifest_status()
	if not bool(status.get("valid", false)):
		_fail("Sequence manifest became invalid during runtime capture: %s" % str(status.get("errors", [])))
	if failures == 0:
		print("FOX_SEQUENCE_FALLBACK_CAPTURE_PASS: %s" % output_dir)
	_finish()


func _position_units() -> void:
	var all_units: Array = app.get("units")
	if all_units.size() < 2:
		_fail("Expected fox and rabbit units for runtime capture.")
		return
	var center = Vector2(360.0, 520.0)
	all_units[all_units.size() - 2]["pos"] = app.call("_canvas_to_world", center + Vector2(-76.0, 0.0))
	all_units[all_units.size() - 1]["pos"] = app.call("_canvas_to_world", center + Vector2(76.0, 0.0))
	app.set("units", all_units)


func _set_motion_state(kind: String) -> void:
	var all_units: Array = app.get("units")
	for index in range(maxi(0, all_units.size() - 2), all_units.size()):
		var unit: Dictionary = all_units[index]
		unit["motion_kind"] = ""
		unit["motion_time"] = 0.0
		unit["motion_duration"] = 0.0
		unit["motion_moving"] = false
		unit["motion_move_phase"] = 0.25
		unit["motion_direction"] = Vector2.RIGHT
		unit["motion_move_direction"] = Vector2.RIGHT
		if kind == "move":
			unit["motion_moving"] = true
		elif kind == "attack":
			unit["motion_kind"] = UnitMotionFeedback.KIND_ATTACK
			unit["motion_duration"] = UnitMotionFeedback.ATTACK_DURATION
			unit["motion_time"] = UnitMotionFeedback.ATTACK_DURATION * 0.5
		all_units[index] = unit
	app.set("units", all_units)


func _capture(file_name: String) -> void:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	if image.get_size() != capture_viewport.size:
		_fail("Unexpected capture size for %s: %s" % [file_name, str(image.get_size())])
		return
	var output_path = output_dir.path_join(file_name)
	var save_error = image.save_png(output_path)
	if save_error != OK:
		_fail("Unable to save %s: %s" % [output_path, error_string(save_error)])


func _fail(message: String) -> void:
	failures += 1
	push_error(message)


func _finish() -> void:
	if app != null:
		app.queue_free()
	if capture_viewport != null:
		capture_viewport.queue_free()
	get_tree().quit(failures)
