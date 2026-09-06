extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

var failures = 0
var checks = 0
var app: Node


func _ready() -> void:
	# This suite verifies gameplay, not audio playback. Keep isolated headless
	# runs from quitting with short spawn/hit voices still on the audio thread.
	var audio = get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.call("set_sfx_enabled", false)
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.set_process(false)
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	_test_income_progress_and_per_building_feedback()
	_test_retaliation_chases_until_first_attack()
	for cooldown in [0.0, 9.0]:
		_test_existing_attack_target_is_preserved(cooldown)
	_test_retaliation_distance_boundaries(false)
	_test_retaliation_distance_boundaries(true)
	_test_chase_target_takes_priority_over_navigation()
	_test_building_retaliation_distance()
	_test_invalid_old_lock_uses_navigation_distance()
	_test_invalid_retaliation_sources()
	_test_building_damage_source_becomes_retaliation_target()
	if failures == 0:
		print("Battle income and retaliation tests passed. checks=", checks)
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
	attacker_index = int(app.call("_unit_index_by_id", attacker_id))
	_expect_true(float(units[attacker_index]["hp"]) < 999.0, "first retaliation really damages the attacker")


func _test_existing_attack_target_is_preserved(cooldown: float) -> void:
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
	victim["range"] = 300.0
	victim["cooldown"] = cooldown
	new_attacker["pos"] = origin + Vector2(10.0, 0.0)
	existing_target["pos"] = origin + Vector2(200.0, 0.0)
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


func _test_retaliation_distance_boundaries(chasing: bool) -> void:
	# Compare against either a locked chase unit or the navigation building.
	# The 0.01 cases also catch accidental >= and coarse/rounded grid distances.
	for extra_distance in [-20.0, -0.01, 0.0, 0.01, 20.0]:
		_setup_units(2)
		var units: Array = app.get("units")
		var victim: Dictionary = units[0]
		var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
		var target_pos: Vector2 = app.call("_hex_center", enemy_base)
		var origin = target_pos - Vector2(200.0, 0.0)
		victim["pos"] = origin
		victim["range"] = 40.0
		victim["navigation_target_kind"] = "building"
		victim["navigation_target_key"] = enemy_base
		units[2]["pos"] = target_pos
		var one_cell = sqrt(3.0) * MainApp.HEX_SIZE
		units[1]["pos"] = origin + Vector2(200.0 - one_cell - extra_distance, 0.0)
		units[0] = victim
		app.set("units", units)
		if chasing:
			victim = app.call("_lock_unit_attack_target", victim, {"kind": "unit", "index": 2, "pos": target_pos}, true)
			units[0] = victim
			app.set("units", units)
		app.call("_damage_unit", 0, 1.0, 1, BoardRules.ENEMY)
		units = app.get("units")
		var label = "%s extra %.2f" % ["chase" if chasing else "navigation", extra_distance]
		var expected_id = int(units[1]["id"]) if extra_distance > 0.0 else (int(units[2]["id"]) if chasing else -1)
		_expect_equal(int(units[0].get("attack_target_unit_id", -1)), expected_id, label)
		_expect_equal(bool(units[0].get("attack_target_chase", false)), extra_distance > 0.0 or chasing, label + " chase state")
		_expect_equal(units[0].get("navigation_target_key"), enemy_base, label + " preserves navigation")


func _test_chase_target_takes_priority_over_navigation() -> void:
	for distances in [[300.0, 100.0, 100.0], [100.0, 300.0, 60.0]]:
		_setup_units(2)
		var units: Array = app.get("units")
		var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
		var building_pos: Vector2 = app.call("_hex_center", enemy_base)
		var origin = building_pos - Vector2(distances[1], 0.0)
		units[0]["pos"] = origin
		units[0]["range"] = 40.0
		units[0]["navigation_target_kind"] = "building"
		units[0]["navigation_target_key"] = enemy_base
		units[1]["pos"] = origin + Vector2(distances[2], 0.0)
		units[2]["pos"] = origin + Vector2(distances[0], 0.0)
		app.set("units", units)
		units[0] = app.call("_lock_unit_attack_target", units[0], {"kind": "unit", "index": 2, "pos": units[2]["pos"]}, true)
		app.set("units", units)
		app.call("_damage_unit", 0, 1.0, 1, BoardRules.ENEMY)
		units = app.get("units")
		var should_switch = distances[0] - distances[2] > sqrt(3.0) * MainApp.HEX_SIZE
		_expect_equal(int(units[0]["attack_target_unit_id"]), int(units[1 if should_switch else 2]["id"]), "chase target takes priority over different navigation distance " + str(distances))


