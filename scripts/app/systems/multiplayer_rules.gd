extends RefCounted

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")

const MIN_PLAYERS_PER_SIDE = 1
const MAX_PLAYERS_PER_SIDE = 3
const CELLS_PER_PLAYER = 36
# Room sizes activate prefixes of these fixed UI slots; team ids never compact.
const SIDE_A_TEAM_IDS = [1, 2, 3]
const SIDE_B_TEAM_IDS = [4, 5, 6]
const TEAM_IDS = [1, 2, 3, 4, 5, 6]
const SIDE_A = "a"
const SIDE_B = "b"
const NO_SIDE = ""
const NEUTRAL = BoardRules.NEUTRAL
const INVALID_KEY = Vector2i(-99, -99)

const SQRT_3 = 1.7320508075688772

const AXIAL_DIRECTIONS = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

# Lane profiles drive 1v1 and 2v2. Six-sector profiles drive 3v3 and list how
# many cells each player owns on each ring of the shared rotational template.
const PROFILE_PLATEAU = [4, 4, 4, 4, 4, 4, 4, 4, 4]
const PROFILE_DIAMOND = [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]
const PROFILE_HOURGLASS = [6, 5, 4, 2, 2, 2, 4, 5, 6]
const PROFILE_CROSSROADS = [2, 2, 4, 6, 8, 6, 4, 2, 2]
const PROFILE_RIPPLE = [3, 5, 3, 5, 3, 5, 3, 5, 4]
const SECTOR_PLATEAU = [1, 2, 3, 4, 5, 6, 7, 8]
const SECTOR_DIAMOND = [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]
const SECTOR_HOURGLASS = [1, 2, 3, 4, 3, 4, 5, 6, 7]
const SECTOR_CROSSROADS = [1, 2, 3, 4, 5, 6, 7, 6, 5, 4]
const SECTOR_RIPPLE = [1, 2, 3, 4, 3, 4, 3, 4, 3, 4, 5]
const FREE_FOR_ALL_MAP_ID = "ffa_regular_hex"
const FREE_FOR_ALL_MAP_NAME = "6人正六边形战场"
const FREE_FOR_ALL_HEX_RADIUS = 10
const FREE_FOR_ALL_SECTOR_PROFILE = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const FREE_FOR_ALL_CELLS_PER_PLAYER = 55

const MAP_IDS_BY_SIZE = {
	1: [
		"1v1_plateau",
		"1v1_diamond",
		"1v1_hourglass",
		"1v1_crossroads",
		"1v1_ripple",
	],
	2: [
		"2v2_plateau",
		"2v2_diamond",
		"2v2_hourglass",
		"2v2_crossroads",
		"2v2_ripple",
	],
	3: [
		"3v3_plateau",
		"3v3_diamond",
		"3v3_hourglass",
		"3v3_crossroads",
		"3v3_ripple",
	],
}

