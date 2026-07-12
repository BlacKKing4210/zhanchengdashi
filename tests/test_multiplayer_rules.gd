extends SceneTree

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

var failures = 0
var tiles = {}


func _init() -> void:
	tiles = MultiplayerRules.create_initial_tiles()
	_test_board_size_and_shape()
	_test_six_balanced_territories()
	_test_team_bases()
	_test_starting_unlock_neighbors()
	_test_coordinate_round_trip()
	_test_neighbors_stay_on_board()
	_test_placement_rewards()
	if failures == 0:
		print("Multiplayer rules tests passed.")
	quit(failures)


func _test_board_size_and_shape() -> void:
	_expect_equal(tiles.size(), 1141, "side-20 hex contains 1141 cells")
	_expect_true(tiles.has(Vector2i.ZERO), "board contains center cell")
	_expect_true(MultiplayerRules.contains(Vector2i(19, 0)), "radius edge is contained")
	_expect_true(MultiplayerRules.contains(Vector2i(-19, 19)), "radius corner is contained")
	_expect_false(MultiplayerRules.contains(Vector2i(20, 0)), "cell beyond radius is rejected")
	_expect_false(MultiplayerRules.contains(Vector2i(-20, 20)), "corner beyond radius is rejected")


func _test_six_balanced_territories() -> void:
	var counts = {}
	for team in MultiplayerRules.TEAM_IDS:
		counts[team] = 0
	var neutral_count = 0
	for key in tiles:
		var team = MultiplayerRules.team_for_key(key)
		if team == BoardRules.NEUTRAL:
			neutral_count += 1
			_expect_equal(key, Vector2i.ZERO, "only center cell is neutral")
			continue
		_expect_true(team in MultiplayerRules.TEAM_IDS, "non-center cell belongs to a valid team")
		counts[team] = int(counts.get(team, 0)) + 1
		_expect_equal(
			int(tiles[key].get("territory_team", BoardRules.NEUTRAL)),
			team,
			"tile territory matches geometric sector"
		)
	_expect_equal(neutral_count, 1, "exactly one neutral center cell")
	for team in MultiplayerRules.TEAM_IDS:
		_expect_equal(int(counts[team]), 190, "team %d owns one sixth of non-center cells" % team)


func _test_team_bases() -> void:
	var seen_keys = {}
	for team in MultiplayerRules.TEAM_IDS:
		var key = MultiplayerRules.base_key(team)
		_expect_true(MultiplayerRules.contains(key), "team %d base is on board" % team)
		_expect_false(seen_keys.has(key), "team %d base key is unique" % team)
		seen_keys[key] = true
		_expect_equal(MultiplayerRules.team_for_key(key), team, "team %d base is in its sector" % team)
		_expect_true(tiles.has(key), "team %d base tile exists" % team)
		if not tiles.has(key):
			continue
		var tile = tiles[key]
		_expect_equal(int(tile.get("team", BoardRules.NEUTRAL)), team, "team %d owns its base" % team)
		_expect_equal(BoardRules.visual_owner(tile), team, "team %d base visual owner matches" % team)
		_expect_equal(String(tile.get("building", "")), "base", "team %d starts with a base" % team)
		_expect_true(float(tile.get("hp", 0.0)) > 0.0, "team %d base starts alive" % team)
	_expect_equal(
		MultiplayerRules.base_key(99),
		MultiplayerRules.INVALID_KEY,
		"unknown team has no base"
	)


