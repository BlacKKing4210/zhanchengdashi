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
	_test_flying_card_tags()
	_test_unit_target_locking()
	_test_ground_path_avoids_missing_cell()
	if failures == 0:
		print("Ground navigation tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_flying_card_tags() -> void:
	for card_id in ["sparrow", "pigeon", "duck", "parrot", "peacock", "swan", "falcon", "crane", "eagle", "golden_eagle"]:
		_expect_true(bool(app.call("_card_is_flying", app.call("_card_by_id", card_id))), "%s is explicitly flying" % card_id)
	for card_id in ["mouse", "chicken", "penguin"]:
		_expect_false(bool(app.call("_card_is_flying", app.call("_card_by_id", card_id))), "%s remains ground-bound" % card_id)


func _test_unit_target_locking() -> void:
	var start_key = Vector2i(0, 0)
	var first_building = Vector2i(4, 0)
	var later_closer_building = Vector2i(2, 0)
	app.set("battle_mode", "classic")
	app.set("tiles", {
		start_key: {"building": "base", "hp": 100.0, "team": BoardRules.PLAYER},
		first_building: {"building": "base", "hp": 100.0, "team": BoardRules.ENEMY},
	})
	var unit = {
		"id": 10,
		"team": BoardRules.PLAYER,
		"pos": app.call("_hex_center", start_key),
		"range": 80.0,
		"navigation_target_key": MultiplayerRules.INVALID_KEY,
		"ground_path": PackedVector2Array(),
		"ground_path_index": 0,
		"ground_path_target": MultiplayerRules.INVALID_KEY,
		"attack_target_kind": "",
		"attack_target_unit_id": -1,
		"attack_target_key": MultiplayerRules.INVALID_KEY,
	}
	unit = app.call("_ensure_unit_navigation_target", unit)
	_expect_equal(unit["navigation_target_key"], first_building, "unit chooses the nearest enemy building when it has no route target")
	var tiles: Dictionary = app.get("tiles")
	tiles[later_closer_building] = {"building": "tower", "hp": 40.0, "team": BoardRules.ENEMY}
	app.set("tiles", tiles)
	unit = app.call("_ensure_unit_navigation_target", unit)
	_expect_equal(unit["navigation_target_key"], first_building, "a new closer building does not replace a living locked route target")
	tiles = app.get("tiles")
	tiles[first_building]["hp"] = 0.0
	app.set("tiles", tiles)
	unit = app.call("_ensure_unit_navigation_target", unit)
	_expect_equal(unit["navigation_target_key"], later_closer_building, "unit retargets after the locked building dies")

	var unit_pos: Vector2 = unit["pos"]
	app.set("units", [
		unit,
		{"id": 20, "team": BoardRules.ENEMY, "hp": 10.0, "pos": unit_pos + Vector2(40, 0), "tile": start_key},
	])
	var attack_target: Dictionary = app.call("_nearest_attack_target_in_range", unit)
	unit["navigation_target_kind"] = ""
	unit["navigation_target_unit_id"] = -1
	unit["navigation_target_key"] = MultiplayerRules.INVALID_KEY
	unit = app.call("_ensure_unit_navigation_target", unit)
	_expect_equal(String(unit["navigation_target_kind"]), "unit", "unit navigation can select an enemy animal")
	_expect_equal(int(unit["navigation_target_unit_id"]), 20, "unit navigation locks the selected enemy animal")
	unit = app.call("_lock_unit_attack_target", unit, attack_target)
	_expect_equal(int(unit["attack_target_unit_id"]), 20, "unit locks an enemy found inside attack range")
	var all_units: Array = app.get("units")
	all_units[0] = unit
	all_units.append({"id": 30, "team": BoardRules.ENEMY, "hp": 10.0, "pos": unit_pos + Vector2(10, 0), "tile": start_key})
	app.set("units", all_units)
	var locked: Dictionary = app.call("_locked_unit_attack_target", unit)
	_expect_equal(int((app.get("units") as Array)[int(locked["index"])]["id"]), 20, "a new closer enemy does not replace a living locked attack target")
	all_units = app.get("units")
	all_units[1]["hp"] = 0.0
	app.set("units", all_units)
	unit = app.call("_ensure_unit_navigation_target", unit)
	_expect_equal(int(unit["navigation_target_unit_id"]), 30, "unit navigation retargets when its enemy animal dies")
	_expect_true((app.call("_locked_unit_attack_target", unit) as Dictionary).is_empty(), "dead locked attack target becomes invalid")
	unit = app.call("_clear_unit_attack_target", unit)
	attack_target = app.call("_nearest_attack_target_in_range", unit)
	unit = app.call("_lock_unit_attack_target", unit, attack_target)
	_expect_equal(int(unit["attack_target_unit_id"]), 30, "unit selects a new attack target only after the old target dies")


func _test_ground_path_avoids_missing_cell() -> void:
	var ring_tiles = {}
	for key in MultiplayerRules.AXIAL_DIRECTIONS:
		ring_tiles[key] = BoardRules.empty_locked_tile()
	app.set("battle_mode", "multiplayer")
	app.set("tiles", ring_tiles)
	app.call("_rebuild_ground_navigation")
	var start_key = Vector2i(1, 0)
	var target_key = Vector2i(-1, 0)
	var start_pos: Vector2 = app.call("_hex_center", start_key)
	var target_pos: Vector2 = app.call("_hex_center", target_key)
	_expect_equal(app.call("_tile_at_world", start_pos.lerp(target_pos, 0.5)), MultiplayerRules.INVALID_KEY, "the direct route crosses a missing cell")
	var path: PackedVector2Array = app.call("_ground_path_between", start_key, target_key)
	_expect_true(path.size() >= 4, "AStar routes around the missing center")
	var previous_key = MultiplayerRules.INVALID_KEY
	for point in path:
		var path_key: Vector2i = app.call("_tile_at_world", point)
		_expect_true(ring_tiles.has(path_key), "every path point stays on an existing tile")
		if previous_key != MultiplayerRules.INVALID_KEY:
			_expect_true(path_key in MultiplayerRules.neighbors(ring_tiles, previous_key), "ground path only uses adjacent hexes")
		previous_key = path_key

	var unit = {
		"pos": start_pos,
		"tile": start_key,
		"speed": 96.0,
		"flying": false,
		"ground_path": PackedVector2Array(),
		"ground_path_index": 0,
		"ground_path_target": MultiplayerRules.INVALID_KEY,
	}
	var target = {"kind": "building", "tile": target_key, "pos": target_pos}
	for _step in range(80):
		unit = app.call("_move_unit_toward_target", unit, target, target_pos, 0.05)
		var current_key: Vector2i = app.call("_tile_at_world", Vector2(unit["pos"]))
		_expect_true(ring_tiles.has(current_key), "ground movement never enters the missing region")
		unit["tile"] = current_key
		if Vector2(unit["pos"]).distance_to(target_pos) <= 0.5:
			break
	_expect_true(Vector2(unit["pos"]).distance_to(target_pos) <= 0.5, "ground unit reaches its target through the valid route")


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
