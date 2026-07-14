extends SceneTree

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

const ANY_TERRITORY = -999999
const EXPECTED_TEAMS_BY_SIZE = {
	1: [1, 4],
	2: [1, 2, 4, 5],
	3: [1, 2, 3, 4, 5, 6],
}

var failures = 0
var matches = {}


func _init() -> void:
	_test_map_catalog()
	_test_team_helpers()
	_test_random_selection()
	_test_all_maps()
	_test_free_for_all_regular_hex()
	_test_shape_signatures()
	_test_scrolling_bounds_scale()
	if failures == 0:
		print("Multiplayer rules tests passed for all 15 room maps and the regular FFA map.")
	quit(failures)


func _test_map_catalog() -> void:
	var all_ids = {}
	for players_per_side in range(1, 4):
		var ids = MultiplayerRules.map_ids_for_size(players_per_side)
		_expect_equal(ids.size(), 5, "%dv%d has exactly five maps" % [players_per_side, players_per_side])
		for map_id in ids:
			_expect_false(all_ids.has(map_id), "map id %s is globally unique" % map_id)
			all_ids[map_id] = true
			var definition = MultiplayerRules.map_definition(map_id)
			_expect_equal(String(definition.get("id", "")), map_id, "%s definition keeps its id" % map_id)
			_expect_equal(
				int(definition.get("players_per_side", 0)),
				players_per_side,
				"%s definition uses the correct room size" % map_id
			)
			var display_name = String(definition.get("name", ""))
			_expect_true(
				display_name.begins_with("%dV%d" % [players_per_side, players_per_side]),
				"%s Chinese display name starts with its room mode" % map_id
			)
			_expect_true(display_name.contains("战场"), "%s uses a clear Chinese battlefield name" % map_id)
			var cells_per_player = int(definition.get("cells_per_player", 0))
			_expect_true(cells_per_player >= 30 and cells_per_player <= 100, "%s publishes a valid per-player cell count" % map_id)
			if players_per_side == 3:
				var sector_profile: Array = definition.get("sector_profile", [])
				_expect_false(sector_profile.is_empty(), "%s publishes a six-sector profile" % map_id)
				_expect_equal(_sum_values(sector_profile), cells_per_player, "%s sector profile owns one player's cells" % map_id)
				_expect_equal(String(definition.get("symmetry", "")), "rotational_6", "%s declares sixfold rotational symmetry" % map_id)
			else:
				var lane_profiles: Array = definition.get("lane_profiles", [])
				_expect_equal(lane_profiles.size(), players_per_side, "%s has one contiguous lane profile per player" % map_id)
				for profile in lane_profiles:
					_expect_equal(_sum_values(profile), cells_per_player, "%s lane contains exactly one player's cells" % map_id)
	_expect_equal(all_ids.size(), 15, "catalog contains 15 unique maps")
	_expect_true(MultiplayerRules.map_ids_for_size(0).is_empty(), "zero-player map pool is rejected")
	_expect_true(MultiplayerRules.map_ids_for_size(4).is_empty(), "4v4 map pool is rejected")
	_expect_true(MultiplayerRules.map_definition("missing").is_empty(), "unknown map definition is rejected")


