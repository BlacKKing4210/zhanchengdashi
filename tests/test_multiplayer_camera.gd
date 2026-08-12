extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

const HEX_SIZE = 43.0
const POSITION_EPSILON = 0.01

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	app.call("_start_multiplayer_match", "3v3_plateau", 3)
	app.call("_layout", app.get_viewport().get_visible_rect().size)
	await get_tree().process_frame
	_test_camera_drag_keeps_world_state_stable()
	await get_tree().process_frame
	if failures == 0:
		print("Multiplayer camera regression tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_camera_drag_keeps_world_state_stable() -> void:
	var player_base_key: Vector2i = app.call("_multiplayer_base_key", BoardRules.PLAYER)
	var enemy_base_key: Vector2i = app.call("_multiplayer_base_key", 4)
	var player_base_world = MultiplayerRules.hex_center(player_base_key, Vector2.ZERO, HEX_SIZE)
	var enemy_base_world = MultiplayerRules.hex_center(enemy_base_key, Vector2.ZERO, HEX_SIZE)
	_expect_float_close(float(app.call("_battle_camera_zoom")), 1.30, "default axial battle camera is 30 percent closer")
	_expect_vector_close(
		Vector2(app.call("_world_to_canvas", enemy_base_world)) - Vector2(app.call("_world_to_canvas", player_base_world)),
		(enemy_base_world - player_base_world) * 1.30,
		"camera zoom scales world projection without changing world coordinates"
	)
	var zoomed_hex_points: PackedVector2Array = app.call("_hex_points", Vector2.ZERO)
	_expect_float_close(zoomed_hex_points[0].length(), HEX_SIZE * 1.30, "hex geometry uses the 1.30 camera zoom")
	var rabbit_card: Dictionary = app.call("_card_by_id", "rabbit")
	_expect_float_close(
		float(app.call("_battle_animal_art_visual_scale", rabbit_card)) / float(app.call("_animal_art_visual_scale", rabbit_card)),
		1.30,
		"animal artwork receives the same 30 percent camera enlargement"
	)
	var spawned_id = int(app.get("next_unit_id"))
	app.call("_spawn_unit", BoardRules.PLAYER, player_base_key, "rabbit")
	var unit_before = _unit_with_id(spawned_id)
	_expect_false(unit_before.is_empty(), "camera fixture spawns a player unit")
	if unit_before.is_empty():
		return

	app.call("_refresh_combat_building_keys")
	app.call("_pulse", player_base_world, Color.WHITE)
	app.call("_projectile", player_base_world, enemy_base_world, BoardRules.PLAYER)
	var target_before: Dictionary = app.call("_nearest_combat_target", player_base_world, 4, -1)
	_expect_equal(String(target_before.get("kind", "")), "building", "automatic targeting resolves the player base as a building target")
	_expect_equal(target_before.get("key", MultiplayerRules.INVALID_KEY), player_base_key, "target keeps the player base key")

	var unit_world_before = Vector2(unit_before.get("pos", Vector2.ZERO))
	var unit_tile_before = unit_before.get("tile", MultiplayerRules.INVALID_KEY)
	var target_world_before = Vector2(target_before.get("pos", Vector2.ZERO))
	var building_world_before: Vector2 = app.call("_hex_center", player_base_key)
	var building_state_before = (app.get("tiles") as Dictionary)[player_base_key].duplicate(true)
	var effects_before = (app.get("effects") as Array).duplicate(true)
	var projectile_before = _last_effect("projectile")
	var pulse_before = _last_effect("pulse")
	var camera_offset_before: Vector2 = app.call("_multiplayer_camera_offset")
	var unit_canvas_before: Vector2 = app.call("_world_to_canvas", unit_world_before)
	var target_canvas_before: Vector2 = app.call("_world_to_canvas", target_world_before)
	var building_canvas_before: Vector2 = app.call("_world_to_canvas", building_world_before)
	var projectile_from_canvas_before: Vector2 = app.call("_world_to_canvas", Vector2(projectile_before.get("from", Vector2.ZERO)))
	var pulse_canvas_before: Vector2 = app.call("_world_to_canvas", Vector2(pulse_before.get("pos", Vector2.ZERO)))

	_expect_vector_close(unit_world_before, player_base_world, "spawned unit is stored in board world coordinates")
	_expect_vector_close(target_world_before, player_base_world, "combat target is stored in board world coordinates")
	_expect_vector_close(building_world_before, player_base_world, "building center is a board world coordinate")
	_expect_equal(app.call("_tile_at_world", unit_world_before), player_base_key, "world-space unit position maps to its tile")
	_expect_equal(app.call("_tile_at_canvas", building_canvas_before), player_base_key, "pre-drag building projection is clickable")

	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	var drag_start_canvas = Vector2(360, 520)
	var drag_delta_canvas = Vector2(28, -20)
	var drag_start_screen = offset + drag_start_canvas * scale
	var drag_delta_screen = drag_delta_canvas * scale
	app.call("_begin_board_pointer", drag_start_screen)
	app.call("_move_board_pointer", drag_start_screen + drag_delta_screen, drag_delta_screen)
	app.call("_end_board_pointer", drag_start_screen + drag_delta_screen)
	app.call("_layout", app.get_viewport().get_visible_rect().size)
	app.call("_update_units", 0.0)

	var camera_offset_after: Vector2 = app.call("_multiplayer_camera_offset")
	var camera_delta = camera_offset_after - camera_offset_before
	var unit_after = _unit_with_id(spawned_id)
	var target_after: Dictionary = app.call("_nearest_combat_target", player_base_world, 4, -1)
	var building_world_after: Vector2 = app.call("_hex_center", player_base_key)
	var building_state_after = (app.get("tiles") as Dictionary)[player_base_key].duplicate(true)
	var effects_after = (app.get("effects") as Array).duplicate(true)
	var projectile_after = _last_effect("projectile")
	var pulse_after = _last_effect("pulse")

	_expect_true(camera_delta.length() > POSITION_EPSILON, "drag changes the camera projection origin")
	_expect_vector_close(Vector2(unit_after.get("pos", Vector2.ZERO)), unit_world_before, "drag does not move unit world position")
	_expect_equal(unit_after.get("tile", MultiplayerRules.INVALID_KEY), unit_tile_before, "drag does not change unit logical tile")
	_expect_vector_close(Vector2(target_after.get("pos", Vector2.ZERO)), target_world_before, "drag does not move combat target world position")
	_expect_vector_close(building_world_after, building_world_before, "drag does not move building world position")
	_expect_equal(building_state_after, building_state_before, "drag does not mutate building state")
	_expect_equal(effects_after, effects_before, "drag does not mutate stored effect world positions")

	var unit_canvas_after: Vector2 = app.call("_world_to_canvas", Vector2(unit_after.get("pos", Vector2.ZERO)))
	var target_canvas_after: Vector2 = app.call("_world_to_canvas", Vector2(target_after.get("pos", Vector2.ZERO)))
	var building_canvas_after: Vector2 = app.call("_world_to_canvas", building_world_after)
	var projectile_from_canvas_after: Vector2 = app.call("_world_to_canvas", Vector2(projectile_after.get("from", Vector2.ZERO)))
	var pulse_canvas_after: Vector2 = app.call("_world_to_canvas", Vector2(pulse_after.get("pos", Vector2.ZERO)))
	_expect_vector_close(unit_canvas_after - unit_canvas_before, camera_delta, "unit screen projection follows camera movement")
	_expect_vector_close(target_canvas_after - target_canvas_before, camera_delta, "target screen projection follows camera movement")
	_expect_vector_close(building_canvas_after - building_canvas_before, camera_delta, "building screen projection follows camera movement")
	_expect_vector_close(projectile_from_canvas_after - projectile_from_canvas_before, camera_delta, "projectile screen projection follows camera movement")
	_expect_vector_close(pulse_canvas_after - pulse_canvas_before, camera_delta, "pulse screen projection follows camera movement")
	_expect_vector_close(app.call("_canvas_to_world", building_canvas_after), building_world_before, "canvas-to-world conversion reverses camera projection")
	_expect_equal(app.call("_tile_at_canvas", building_canvas_after), player_base_key, "post-drag building projection still hits its tile")

	# The unit fixture stands on the base center and intentionally has input
	# priority. Tap a clear part of the enlarged hex to verify building/tile hit
	# conversion without selecting the unit first.
	var clear_building_canvas = building_canvas_after + Vector2(HEX_SIZE * 1.30 * 0.75, 0.0)
	var building_screen_after = offset + clear_building_canvas * scale
	app.call("_handle_tap", building_screen_after)
	_expect_equal(app.get("selected_tile"), player_base_key, "post-drag click selects the projected building tile")


func _unit_with_id(unit_id: int) -> Dictionary:
	for unit in app.get("units"):
		if int(unit.get("id", -1)) == unit_id:
			return unit
	return {}


func _last_effect(kind: String) -> Dictionary:
	var all_effects: Array = app.get("effects")
	for index in range(all_effects.size() - 1, -1, -1):
		if String(all_effects[index].get("kind", "")) == kind:
			return all_effects[index]
	return {}


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_false(value: bool, label: String) -> void:
	if not value:
		return
	failures += 1
	push_error("%s: expected false" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_vector_close(actual: Vector2, expected: Vector2, label: String) -> void:
	if actual.distance_to(expected) <= POSITION_EPSILON:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_float_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= POSITION_EPSILON:
		return
	failures += 1
	push_error("%s: expected %.3f, got %.3f" % [label, expected, actual])