const MAP_DEFINITIONS = {
	"1v1_plateau": {
		"name": "1V1 高原战场",
		"players_per_side": 1,
		"shape": "plateau",
		"lane_profiles": [PROFILE_PLATEAU],
	},
	"1v1_diamond": {
		"name": "1V1 菱形战场",
		"players_per_side": 1,
		"shape": "diamond",
		"lane_profiles": [PROFILE_DIAMOND],
	},
	"1v1_hourglass": {
		"name": "1V1 沙漏战场",
		"players_per_side": 1,
		"shape": "hourglass",
		"lane_profiles": [PROFILE_HOURGLASS],
	},
	"1v1_crossroads": {
		"name": "1V1 十字战场",
		"players_per_side": 1,
		"shape": "crossroads",
		"lane_profiles": [PROFILE_CROSSROADS],
	},
	"1v1_ripple": {
		"name": "1V1 波纹战场",
		"players_per_side": 1,
		"shape": "ripple",
		"lane_profiles": [PROFILE_RIPPLE],
	},
	"2v2_plateau": {
		"name": "2V2 双层高原战场",
		"players_per_side": 2,
		"shape": "plateau",
		"lane_profiles": [PROFILE_PLATEAU, PROFILE_PLATEAU],
	},
	"2v2_diamond": {
		"name": "2V2 双菱战场",
		"players_per_side": 2,
		"shape": "diamond",
		"lane_profiles": [PROFILE_DIAMOND, PROFILE_DIAMOND],
	},
	"2v2_hourglass": {
		"name": "2V2 双沙漏战场",
		"players_per_side": 2,
		"shape": "hourglass",
		"lane_profiles": [PROFILE_HOURGLASS, PROFILE_HOURGLASS],
	},
	"2v2_crossroads": {
		"name": "2V2 大十字战场",
		"players_per_side": 2,
		"shape": "crossroads",
		"lane_profiles": [PROFILE_CROSSROADS, PROFILE_CROSSROADS],
	},
	"2v2_ripple": {
		"name": "2V2 双波纹战场",
		"players_per_side": 2,
		"shape": "ripple",
		"lane_profiles": [PROFILE_RIPPLE, PROFILE_RIPPLE],
	},
	"3v3_plateau": {
		"name": "3V3 六角高原战场",
		"players_per_side": 3,
		"shape": "plateau",
		"sector_profile": SECTOR_PLATEAU,
		"symmetry": "rotational_6",
	},
	"3v3_diamond": {
		"name": "3V3 六角菱台战场",
		"players_per_side": 3,
		"shape": "diamond",
		"sector_profile": SECTOR_DIAMOND,
		"symmetry": "rotational_6",
	},
	"3v3_hourglass": {
		"name": "3V3 六角沙漏战场",
		"players_per_side": 3,
		"shape": "hourglass",
		"sector_profile": SECTOR_HOURGLASS,
		"symmetry": "rotational_6",
	},
	"3v3_crossroads": {
		"name": "3V3 六角十字战场",
		"players_per_side": 3,
		"shape": "crossroads",
		"sector_profile": SECTOR_CROSSROADS,
		"symmetry": "rotational_6",
	},
	"3v3_ripple": {
		"name": "3V3 六角波纹战场",
		"players_per_side": 3,
		"shape": "ripple",
		"sector_profile": SECTOR_RIPPLE,
		"symmetry": "rotational_6",
	},
}

const PLACEMENT_REWARDS = {
	1: {"star_delta": 3, "gacha_tickets": 5},
	2: {"star_delta": 2, "gacha_tickets": 2},
	3: {"star_delta": 2, "gacha_tickets": 2},
	4: {"star_delta": -1, "gacha_tickets": 1},
	5: {"star_delta": -1, "gacha_tickets": 1},
	6: {"star_delta": -1, "gacha_tickets": 1},
}

# These values keep the legacy wrappers working until main.gd consumes the
# create_match result directly. They contain a real generated map, not a fixed
# radius or six-sector board assumption.
static var _compat_tiles: Dictionary = {}
static var _compat_base_keys: Dictionary = {}
static var _compat_players_per_side = MAX_PLAYERS_PER_SIDE


static func map_ids_for_size(players_per_side: int) -> Array:
	if not MAP_IDS_BY_SIZE.has(players_per_side):
		return []
	return MAP_IDS_BY_SIZE[players_per_side].duplicate()


static func map_definition(map_id: String) -> Dictionary:
	if not MAP_DEFINITIONS.has(map_id):
		return {}
	var definition: Dictionary = MAP_DEFINITIONS[map_id].duplicate(true)
	definition["id"] = map_id
	if definition.has("sector_profile"):
		definition["cells_per_player"] = _sum_profile(definition["sector_profile"])
		definition["row_widths"] = (definition["sector_profile"] as Array).duplicate()
	else:
		definition["cells_per_player"] = CELLS_PER_PLAYER
		definition["row_widths"] = _flatten_profiles(definition["lane_profiles"])
	return definition


static func create_match(
	players_per_side: int,
	map_id: String = "",
	cell_type_rows: Array = [],
	seed: int = 0
) -> Dictionary:
	var map_ids = map_ids_for_size(players_per_side)
	if map_ids.is_empty():
		return {}
	var selected_map_id = map_id
	if selected_map_id.is_empty():
		selected_map_id = _select_map_id(map_ids, seed)
	if not selected_map_id in map_ids:
		return {}
	var definition = map_definition(selected_map_id)
	var tiles = _create_map_tiles(definition, cell_type_rows)
	var team_ids = active_team_ids(players_per_side)
	var side_a = team_ids.slice(0, players_per_side)
	var side_b = team_ids.slice(players_per_side, team_ids.size())
	var base_keys = _place_bases_and_starting_resources(
		tiles,
		players_per_side,
		cell_type_rows
	)
	if base_keys.size() != team_ids.size():
		return {}

	_compat_tiles = tiles
	_compat_base_keys = base_keys
	_compat_players_per_side = players_per_side
	return {
		"tiles": tiles,
		"map_id": selected_map_id,
		"map_name": String(definition["name"]),
		"players_per_side": players_per_side,
		"team_ids": team_ids,
		"side_a": side_a,
		"side_b": side_b,
		"base_keys": base_keys,
		"cells_per_player": int(definition["cells_per_player"]),
	}


