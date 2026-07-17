extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_team_mode_elimination_transfer()
	_test_free_for_all_elimination_transfer()
	_test_classic_transfer_before_result()
	if failures == 0:
		print("Multiplayer elimination transfer tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_team_mode_elimination_transfer() -> void:
	const ATTACKER = 1
	const DEFEATED = 4
	const SURVIVOR = 5
	_start_multiplayer("3v3_crossroads", 3, false)
	var base_keys = _multiplayer_base_keys()
	var defeated_base: Vector2i = base_keys.get(DEFEATED, MultiplayerRules.INVALID_KEY)
	var attacker_base: Vector2i = base_keys.get(ATTACKER, MultiplayerRules.INVALID_KEY)
	var tiles: Dictionary = app.get("tiles")
	var near_key = _first_site_neighbor(tiles, defeated_base)
	var building_key = _first_territory_key(tiles, DEFEATED, [defeated_base, near_key])
	var empty_key = _first_territory_key(tiles, DEFEATED, [defeated_base, near_key, building_key])
	var third_party_key = _first_territory_key(tiles, DEFEATED, [defeated_base, near_key, building_key, empty_key])

	_expect_not_equal(near_key, MultiplayerRules.INVALID_KEY, "captured base has an adjacent site to re-unlock")
	_expect_not_equal(building_key, MultiplayerRules.INVALID_KEY, "defeated territory has a building test tile")
	_expect_not_equal(empty_key, MultiplayerRules.INVALID_KEY, "defeated territory has an unlocked-empty test tile")
	_expect_not_equal(third_party_key, MultiplayerRules.INVALID_KEY, "defeated territory has a third-party protection tile")

	var attacker_tiles_before = int(app.call("_tile_count", ATTACKER))
	app.call("_set_building", building_key, DEFEATED, "tower", "defense_watch_tower")
	tiles = app.get("tiles")
	tiles[empty_key] = BoardRules.as_unlocked_empty(tiles[empty_key], DEFEATED)
	tiles[third_party_key] = BoardRules.with_building(
		tiles[third_party_key],
		SURVIVOR,
		"tower",
		"defense_watch_tower",
		BoardRules.building_hp("tower"),
		BoardRules.building_delay("tower", SURVIVOR)
	)
	app.set("tiles", tiles)
	var expected_transfer_keys = _transfer_keys(tiles, DEFEATED, defeated_base)
	app.call("_spawn_unit", DEFEATED, defeated_base, "rabbit")

	var attacker_bases_before = int(app.call("_building_count", ATTACKER, "base"))
	_expect_true(bool(app.call("_damage_tile", defeated_base, ATTACKER, 99999.0)), "lethal damage destroys the original base")
	tiles = app.get("tiles")

	_expect_false(bool(app.call("_is_multiplayer_team_alive", DEFEATED)), "original base destruction eliminates its slot owner")
	_expect_false(bool(app.get("game_over")), "one defeated rival does not end a 2v2 match")
	_expect_equal(int(app.call("_building_count", ATTACKER, "base")), attacker_bases_before + 1, "captured base counts as an attacker base")
	_expect_equal(int(app.call("_tile_count", ATTACKER)), attacker_tiles_before + expected_transfer_keys.size() + 1, "all defeated territory becomes attacker-owned immediately")
	_expect_equal(int(app.call("_original_base_hp", DEFEATED)), 0, "captured base HP is not scored for the eliminated origin team")
	_assert_captured_base(tiles[defeated_base], ATTACKER, "destroyed original base transfers to attacker")
	_assert_transferred_tile(tiles[near_key], ATTACKER, "adjacent locked territory becomes owned")
	_assert_transferred_tile(tiles[building_key], ATTACKER, "defeated building territory becomes owned")
	_assert_transferred_tile(tiles[empty_key], ATTACKER, "previously unlocked empty territory remains owned")
	_expect_equal(String(tiles[building_key].get("building", "missing")), "", "defeated tower is cleared while its territory transfers")
	_expect_equal(String(tiles[building_key].get("site_card", "missing")), "", "cleared tower cannot retain an out-of-deck card")
	_expect_false(MultiplayerRules.can_unlock(tiles, near_key, ATTACKER), "transferred territory is already unlocked")
	_expect_equal(int(tiles[third_party_key].get("team", BoardRules.NEUTRAL)), SURVIVOR, "third-party owned tile is not confiscated with stale territory")
	_expect_equal(String(tiles[third_party_key].get("building", "")), "tower", "third-party building survives another team's elimination")
	for key in expected_transfer_keys:
		_assert_transferred_tile(tiles[key], ATTACKER, "every defeated controlled tile transfers")

	for unit in app.get("units"):
		if int(unit.get("team", BoardRules.NEUTRAL)) == DEFEATED:
			_expect_true(float(unit.get("hp", 0.0)) <= 0.0, "all defeated-team units are cleared")

	var gold_before_unlock_attempt = int(app.call("_gold_for_team", ATTACKER))
	_expect_false(bool(app.call("_try_unlock", near_key)), "already transferred territory cannot be purchased again")
	_expect_equal(int(app.call("_gold_for_team", ATTACKER)), gold_before_unlock_attempt, "transferred territory charges no second unlock cost")

	var base_count = int(app.call("_building_count", ATTACKER, "base"))
	var mine_count = int(app.call("_building_count", ATTACKER, "mine"))
	var gold_before = int(app.call("_gold_for_team", ATTACKER))
	app.set("income_timer", 0.0)
	app.call("_update_battle", 0.01)
	var gold_after = int(app.call("_gold_for_team", ATTACKER))
	var expected_income = base_count * int(MainApp.BASE_INCOME) + mine_count * int(MainApp.MINE_INCOME)
	_expect_equal(gold_after - gold_before, expected_income, "captured base contributes one exact base-income share")

	var enemy_unit_id = int(app.get("next_unit_id"))
	app.call("_spawn_unit", SURVIVOR, defeated_base, "rabbit")
	var enemy_hp_before = _unit_hp(enemy_unit_id)
	tiles = app.get("tiles")
	for key in tiles.keys():
		if String(tiles[key].get("building", "")) != "":
			var muted_building: Dictionary = tiles[key]
			muted_building["spawn_timer"] = 999.0
			tiles[key] = muted_building
	var captured_base_tile: Dictionary = tiles[defeated_base]
	captured_base_tile["spawn_timer"] = 0.0
	tiles[defeated_base] = captured_base_tile
	app.set("tiles", tiles)
	app.call("_update_buildings", 0.01)
	_expect_true(_unit_hp(enemy_unit_id) < enemy_hp_before, "captured base attacks a nearby enemy unit")

	var player_unit_id = int(app.get("next_unit_id"))
	app.call("_spawn_unit", ATTACKER, attacker_base, "rabbit")
	_expect_true(bool(app.call("_damage_tile", defeated_base, SURVIVOR, 99999.0)), "captured base can be destroyed and captured again")
	tiles = app.get("tiles")
	_assert_captured_base(tiles[defeated_base], SURVIVOR, "captured base transfers to the new attacker")
	_expect_true(bool(app.call("_is_multiplayer_team_alive", ATTACKER)), "losing a captured secondary base does not eliminate its current owner")
	_expect_true(_unit_hp(player_unit_id) > 0.0, "secondary-base loss does not clear the current owner's units")
	_expect_equal(int(tiles[attacker_base].get("team", BoardRules.NEUTRAL)), ATTACKER, "secondary-base loss does not transfer the current owner's original base")
	_expect_equal(int(tiles[near_key].get("team", BoardRules.NEUTRAL)), ATTACKER, "secondary-base loss does not transfer surrounding attacker property")


func _test_free_for_all_elimination_transfer() -> void:
	const ATTACKER = 1
	const DEFEATED = 4
	_start_multiplayer("3v3_crossroads", 3, true)
	var base_keys = _multiplayer_base_keys()
	var defeated_base: Vector2i = base_keys.get(DEFEATED, MultiplayerRules.INVALID_KEY)
	var tiles_before: Dictionary = app.get("tiles")
	var expected_transfer_keys = _transfer_keys(tiles_before, DEFEATED, defeated_base)
	var attacker_score_before = int(app.call("_multiplayer_tile_score", ATTACKER))
	_expect_true(bool(app.call("_damage_tile", defeated_base, ATTACKER, 99999.0)), "FFA original base can be destroyed")
	var tiles: Dictionary = app.get("tiles")
	_expect_false(bool(app.call("_is_multiplayer_team_alive", DEFEATED)), "FFA base owner is eliminated")
	_expect_false(bool(app.get("game_over")), "FFA continues while multiple players remain")
	_assert_captured_base(tiles[defeated_base], ATTACKER, "FFA destroyed base transfers to the attacker")
	_expect_equal(int(app.call("_multiplayer_tile_score", DEFEATED)), 0, "FFA eliminated player has zero tile score")
	_expect_equal(int(app.call("_multiplayer_tile_score", ATTACKER)), attacker_score_before + expected_transfer_keys.size() + 1, "FFA attacker gains the defeated player's full territory score")
	for key in expected_transfer_keys:
		_assert_transferred_tile(tiles[key], ATTACKER, "FFA defeated territory transfers instead of turning gray")
		_expect_equal(int(tiles[key].get("eliminated_team", BoardRules.NEUTRAL)), BoardRules.NEUTRAL, "FFA transfer clears any gray marker")


func _test_classic_transfer_before_result() -> void:
	app.call("_start_match")
	var enemy_base = BoardRules.ENEMY_BASE
	if _has_property("classic_base_keys"):
		var base_keys: Dictionary = app.get("classic_base_keys")
		enemy_base = base_keys.get(BoardRules.ENEMY, MultiplayerRules.INVALID_KEY)
	var tiles: Dictionary = app.get("tiles")
	var enemy_tile = _first_territory_key(tiles, BoardRules.ENEMY, [enemy_base])
	app.call("_spawn_unit", BoardRules.ENEMY, enemy_base, "rabbit")
	_expect_true(bool(app.call("_damage_tile", enemy_base, BoardRules.PLAYER, 99999.0)), "classic enemy base can be destroyed")
	tiles = app.get("tiles")
	_expect_true(bool(app.get("game_over")), "classic battle still ends immediately")
	_expect_equal(String(app.get("result_text")), "胜利", "classic transfer preserves the victory result")
	_assert_captured_base(tiles[enemy_base], BoardRules.PLAYER, "classic destroyed base transfers before settlement")
	_assert_transferred_tile(tiles[enemy_tile], BoardRules.PLAYER, "classic enemy territory transfers before settlement")
	for unit in app.get("units"):
		if int(unit.get("team", BoardRules.NEUTRAL)) == BoardRules.ENEMY:
			_expect_true(float(unit.get("hp", 0.0)) <= 0.0, "classic defeated computer units are cleared")


func _start_multiplayer(map_id: String, team_size: int, free_for_all: bool) -> void:
	var argument_count = _method_argument_count("_start_multiplayer_match")
	if argument_count == 0:
		app.call("_start_multiplayer_match")
	else:
		app.call("_start_multiplayer_match", map_id, team_size, free_for_all)


func _multiplayer_base_keys() -> Dictionary:
	if _has_property("room_base_keys"):
		return (app.get("room_base_keys") as Dictionary).duplicate()
	var result = {}
	for team in MultiplayerRules.TEAM_IDS:
		result[team] = MultiplayerRules.base_key(team)
	return result


func _method_argument_count(method_name: String) -> int:
	for method in app.get_method_list():
		if String(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1


func _has_property(property_name: String) -> bool:
	for property in app.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _first_site_neighbor(tiles: Dictionary, base_key: Vector2i) -> Vector2i:
	for key in MultiplayerRules.neighbors(base_key):
		if String(tiles[key].get("site", "")) != "":
			return key
	return MultiplayerRules.INVALID_KEY


func _transfer_keys(tiles: Dictionary, defeated_team: int, excluded_base: Vector2i) -> Array:
	var result = []
	for key in tiles.keys():
		if key == excluded_base:
			continue
		var tile: Dictionary = tiles[key]
		var tile_team = int(tile.get("team", BoardRules.NEUTRAL))
		if tile_team == defeated_team or (tile_team == BoardRules.NEUTRAL and BoardRules.visual_owner(tile) == defeated_team):
			result.append(key)
	return result


func _first_territory_key(tiles: Dictionary, team: int, excluded: Array) -> Vector2i:
	for key in tiles.keys():
		if excluded.has(key):
			continue
		if int(tiles[key].get("territory_team", BoardRules.NEUTRAL)) == team:
			return key
	return MultiplayerRules.INVALID_KEY


func _assert_transferred_tile(tile: Dictionary, attacker: int, label: String) -> void:
	_expect_equal(int(tile.get("team", -99)), attacker, label + " has attacker team")
	_expect_equal(int(tile.get("occupier", -99)), attacker, label + " has attacker occupier")
	_expect_equal(int(tile.get("territory_team", -99)), attacker, label + " has attacker territory")
	_expect_equal(String(tile.get("site", "missing")), "", label + " has no locked site")
	_expect_equal(int(tile.get("site_cost", -1)), 0, label + " has no unlock cost")
	_expect_equal(String(tile.get("building", "missing")), "", label + " clears the defeated building")
	_expect_equal(String(tile.get("site_card", "missing")), "", label + " clears the defeated card binding")
	_expect_equal(float(tile.get("hp", -1.0)), 0.0, label + " clears building HP")
	_expect_equal(float(tile.get("max_hp", -1.0)), 0.0, label + " clears building max HP")
	_expect_equal(float(tile.get("spawn_timer", -1.0)), 0.0, label + " clears building timing")


func _assert_captured_base(tile: Dictionary, attacker: int, label: String) -> void:
	_expect_equal(int(tile.get("team", -99)), attacker, label + " has attacker team")
	_expect_equal(int(tile.get("occupier", -99)), attacker, label + " has attacker occupier")
	_expect_equal(int(tile.get("territory_team", -99)), attacker, label + " has attacker territory")
	_expect_equal(String(tile.get("building", "")), "base", label + " remains a base")
	_expect_equal(float(tile.get("hp", 0.0)), BoardRules.building_hp("base"), label + " restores full HP")
	_expect_equal(float(tile.get("max_hp", 0.0)), BoardRules.building_hp("base"), label + " restores full max HP")
	_expect_true(float(tile.get("spawn_timer", 0.0)) > 0.0, label + " restores attack timing")


func _unit_hp(unit_id: int) -> float:
	for unit in app.get("units"):
		if int(unit.get("id", -1)) == unit_id:
			return float(unit.get("hp", 0.0))
	return 0.0


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


func _expect_not_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		return
	failures += 1
	push_error("%s: did not expect %s" % [label, str(expected)])