func _test_team_helpers() -> void:
	for players_per_side in range(1, 4):
		var teams = MultiplayerRules.active_team_ids(players_per_side)
		_expect_equal(teams.size(), players_per_side * 2, "active team count matches room size")
		_expect_equal(
			teams,
			EXPECTED_TEAMS_BY_SIZE[players_per_side],
			"%dv%d uses the fixed side slot team ids" % [players_per_side, players_per_side]
		)
		for index in range(players_per_side):
			var side_a_team = index + 1
			var side_b_team = side_a_team + MultiplayerRules.MAX_PLAYERS_PER_SIDE
			_expect_equal(
				MultiplayerRules.side_for_team(side_a_team, players_per_side),
				MultiplayerRules.SIDE_A,
				"team %d belongs to side A in %dv%d" % [side_a_team, players_per_side, players_per_side]
			)
			_expect_equal(
				MultiplayerRules.side_for_team(side_b_team, players_per_side),
				MultiplayerRules.SIDE_B,
				"team %d belongs to side B in %dv%d" % [side_b_team, players_per_side, players_per_side]
			)
			_expect_equal(
				MultiplayerRules.mirror_team(side_a_team, players_per_side),
				side_b_team,
				"side A team maps to its opposing mirror team"
			)
			_expect_equal(
				MultiplayerRules.mirror_team(side_b_team, players_per_side),
				side_a_team,
				"side B team maps back to its opposing mirror team"
			)
		_expect_true(
			MultiplayerRules.are_allies(1, players_per_side, players_per_side),
			"first and last side A teams are allies"
		)
		_expect_true(
			MultiplayerRules.are_allies(4, 3 + players_per_side, players_per_side),
			"first and last side B teams are allies"
		)
		_expect_false(
			MultiplayerRules.are_allies(1, 4, players_per_side),
			"opposing teams are not allies"
		)
		_expect_equal(
			MultiplayerRules.side_for_team(0, players_per_side),
			MultiplayerRules.NO_SIDE,
			"neutral has no room side"
		)
	_expect_true(MultiplayerRules.active_team_ids(0).is_empty(), "invalid room size has no active teams")
	_expect_true(MultiplayerRules.active_team_ids(4).is_empty(), "unsupported room size has no active teams")


func _test_random_selection() -> void:
	for players_per_side in range(1, 4):
		var allowed_ids = MultiplayerRules.map_ids_for_size(players_per_side)
		var seen_ids = {}
		for seed in range(1, 51):
			var first = MultiplayerRules.create_match(players_per_side, "", [], seed)
			var second = MultiplayerRules.create_match(players_per_side, "", [], seed)
			var selected_id = String(first.get("map_id", ""))
			_expect_true(selected_id in allowed_ids, "seeded random map stays inside the %dv%d pool" % [players_per_side, players_per_side])
			_expect_equal(
				String(second.get("map_id", "")),
				selected_id,
				"same room size and seed reproduce the selected map"
			)
			seen_ids[selected_id] = true
		_expect_equal(seen_ids.size(), 5, "seed sample reaches all five %dv%d maps" % [players_per_side, players_per_side])
		var explicit_id = String(allowed_ids[3])
		var explicit_match = MultiplayerRules.create_match(players_per_side, explicit_id, [], 987654)
		_expect_equal(
			String(explicit_match.get("map_id", "")),
			explicit_id,
			"explicit map id overrides random selection"
		)
	var wrong_size_id = String(MultiplayerRules.map_ids_for_size(3)[0])
	_expect_true(
		MultiplayerRules.create_match(1, wrong_size_id).is_empty(),
		"map id from another room-size pool is rejected"
	)
	_expect_true(MultiplayerRules.create_match(0).is_empty(), "unsupported 0v0 match is rejected")
	_expect_true(MultiplayerRules.create_match(4).is_empty(), "unsupported 4v4 match is rejected")


func _test_all_maps() -> void:
	for players_per_side in range(1, 4):
		for map_id in MultiplayerRules.map_ids_for_size(players_per_side):
			var match_data = MultiplayerRules.create_match(players_per_side, map_id, [], 24680)
			matches[map_id] = match_data
			_expect_false(match_data.is_empty(), "%s creates a match" % map_id)
			if match_data.is_empty():
				continue
			_test_match_contract(match_data, players_per_side, map_id)
			_test_balanced_territories(match_data, players_per_side, map_id)
			_test_player_symmetry(match_data, players_per_side, map_id)
			_test_bases_and_resources(match_data, players_per_side, map_id)
			_test_connectivity(match_data, players_per_side, map_id)
			_test_coordinates_and_bounds(match_data, map_id)
			print(
				"%s: %d cells/player, %d total tiles"
				% [
					map_id,
					int(match_data["cells_per_player"]),
					int(match_data["tiles"].size()),
				]
			)