static func create_free_for_all_match(cell_type_rows: Array = []) -> Dictionary:
	var tiles = _create_six_sector_tiles(FREE_FOR_ALL_SECTOR_PROFILE, cell_type_rows)
	var base_keys = _place_six_sector_bases_and_resources(tiles, cell_type_rows)
	if base_keys.size() != TEAM_IDS.size():
		return {}
	_compat_tiles = tiles
	_compat_base_keys = base_keys
	_compat_players_per_side = MAX_PLAYERS_PER_SIDE
	return {
		"tiles": tiles,
		"map_id": FREE_FOR_ALL_MAP_ID,
		"map_name": FREE_FOR_ALL_MAP_NAME,
		"players_per_side": MAX_PLAYERS_PER_SIDE,
		"team_ids": TEAM_IDS.duplicate(),
		"side_a": [],
		"side_b": [],
		"base_keys": base_keys,
		"cells_per_player": FREE_FOR_ALL_CELLS_PER_PLAYER,
		"hex_radius": FREE_FOR_ALL_HEX_RADIUS,
		"shape": "regular_hex",
	}


static func active_team_ids(players_per_side: int) -> Array:
	if players_per_side < MIN_PLAYERS_PER_SIDE or players_per_side > MAX_PLAYERS_PER_SIDE:
		return []
	var result = SIDE_A_TEAM_IDS.slice(0, players_per_side)
	result.append_array(SIDE_B_TEAM_IDS.slice(0, players_per_side))
	return result


static func side_for_team(team: int, players_per_side: int = MAX_PLAYERS_PER_SIDE) -> String:
	if team >= 1 and team <= players_per_side:
		return SIDE_A
	if team >= MAX_PLAYERS_PER_SIDE + 1 and team <= MAX_PLAYERS_PER_SIDE + players_per_side:
		return SIDE_B
	return NO_SIDE


static func are_allies(
	first_team: int,
	second_team: int,
	players_per_side: int = MAX_PLAYERS_PER_SIDE
) -> bool:
	var first_side = side_for_team(first_team, players_per_side)
	return first_side != NO_SIDE and first_side == side_for_team(second_team, players_per_side)


static func mirror_key(key: Vector2i) -> Vector2i:
	return Vector2i(-key.x - key.y, key.y)


static func rotate_key(key: Vector2i, steps: int = 1) -> Vector2i:
	var result = key
	for _index in range(posmod(steps, 6)):
		result = Vector2i(-result.y, result.x + result.y)
	return result


static func mirror_team(team: int, players_per_side: int) -> int:
	var side = side_for_team(team, players_per_side)
	if side == SIDE_A:
		return team + MAX_PLAYERS_PER_SIDE
	if side == SIDE_B:
		return team - MAX_PLAYERS_PER_SIDE
	return NEUTRAL


static func create_initial_tiles(cell_type_rows: Array = []) -> Dictionary:
	var match_data = create_match(MAX_PLAYERS_PER_SIDE, "", cell_type_rows)
	return match_data.get("tiles", {})


static func base_key(team: int, base_keys: Dictionary = {}) -> Vector2i:
	var source = base_keys if not base_keys.is_empty() else _compat_base_keys
	return source.get(team, INVALID_KEY)


static func team_for_key(tiles_or_key: Variant, maybe_key: Vector2i = INVALID_KEY) -> int:
	var tiles = _compat_tiles
	var key = tiles_or_key
	if typeof(tiles_or_key) == TYPE_DICTIONARY:
		tiles = tiles_or_key
		key = maybe_key
	if not tiles.has(key):
		return NEUTRAL
	return int(tiles[key].get("territory_team", NEUTRAL))


static func contains(tiles_or_key: Variant, maybe_key: Vector2i = INVALID_KEY) -> bool:
	if typeof(tiles_or_key) == TYPE_DICTIONARY:
		return tiles_or_key.has(maybe_key)
	return _compat_tiles.has(tiles_or_key)


