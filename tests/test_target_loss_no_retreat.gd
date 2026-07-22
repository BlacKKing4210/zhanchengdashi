extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_navigation_retargets_without_retreat()
	if failures == 0:
		print("Target-loss no-retreat tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_navigation_retargets_without_retreat() -> void:
	var start_key = Vector2i(0, 0)
	var middle_key = Vector2i(1, 0)
	var replacement_key = Vector2i(2, 0)
	var defeated_key = Vector2i(3, 0)
	var board = {
		start_key: {"building": "base", "hp": 100.0, "team": BoardRules.PLAYER},
		middle_key: BoardRules.empty_locked_tile(),
		replacement_key: {"building": "tower", "hp": 60.0, "team": BoardRules.ENEMY},
		defeated_key: {"building": "tower", "hp": 60.0, "team": BoardRules.ENEMY},
	}
	app.set("battle_mode", "classic")
	app.set("tiles", board)
	app.call("_rebuild_ground_navigation")

	var start_pos: Vector2 = app.call("_hex_center", start_key)
	var middle_pos: Vector2 = app.call("_hex_center", middle_key)
	var replacement_pos: Vector2 = app.call("_hex_center", replacement_key)
	var midway_pos = start_pos.lerp(middle_pos, 0.30)
	_expect_equal(app.call("_tile_at_world", midway_pos), start_key, "test unit remains inside its current hex before retargeting")

	var runner = {
		"id": 1,
		"team": BoardRules.PLAYER,
		"pos": midway_pos,
		"tile": start_key,
		"range": 64.0,
		"speed": 96.0,
		"flying": false,
		"navigation_target_key": defeated_key,
		"ground_path": app.call("_ground_path_between", start_key, defeated_key),
		"ground_path_index": 1,
		"ground_path_target": defeated_key,
		"attack_target_kind": "",
		"attack_target_unit_id": -1,
		"attack_target_key": MultiplayerRules.INVALID_KEY,
	}
	var nearby_enemy = {
		"id": 2,
		"team": BoardRules.ENEMY,
		"hp": 10.0,
		"pos": midway_pos + Vector2(12.0, 0.0),
		"tile": start_key,
	}
	app.set("units", [runner, nearby_enemy])

	var attack_target: Dictionary = app.call("_nearest_attack_target_in_range", runner)
	_expect_equal(String(attack_target.get("kind", "")), "unit", "animals remain valid immediate attack targets inside range")

	# Simulate the locked building disappearing while the runner is between hex centers.
	runner["navigation_target_key"] = defeated_key
	runner["ground_path"] = app.call("_ground_path_between", start_key, defeated_key)
	runner["ground_path_index"] = 1
	runner["ground_path_target"] = defeated_key
	board[defeated_key]["hp"] = 0.0
	app.set("tiles", board)
	runner = app.call("_ensure_unit_navigation_target", runner)
	_expect_equal(runner["navigation_target_key"], replacement_key, "a destroyed building selects the next enemy building")
	_expect_true((runner["ground_path"] as PackedVector2Array).is_empty(), "retargeting clears the obsolete path")

	var distance_to_start_before = midway_pos.distance_to(start_pos)
	var distance_to_replacement_before = midway_pos.distance_to(replacement_pos)
	var replacement_target: Dictionary = app.call("_unit_navigation_target", runner)
	runner = app.call("_move_unit_toward_target", runner, replacement_target, replacement_pos, 0.05)
	var moved_pos = Vector2(runner["pos"])
	_expect_true(moved_pos.distance_to(start_pos) >= distance_to_start_before - 0.05, "retarget movement never walks back to the current hex center")
	_expect_true(moved_pos.distance_to(replacement_pos) < distance_to_replacement_before, "retarget movement advances directly toward the next building")
	_expect_true(int(runner["ground_path_index"]) >= 1, "new ground path starts at the following waypoint")


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
