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
	await get_tree().process_frame
	app.set_process(false)
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	_test_income_progress_and_per_building_feedback()
	_test_retaliation_chases_until_first_attack()
	_test_existing_attack_target_is_preserved()
	_test_building_damage_source_becomes_retaliation_target()
	if failures == 0:
		print("Battle income and retaliation tests passed.")
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func _test_income_progress_and_per_building_feedback() -> void:
	app.call("_reset_battle")
	app.set("income_timer", 3.0)
	_expect_float(float(app.call("_building_income_progress")), 0.0, "income bar starts empty")
	app.set("income_timer", 1.5)
	_expect_float(float(app.call("_building_income_progress")), 0.5, "income bar reaches half at half time")
	app.set("income_timer", 0.0)
	_expect_float(float(app.call("_building_income_progress")), 1.0, "income bar fills at payout")

	var tiles: Dictionary = app.get("tiles")
	var mine_key = _first_empty_tile_key(tiles)
	_expect_true(mine_key != MultiplayerRules.INVALID_KEY, "income test has an empty tile for a mine")
	if mine_key == MultiplayerRules.INVALID_KEY:
		return
	var mine_tile: Dictionary = (tiles[mine_key] as Dictionary).duplicate(true)
	mine_tile["building"] = "mine"
	mine_tile["team"] = BoardRules.PLAYER
	mine_tile["hp"] = 125.0
	mine_tile["max_hp"] = 125.0
	tiles[mine_key] = mine_tile
	app.set("tiles", tiles)
	app.set("gold", 100)
	app.set("enemy_gold", 100)
	app.set("effects", [])
	app.call("_award_periodic_building_income")
	_expect_equal(int(app.get("gold")), 122, "player base and mine retain 12 plus 10 income")
	_expect_equal(int(app.get("enemy_gold")), 112, "enemy base retains 12 income")
	var effects: Array = app.get("effects")
	var amounts: Array[int] = []
	var positions: Array[Vector2] = []
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		if String(effect.get("kind", "")) != "gold_gain":
			continue
		amounts.append(int(effect.get("amount", 0)))
		positions.append(Vector2(effect.get("pos", Vector2.ZERO)))
	amounts.sort()
	_expect_equal(amounts, [10, 12, 12], "each base and mine emits its own unchanged payout amount")
	_expect_equal(positions.size(), 3, "each income building emits one feedback effect")
	if positions.size() == 3:
		_expect_true(
			positions[0].distance_to(positions[1]) > 18.0
			and positions[0].distance_to(positions[2]) > 18.0
			and positions[1].distance_to(positions[2]) > 18.0,
			"building income effects remain anchored to distinct buildings"
		)


func _test_retaliation_chases_until_first_attack() -> void:
	_setup_units(1)
	var units: Array = app.get("units")
	if units.size() != 2:
		_expect_equal(units.size(), 2, "retaliation chase setup")
		return
	var victim: Dictionary = units[0]
	var attacker: Dictionary = units[1]
	var victim_id = int(victim.get("id", -1))
	var attacker_id = int(attacker.get("id", -1))
	var origin = Vector2(10000.0, 10000.0)
	victim["pos"] = origin
	victim["tile"] = app.call("_tile_at_world", origin)
	victim["range"] = 40.0
	victim["speed"] = 120.0
	victim["flying"] = true
	victim["cooldown"] = 0.0
	attacker["pos"] = origin + Vector2(120.0, 0.0)
	attacker["tile"] = app.call("_tile_at_world", Vector2(attacker["pos"]))
	attacker["hp"] = 999.0
	attacker["max_hp"] = 999.0
	attacker["range"] = 0.0
	attacker["speed"] = 0.0
	attacker["cooldown"] = 999.0
	units[0] = victim
	units[1] = attacker
	app.set("units", units)
	app.call("_damage_unit", 0, 1.0, 1, BoardRules.ENEMY)
	units = app.get("units")
	victim = units[0]
	_expect_equal(int(victim.get("attack_target_unit_id", -1)), attacker_id, "moving animal locks the actual attacker")
	_expect_true(bool(victim.get("attack_target_chase", false)), "out-of-range retaliation enables first-attack chase")
	var locked: Dictionary = app.call("_locked_unit_attack_target", victim)
	_expect_equal(_target_unit_id(locked), attacker_id, "retaliation lock remains valid outside normal range")
	var distance_before = Vector2(victim["pos"]).distance_to(Vector2(attacker["pos"]))
	app.call("_update_units", 0.10)
	var victim_index = int(app.call("_unit_index_by_id", victim_id))
	var attacker_index = int(app.call("_unit_index_by_id", attacker_id))
	units = app.get("units")
	var distance_after = Vector2(units[victim_index]["pos"]).distance_to(Vector2(units[attacker_index]["pos"]))
	_expect_true(distance_after < distance_before, "retaliating animal moves toward the attacker")

	victim = units[victim_index]
	attacker = units[attacker_index]
	attacker["pos"] = Vector2(victim["pos"]) + Vector2(10.0, 0.0)
	attacker["tile"] = victim.get("tile", MultiplayerRules.INVALID_KEY)
	victim["cooldown"] = 0.0
	units[victim_index] = victim
	units[attacker_index] = attacker
	app.set("units", units)
	app.call("_update_units", 0.01)
	victim_index = int(app.call("_unit_index_by_id", victim_id))
	units = app.get("units")
	_expect_false(bool(units[victim_index].get("attack_target_chase", true)), "first retaliation attack restores normal range lock")