static func neighbors(tiles_or_key: Variant, maybe_key: Vector2i = INVALID_KEY) -> Array:
	var tiles = _compat_tiles
	var key = tiles_or_key
	if typeof(tiles_or_key) == TYPE_DICTIONARY:
		tiles = tiles_or_key
		key = maybe_key
	var result = []
	for direction in AXIAL_DIRECTIONS:
		var next = key + direction
		if tiles.has(next):
			result.append(next)
	return result


static func can_unlock(tiles: Dictionary, key: Vector2i, team: int) -> bool:
	if team == NEUTRAL or not tiles.has(key):
		return false
	var tile = tiles[key]
	if int(tile.get("team", NEUTRAL)) != NEUTRAL:
		return false
	if BoardRules.visual_owner(tile) != team:
		return false
	if String(tile.get("building", "")) != "" or String(tile.get("site", "")) == "":
		return false
	for neighbor in neighbors(tiles, key):
		if int(tiles[neighbor].get("team", NEUTRAL)) == team:
			return true
	return false


static func hex_center(key: Vector2i, origin: Vector2, hex_size: float) -> Vector2:
	return origin + _axial_vector(key) * hex_size


static func tile_at(
	tiles: Dictionary,
	pos: Vector2,
	origin: Vector2,
	hex_size: float
) -> Vector2i:
	if hex_size <= 0.0 or tiles.is_empty():
		return INVALID_KEY
	var local = (pos - origin) / hex_size
	var q = (SQRT_3 / 3.0) * local.x - (1.0 / 3.0) * local.y
	var r = (2.0 / 3.0) * local.y
	var key = _round_axial(q, r)
	return key if tiles.has(key) else INVALID_KEY


static func board_bounds(
	tiles_or_origin: Variant,
	origin_or_hex_size: Variant = Vector2.ZERO,
	maybe_hex_size: float = -1.0
) -> Rect2:
	var tiles = _compat_tiles
	var origin = Vector2.ZERO
	var hex_size = maybe_hex_size
	if typeof(tiles_or_origin) == TYPE_DICTIONARY:
		tiles = tiles_or_origin
		origin = origin_or_hex_size
	else:
		origin = tiles_or_origin
		hex_size = float(origin_or_hex_size)
	if hex_size <= 0.0 or tiles.is_empty():
		return Rect2(origin, Vector2.ZERO)
	var half_width = SQRT_3 * hex_size * 0.5
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	for key in tiles:
		var center = hex_center(key, origin, hex_size)
		min_pos.x = minf(min_pos.x, center.x - half_width)
		min_pos.y = minf(min_pos.y, center.y - hex_size)
		max_pos.x = maxf(max_pos.x, center.x + half_width)
		max_pos.y = maxf(max_pos.y, center.y + hex_size)
	return Rect2(min_pos, max_pos - min_pos)


static func placement_rewards(placement: int) -> Dictionary:
	if not PLACEMENT_REWARDS.has(placement):
		return {}
	return PLACEMENT_REWARDS[placement].duplicate(true)


static func starting_mine_key(tiles: Dictionary, start_base_key: Vector2i) -> Vector2i:
	var marked_key = _starting_resource_key(tiles, start_base_key, "mine")
	if marked_key != INVALID_KEY:
		return marked_key
	return _best_starting_resource_key(tiles, start_base_key, INVALID_KEY, 5)


static func starting_camp_key(
	tiles: Dictionary,
	start_base_key: Vector2i,
	mine_key: Vector2i
) -> Vector2i:
	var marked_key = _starting_resource_key(tiles, start_base_key, "camp")
	if marked_key != INVALID_KEY:
		return marked_key
	return _best_starting_resource_key(tiles, start_base_key, mine_key, 13)


static func _select_map_id(map_ids: Array, seed: int) -> String:
	var random = RandomNumberGenerator.new()
	if seed == 0:
		random.randomize()
	else:
		random.seed = seed
	return String(map_ids[random.randi_range(0, map_ids.size() - 1)])


static func _flatten_profiles(lane_profiles: Array) -> Array:
	var result = []
	for profile in lane_profiles:
		result.append_array(profile)
	return result


static func _sum_profile(profile: Array) -> int:
	var result = 0
	for value in profile:
		result += int(value)
	return result