func _test_starting_unlock_neighbors() -> void:
	for team in MultiplayerRules.TEAM_IDS:
		var base = MultiplayerRules.base_key(team)
		var mine = MultiplayerRules.starting_mine_key(tiles, base)
		var camp = MultiplayerRules.starting_camp_key(tiles, base, mine)
		var neighbors = MultiplayerRules.neighbors(base)
		_expect_true(mine in neighbors, "team %d mine is adjacent to base" % team)
		_expect_true(camp in neighbors, "team %d camp is adjacent to base" % team)
		_expect_true(mine != camp, "team %d mine and camp use different cells" % team)
		_expect_equal(String(tiles[mine].get("site", "")), "mine", "team %d starts next to a mine" % team)
		_expect_equal(
			int(tiles[mine].get("site_cost", 0)),
			BoardRules.MINE_PRICE,
			"team %d starting mine uses mine price" % team
		)
		_expect_equal(String(tiles[camp].get("site", "")), "barracks", "team %d starts next to a low camp" % team)
		_expect_equal(
			int(tiles[camp].get("site_cost", 0)),
			BoardRules.UNIT_LOW_PRICE,
			"team %d starting camp uses low price" % team
		)
		_expect_true(MultiplayerRules.can_unlock(tiles, mine, team), "team %d can unlock adjacent mine" % team)
		_expect_true(MultiplayerRules.can_unlock(tiles, camp, team), "team %d can unlock adjacent camp" % team)
		var rival_team = team % MultiplayerRules.TEAM_IDS.size() + 1
		_expect_false(
			MultiplayerRules.can_unlock(tiles, mine, rival_team),
			"rival cannot unlock team %d starting mine" % team
		)
	_expect_false(
		MultiplayerRules.can_unlock(tiles, Vector2i.ZERO, BoardRules.NEUTRAL),
		"neutral team cannot unlock cells"
	)


func _test_coordinate_round_trip() -> void:
	var origin = Vector2(321.5, -87.25)
	var hex_size = 26.0
	for key in tiles:
		var center = MultiplayerRules.hex_center(key, origin, hex_size)
		_expect_equal(
			MultiplayerRules.tile_at(tiles, center, origin, hex_size),
			key,
			"hex center round-trips for %s" % str(key)
		)
	_expect_equal(
		MultiplayerRules.tile_at(tiles, origin, origin, hex_size),
		Vector2i.ZERO,
		"origin maps to center cell"
	)
	var outside = MultiplayerRules.hex_center(Vector2i(20, 0), origin, hex_size)
	_expect_equal(
		MultiplayerRules.tile_at(tiles, outside, origin, hex_size),
		MultiplayerRules.INVALID_KEY,
		"position beyond board maps to invalid key"
	)
	_expect_equal(
		MultiplayerRules.tile_at(tiles, origin, origin, 0.0),
		MultiplayerRules.INVALID_KEY,
		"zero hex size maps to invalid key"
	)


func _test_neighbors_stay_on_board() -> void:
	_expect_equal(MultiplayerRules.neighbors(Vector2i.ZERO).size(), 6, "center has six neighbors")
	_expect_equal(MultiplayerRules.neighbors(Vector2i(19, 0)).size(), 3, "corner has three neighbors")
	for key in tiles:
		for neighbor in MultiplayerRules.neighbors(key):
			_expect_true(tiles.has(neighbor), "neighbor of %s remains on board" % str(key))
			_expect_true(key in MultiplayerRules.neighbors(neighbor), "neighbor relation is reciprocal")


func _test_placement_rewards() -> void:
	var expected = {
		1: [3, 5],
		2: [2, 2],
		3: [2, 2],
		4: [-1, 1],
		5: [-1, 1],
		6: [-1, 1],
	}
	for placement in expected:
		var reward = MultiplayerRules.placement_rewards(placement)
		_expect_equal(
			int(reward.get("star_delta", 0)),
			int(expected[placement][0]),
			"placement %d star reward" % placement
		)
		_expect_equal(
			int(reward.get("gacha_tickets", 0)),
			int(expected[placement][1]),
			"placement %d ticket reward" % placement
		)
	_expect_true(MultiplayerRules.placement_rewards(0).is_empty(), "placement below range has no reward")
	_expect_true(MultiplayerRules.placement_rewards(7).is_empty(), "placement above range has no reward")
	var mutable_reward = MultiplayerRules.placement_rewards(1)
	mutable_reward["star_delta"] = 99
	_expect_equal(
		int(MultiplayerRules.placement_rewards(1).get("star_delta", 0)),
		3,
		"reward lookup returns an independent copy"
	)


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