func _test_building_retaliation_distance() -> void:
	for gap_cells in [0, 1, 2]:
		_setup_units(1)
		var units: Array = app.get("units")
		var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
		var navigation_key = enemy_base + Vector2i(0, gap_cells)
		var tiles: Dictionary = app.get("tiles")
		tiles[navigation_key] = (tiles[enemy_base] as Dictionary).duplicate(true)
		app.set("tiles", tiles)
		var source_pos: Vector2 = app.call("_hex_center", enemy_base)
		var next_pos: Vector2 = app.call("_hex_center", enemy_base + Vector2i(0, 1))
		units[0]["pos"] = source_pos - (next_pos - source_pos).normalized() * 100.0
		units[0]["range"] = 40.0
		units[0]["navigation_target_kind"] = "building"
		units[0]["navigation_target_key"] = navigation_key
		app.set("units", units)
		app.call("_damage_unit", 0, 1.0, -1, BoardRules.ENEMY, true, enemy_base, true)
		units = app.get("units")
		_expect_equal(String(units[0].get("attack_target_kind", "")), "building" if gap_cells > 1 else "", "building source distance gap " + str(gap_cells))
		if gap_cells > 1:
			_expect_equal(units[0]["attack_target_key"], enemy_base, "closer building source is the actual retaliation target")


func _test_invalid_old_lock_uses_navigation_distance() -> void:
	for invalid_state in ["dead", "friendly", "out_of_range"]:
		_setup_units(2)
		var units: Array = app.get("units")
		var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
		var building_pos: Vector2 = app.call("_hex_center", enemy_base)
		var origin = building_pos - Vector2(100.0, 0.0)
		units[0]["pos"] = origin
		units[0]["range"] = 40.0
		units[0]["navigation_target_kind"] = "building"
		units[0]["navigation_target_key"] = enemy_base
		units[1]["pos"] = origin + Vector2(90.0, 0.0)
		units[2]["pos"] = origin + Vector2(500.0, 0.0)
		app.set("units", units)
		units[0] = app.call("_lock_unit_attack_target", units[0], {"kind": "unit", "index": 2, "pos": units[2]["pos"]}, invalid_state != "out_of_range")
		if invalid_state == "dead":
			units[2]["hp"] = 0.0
		elif invalid_state == "friendly":
			units[2]["team"] = BoardRules.PLAYER
		app.set("units", units)
		app.call("_damage_unit", 0, 1.0, 1, BoardRules.ENEMY)
		units = app.get("units")
		_expect_true(int(units[0].get("attack_target_unit_id", -1)) != int(units[1]["id"]), invalid_state + " old lock uses near navigation, not stale far position")


func _test_invalid_retaliation_sources() -> void:
	for invalid_state in ["dead", "friendly", "missing"]:
		_setup_units(1)
		var units: Array = app.get("units")
		units[0]["navigation_target_kind"] = ""
		units[0]["navigation_target_key"] = MultiplayerRules.INVALID_KEY
		if invalid_state == "dead":
			units[1]["hp"] = 0.0
		elif invalid_state == "friendly":
			units[1]["team"] = BoardRules.PLAYER
		app.set("units", units)
		app.call("_damage_unit", 0, 1.0, -1 if invalid_state == "missing" else 1, BoardRules.ENEMY)
		units = app.get("units")
		_expect_equal(String(units[0].get("attack_target_kind", "")), "", invalid_state + " attacker cannot become retaliation target")


func _test_building_damage_source_becomes_retaliation_target() -> void:
	_setup_units(1)
	var units: Array = app.get("units")
	if units.size() != 2:
		_expect_equal(units.size(), 2, "building retaliation setup")
		return
	var victim: Dictionary = app.call("_clear_unit_attack_target", units[0])
	# No valid search target preserves the existing idle retaliation fallback.
	victim["navigation_target_kind"] = ""
	victim["navigation_target_key"] = MultiplayerRules.INVALID_KEY
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
	checks += 1
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_false(value: bool, label: String) -> void:
	checks += 1
	if not value:
		return
	failures += 1
	push_error("%s: expected false" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	checks += 1
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, label: String) -> void:
	checks += 1
	if is_equal_approx(actual, expected):
		return
	failures += 1
	push_error("%s: expected %.3f, got %.3f" % [label, expected, actual])