static func _create_map_tiles(definition: Dictionary, cell_type_rows: Array) -> Dictionary:
	if definition.has("sector_profile"):
		return _create_six_sector_tiles(definition["sector_profile"], cell_type_rows)
	if int(definition["players_per_side"]) == 2:
		return _create_four_sector_tiles(definition["lane_profiles"][0], cell_type_rows)
	var tiles = {}
	var lane_profiles: Array = definition["lane_profiles"]
	var total_rows = int(definition["row_widths"].size())
	var first_r = -floori(float(total_rows) * 0.5)
	var row_index = 0
	var players_per_side = int(definition["players_per_side"])
	for lane_index in range(lane_profiles.size()):
		var profile: Array = lane_profiles[lane_index]
		for width_value in profile:
			var r = first_r + row_index
			var first_u = 2 if r % 2 == 0 else 1
			for column in range(int(width_value)):
				var u = first_u + column * 2
				var right_key = Vector2i(int((u - r) / 2), r)
				var left_key = mirror_key(right_key)
				var left_tile = BoardRules.empty_locked_tile()
				left_tile["territory_team"] = lane_index + 1
				left_tile = BoardRules.with_site(
					left_tile,
					BoardRules.site_for_key(left_key, cell_type_rows)
				)
				var right_tile = left_tile.duplicate(true)
				right_tile["territory_team"] = SIDE_B_TEAM_IDS[lane_index]
				tiles[left_key] = left_tile
				tiles[right_key] = right_tile
			if r % 4 == 0:
				var center_key = Vector2i(int(-r / 2), r)
				var center_tile = BoardRules.empty_locked_tile()
				center_tile = BoardRules.with_site(
					center_tile,
					BoardRules.site_for_key(center_key, cell_type_rows)
				)
				tiles[center_key] = center_tile
			row_index += 1
	return tiles


static func _create_four_sector_tiles(profile: Array, cell_type_rows: Array) -> Dictionary:
	var tiles = {}
	var canonical_cells = []
	var first_r = -floori(float(profile.size()) * 0.5)
	for row_index in range(profile.size()):
		var r = first_r + row_index
		var first_u = 2 if r % 2 == 0 else 1
		for column in range(int(profile[row_index])):
			var u = first_u + column * 2
			var right_key = Vector2i(int((u - r) / 2), r)
			var canonical_key = mirror_key(right_key)
			canonical_cells.append({
				"key": canonical_key,
				"site": BoardRules.site_for_key(canonical_key, cell_type_rows),
			})
	var shift_r = maxi(4, ceili(float(profile.size()) * 0.5))
	if shift_r % 2 != 0:
		shift_r += 1
	var translations = [
		Vector2i(int(shift_r / 2), -shift_r),
		Vector2i(int(-shift_r / 2), shift_r),
	]
	var min_r = 999999
	var max_r = -999999
	for lane_index in range(2):
		var translation: Vector2i = translations[lane_index]
		for cell in canonical_cells:
			var left_key: Vector2i = cell["key"] + translation
			var right_key = mirror_key(left_key)
			var left_tile = BoardRules.empty_locked_tile()
			left_tile["territory_team"] = lane_index + 1
			left_tile = BoardRules.with_site(left_tile, cell["site"])
			var right_tile = left_tile.duplicate(true)
			right_tile["territory_team"] = SIDE_B_TEAM_IDS[lane_index]
			tiles[left_key] = left_tile
			tiles[right_key] = right_tile
			min_r = mini(min_r, left_key.y)
			max_r = maxi(max_r, left_key.y)
	for r in range(min_r, max_r + 1):
		var center_key = Vector2i(floori(float(-r) * 0.5), r)
		var center_keys = [center_key]
		var mirrored_center = mirror_key(center_key)
		if mirrored_center != center_key:
			center_keys.append(mirrored_center)
		var center_site = BoardRules.site_for_key(center_key, cell_type_rows)
		for key in center_keys:
			if tiles.has(key):
				continue
			var center_tile = BoardRules.empty_locked_tile()
			center_tile = BoardRules.with_site(center_tile, center_site)
			tiles[key] = center_tile
	return tiles