func _test_existing_attack_target_is_preserved() -> void:
	_setup_units(2)
	var units: Array = app.get("units")
	if units.size() != 3:
		_expect_equal(units.size(), 3, "existing target setup")
		return
	var victim: Dictionary = units[0]
	var new_attacker: Dictionary = units[1]
	var existing_target: Dictionary = units[2]
	var origin = Vector2(12000.0, 12000.0)
	victim["pos"] = origin
	victim["range"] = 80.0
	new_attacker["pos"] = origin + Vector2(120.0, 0.0)
	existing_target["pos"] = origin + Vector2(30.0, 0.0)
	existing_target["hp"] = 999.0
	existing_target["max_hp"] = 999.0
	units[0] = victim
	units[1] = new_attacker
	units[2] = existing_target
	app.set("units", units)
	var target = {
		"kind": "unit",
		"index": 2,
		"pos": Vector2(existing_target["pos"]),
		"tile": existing_target.get("tile", MultiplayerRules.INVALID_KEY),
	}
	victim = app.call("_lock_unit_attack_target", victim, target)
	units = app.get("units")
	units[0] = victim
	app.set("units", units)
	app.call("_damage_unit", 0, 1.0, 1, BoardRules.ENEMY)
	units = app.get("units")
	_expect_equal(
		int(units[0].get("attack_target_unit_id", -1)),
		int(existing_target.get("id", -1)),
		"a valid current attack target is not stolen by a new attacker"
	)
	_expect_false(bool(units[0].get("attack_target_chase", false)), "preserved normal target does not enter retaliation chase")


func _test_building_damage_source_becomes_retaliation_target() -> void:
	_setup_units(1)
	var units: Array = app.get("units")
	if units.size() != 2:
		_expect_equal(units.size(), 2, "building retaliation setup")
		return
	var victim: Dictionary = app.call("_clear_unit_attack_target", units[0])
	units[0] = victim
	app.set("units", units)
	var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
	app.call("_damage_unit", 0, 1.0, -1, BoardRules.ENEMY, true, enemy_base, true)
	units = app.get("units")
	_expect_equal(String(units[0].get("attack_target_kind", "")), "building", "tower or base damage can trigger building retaliation")
	_expect_equal(units[0].get("attack_target_key", MultiplayerRules.INVALID_KEY), enemy_base, "retaliation stores the attacking building key")
	_expect_true(bool(units[0].get("attack_target_chase", false)), "out-of-range attacking building is chased until first attack")


func _setup_units(enemy_count: int) -> void:
	app.call("_reset_battle")
	var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
	app.call("_spawn_unit", BoardRules.PLAYER, player_base, "rabbit", false, 0, {"skill_triggers_enabled": false})
	for _index in range(enemy_count):
		app.call("_spawn_unit", BoardRules.ENEMY, enemy_base, "wolf", false, 0, {"skill_triggers_enabled": false})


func _first_empty_tile_key(tiles: Dictionary) -> Vector2i:
	for key_value in tiles.keys():
		var key: Vector2i = key_value
		var tile: Dictionary = tiles[key]
		if String(tile.get("building", "")).is_empty():
			return key
	return MultiplayerRules.INVALID_KEY


func _target_unit_id(target: Dictionary) -> int:
	if String(target.get("kind", "")) != "unit":
		return -1
	var units: Array = app.get("units")
	var index = int(target.get("index", -1))
	if index < 0 or index >= units.size():
		return -1
	return int(units[index].get("id", -1))


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


func _expect_float(actual: float, expected: float, label: String) -> void:
	if is_equal_approx(actual, expected):
		return
	failures += 1
	push_error("%s: expected %.3f, got %.3f" % [label, expected, actual])