func _test_free_for_all_regular_hex() -> void:
	var match_data = MultiplayerRules.create_free_for_all_match()
	_expect_false(match_data.is_empty(), "FFA regular hex creates a match")
	if match_data.is_empty():
		return
	var tiles: Dictionary = match_data["tiles"]
	var radius = int(match_data.get("hex_radius", 0))
	_expect_equal(String(match_data.get("map_id", "")), MultiplayerRules.FREE_FOR_ALL_MAP_ID, "FFA uses its dedicated map id")
	_expect_equal(String(match_data.get("shape", "")), "regular_hex", "FFA declares a regular hex shape")
	_expect_equal(radius, MultiplayerRules.FREE_FOR_ALL_HEX_RADIUS, "FFA publishes the intended hex radius")
	_expect_equal(int(match_data.get("cells_per_player", 0)), 55, "FFA gives every player 55 territory cells")
	_expect_equal(tiles.size(), 1 + 3 * radius * (radius + 1), "FFA contains every cell in the complete regular hex")
	_expect_equal(match_data.get("team_ids", []), MultiplayerRules.TEAM_IDS, "FFA activates all six independent slots")
	for q in range(-radius, radius + 1):
		var min_r = maxi(-radius, -q - radius)
		var max_r = mini(radius, -q + radius)
		for r in range(min_r, max_r + 1):
			_expect_true(tiles.has(Vector2i(q, r)), "FFA regular hex has no missing interior cell")
	_test_balanced_territories(match_data, MultiplayerRules.MAX_PLAYERS_PER_SIDE, MultiplayerRules.FREE_FOR_ALL_MAP_ID)
	_test_sixfold_rotation(match_data, MultiplayerRules.FREE_FOR_ALL_MAP_ID)
	_test_bases_and_resources(match_data, MultiplayerRules.MAX_PLAYERS_PER_SIDE, MultiplayerRules.FREE_FOR_ALL_MAP_ID)
	_test_connectivity(match_data, MultiplayerRules.MAX_PLAYERS_PER_SIDE, MultiplayerRules.FREE_FOR_ALL_MAP_ID)
	_test_coordinates_and_bounds(match_data, MultiplayerRules.FREE_FOR_ALL_MAP_ID)


func _test_match_contract(match_data: Dictionary, players_per_side: int, map_id: String) -> void:
	var expected_teams: Array = EXPECTED_TEAMS_BY_SIZE[players_per_side]
	_expect_equal(String(match_data.get("map_id", "")), map_id, "%s returns its selected id" % map_id)
	_expect_false(String(match_data.get("map_name", "")).is_empty(), "%s returns a display name" % map_id)
	_expect_equal(match_data.get("team_ids", []), expected_teams, "%s returns active team ids" % map_id)
	_expect_equal(
		match_data.get("side_a", []),
		expected_teams.slice(0, players_per_side),
		"%s returns side A team ids" % map_id
	)
	_expect_equal(
		match_data.get("side_b", []),
		expected_teams.slice(players_per_side, expected_teams.size()),
		"%s returns side B team ids" % map_id
	)
	_expect_equal(int(match_data.get("cells_per_player", 0)), int(MultiplayerRules.map_definition(map_id).get("cells_per_player", 0)), "%s returns the map's per-player cell count" % map_id)
	_expect_equal(
		int(match_data.get("base_keys", {}).size()),
		expected_teams.size(),
		"%s returns one base key per active team" % map_id
	)


func _test_balanced_territories(match_data: Dictionary, players_per_side: int, map_id: String) -> void:
	var tiles: Dictionary = match_data["tiles"]
	var counts = {}
	for team in MultiplayerRules.active_team_ids(players_per_side):
		counts[team] = 0
	var neutral_count = 0
	for tile in tiles.values():
		var territory_team = int(tile.get("territory_team", BoardRules.NEUTRAL))
		if territory_team == BoardRules.NEUTRAL:
			neutral_count += 1
		else:
			_expect_true(counts.has(territory_team), "%s only uses active territory teams" % map_id)
			counts[territory_team] = int(counts.get(territory_team, 0)) + 1
	var expected_count = int(match_data["cells_per_player"])
	_expect_true(expected_count >= 30 and expected_count <= 100, "%s cells per player stay in the 30-100 range" % map_id)
	for team in counts:
		_expect_equal(int(counts[team]), expected_count, "%s team %d has an equal territory" % [map_id, team])
	_expect_true(neutral_count >= 1, "%s includes a neutral frontline" % map_id)
	_expect_true(neutral_count <= 25, "%s keeps the neutral frontline sparse" % map_id)