static func _create_six_sector_tiles(sector_profile: Array, cell_type_rows: Array) -> Dictionary:
	var tiles = {}
	for ring_index in range(sector_profile.size()):
		var distance = ring_index + 1
		var width = clampi(int(sector_profile[ring_index]), 1, distance)
		for offset in range(width):
			var canonical_key = Vector2i(distance - offset, offset)
			var canonical_site = BoardRules.site_for_key(canonical_key, cell_type_rows)
			for sector in range(6):
				var key = rotate_key(canonical_key, sector)
				var tile = BoardRules.empty_locked_tile()
				tile["territory_team"] = sector + 1
				tile = BoardRules.with_site(tile, canonical_site)
				tiles[key] = tile
	var center_tile = BoardRules.empty_locked_tile()
	center_tile["territory_team"] = NEUTRAL
	tiles[Vector2i.ZERO] = center_tile
	return tiles


static func _place_bases_and_starting_resources(
	tiles: Dictionary,
	players_per_side: int,
	cell_type_rows: Array
) -> Dictionary:
	if players_per_side == MAX_PLAYERS_PER_SIDE:
		return _place_six_sector_bases_and_resources(tiles, cell_type_rows)
	var result = {}
	for team in range(1, players_per_side + 1):
		var rival_team = mirror_team(team, players_per_side)
		var left_base = _choose_base_key(tiles, team)
		if left_base == INVALID_KEY:
			return {}
		var right_base = mirror_key(left_base)
		if team_for_key(tiles, right_base) != rival_team:
			return {}
		result[team] = left_base
		result[rival_team] = right_base
		tiles[left_base] = BoardRules.with_building(
			tiles[left_base],
			team,
			"base",
			"",
			BoardRules.building_hp("base"),
			BoardRules.building_delay("base", team)
		)
		tiles[right_base] = BoardRules.with_building(
			tiles[right_base],
			rival_team,
			"base",
			"",
			BoardRules.building_hp("base"),
			BoardRules.building_delay("base", rival_team)
		)
		_apply_mirrored_starting_resources(
			tiles,
			left_base,
			right_base,
			cell_type_rows
		)
	return result


static func _place_six_sector_bases_and_resources(
	tiles: Dictionary,
	cell_type_rows: Array
) -> Dictionary:
	var canonical_base = _choose_base_key(tiles, 1)
	if canonical_base == INVALID_KEY:
		return {}
	var canonical_neighbors = []
	for direction in AXIAL_DIRECTIONS:
		var key = canonical_base + direction
		if team_for_key(tiles, key) == 1:
			canonical_neighbors.append(key)
	if canonical_neighbors.size() < 2:
		return {}
	var mine_key: Vector2i = canonical_neighbors[0]
	var camp_key: Vector2i = canonical_neighbors[1]
	var result = {}
	for sector in range(6):
		var team = sector + 1
		var base = rotate_key(canonical_base, sector)
		result[team] = base
		tiles[base] = BoardRules.with_building(
			tiles[base],
			team,
			"base",
			"",
			BoardRules.building_hp("base"),
			BoardRules.building_delay("base", team)
		)
	for neighbor_key in canonical_neighbors:
		var site = BoardRules.site_for_key(neighbor_key, cell_type_rows)
		var starting_resource = ""
		if neighbor_key == mine_key:
			site = BoardRules.mine_site()
			starting_resource = "mine"
		elif neighbor_key == camp_key:
			site = BoardRules.camp_site_for_cost(BoardRules.UNIT_LOW_PRICE)
			starting_resource = "camp"
		elif String(site.get("site", "")) == "mine":
			site = BoardRules.non_mine_starting_site_for_key(neighbor_key, cell_type_rows)
		_set_rotated_site(tiles, neighbor_key, site, starting_resource)
	return result


static func _set_rotated_site(
	tiles: Dictionary,
	canonical_key: Vector2i,
	site: Dictionary,
	starting_resource: String
) -> void:
	for sector in range(6):
		var key = rotate_key(canonical_key, sector)
		var tile = BoardRules.with_site(tiles[key], site)
		if starting_resource.is_empty():
			tile.erase("starting_resource")
		else:
			tile["starting_resource"] = starting_resource
		tiles[key] = tile


static func _choose_base_key(tiles: Dictionary, team: int) -> Vector2i:
	var team_keys = []
	var min_r = 999999
	var max_r = -999999
	for key in tiles:
		if team_for_key(tiles, key) != team:
			continue
		team_keys.append(key)
		min_r = mini(min_r, key.y)
		max_r = maxi(max_r, key.y)
	if team_keys.is_empty():
		return INVALID_KEY
	var lane_center = (float(min_r) + float(max_r)) * 0.5
	var best_key = INVALID_KEY
	var best_score = -INF
	for key in team_keys:
		var own_neighbor_count = 0
		for neighbor in neighbors(tiles, key):
			if team_for_key(tiles, neighbor) == team:
				own_neighbor_count += 1
		if own_neighbor_count < 3:
			continue
		var projected_x = 2 * key.x + key.y
		var score = (
			float(own_neighbor_count) * 10000.0
			+ float(absi(projected_x)) * 100.0
			- absf(float(key.y) - lane_center)
		)
		if score > best_score:
			best_score = score
			best_key = key
	return best_key


