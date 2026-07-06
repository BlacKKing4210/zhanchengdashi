extends RefCounted

const GRID_COLS = 7
const GRID_ROWS = 13
const PLAYER = 1
const ENEMY = -1
const NEUTRAL = 0

const QUESTION_PRICE = 25
const MINE_PRICE = 50
const TOWER_PRICE = 50
const UNIT_LOW_PRICE = 50
const UNIT_MID_PRICE = 100
const UNIT_HIGH_PRICE = 250

const PLAYER_BASE = Vector2i(3, 11)
const ENEMY_BASE = Vector2i(3, 1)

const NEIGHBORS_EVEN = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]
const NEIGHBORS_ODD = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)
]


static func create_initial_tiles(_card_for_cost: Callable, _card_for_tier_range: Callable) -> Dictionary:
	var result = {}
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var key = Vector2i(x, y)
			var tile = empty_locked_tile()
			tile["territory_team"] = starting_territory_for_key(key)
			if key != PLAYER_BASE and key != ENEMY_BASE:
				var site = site_for_key(key)
				for field in site.keys():
					tile[field] = site[field]
			result[key] = tile
	return result


static func empty_locked_tile() -> Dictionary:
	return {
		"team": NEUTRAL,
		"occupier": NEUTRAL,
		"building": "",
		"hp": 0.0,
		"max_hp": 0.0,
		"spawn_timer": 0.0,
		"site": "",
		"site_cost": 0,
		"site_reward": "",
		"site_target_rarity": "",
		"site_roll_seed": 0,
		"site_card": "",
		"territory_team": NEUTRAL,
	}


static func starting_territory_for_key(key: Vector2i) -> int:
	return PLAYER if key.y >= floori(float(GRID_ROWS) * 0.5) else ENEMY


static func site_for_key(key: Vector2i) -> Dictionary:
	var site_seed = site_seed_for_key(key)
	var roll = site_seed % 100
	var site = "mystery"
	var cost = QUESTION_PRICE
	if roll < 50:
		site = "mystery"
		cost = QUESTION_PRICE
	elif roll < 70:
		cost = UNIT_LOW_PRICE if is_next_to_starting_base(key) else price_for_seed(site_seed)
		site = "hall" if cost >= UNIT_HIGH_PRICE else "barracks"
	elif roll < 90:
		site = "tower"
		cost = TOWER_PRICE
	else:
		site = "mine"
		cost = MINE_PRICE
	return {
		"site": site,
		"site_cost": cost,
		"site_reward": "",
		"site_target_rarity": "",
		"site_roll_seed": 0,
		"site_card": "",
	}


static func is_next_to_starting_base(key: Vector2i) -> bool:
	return key in neighbors(PLAYER_BASE) or key in neighbors(ENEMY_BASE)


static func site_seed_for_key(key: Vector2i) -> int:
	return absi(hash("%d:%d" % [key.x, key.y]))


static func price_for_seed(site_seed: int) -> int:
	var roll = floori(float(site_seed) / 7.0) % 100
	if roll < 30:
		return UNIT_LOW_PRICE
	if roll < 80:
		return UNIT_MID_PRICE
	return UNIT_HIGH_PRICE


static func roll_unlock_result(tile: Dictionary) -> Dictionary:
	var site = String(tile.get("site", ""))
	var roll_seed = randi()
	var result = site
	var target_rarity = ""
	if site == "mystery":
		var roll = int(roll_seed % 100)
		if roll < 70:
			result = "empty"
		elif roll < 80:
			result = "barracks"
			target_rarity = "rare"
		elif roll < 95:
			result = "hall"
			target_rarity = "epic"
		else:
			result = "hall"
			target_rarity = "legendary"
	elif site == "tower":
		target_rarity = target_rarity_for_tower(int(roll_seed))
	elif site == "barracks" or site == "hall":
		target_rarity = target_rarity_for_price(int(tile.get("site_cost", UNIT_LOW_PRICE)), int(roll_seed))
	return {
		"result": result,
		"target_rarity": target_rarity,
		"roll_seed": int(roll_seed),
	}


static func with_unlock_roll(tile: Dictionary, result: String, target_rarity: String, roll_seed: int) -> Dictionary:
	var next = tile.duplicate()
	next["site_reward"] = result
	next["site_target_rarity"] = target_rarity
	next["site_roll_seed"] = roll_seed
	return next


static func target_rarity_for_price(cost: int, site_seed: int) -> String:
	var roll = floori(float(site_seed) / 17.0) % 100
	if cost >= UNIT_HIGH_PRICE:
		if roll < 10:
			return "rare"
		if roll < 60:
			return "epic"
		return "legendary"
	if cost >= UNIT_MID_PRICE:
		if roll < 29:
			return "common"
		if roll < 75:
			return "rare"
		if roll < 95:
			return "epic"
		return "legendary"
	if roll < 65:
		return "common"
	if roll < 95:
		return "rare"
	return "epic"