func _test_player_symmetry(match_data: Dictionary, players_per_side: int, map_id: String) -> void:
	if players_per_side == 3:
		_test_sixfold_rotation(match_data, map_id)
		return
	_test_lane_symmetry(match_data, players_per_side, map_id)


func _test_lane_symmetry(match_data: Dictionary, players_per_side: int, map_id: String) -> void:
	var tiles: Dictionary = match_data["tiles"]
	for key in tiles:
		var mirrored_key = MultiplayerRules.mirror_key(key)
		_expect_true(tiles.has(mirrored_key), "%s mirrors cell %s" % [map_id, str(key)])
		_expect_equal(
			MultiplayerRules.mirror_key(mirrored_key),
			key,
			"%s mirror transform is an involution" % map_id
		)
		if not tiles.has(mirrored_key):
			continue
		var tile: Dictionary = tiles[key]
		var mirrored_tile: Dictionary = tiles[mirrored_key]
		_expect_equal(
			int(mirrored_tile.get("territory_team", BoardRules.NEUTRAL)),
			_mirrored_owner(int(tile.get("territory_team", BoardRules.NEUTRAL)), players_per_side),
			"%s mirrored cell maps to the opposing territory" % map_id
		)
		_expect_equal(
			int(mirrored_tile.get("team", BoardRules.NEUTRAL)),
			_mirrored_owner(int(tile.get("team", BoardRules.NEUTRAL)), players_per_side),
			"%s mirrored building owner maps to the opposing team" % map_id
		)
		_expect_equal(String(mirrored_tile.get("building", "")), String(tile.get("building", "")), "%s mirrors buildings" % map_id)
		_expect_equal(String(mirrored_tile.get("site", "")), String(tile.get("site", "")), "%s mirrors site types" % map_id)
		_expect_equal(int(mirrored_tile.get("site_cost", 0)), int(tile.get("site_cost", 0)), "%s mirrors site prices" % map_id)
		_expect_equal(
			String(mirrored_tile.get("starting_resource", "")),
			String(tile.get("starting_resource", "")),
			"%s mirrors guaranteed starting resources" % map_id
		)
	var canonical_signature = _normalized_team_signature(tiles, 1, players_per_side)
	var canonical_layout = _normalized_start_layout(match_data, 1, players_per_side)
	for team in MultiplayerRules.active_team_ids(players_per_side):
		_expect_equal(_normalized_team_signature(tiles, team, players_per_side), canonical_signature, "%s team %d uses the same territory shape" % [map_id, team])
		_expect_equal(_normalized_start_layout(match_data, team, players_per_side), canonical_layout, "%s team %d uses the same base and resource layout" % [map_id, team])


func _test_sixfold_rotation(match_data: Dictionary, map_id: String) -> void:
	var tiles: Dictionary = match_data["tiles"]
	var base_keys: Dictionary = match_data["base_keys"]
	var canonical_base: Vector2i = base_keys[1]
	var canonical_mine = MultiplayerRules.starting_mine_key(tiles, canonical_base)
	var canonical_camp = MultiplayerRules.starting_camp_key(tiles, canonical_base, canonical_mine)
	for key in tiles:
		var rotated_key = MultiplayerRules.rotate_key(key, 1)
		_expect_true(tiles.has(rotated_key), "%s rotates every cell by 60 degrees" % map_id)
		if not tiles.has(rotated_key):
			continue
		var tile: Dictionary = tiles[key]
		var rotated_tile: Dictionary = tiles[rotated_key]
		var owner = int(tile.get("territory_team", BoardRules.NEUTRAL))
		var expected_owner = BoardRules.NEUTRAL if owner == BoardRules.NEUTRAL else (owner % 6) + 1
		var building_owner = int(tile.get("team", BoardRules.NEUTRAL))
		var expected_building_owner = BoardRules.NEUTRAL if building_owner == BoardRules.NEUTRAL else (building_owner % 6) + 1
		_expect_equal(int(rotated_tile.get("territory_team", BoardRules.NEUTRAL)), expected_owner, "%s rotates territory ownership to the next slot" % map_id)
		_expect_equal(int(rotated_tile.get("team", BoardRules.NEUTRAL)), expected_building_owner, "%s rotates building ownership to the next slot" % map_id)
		_expect_equal(String(rotated_tile.get("building", "")), String(tile.get("building", "")), "%s rotates buildings" % map_id)
		_expect_equal(String(rotated_tile.get("site", "")), String(tile.get("site", "")), "%s rotates site types" % map_id)
		_expect_equal(int(rotated_tile.get("site_cost", 0)), int(tile.get("site_cost", 0)), "%s rotates site prices" % map_id)
		_expect_equal(String(rotated_tile.get("starting_resource", "")), String(tile.get("starting_resource", "")), "%s rotates starting resources" % map_id)
	for team in MultiplayerRules.active_team_ids(3):
		var steps = team - 1
		_expect_equal(base_keys[team], MultiplayerRules.rotate_key(canonical_base, steps), "%s team %d base is the rotated canonical base" % [map_id, team])
		_expect_equal(MultiplayerRules.starting_mine_key(tiles, base_keys[team]), MultiplayerRules.rotate_key(canonical_mine, steps), "%s team %d mine is the rotated canonical mine" % [map_id, team])
		_expect_equal(MultiplayerRules.starting_camp_key(tiles, base_keys[team], MultiplayerRules.rotate_key(canonical_mine, steps)), MultiplayerRules.rotate_key(canonical_camp, steps), "%s team %d camp is the rotated canonical camp" % [map_id, team])