static func _apply_mirrored_starting_resources(
	tiles: Dictionary,
	left_base: Vector2i,
	right_base: Vector2i,
	cell_type_rows: Array
) -> void:
	var left_team = team_for_key(tiles, left_base)
	var mine_key = _best_starting_resource_key(tiles, left_base, INVALID_KEY, 5)
	var camp_key = _best_starting_resource_key(tiles, left_base, mine_key, 13)
	for key in neighbors(tiles, left_base):
		if team_for_key(tiles, key) != left_team:
			continue
		var mirrored = mirror_key(key)
		if key == mine_key:
			_set_mirrored_site(tiles, key, mirrored, BoardRules.mine_site(), "mine")
			continue
		if key == camp_key:
			_set_mirrored_site(
				tiles,
				key,
				mirrored,
				BoardRules.camp_site_for_cost(BoardRules.UNIT_LOW_PRICE),
				"camp"
			)
			continue
		var site = BoardRules.site_for_key(key, cell_type_rows)
		if String(site.get("site", "")) == "mine":
			site = BoardRules.non_mine_starting_site_for_key(key, cell_type_rows)
		_set_mirrored_site(tiles, key, mirrored, site, "")
	# Both bases were selected as a mirrored pair; this also catches malformed
	# custom definitions before their resources can silently diverge.
	assert(mirror_key(left_base) == right_base)


static func _set_mirrored_site(
	tiles: Dictionary,
	left_key: Vector2i,
	right_key: Vector2i,
	site: Dictionary,
	starting_resource: String
) -> void:
	var left_tile = BoardRules.with_site(tiles[left_key], site)
	var right_tile = BoardRules.with_site(tiles[right_key], site)
	if starting_resource.is_empty():
		left_tile.erase("starting_resource")
		right_tile.erase("starting_resource")
	else:
		left_tile["starting_resource"] = starting_resource
		right_tile["starting_resource"] = starting_resource
	tiles[left_key] = left_tile
	tiles[right_key] = right_tile


static func _starting_resource_key(
	tiles: Dictionary,
	start_base_key: Vector2i,
	resource: String
) -> Vector2i:
	for key in neighbors(tiles, start_base_key):
		if String(tiles[key].get("starting_resource", "")) == resource:
			return key
	return INVALID_KEY


static func _best_starting_resource_key(
	tiles: Dictionary,
	start_base_key: Vector2i,
	excluded_key: Vector2i,
	_seed_divisor: int
) -> Vector2i:
	if not tiles.has(start_base_key):
		return INVALID_KEY
	var territory_team = team_for_key(tiles, start_base_key)
	for direction in AXIAL_DIRECTIONS:
		var key = start_base_key + direction
		if not tiles.has(key):
			continue
		if key == excluded_key or team_for_key(tiles, key) != territory_team:
			continue
		if String(tiles[key].get("building", "")) != "":
			continue
		return key
	return INVALID_KEY


static func _axial_vector(key: Vector2i) -> Vector2:
	return Vector2(
		SQRT_3 * (float(key.x) + float(key.y) * 0.5),
		1.5 * float(key.y)
	)


static func _round_axial(q: float, r: float) -> Vector2i:
	var cube_x = q
	var cube_z = r
	var cube_y = -cube_x - cube_z
	var rounded_x = roundi(cube_x)
	var rounded_y = roundi(cube_y)
	var rounded_z = roundi(cube_z)
	var x_diff = absf(float(rounded_x) - cube_x)
	var y_diff = absf(float(rounded_y) - cube_y)
	var z_diff = absf(float(rounded_z) - cube_z)
	if x_diff > y_diff and x_diff > z_diff:
		rounded_x = -rounded_y - rounded_z
	elif y_diff > z_diff:
		rounded_y = -rounded_x - rounded_z
	else:
		rounded_z = -rounded_x - rounded_y
	return Vector2i(rounded_x, rounded_z)
