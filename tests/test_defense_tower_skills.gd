extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const DefenseTowerRules = preload("res://scripts/app/systems/defense_tower_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

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
	_test_rule_contract()
	_test_far_sight_prioritizes_ranged_and_keeps_lock()
	_test_plunder_transfers_without_minting()
	_test_twin_shot_hits_one_distinct_extra_unit()
	_test_bounty_rewards_actual_redirected_kill()
	_test_bounty_requires_a_lethal_animal_hit()
	_test_territory_tower_uses_live_tile_owner()
	_test_global_pulse_hits_every_living_animal_once()
	_test_global_pulse_preserves_damage_and_kill_context()
	_test_global_pulse_stays_within_72_unit_budget()
	_test_all_skill_descriptions_wrap_without_ellipsis()
	if failures == 0:
		print("Defense tower skill tests passed.")
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func _test_rule_contract() -> void:
	_expect_equal(DefenseTowerRules.transfer_amount(0, 1), 0, "zero-gold target cannot mint plunder gold")
	_expect_equal(DefenseTowerRules.transfer_amount(1, 1), 1, "one available gold transfers once")
	_expect_equal(DefenseTowerRules.transfer_amount(99, 1), 1, "plunder is capped by requested amount")
	_expect_close(DefenseTowerRules.range_world(3.5, MainApp.HEX_SIZE), 150.5, "3.5-tile range converts exactly once")
	_expect_close(DefenseTowerRules.interval_seconds(0.5, 1.0), 0.5, "rapid tower interval remains below one second")


func _test_far_sight_prioritizes_ranged_and_keeps_lock() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_longshot_tower")
	var center: Vector2 = app.call("_hex_center", tower_key)
	var melee_id = _spawn_enemy("rabbit", center + Vector2(38.0, 0.0), 99.0)
	var ranged_id = _spawn_enemy("falcon", center + Vector2(105.0, 0.0), 99.0)
	var card: Dictionary = app.call("_card_by_id", "defense_longshot_tower")
	var stats: Dictionary = app.call("_card_stats_for_team", card, BoardRules.PLAYER)
	var acquired: Dictionary = app.call(
		"_nearest_tower_attack_target",
		tower_key,
		BoardRules.PLAYER,
		float(stats.get("attack_range", 0.0)),
		true,
		card
	)
	_expect_equal(int(acquired.get("unit_id", -1)), ranged_id, "far-sight tower selects a farther ranged animal before a nearer melee animal")
	app.call("_lock_tower_attack_target", tower_key, acquired)
	var units: Array = app.get("units")
	var melee_index = int(app.call("_unit_index_by_id", melee_id))
	units[melee_index]["pos"] = center + Vector2(10.0, 0.0)
	units[melee_index]["range"] = 999.0
	units[melee_index]["base_range"] = 999.0
	app.set("units", units)
	acquired = app.call(
		"_nearest_tower_attack_target",
		tower_key,
		BoardRules.PLAYER,
		float(stats.get("attack_range", 0.0)),
		true,
		card
	)
	_expect_equal(int(acquired.get("unit_id", -1)), ranged_id, "far-sight classification stays tied to the base card when a melee unit's upgraded range exceeds the threshold")
	var locked: Dictionary = app.call(
		"_locked_tower_attack_target",
		tower_key,
		BoardRules.PLAYER,
		float(stats.get("attack_range", 0.0)),
		card
	)
	_expect_equal(int(locked.get("unit_id", -1)), ranged_id, "far-sight tower keeps its existing legal sticky target")


func _test_plunder_transfers_without_minting() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_plunder_tower")
	var center: Vector2 = app.call("_hex_center", tower_key)
	_spawn_enemy("rabbit", center + Vector2(40.0, 0.0), 99.0)
	app.set("gold", 60)
	app.set("enemy_gold", 1)
	app.call("_tower_attack", tower_key, BoardRules.PLAYER)
	_expect_equal(int(app.get("gold")), 61, "plunder adds one transferred gold to the tower owner")
	_expect_equal(int(app.get("enemy_gold")), 0, "plunder removes one gold from the attacked team")
	app.call("_tower_attack", tower_key, BoardRules.PLAYER)
	_expect_equal(int(app.get("gold")), 61, "attacking a zero-gold target does not mint gold")
	_expect_equal(int(app.get("enemy_gold")), 0, "zero-gold target remains non-negative")


func _test_twin_shot_hits_one_distinct_extra_unit() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_twinshot_tower")
	var center: Vector2 = app.call("_hex_center", tower_key)
	var ids = [
		_spawn_enemy("rabbit", center + Vector2(35.0, 0.0), 10.0),
		_spawn_enemy("rabbit", center + Vector2(65.0, 0.0), 10.0),
		_spawn_enemy("rabbit", center + Vector2(95.0, 0.0), 10.0),
	]
	app.call("_tower_attack", tower_key, BoardRules.PLAYER)
	var damaged = 0
	var untouched = 0
	for unit_id in ids:
		var index = int(app.call("_unit_index_by_id", unit_id))
		var hp = float((app.get("units") as Array)[index].get("hp", 0.0))
		if is_equal_approx(hp, 9.0):
			damaged += 1
		elif is_equal_approx(hp, 10.0):
			untouched += 1
	_expect_equal(damaged, 2, "twin-shot tower damages exactly two distinct enemy animals")
	_expect_equal(untouched, 1, "twin-shot tower does not hit a third animal")


func _test_bounty_rewards_actual_redirected_kill() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_bounty_tower")
	var center: Vector2 = app.call("_hex_center", tower_key)
	var protected_id = _spawn_enemy("rabbit", center + Vector2(35.0, 0.0), 10.0)
	var guardian_id = _spawn_enemy("mammoth", center + Vector2(62.0, 0.0), 2.0)
	app.set("gold", 60)
	app.call("_tower_attack", tower_key, BoardRules.PLAYER)
	var protected_index = int(app.call("_unit_index_by_id", protected_id))
	var guardian_index = int(app.call("_unit_index_by_id", guardian_id))
	var units: Array = app.get("units")
	_expect_close(float(units[protected_index].get("hp", 0.0)), 10.0, "guardian keeps the directly targeted animal unharmed")
	_expect_true(float(units[guardian_index].get("hp", 0.0)) <= 0.0, "bounty tower actually kills the redirected guardian")
	_expect_equal(int(app.get("gold")), 70, "bounty rewards the actual redirected animal kill")


func _test_bounty_requires_a_lethal_animal_hit() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_bounty_tower")
	var center: Vector2 = app.call("_hex_center", tower_key)
	var target_id = _spawn_enemy("rabbit", center + Vector2(35.0, 0.0), 10.0)
	app.set("gold", 60)
	app.call("_tower_attack", tower_key, BoardRules.PLAYER)
	var target_index = int(app.call("_unit_index_by_id", target_id))
	_expect_close(float((app.get("units") as Array)[target_index].get("hp", 0.0)), 7.0, "nonlethal bounty hit still deals its final three damage")
	_expect_equal(int(app.get("gold")), 60, "nonlethal animal hit grants no bounty")


func _test_territory_tower_uses_live_tile_owner() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_territory_tower")
	var tiles: Dictionary = app.get("tiles")
	var target_key = _farthest_tile_key(tower_key, tiles)
	_expect_true(target_key != tower_key, "territory test finds a distinct target tile")
	if target_key == tower_key:
		return
	var territory_tile: Dictionary = (tiles[target_key] as Dictionary).duplicate(true)
	territory_tile["team"] = BoardRules.NEUTRAL
	territory_tile["occupier"] = BoardRules.NEUTRAL
	territory_tile["territory_team"] = BoardRules.PLAYER
	tiles[target_key] = territory_tile
	app.set("tiles", tiles)
	var unit_id = _spawn_enemy("rabbit", app.call("_hex_center", target_key), 10.0)
	var card: Dictionary = app.call("_card_by_id", "defense_territory_tower")
	var stats: Dictionary = app.call("_card_stats_for_team", card, BoardRules.PLAYER)
	var acquired: Dictionary = app.call(
		"_nearest_tower_attack_target",
		tower_key,
		BoardRules.PLAYER,
		float(stats.get("attack_range", 0.0)),
		true,
		card
	)
	_expect_equal(int(acquired.get("unit_id", -1)), unit_id, "territory tower acquires a far enemy animal on allied territory")
	territory_tile["territory_team"] = BoardRules.ENEMY
	tiles = app.get("tiles")
	tiles[target_key] = territory_tile
	app.set("tiles", tiles)
	acquired = app.call(
		"_nearest_tower_attack_target",
		tower_key,
		BoardRules.PLAYER,
		float(stats.get("attack_range", 0.0)),
		true,
		card
	)
	_expect_true(acquired.is_empty(), "territory tower rejects the same animal immediately after live territory ownership changes")


func _test_global_pulse_hits_every_living_animal_once() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_storm_obelisk")
	var center: Vector2 = app.call("_hex_center", tower_key)
	var player_id = _spawn_unit(BoardRules.PLAYER, "rabbit", center + Vector2(30.0, 0.0), 3.0)
	var enemy_id = _spawn_enemy("rabbit", center + Vector2(55.0, 0.0), 3.0)
	var far_enemy_id = _spawn_enemy("rabbit", center + Vector2(900.0, 0.0), 3.0)
	app.call("_tower_attack", tower_key, BoardRules.PLAYER)
	for unit_id in [player_id, enemy_id, far_enemy_id]:
		var index = int(app.call("_unit_index_by_id", unit_id))
		_expect_close(float((app.get("units") as Array)[index].get("hp", 0.0)), 2.0, "global pulse deals exactly one damage to unit %d" % unit_id)


func _test_global_pulse_preserves_damage_and_kill_context() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_storm_obelisk")
	var center: Vector2 = app.call("_hex_center", tower_key)
	var gorilla_id = _spawn_unit(BoardRules.ENEMY, "gorilla", center + Vector2(40.0, 0.0), 4.0, true)
	_spawn_unit(BoardRules.ENEMY, "pig", center + Vector2(70.0, 0.0), 1.0, true)
	_spawn_unit(BoardRules.PLAYER, "pig", center + Vector2(100.0, 0.0), 1.0, true)
	var gorilla_index = int(app.call("_unit_index_by_id", gorilla_id))
	var attack_before = float((app.get("units") as Array)[gorilla_index].get("attack", 0.0))
	app.set("gold", 60)
	app.call("_tower_attack", tower_key, BoardRules.PLAYER)
	_expect_close(float((app.get("units") as Array)[gorilla_index].get("attack", 0.0)), attack_before + 1.0, "global pulse triggers ordinary on-damage animal skills")
	_expect_equal(int(app.get("gold")), 70, "tower team receives both enemy and friendly-fire killer rewards with preserved source attribution")


func _test_global_pulse_stays_within_72_unit_budget() -> void:
	app.call("_reset_battle")
	var tower_key = _setup_tower("defense_storm_obelisk")
	var center: Vector2 = app.call("_hex_center", tower_key)
	for index in range(72):
		var team = BoardRules.PLAYER if index % 2 == 0 else BoardRules.ENEMY
		_spawn_unit(team, "rabbit", center + Vector2(160.0 + float(index % 12) * 8.0, float(index / 12) * 8.0), 500.0)
	var before_count = (app.get("units") as Array).filter(func(unit: Dictionary) -> bool: return float(unit.get("hp", 0.0)) > 0.0).size()
	var started_usec = Time.get_ticks_usec()
	app.call("_tower_attack", tower_key, BoardRules.PLAYER)
	var elapsed_usec = Time.get_ticks_usec() - started_usec
	_expect_equal(before_count, 72, "global pulse performance fixture contains the full 72-unit cap")
	_expect_true(elapsed_usec <= 100000, "one 72-unit global pulse completes within a 100 ms debug-test budget (actual %d us)" % elapsed_usec)


func _test_all_skill_descriptions_wrap_without_ellipsis() -> void:
	var tower_ids = [
		"defense_watch_tower",
		"defense_longshot_tower",
		"defense_cannon_tower",
		"defense_plunder_tower",
		"defense_rapid_tower",
		"defense_repair_beacon",
		"defense_twinshot_tower",
		"defense_bounty_tower",
		"defense_territory_tower",
		"defense_storm_obelisk",
	]
	for tower_id in tower_ids:
		var card: Dictionary = app.call("_card_by_id", tower_id)
		var text = String(card.get("skill_text", ""))
		if tower_id == "defense_watch_tower":
			_expect_equal(text, "", "base tower keeps the producer's blank skill-description cell")
			_expect_equal(app.call("_card_detail_skill_text", card), "", "base tower does not draw an invented skill line")
			continue
		var lines: Array = app.call("_split_text_for_width", text, 370.0, 14, 2)
		_expect_true(lines.size() >= 1 and lines.size() <= 2, "%s description uses at most two complete lines" % tower_id)
		_expect_equal("".join(lines), text, "%s description keeps every character without ellipsis" % tower_id)


func _setup_tower(card_id: String) -> Vector2i:
	var tower_key: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	var tiles: Dictionary = app.get("tiles")
	var tile: Dictionary = (tiles[tower_key] as Dictionary).duplicate(true)
	tile["building"] = "tower"
	tile["team"] = BoardRules.PLAYER
	tile["occupier"] = BoardRules.NEUTRAL
	tile["territory_team"] = BoardRules.PLAYER
	tile["site_card"] = card_id
	tile["hp"] = 999.0
	tile["max_hp"] = 999.0
	tile["spawn_timer"] = 0.0
	tiles[tower_key] = tile
	app.set("tiles", tiles)
	app.set("tower_target_locks", {})
	return tower_key


func _spawn_enemy(card_id: String, pos: Vector2, hp: float) -> int:
	return _spawn_unit(BoardRules.ENEMY, card_id, pos, hp)


func _farthest_tile_key(origin: Vector2i, tiles: Dictionary) -> Vector2i:
	var origin_pos: Vector2 = app.call("_hex_center", origin)
	var best_key = origin
	var best_distance = -1.0
	for key_value in tiles.keys():
		var key: Vector2i = key_value
		var distance = origin_pos.distance_to(app.call("_hex_center", key))
		if distance > best_distance:
			best_distance = distance
			best_key = key
	return best_key


func _spawn_unit(team: int, card_id: String, pos: Vector2, hp: float, skill_triggers_enabled: bool = false) -> int:
	var spawn_key: Vector2i = app.call("_battle_base_key", team)
	app.call("_spawn_unit", team, spawn_key, card_id, false, 0, {"skill_triggers_enabled": skill_triggers_enabled})
	var units: Array = app.get("units")
	var index = units.size() - 1
	var unit: Dictionary = units[index]
	unit["pos"] = pos
	unit["tile"] = app.call("_tile_at_world", pos)
	unit["hp"] = hp
	unit["max_hp"] = maxf(hp, float(unit.get("max_hp", hp)))
	unit["shield"] = 0.0
	unit["cooldown"] = 9999.0
	units[index] = unit
	app.set("units", units)
	return int(unit.get("id", -1))


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	_fail("%s: expected true" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_close(actual: float, expected: float, label: String) -> void:
	if is_equal_approx(actual, expected):
		return
	_fail("%s: expected %.3f, got %.3f" % [label, expected, actual])


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
