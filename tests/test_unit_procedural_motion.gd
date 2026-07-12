extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const UnitMotionFeedback = preload("res://scripts/app/systems/unit_motion_feedback.gd")

const EPSILON = 0.001

var failures = 0
var app


func _ready() -> void:
	_test_motion_math_keeps_logic_state_stable()
	_test_priority_and_pending_motion()
	_test_death_pose_uses_only_the_animal_snapshot()
	app = MainApp.new()
	add_child(app)
	_test_rarity_visual_scaling_keeps_logic_state_stable()
	_test_runtime_triggers_keep_world_state_stable()
	_test_card_upgrade_triggers_power_motion_only_on_success()
	_test_rejected_image_fx_are_absent()
	if failures == 0:
		print("Unit procedural motion tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_motion_math_keeps_logic_state_stable() -> void:
	var unit = {
		"id": 17,
		"pos": Vector2(120.0, 240.0),
		"tile": Vector2i(2, 3),
	}
	var pos_before = Vector2(unit["pos"])
	var tile_before: Vector2i = unit["tile"]
	UnitMotionFeedback.begin_frame(unit, 0.08)
	UnitMotionFeedback.mark_moving(unit, Vector2.RIGHT, 0.08)
	var move_pose = UnitMotionFeedback.pose(unit)
	_expect_true(Vector2(move_pose["offset"]).y < 0.0, "moving raises the animal image from its foot point")
	_expect_true(Vector2(move_pose["scale"]) != Vector2.ONE, "moving applies a small squash/stretch")
	_expect_equal(unit["pos"], pos_before, "moving pose does not mutate unit world position")
	_expect_equal(unit["tile"], tile_before, "moving pose does not mutate unit tile")

	UnitMotionFeedback.trigger(unit, UnitMotionFeedback.KIND_ATTACK, Vector2.RIGHT)
	unit["motion_time"] = UnitMotionFeedback.ATTACK_DURATION * 0.5
	var attack_pose = UnitMotionFeedback.pose(unit)
	_expect_true(Vector2(attack_pose["offset"]).x > 0.0, "attack pose lunges toward the target")
	_expect_equal(unit["pos"], pos_before, "attack pose does not mutate unit world position")
	_expect_equal(unit["tile"], tile_before, "attack pose does not mutate unit tile")


func _test_rarity_visual_scaling_keeps_logic_state_stable() -> void:
	var cases = [
		{"card_id": "mouse", "rarity": "common", "scale": 1.0},
		{"card_id": "cat", "rarity": "rare", "scale": 1.2},
		{"card_id": "fox", "rarity": "epic", "scale": 1.5},
		{"card_id": "bear", "rarity": "legendary", "scale": 1.8},
	]
	var unit = {
		"pos": Vector2(184.0, 362.0),
		"tile": Vector2i(4, 7),
	}
	var pose = {
		"offset": Vector2(3.0, -2.0),
		"scale": Vector2(1.1, 0.9),
		"rotation": 0.2,
	}
	var unit_before = unit.duplicate(true)
	var pose_before = pose.duplicate(true)
	for test_case in cases:
		var card_id = String(test_case["card_id"])
		var expected_rarity = String(test_case["rarity"])
		var expected_visual_scale = float(test_case["scale"])
		var card: Dictionary = app.call("_card_by_id", card_id)
		_expect_false(card.is_empty(), "%s card is available for rarity scale test" % card_id)
		_expect_equal(String(card.get("rarity", "")), expected_rarity, "%s uses the expected rarity" % card_id)
		var visual_scale = float(app.call("_animal_rarity_visual_scale", card))
		_expect_close(visual_scale, expected_visual_scale, "%s uses the configured visual scale" % expected_rarity)
		var combined_scale = Vector2(app.call("_animal_texture_draw_scale", pose, visual_scale))
		var expected_combined = Vector2(pose["scale"]) * expected_visual_scale
		_expect_close(combined_scale.x, expected_combined.x, "%s multiplies procedural x scale" % expected_rarity)
		_expect_close(combined_scale.y, expected_combined.y, "%s multiplies procedural y scale" % expected_rarity)
	_expect_equal(pose, pose_before, "rarity visual scaling does not mutate the procedural pose")
	_expect_equal(unit, unit_before, "rarity visual scaling does not mutate unit world state")


func _test_priority_and_pending_motion() -> void:
	var unit = {}
	UnitMotionFeedback.trigger(unit, UnitMotionFeedback.KIND_ATTACK, Vector2.RIGHT)
	UnitMotionFeedback.trigger(unit, UnitMotionFeedback.KIND_HIT, Vector2.LEFT)
	_expect_equal(UnitMotionFeedback.current_kind(unit), UnitMotionFeedback.KIND_HIT, "hit interrupts attack")
	var refreshed_time = float(unit["motion_time"])
	UnitMotionFeedback.begin_frame(unit, 0.05)
	UnitMotionFeedback.trigger(unit, UnitMotionFeedback.KIND_HIT, Vector2.UP)
	_expect_close(float(unit["motion_time"]), refreshed_time, "repeated hit refreshes instead of stacking")
	UnitMotionFeedback.trigger(unit, UnitMotionFeedback.KIND_STAT_GAIN)
	_expect_equal(String(unit.get("motion_pending_kind", "")), UnitMotionFeedback.KIND_STAT_GAIN, "lower-priority gain waits behind hit")
	UnitMotionFeedback.begin_frame(unit, UnitMotionFeedback.HIT_DURATION + 0.01)
	_expect_equal(UnitMotionFeedback.current_kind(unit), UnitMotionFeedback.KIND_STAT_GAIN, "pending gain plays after hit")


func _test_death_pose_uses_only_the_animal_snapshot() -> void:
	var effect = {
		"kind": UnitMotionFeedback.KIND_DEATH,
		"card_id": "rabbit",
		"pos": Vector2(310.0, 460.0),
		"direction": Vector2.RIGHT,
		"duration": UnitMotionFeedback.DEATH_DURATION,
		"time": UnitMotionFeedback.DEATH_DURATION * 0.5,
	}
	var world_pos_before = Vector2(effect["pos"])
	var pose = UnitMotionFeedback.death_pose(effect)
	_expect_true(Vector2(pose["scale"]).x < 1.0, "death snapshot shrinks the existing animal image")
	_expect_true(absf(float(pose["rotation"])) > 0.0, "death snapshot tilts the existing animal image")
	_expect_equal(effect["pos"], world_pos_before, "death pose does not mutate snapshot world position")
	_expect_false(effect.has("texture") or effect.has("fx_texture") or effect.has("atlas"), "death snapshot has no separate FX image")


func _test_runtime_triggers_keep_world_state_stable() -> void:
	app.call("_start_match")
	app.call("_spawn_unit", BoardRules.PLAYER, _base_key(BoardRules.PLAYER), "rabbit")
	app.call("_spawn_unit", BoardRules.ENEMY, _base_key(BoardRules.ENEMY), "rabbit")
	var all_units: Array = app.get("units")
	var attacker_id = int(all_units[0]["id"])
	var target_id = int(all_units[1]["id"])
	all_units[0]["pos"] = Vector2(240.0, 420.0)
	all_units[0]["tile"] = Vector2i(2, 5)
	all_units[0]["attack"] = 1.0
	all_units[1]["pos"] = Vector2(270.0, 420.0)
	all_units[1]["tile"] = Vector2i(3, 5)
	all_units[1]["hp"] = 100.0
	all_units[1]["max_hp"] = 100.0
	app.set("units", all_units)
	var attacker_pos = Vector2(all_units[0]["pos"])
	var attacker_tile: Vector2i = all_units[0]["tile"]
	var target_pos = Vector2(all_units[1]["pos"])
	var target_tile: Vector2i = all_units[1]["tile"]
	var target = {"kind": "unit", "index": 1, "pos": target_pos}
	app.call("_unit_attack_target", 0, target, attacker_pos.distance_to(target_pos))
	all_units = app.get("units")
	_expect_equal(UnitMotionFeedback.current_kind(all_units[0]), UnitMotionFeedback.KIND_ATTACK, "runtime attack trigger starts attack pose")
	_expect_equal(UnitMotionFeedback.current_kind(all_units[1]), UnitMotionFeedback.KIND_HIT, "runtime damage trigger starts hit pose")
	_expect_equal(all_units[0]["pos"], attacker_pos, "runtime attack pose keeps attacker world position")
	_expect_equal(all_units[0]["tile"], attacker_tile, "runtime attack pose keeps attacker tile")
	_expect_equal(all_units[1]["pos"], target_pos, "runtime hit pose keeps target world position")
	_expect_equal(all_units[1]["tile"], target_tile, "runtime hit pose keeps target tile")

	app.call("_add_attack_bonus", 0, 1.0)
	all_units = app.get("units")
	_expect_equal(String(all_units[0].get("motion_pending_kind", "")), UnitMotionFeedback.KIND_STAT_GAIN, "runtime stat gain queues behind attack")
	_expect_equal(all_units[0]["pos"], attacker_pos, "runtime stat gain keeps unit world position")

	all_units[1]["hp"] = 1.0
	app.set("units", all_units)
	app.call("_damage_unit", 1, 999.0, 0, BoardRules.PLAYER)
	var death_snapshot = _last_effect(UnitMotionFeedback.KIND_DEATH)
	_expect_false(death_snapshot.is_empty(), "lethal damage creates an animal death snapshot")
	_expect_equal(int(death_snapshot.get("unit_id", -1)), target_id, "death snapshot keeps stable unit identity")
	_expect_equal(Vector2(death_snapshot.get("pos", Vector2.ZERO)), target_pos, "death snapshot keeps pre-death world position")
	app.call("_update_units", 0.0)
	_expect_false(_has_unit(target_id), "dead logic unit is removed in the same update")
	_expect_true(_has_unit(attacker_id), "surviving unit keeps its own motion state after array compaction")
	app.call("_update_effects", UnitMotionFeedback.DEATH_DURATION + 0.01)
	_expect_true(_last_effect(UnitMotionFeedback.KIND_DEATH).is_empty(), "death snapshot is removed after its visual duration")


func _test_card_upgrade_triggers_power_motion_only_on_success() -> void:
	app.set("selected_card_id", "rabbit")
	var levels: Dictionary = app.get("card_levels")
	var counts: Dictionary = app.get("card_counts")
	levels["rabbit"] = 1
	counts["rabbit"] = 99
	app.set("card_levels", levels)
	app.set("card_counts", counts)
	app.set("detail_upgrade_motion_timer", 0.0)
	app.call("_try_upgrade_selected_card")
	_expect_true(float(app.get("detail_upgrade_motion_timer")) > 0.0, "successful card upgrade starts the animal power-up pose")

	counts = app.get("card_counts")
	counts["rabbit"] = 0
	app.set("card_counts", counts)
	app.set("detail_upgrade_motion_timer", 0.0)
	app.call("_try_upgrade_selected_card")
	_expect_close(float(app.get("detail_upgrade_motion_timer")), 0.0, "failed card upgrade does not start the power-up pose")


func _test_rejected_image_fx_are_absent() -> void:
	for file_name in DirAccess.get_files_at("res://output/visual_concepts"):
		_expect_false(String(file_name).begins_with("animal_universal_motion"), "rejected animal motion image FX is removed: %s" % file_name)


func _has_unit(unit_id: int) -> bool:
	for unit in app.get("units"):
		if int(unit.get("id", -1)) == unit_id:
			return true
	return false


func _base_key(team: int) -> Vector2i:
	var all_tiles: Dictionary = app.get("tiles")
	for key in all_tiles.keys():
		var tile: Dictionary = all_tiles[key]
		if int(tile.get("team", BoardRules.NEUTRAL)) == team and String(tile.get("building", "")) == "base":
			return key
	push_error("unit motion test could not find team %d base" % team)
	return Vector2i(-99, -99)


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


func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= EPSILON:
		return
	failures += 1
	push_error("%s: expected %.3f, got %.3f" % [label, expected, actual])
