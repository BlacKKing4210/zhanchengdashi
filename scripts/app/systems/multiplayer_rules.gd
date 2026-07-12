extends RefCounted

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")

const SIDE_LENGTH = 20
const RADIUS = SIDE_LENGTH - 1
const TEAM_IDS = [1, 2, 3, 4, 5, 6]
const NEUTRAL = BoardRules.NEUTRAL
const INVALID_KEY = Vector2i(-99, -99)

const SQRT_3 = 1.7320508075688772
const ANGLE_EPSILON = 0.0000001

const AXIAL_DIRECTIONS = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

# A side with 20 cells has two central cells. These keys consistently choose
# the clockwise member of each pair, producing a rotationally symmetric orbit.
# Team 1 starts on the bottom side and teams 2-6 continue clockwise on screen.
const BASE_KEYS = {
	1: Vector2i(-9, 19),
	2: Vector2i(-19, 10),
	3: Vector2i(-10, -9),
	4: Vector2i(9, -19),
	5: Vector2i(19, -10),
	6: Vector2i(10, 9),
}

# Sector 0 spans screen-space angles [0, 60), then advances clockwise because
# Godot's 2D y-axis points down. Team 1 owns the bottom-facing sector.
const SECTOR_TEAMS = [6, 1, 2, 3, 4, 5]

const PLACEMENT_REWARDS = {
	1: {"star_delta": 3, "gacha_tickets": 5},
	2: {"star_delta": 2, "gacha_tickets": 2},
	3: {"star_delta": 2, "gacha_tickets": 2},
	4: {"star_delta": -1, "gacha_tickets": 1},
	5: {"star_delta": -1, "gacha_tickets": 1},
	6: {"star_delta": -1, "gacha_tickets": 1},
}


static func create_initial_tiles(cell_type_rows: Array = []) -> Dictionary:
	var tiles = {}
	for q in range(-RADIUS, RADIUS + 1):
		var min_r = maxi(-RADIUS, -q - RADIUS)
		var max_r = mini(RADIUS, -q + RADIUS)
		for r in range(min_r, max_r + 1):
			var key = Vector2i(q, r)
			var tile = BoardRules.empty_locked_tile()
			tile["territory_team"] = team_for_key(key)
			if not _is_base_key(key):
				tile = BoardRules.with_site(tile, BoardRules.site_for_key(key, cell_type_rows))
			tiles[key] = tile

	for team in TEAM_IDS:
		var key = base_key(team)
		var base_tile = tiles[key]
		tiles[key] = BoardRules.with_building(
			base_tile,
			team,
			"base",
			"",
			BoardRules.building_hp("base"),
			BoardRules.building_delay("base", team)
		)
		_apply_starting_unlock_rules(tiles, key, cell_type_rows)
	return tiles


static func base_key(team: int) -> Vector2i:
	if BASE_KEYS.has(team):
		return BASE_KEYS[team]
	return INVALID_KEY


static func team_for_key(key: Vector2i) -> int:
	if key == Vector2i.ZERO or not contains(key):
		return NEUTRAL
	var pixel = _axial_vector(key)
	var angle = fposmod(atan2(pixel.y, pixel.x) + TAU + ANGLE_EPSILON, TAU)
	var sector = floori(angle / (TAU / 6.0)) % 6
	return int(SECTOR_TEAMS[sector])


static func contains(key: Vector2i) -> bool:
	var cube_y = -key.x - key.y
	return maxi(absi(key.x), maxi(absi(key.y), absi(cube_y))) <= RADIUS


static func neighbors(key: Vector2i) -> Array:
	var result = []
	for direction in AXIAL_DIRECTIONS:
		var next = key + direction
		if contains(next):
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
	for neighbor in neighbors(key):
		if tiles.has(neighbor) and int(tiles[neighbor].get("team", NEUTRAL)) == team:
			return true
	return false


static func hex_center(key: Vector2i, origin: Vector2, hex_size: float) -> Vector2:
	return origin + _axial_vector(key) * hex_size


static func tile_at(tiles: Dictionary, pos: Vector2, origin: Vector2, hex_size: float) -> Vector2i:
	if hex_size <= 0.0 or tiles.is_empty():
		return INVALID_KEY
	var local = (pos - origin) / hex_size
	var q = (SQRT_3 / 3.0) * local.x - (1.0 / 3.0) * local.y
	var r = (2.0 / 3.0) * local.y
	var key = _round_axial(q, r)
	if contains(key) and tiles.has(key):
		return key
	return INVALID_KEY


static func board_bounds(origin: Vector2, hex_size: float) -> Rect2:
	if hex_size <= 0.0:
		return Rect2(origin, Vector2.ZERO)
	var half_width = SQRT_3 * hex_size * 0.5
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	for q in range(-RADIUS, RADIUS + 1):
		var min_r = maxi(-RADIUS, -q - RADIUS)
		var max_r = mini(RADIUS, -q + RADIUS)
		for r in range(min_r, max_r + 1):
			var center = hex_center(Vector2i(q, r), origin, hex_size)
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
	var best_key = INVALID_KEY
	var best_score = 999999999
	for key in neighbors(start_base_key):
		if not tiles.has(key):
			continue
		var score = floori(float(BoardRules.site_seed_for_key(key)) / 5.0) % 1000000
		if score < best_score:
			best_score = score
			best_key = key
	return best_key


static func starting_camp_key(tiles: Dictionary, start_base_key: Vector2i, mine_key: Vector2i) -> Vector2i:
	var best_key = INVALID_KEY
	var best_score = 999999999
	for key in neighbors(start_base_key):
		if key == mine_key or not tiles.has(key):
			continue
		var score = floori(float(BoardRules.site_seed_for_key(key)) / 13.0) % 1000000
		if score < best_score:
			best_score = score
			best_key = key
	return best_key


static func _apply_starting_unlock_rules(tiles: Dictionary, start_base_key: Vector2i, cell_type_rows: Array) -> void:
	var mine_key = starting_mine_key(tiles, start_base_key)
	var camp_key = starting_camp_key(tiles, start_base_key, mine_key)
	for key in neighbors(start_base_key):
		if not tiles.has(key):
			continue
		if key == mine_key:
			tiles[key] = BoardRules.with_site(tiles[key], BoardRules.mine_site())
			continue
		if key == camp_key:
			tiles[key] = BoardRules.with_site(tiles[key], BoardRules.camp_site_for_cost(BoardRules.UNIT_LOW_PRICE))
			continue
		var site = BoardRules.site_for_key(key, cell_type_rows)
		if String(site.get("site", "")) == "mine":
			site = BoardRules.non_mine_starting_site_for_key(key, cell_type_rows)
		tiles[key] = BoardRules.with_site(tiles[key], site)


static func _is_base_key(key: Vector2i) -> bool:
	for candidate in BASE_KEYS.values():
		if candidate == key:
			return true
	return false


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