func _test_bases_and_resources(match_data: Dictionary, players_per_side: int, map_id: String) -> void:
	var tiles: Dictionary = match_data["tiles"]
	var base_keys: Dictionary = match_data["base_keys"]
	for team in MultiplayerRules.active_team_ids(players_per_side):
		var base: Vector2i = base_keys.get(team, MultiplayerRules.INVALID_KEY)
		_expect_true(tiles.has(base), "%s team %d base is on the map" % [map_id, team])
		if not tiles.has(base):
			continue
		var base_tile: Dictionary = tiles[base]
		_expect_equal(int(base_tile.get("territory_team", 0)), team, "%s team %d base stays in its territory" % [map_id, team])
		_expect_equal(int(base_tile.get("team", 0)), team, "%s team %d owns its base" % [map_id, team])
		_expect_equal(String(base_tile.get("building", "")), "base", "%s team %d starts with a base" % [map_id, team])
		var mine = MultiplayerRules.starting_mine_key(tiles, base)
		var camp = MultiplayerRules.starting_camp_key(tiles, base, mine)
		var adjacent = MultiplayerRules.neighbors(tiles, base)
		_expect_true(mine in adjacent, "%s team %d mine is adjacent to its base" % [map_id, team])
		_expect_true(camp in adjacent, "%s team %d camp is adjacent to its base" % [map_id, team])
		_expect_true(mine != camp, "%s team %d mine and camp are distinct" % [map_id, team])
		if tiles.has(mine):
			_expect_equal(int(tiles[mine].get("territory_team", 0)), team, "%s team %d mine remains in its territory" % [map_id, team])
			_expect_equal(String(tiles[mine].get("site", "")), "mine", "%s team %d receives a mine" % [map_id, team])
			_expect_equal(int(tiles[mine].get("site_cost", 0)), BoardRules.MINE_PRICE, "%s team %d mine costs 50" % [map_id, team])
			_expect_true(MultiplayerRules.can_unlock(tiles, mine, team), "%s team %d can unlock its mine" % [map_id, team])
		if tiles.has(camp):
			_expect_equal(int(tiles[camp].get("territory_team", 0)), team, "%s team %d camp remains in its territory" % [map_id, team])
			_expect_equal(String(tiles[camp].get("site", "")), "barracks", "%s team %d receives a low camp" % [map_id, team])
			_expect_equal(int(tiles[camp].get("site_cost", 0)), 50, "%s team %d camp costs 50 gold" % [map_id, team])
			_expect_true(MultiplayerRules.can_unlock(tiles, camp, team), "%s team %d can unlock its camp" % [map_id, team])
	for side_a_team in match_data["side_a"]:
		var opposing_team = MultiplayerRules.mirror_team(side_a_team, players_per_side)
		var expected_base = MultiplayerRules.rotate_key(base_keys[side_a_team], 3) if players_per_side == 3 else MultiplayerRules.mirror_key(base_keys[side_a_team])
		_expect_equal(
			expected_base,
			base_keys[opposing_team],
			"%s opposing bases use the map's exact symmetry" % map_id
		)