static func target_rarity_for_tower(site_seed: int) -> String:
	var roll = floori(float(site_seed) / 19.0) % 100
	if roll < 55:
		return "common"
	if roll < 85:
		return "rare"
	if roll < 97:
		return "epic"
	return "legendary"


static func with_building(tile: Dictionary, team: int, building: String, card_id: String, hp: float, delay: float) -> Dictionary:
	var next = tile.duplicate()
	next["team"] = team
	next["occupier"] = team
	next["building"] = building
	next["hp"] = hp
	next["max_hp"] = hp
	next["spawn_timer"] = delay
	if card_id != "":
		next["site_card"] = card_id
	return next


static func as_unlocked_empty(tile: Dictionary, team: int) -> Dictionary:
	var next = tile.duplicate()
	next["team"] = team
	next["occupier"] = team
	next["building"] = ""
	next["hp"] = 0.0
	next["max_hp"] = 0.0
	next["spawn_timer"] = 0.0
	next["site"] = ""
	next["site_cost"] = 0
	next["site_reward"] = ""
	next["site_target_rarity"] = ""
	next["site_roll_seed"] = 0
	next["site_card"] = ""
	return next


static func with_occupier(tile: Dictionary, team: int) -> Dictionary:
	var next = tile.duplicate()
	next["occupier"] = team
	return next


static func as_destroyed_building(tile: Dictionary, attacker: int) -> Dictionary:
	var next = tile.duplicate()
	next["team"] = attacker
	next["building"] = ""
	next["hp"] = 0.0
	next["max_hp"] = 0.0
	next["spawn_timer"] = 0.0
	next["site"] = ""
	next["site_cost"] = 0
	next["site_reward"] = ""
	next["site_target_rarity"] = ""
	next["site_roll_seed"] = 0
	next["site_card"] = ""
	next["occupier"] = attacker
	return next


static func can_unlock(tiles: Dictionary, key: Vector2i, team: int) -> bool:
	if not tiles.has(key):
		return false
	var tile = tiles[key]
	if int(tile["team"]) == team:
		return false
	if String(tile["building"]) != "" or String(tile["site"]) == "":
		return false
	for neighbor in neighbors(key):
		if tiles.has(neighbor) and int(tiles[neighbor]["team"]) == team:
			return true
	return false


static func resolved_site(tile: Dictionary) -> String:
	if String(tile.get("site", "")) == "mystery":
		return String(tile.get("site_reward", "barracks"))
	return String(tile.get("site", ""))


static func tile_count(tiles: Dictionary, team: int) -> int:
	var count = 0
	for tile in tiles.values():
		if int(tile["team"]) == team:
			count += 1
	return count


static func building_count(tiles: Dictionary, team: int, building: String) -> int:
	var count = 0
	for tile in tiles.values():
		if int(tile["team"]) == team and String(tile["building"]) == building:
			count += 1
	return count


static func building_hp(building: String) -> float:
	match building:
		"base":
			return 520.0
		"hall":
			return 210.0
		"tower":
			return 180.0
		"mine":
			return 125.0
		"barracks":
			return 145.0
		_:
			return 100.0


static func building_delay(building: String, _team: int, card_interval: float = -1.0) -> float:
	if (building == "barracks" or building == "hall" or building == "tower") and card_interval > 0.0:
		return card_interval
	match building:
		"base":
			return 1.1
		"tower":
			return 1.1
		"hall":
			return 4.8
		"barracks":
			return 3.5
		_:
			return 1.0


static func neighbors(key: Vector2i) -> Array:
	var result = []
	var offsets = NEIGHBORS_ODD if key.y % 2 == 1 else NEIGHBORS_EVEN
	for offset in offsets:
		var next = key + offset
		if next.x >= 0 and next.x < GRID_COLS and next.y >= 0 and next.y < GRID_ROWS:
			result.append(next)
	return result


static func hex_center(key: Vector2i, origin: Vector2, hex_size: float) -> Vector2:
	var w = sqrt(3.0) * hex_size
	var x = origin.x + w * (float(key.x) + 0.5 * float(key.y % 2))
	var y = origin.y + hex_size * 1.5 * float(key.y)
	return Vector2(x, y)


static func hex_points(center: Vector2, hex_size: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * float(i) - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
	return points


static func tile_at(tiles: Dictionary, pos: Vector2, origin: Vector2, hex_size: float) -> Vector2i:
	for key in tiles.keys():
		if Geometry2D.is_point_in_polygon(pos, hex_points(hex_center(key, origin, hex_size), hex_size)):
			return key
	return Vector2i(-99, -99)
