extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const ClassicMapRules = preload("res://scripts/app/systems/classic_map_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

const REGRESSION_SEEDS = [1, 17, 24680, 987654]

var failures = 0


func _ready() -> void:
	_test_all_match_generators([], "default rules")
	var runtime_rows = _load_runtime_board_rows()
	_expect_false(runtime_rows.is_empty(), "runtime board-cell configuration is available")
	if not runtime_rows.is_empty():
		_test_all_match_generators(runtime_rows, "runtime config")
		_test_classic_battle_pipeline(runtime_rows)
	if failures == 0:
		print("OPENING_HIGH_PRICE_TILE_QUOTA_TEST_PASS")
	else:
		push_error("OPENING_HIGH_PRICE_TILE_QUOTA_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _test_all_match_generators(cell_type_rows: Array, rules_label: String) -> void:
	for players_per_side in range(1, MultiplayerRules.MAX_PLAYERS_PER_SIDE + 1):
		for map_id in MultiplayerRules.map_ids_for_size(players_per_side):
			for seed in REGRESSION_SEEDS:
				var label = "%s %s seed %d" % [map_id, rules_label, seed]
				var match_data = MultiplayerRules.create_match(
					players_per_side,
					String(map_id),
					cell_type_rows,
					seed
				)
				_assert_opening_high_price_contract(match_data, players_per_side, label)
				if seed == REGRESSION_SEEDS[0]:
					var replay = MultiplayerRules.create_match(
						players_per_side,
						String(map_id),
						cell_type_rows,
						seed
					)
					_expect_equal(
						_tile_signature(replay.get("tiles", {})),
						_tile_signature(match_data.get("tiles", {})),
						"%s deterministically reproduces its complete tile layout" % label
					)
	for seed in REGRESSION_SEEDS:
		var label = "%s %s seed %d" % [
			MultiplayerRules.FREE_FOR_ALL_MAP_ID,
			rules_label,
			seed,
		]
		var match_data = MultiplayerRules.create_free_for_all_match(cell_type_rows, seed)
		_assert_opening_high_price_contract(
			match_data,
			MultiplayerRules.MAX_PLAYERS_PER_SIDE,
			label
		)
		if seed == REGRESSION_SEEDS[0]:
			var replay = MultiplayerRules.create_free_for_all_match(cell_type_rows, seed)
			_expect_equal(
				_tile_signature(replay.get("tiles", {})),
				_tile_signature(match_data.get("tiles", {})),
				"%s deterministically reproduces its complete tile layout" % label
			)


func _test_classic_battle_pipeline(cell_type_rows: Array) -> void:
	for map_id in MultiplayerRules.map_ids_for_size(1):
		for seed in REGRESSION_SEEDS:
			var generated = MultiplayerRules.create_match(1, String(map_id), cell_type_rows, seed)
			var optimized = ClassicMapRules.optimize_match(generated)
			_assert_opening_high_price_contract(
				optimized,
				1,
				"classic %s runtime config seed %d" % [map_id, seed]
			)


func _assert_opening_high_price_contract(
	match_data: Dictionary,
	players_per_side: int,
	label: String
) -> void:
	_expect_false(match_data.is_empty(), "%s generates a match" % label)
	if match_data.is_empty():
		return
	var tiles: Dictionary = match_data.get("tiles", {})
	var base_keys: Dictionary = match_data.get("base_keys", {})
	var active_teams = MultiplayerRules.active_team_ids(players_per_side)
	for team in active_teams:
		var base: Vector2i = base_keys.get(team, MultiplayerRules.INVALID_KEY)
		_expect_true(tiles.has(base), "%s team %d keeps its base" % [label, team])
		if not tiles.has(base):
			continue
		_expect_equal(
			String(tiles[base].get("building", "")),
			"base",
			"%s team %d base is not overwritten" % [label, team]
		)
		_assert_starting_resources(tiles, base, team, label)
		_assert_exact_mine_quota(tiles, team, label)
		var high_price_keys = _opening_high_price_keys(tiles, base, team)
		_expect_true(
			high_price_keys.size() >= 1,
			"%s team %d has an opening-adjacent unlockable 250 hall" % [label, team]
		)
		for key in high_price_keys:
			var tile: Dictionary = tiles[key]
			_expect_equal(
				int(tile.get("territory_team", BoardRules.NEUTRAL)),
				team,
				"%s team %d owns the 250 hall territory" % [label, team]
			)
			_expect_equal(
				String(tile.get("starting_resource", "")),
				"",
				"%s team %d 250 hall does not replace a starting resource" % [label, team]
			)
			_assert_high_price_symmetry(
				tiles,
				base_keys,
				key,
				team,
				players_per_side,
				label
			)


func _assert_starting_resources(
	tiles: Dictionary,
	base: Vector2i,
	team: int,
	label: String
) -> void:
	var mine = MultiplayerRules.starting_mine_key(tiles, base)
	var camp = MultiplayerRules.starting_camp_key(tiles, base, mine)
	_expect_true(mine in MultiplayerRules.neighbors(tiles, base), "%s team %d keeps its adjacent mine" % [label, team])
	_expect_true(camp in MultiplayerRules.neighbors(tiles, base), "%s team %d keeps its adjacent camp" % [label, team])
	if tiles.has(mine):
		_expect_equal(String(tiles[mine].get("starting_resource", "")), "mine", "%s team %d mine marker is preserved" % [label, team])
		_expect_equal(String(tiles[mine].get("site", "")), "mine", "%s team %d mine site is preserved" % [label, team])
		_expect_equal(int(tiles[mine].get("site_cost", 0)), BoardRules.MINE_PRICE, "%s team %d mine price is preserved" % [label, team])
	if tiles.has(camp):
		_expect_equal(String(tiles[camp].get("starting_resource", "")), "camp", "%s team %d camp marker is preserved" % [label, team])
		_expect_equal(String(tiles[camp].get("site", "")), "barracks", "%s team %d low camp site is preserved" % [label, team])
		_expect_equal(int(tiles[camp].get("site_cost", 0)), BoardRules.UNIT_LOW_PRICE, "%s team %d low camp price is preserved" % [label, team])


func _assert_exact_mine_quota(tiles: Dictionary, team: int, label: String) -> void:
	var mine_count = 0
	var starting_mine_count = 0
	for tile in tiles.values():
		if (
			int(tile.get("territory_team", BoardRules.NEUTRAL)) != team
			or String(tile.get("site", "")) != "mine"
		):
			continue
		mine_count += 1
		if String(tile.get("starting_resource", "")) == "mine":
			starting_mine_count += 1
	_expect_equal(mine_count, 2, "%s team %d still has exactly two mines" % [label, team])
	_expect_equal(starting_mine_count, 1, "%s team %d still has exactly one starting mine" % [label, team])


func _assert_high_price_symmetry(
	tiles: Dictionary,
	base_keys: Dictionary,
	key: Vector2i,
	team: int,
	players_per_side: int,
	label: String
) -> void:
	var counterpart_team = 0
	var counterpart_key = MultiplayerRules.INVALID_KEY
	if players_per_side == MultiplayerRules.MAX_PLAYERS_PER_SIDE:
		counterpart_team = (team % 6) + 1
		counterpart_key = MultiplayerRules.rotate_key(key, 1)
	else:
		counterpart_team = MultiplayerRules.mirror_team(team, players_per_side)
		counterpart_key = MultiplayerRules.mirror_key(key)
	_expect_true(tiles.has(counterpart_key), "%s 250 hall symmetry counterpart exists" % label)
	if not tiles.has(counterpart_key):
		return
	var counterpart_base: Vector2i = base_keys.get(counterpart_team, MultiplayerRules.INVALID_KEY)
	_expect_true(counterpart_key in MultiplayerRules.neighbors(tiles, counterpart_base), "%s 250 hall counterpart is base-adjacent" % label)
	_expect_true(_is_high_price_hall(tiles[counterpart_key]), "%s 250 hall counterpart preserves type and price" % label)
	_expect_true(MultiplayerRules.can_unlock(tiles, counterpart_key, counterpart_team), "%s 250 hall counterpart is immediately unlockable" % label)


func _opening_high_price_keys(tiles: Dictionary, base: Vector2i, team: int) -> Array:
	var result = []
	for key in MultiplayerRules.neighbors(tiles, base):
		if _is_high_price_hall(tiles[key]) and MultiplayerRules.can_unlock(tiles, key, team):
			result.append(key)
	return result


func _is_high_price_hall(tile: Dictionary) -> bool:
	return (
		String(tile.get("site", "")) == "hall"
		and int(tile.get("site_cost", 0)) == BoardRules.UNIT_HIGH_PRICE
		and String(tile.get("building", "")) == ""
	)


func _load_runtime_board_rows() -> Array:
	var file = FileAccess.open("res://runtime/config/board_cells.json", FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func _tile_signature(tiles: Dictionary) -> String:
	var keys = tiles.keys()
	keys.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		if left.y != right.y:
			return left.y < right.y
		return left.x < right.x
	)
	var rows = []
	for key in keys:
		rows.append("%d,%d=%s" % [key.x, key.y, JSON.stringify(tiles[key])])
	return "|".join(rows)


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