func _test_connectivity(match_data: Dictionary, players_per_side: int, map_id: String) -> void:
	var tiles: Dictionary = match_data["tiles"]
	var all_keys = tiles.keys()
	_expect_equal(
		_reachable_count(tiles, all_keys[0], ANY_TERRITORY),
		tiles.size(),
		"%s entire board is connected" % map_id
	)
	for key in tiles:
		for neighbor in MultiplayerRules.neighbors(tiles, key):
			_expect_true(tiles.has(neighbor), "%s neighbor remains on the actual map" % map_id)
			_expect_true(key in MultiplayerRules.neighbors(tiles, neighbor), "%s neighbor relation is reciprocal" % map_id)
	var base_keys: Dictionary = match_data["base_keys"]
	for team in MultiplayerRules.active_team_ids(players_per_side):
		_expect_equal(
			_reachable_count(tiles, base_keys[team], team),
			int(match_data["cells_per_player"]),
			"%s team %d can reach all initial territory from its base" % [map_id, team]
		)


func _test_coordinates_and_bounds(match_data: Dictionary, map_id: String) -> void:
	var tiles: Dictionary = match_data["tiles"]
	var origin = Vector2(317.25, -91.5)
	var hex_size = 23.0
	var bounds = MultiplayerRules.board_bounds(tiles, origin, hex_size)
	_expect_true(bounds.size.x > 0.0 and bounds.size.y > 0.0, "%s has non-empty actual board bounds" % map_id)
	for key in tiles:
		var center = MultiplayerRules.hex_center(key, origin, hex_size)
		_expect_equal(
			MultiplayerRules.tile_at(tiles, center, origin, hex_size),
			key,
			"%s tile center round-trips through hit detection" % map_id
		)
		_expect_true(
			center.x >= bounds.position.x
				and center.y >= bounds.position.y
				and center.x <= bounds.end.x
				and center.y <= bounds.end.y,
			"%s bounds contain every tile center" % map_id
		)
	var outside = bounds.position - Vector2(hex_size * 4.0, hex_size * 4.0)
	_expect_equal(
		MultiplayerRules.tile_at(tiles, outside, origin, hex_size),
		MultiplayerRules.INVALID_KEY,
		"%s hit detection rejects positions outside its irregular shape" % map_id
	)
	_expect_equal(
		MultiplayerRules.tile_at(tiles, origin, origin, 0.0),
		MultiplayerRules.INVALID_KEY,
		"%s hit detection rejects zero-sized hexes" % map_id
	)
	_expect_equal(
		MultiplayerRules.board_bounds(tiles, origin, 0.0),
		Rect2(origin, Vector2.ZERO),
		"%s zero-sized hexes return empty bounds" % map_id
	)


func _test_shape_signatures() -> void:
	for players_per_side in range(1, 4):
		var exact_signatures = {}
		var coarse_signatures = {}
		for map_id in MultiplayerRules.map_ids_for_size(players_per_side):
			var tiles: Dictionary = matches[map_id]["tiles"]
			var row_profile = _side_a_row_profile(tiles, players_per_side)
			var exact_signature = ",".join(row_profile.map(func(value): return str(value)))
			var max_width = 0
			for width in row_profile:
				max_width = maxi(max_width, int(width))
			var coarse_signature = "%d:%d" % [row_profile.size(), max_width]
			_expect_false(exact_signatures.has(exact_signature), "%s has a unique detailed silhouette" % map_id)
			_expect_false(coarse_signatures.has(coarse_signature), "%s differs at a coarse silhouette level" % map_id)
			exact_signatures[exact_signature] = true
			coarse_signatures[coarse_signature] = true
		_expect_equal(exact_signatures.size(), 5, "%dv%d has five distinct shape signatures" % [players_per_side, players_per_side])
		_expect_equal(coarse_signatures.size(), 5, "%dv%d has five visibly different coarse silhouettes" % [players_per_side, players_per_side])


