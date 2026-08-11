extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_legendary_camp_guard_and_capacity_wait()
	_test_ready_camp_status_and_priority()
	_test_classic_ready_camp_priority()
	_test_equal_attack_ready_camp_tie_break()
	if failures == 0:
		print("Legendary camp guard tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_legendary_camp_guard_and_capacity_wait() -> void:
	var team = BoardRules.PLAYER
	var legendary_key = Vector2i(90, 1)
	var fallback_key = Vector2i(91, 1)
	var roster = [
		"gold_mine_card",
		"defense_watch_tower",
		"rabbit",
		"wolf",
		"lynx",
		"elephant",
	]
	app.set("battle_mode", MainApp.BATTLE_MODE_MULTIPLAYER)
	app.set("room_active_team_ids", [team])
	app.set("multiplayer_alive", {team: true})
	app.set("multiplayer_team_decks", {team: roster})
	app.set("multiplayer_team_card_levels", {team: {}})
	app.set("team_spawned_legendary_buildings", {})
	app.set("units", [])
	var animal_cap = int(app.call("_animal_cap_per_living_faction"))

	var legendary_camp = _camp_tile("legendary", 71)
	var fallback_camp = _camp_tile("legendary", 73)
	app.set("tiles", {
		legendary_key: legendary_camp.duplicate(true),
		fallback_key: fallback_camp.duplicate(true),
	})

	_expect_true(
		bool(app.call("_complete_building_unlock", legendary_key, team, "hall", "elephant")),
		"first legendary animal camp unlocks"
	)
	var after_first: Dictionary = app.get("tiles")
	var first_tile: Dictionary = after_first[legendary_key]
	_expect_equal(String(first_tile.get("building", "")), "hall", "legendary animal binds to a camp")
	_expect_equal(String(first_tile.get("site_card", "")), "elephant", "first camp retains its legendary animal")
	_expect_equal(
		String(app.call("_card_kind_by_id", String(first_tile.get("site_card", "")))),
		"animal",
		"camp binding is always an animal card"
	)

	var resolved_fallback = String(app.call("_site_card_for_team", fallback_key, fallback_camp, team, ""))
	var fallback_card: Dictionary = app.call("_card_by_id", resolved_fallback)
	_expect_false(resolved_fallback.is_empty(), "duplicate legendary target resolves to a usable fallback camp")
	_expect_true(
		String(app.call("_card_kind_by_id", resolved_fallback)) == "animal",
		"fallback camp still binds an animal instead of a building or blank"
	)
	_expect_true(resolved_fallback != "elephant", "the same legendary animal cannot occupy two camps for one team")
	_expect_true(
		int(app.call("_rarity_sort_rank", String(fallback_card.get("rarity", "legendary")))) < int(app.call("_rarity_sort_rank", "legendary")),
		"used legendary target falls back to a lower-rarity animal"
	)
	_expect_true(
		bool(app.call("_complete_building_unlock", fallback_key, team, "hall", resolved_fallback)),
		"fallback animal camp unlocks instead of silently becoming empty"
	)

	var prepared_tiles: Dictionary = app.get("tiles")
	var ready_tile: Dictionary = prepared_tiles[legendary_key]
	ready_tile["spawn_timer"] = 0.0
	prepared_tiles[legendary_key] = ready_tile
	var delayed_fallback_tile: Dictionary = prepared_tiles[fallback_key]
	delayed_fallback_tile["spawn_timer"] = 999.0
	prepared_tiles[fallback_key] = delayed_fallback_tile
	app.set("tiles", prepared_tiles)
	app.set("units", _alive_units(team, animal_cap))

	app.call("_update_buildings", 0.10)
	var at_cap_tiles: Dictionary = app.get("tiles")
	var at_cap_camp: Dictionary = at_cap_tiles[legendary_key]
	_expect_equal(String(at_cap_camp.get("building", "")), "hall", "full unit cap never erases a ready camp")
	_expect_equal(String(at_cap_camp.get("site_card", "")), "elephant", "full unit cap preserves the camp's bound animal")
	_expect_equal(
		String(app.call("_card_kind_by_id", String(at_cap_camp.get("site_card", "")))),
		"animal",
		"capacity pressure cannot replace the camp binding with a non-animal"
	)
	_expect_true(
		float(at_cap_camp.get("spawn_timer", 0.0)) < -0.09,
		"a full unit cap records the camp waiting age instead of pretending its ready state is a fresh timer"
	)
	_expect_equal((app.get("units") as Array).size(), animal_cap, "full cap prevents an extra spawn")

	var units_after_cap: Array = app.get("units")
	units_after_cap.pop_back()
	app.set("units", units_after_cap)
	app.call("_update_buildings", 0.01)
	var units_after_release: Array = app.get("units")
	var released_tile: Dictionary = (app.get("tiles") as Dictionary)[legendary_key]
	_expect_equal(units_after_release.size(), animal_cap, "freeing one slot immediately lets the ready camp spawn")
	if units_after_release.size() == animal_cap:
		var spawned: Dictionary = units_after_release[units_after_release.size() - 1]
		_expect_equal(String(spawned.get("card", "")), "elephant", "released camp spawns its bound legendary animal")
	_expect_true(float(released_tile.get("spawn_timer", 0.0)) > 0.0, "camp delay resets only after a successful spawn")


func _test_ready_camp_status_and_priority() -> void:
	var team = BoardRules.PLAYER
	var oldest_key = Vector2i(96, 2)
	var newer_key = Vector2i(97, 2)
	app.set("battle_mode", MainApp.BATTLE_MODE_MULTIPLAYER)
	app.set("room_active_team_ids", [team])
	app.set("multiplayer_alive", {team: true})
	app.set("multiplayer_team_decks", {team: ["rabbit", "goat"]})
	app.set("multiplayer_team_card_levels", {team: {}})
	var animal_cap = int(app.call("_animal_cap_per_living_faction"))
	app.set("units", _alive_units(team, animal_cap))
	app.set("tiles", {
		oldest_key: _camp_tile("common", 83),
		newer_key: _camp_tile("common", 89),
	})
	app.call("_set_building", oldest_key, team, "barracks", "rabbit")
	app.call("_set_building", newer_key, team, "barracks", "goat")

	var prepared_tiles: Dictionary = app.get("tiles")
	var oldest_tile: Dictionary = prepared_tiles[oldest_key]
	oldest_tile["spawn_timer"] = -1.0
	prepared_tiles[oldest_key] = oldest_tile
	var newer_tile: Dictionary = prepared_tiles[newer_key]
	newer_tile["spawn_timer"] = -0.2
	prepared_tiles[newer_key] = newer_tile
	app.set("tiles", prepared_tiles)

	_expect_equal(
		String(app.call("_camp_spawn_state", _camp_tile("common", 97))),
		"not_camp",
		"an unbuilt camp site is never reported as a ready production building"
	)
	_expect_equal(
		String(app.call("_camp_spawn_state", oldest_tile)),
		"population_full",
		"a ready camp reports the visible full-population waiting state"
	)

	var units_after_first_release: Array = app.get("units")
	units_after_first_release.pop_back()
	app.set("units", units_after_first_release)
	app.call("_update_buildings", 0.01)
	var after_first_spawn: Array = app.get("units")
	_expect_equal(
		String(after_first_spawn[after_first_spawn.size() - 1].get("card", "")),
		"goat",
		"the highest-attack ready camp receives the first available population slot"
	)

	var units_after_second_release: Array = app.get("units")
	units_after_second_release.pop_back()
	app.set("units", units_after_second_release)
	app.call("_update_buildings", 0.01)
	var after_second_spawn: Array = app.get("units")
	_expect_equal(
		String(after_second_spawn[after_second_spawn.size() - 1].get("card", "")),
		"rabbit",
		"the lower-attack camp remains ready for the following population slot"
	)


func _test_classic_ready_camp_priority() -> void:
	var team = BoardRules.PLAYER
	var low_attack_key = Vector2i(98, 2)
	var high_attack_key = Vector2i(99, 2)
	app.set("battle_mode", MainApp.BATTLE_MODE_CLASSIC)
	var animal_cap = int(app.call("_animal_cap_per_living_faction"))
	app.set("units", _alive_units(team, animal_cap - 1))
	app.set("tiles", {
		low_attack_key: _camp_tile("common", 101),
		high_attack_key: _camp_tile("common", 103),
	})
	app.call("_set_building", low_attack_key, team, "barracks", "rabbit")
	app.call("_set_building", high_attack_key, team, "barracks", "goat")
	var prepared_tiles: Dictionary = app.get("tiles")
	for key in [low_attack_key, high_attack_key]:
		var tile: Dictionary = prepared_tiles[key]
		tile["spawn_timer"] = -0.1
		prepared_tiles[key] = tile
	app.set("tiles", prepared_tiles)
	app.call("_update_buildings", 0.01)
	var spawned_units: Array = app.get("units")
	_expect_equal(
		String(spawned_units[spawned_units.size() - 1].get("card", "")),
		"goat",
		"classic battle also prioritizes the highest-attack ready camp"
	)


func _test_equal_attack_ready_camp_tie_break() -> void:
	var team = BoardRules.PLAYER
	var oldest_key = Vector2i(100, 2)
	var newer_key = Vector2i(101, 2)
	app.set("battle_mode", MainApp.BATTLE_MODE_MULTIPLAYER)
	app.set("room_active_team_ids", [team])
	app.set("multiplayer_alive", {team: true})
	app.set("multiplayer_team_decks", {team: ["rabbit"]})
	app.set("multiplayer_team_card_levels", {team: {}})
	var animal_cap = int(app.call("_animal_cap_per_living_faction"))
	app.set("units", _alive_units(team, animal_cap - 1))
	app.set("tiles", {
		oldest_key: _camp_tile("common", 107),
		newer_key: _camp_tile("common", 109),
	})
	app.call("_set_building", oldest_key, team, "barracks", "rabbit")
	app.call("_set_building", newer_key, team, "barracks", "rabbit")
	var prepared_tiles: Dictionary = app.get("tiles")
	var oldest_tile: Dictionary = prepared_tiles[oldest_key]
	oldest_tile["spawn_timer"] = -1.0
	prepared_tiles[oldest_key] = oldest_tile
	var newer_tile: Dictionary = prepared_tiles[newer_key]
	newer_tile["spawn_timer"] = -0.2
	prepared_tiles[newer_key] = newer_tile
	app.set("tiles", prepared_tiles)
	app.call("_update_buildings", 0.01)
	var after_spawn_tiles: Dictionary = app.get("tiles")
	_expect_true(
		float((after_spawn_tiles[oldest_key] as Dictionary).get("spawn_timer", 0.0)) > 0.0,
		"equal-attack camps use the longest waiting camp as the deterministic tie-break"
	)
	_expect_true(
		float((after_spawn_tiles[newer_key] as Dictionary).get("spawn_timer", 0.0)) < 0.0,
		"the newer equal-attack camp remains ready after the oldest one gets the slot"
	)


func _camp_tile(target_rarity: String, site_seed: int) -> Dictionary:
	var tile = BoardRules.with_site(BoardRules.empty_locked_tile(), BoardRules.camp_site_for_cost(BoardRules.UNIT_HIGH_PRICE))
	tile["site_target_rarity"] = target_rarity
	tile["site_roll_seed"] = site_seed
	return tile


func _alive_units(team: int, count: int) -> Array:
	var result = []
	for index in range(count):
		result.append({
			"id": 1000 + index,
			"team": team,
			"card": "rabbit",
			"hp": 10.0,
			"max_hp": 10.0,
			"base_max_hp": 10.0,
			"attack": 1.0,
			"base_attack": 1.0,
			"attack_bonus": 0.0,
			"speed": 0.0,
			"base_speed": 0.0,
			"range": 40.0,
			"base_range": 40.0,
			"shield": 0.0,
			"skill_triggers_enabled": false,
			"pos": Vector2(float(index) * 8.0, 0.0),
			"tile": Vector2i.ZERO,
		})
	return result


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