func _test_scrolling_bounds_scale() -> void:
	var origin = Vector2.ZERO
	var hex_size = 24.0
	var duel: Dictionary = matches[MultiplayerRules.map_ids_for_size(1)[0]]["tiles"]
	var full_room: Dictionary = matches[MultiplayerRules.map_ids_for_size(3)[0]]["tiles"]
	var duel_bounds = MultiplayerRules.board_bounds(duel, origin, hex_size)
	var full_room_bounds = MultiplayerRules.board_bounds(full_room, origin, hex_size)
	_expect_true(full_room_bounds.size.y > duel_bounds.size.y * 1.5, "3v3 actual bounds expose a larger scrollable board")


func _normalized_team_signature(tiles: Dictionary, team: int, players_per_side: int) -> String:
	var transformed = []
	for key in tiles:
		if int(tiles[key].get("territory_team", BoardRules.NEUTRAL)) != team:
			continue
		transformed.append(MultiplayerRules.mirror_key(key) if MultiplayerRules.side_for_team(team, players_per_side) == MultiplayerRules.SIDE_B else key)
	return _normalized_key_signature(transformed)


func _normalized_start_layout(match_data: Dictionary, team: int, players_per_side: int) -> String:
	var tiles: Dictionary = match_data["tiles"]
	var base: Vector2i = match_data["base_keys"][team]
	var mine = MultiplayerRules.starting_mine_key(tiles, base)
	var camp = MultiplayerRules.starting_camp_key(tiles, base, mine)
	var keys = []
	for key in tiles:
		if int(tiles[key].get("territory_team", BoardRules.NEUTRAL)) == team:
			keys.append(MultiplayerRules.mirror_key(key) if MultiplayerRules.side_for_team(team, players_per_side) == MultiplayerRules.SIDE_B else key)
	var min_q = 999999
	var min_r = 999999
	for key in keys:
		min_q = mini(min_q, key.x)
		min_r = mini(min_r, key.y)
	var layout_keys = [base, mine, camp]
	var normalized = []
	for key in layout_keys:
		var transformed_key = MultiplayerRules.mirror_key(key) if MultiplayerRules.side_for_team(team, players_per_side) == MultiplayerRules.SIDE_B else key
		normalized.append("%d:%d" % [transformed_key.x - min_q, transformed_key.y - min_r])
	return "|".join(normalized)


func _normalized_key_signature(keys: Array) -> String:
	var min_q = 999999
	var min_r = 999999
	for key in keys:
		min_q = mini(min_q, key.x)
		min_r = mini(min_r, key.y)
	var normalized = []
	for key in keys:
		normalized.append("%d:%d" % [key.x - min_q, key.y - min_r])
	normalized.sort()
	return ",".join(normalized)


func _side_a_row_profile(tiles: Dictionary, players_per_side: int) -> Array:
	var rows = {}
	for key in tiles:
		var team = int(tiles[key].get("territory_team", BoardRules.NEUTRAL))
		if MultiplayerRules.side_for_team(team, players_per_side) != MultiplayerRules.SIDE_A:
			continue
		rows[key.y] = int(rows.get(key.y, 0)) + 1
	var row_keys = rows.keys()
	row_keys.sort()
	var result = []
	for row in row_keys:
		result.append(int(rows[row]))
	return result


func _reachable_count(
	tiles: Dictionary,
	start: Vector2i,
	territory_filter: int
) -> int:
	if not tiles.has(start):
		return 0
	var visited = {start: true}
	var queue = [start]
	var cursor = 0
	while cursor < queue.size():
		var key: Vector2i = queue[cursor]
		cursor += 1
		for neighbor in MultiplayerRules.neighbors(tiles, key):
			if visited.has(neighbor):
				continue
			if (
				territory_filter != ANY_TERRITORY
				and int(tiles[neighbor].get("territory_team", BoardRules.NEUTRAL)) != territory_filter
			):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return visited.size()


func _mirrored_owner(team: int, players_per_side: int) -> int:
	return MultiplayerRules.mirror_team(team, players_per_side) if team != BoardRules.NEUTRAL else BoardRules.NEUTRAL


func _sum_values(values: Array) -> int:
	var result = 0
	for value in values:
		result += int(value)
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
