extends Node2D

const DESIGN_SIZE = Vector2(720.0, 1280.0)
const HEX_SIZE = 43.0
const GRID_COLS = 7
const GRID_ROWS = 13
const PLAYER = 1
const ENEMY = -1
const NEUTRAL = 0

const SCREEN_LOBBY = "lobby"
const SCREEN_DECK = "deck"
const SCREEN_BATTLE = "battle"
const SCREEN_GACHA = "gacha"

const DECK_SIZE = 8
const BATTLE_TIME = 180.0
const STARTING_GOLD = 60
const INCOME_INTERVAL = 3.0
const BASE_INCOME = 12
const MINE_INCOME = 10
const BATTLE_REWARD_TICKETS = 2

const QUESTION_PRICE = 25
const MINE_PRICE = 50
const TOWER_PRICE = 50
const UNIT_LOW_PRICE = 50
const UNIT_MID_PRICE = 100
const UNIT_HIGH_PRICE = 250

const PLAYER_BASE = Vector2i(3, 11)
const ENEMY_BASE = Vector2i(3, 1)

const COLOR_LINE = Color(0.07, 0.09, 0.14)
const COLOR_BLUE = Color(0.25, 0.55, 0.95)
const COLOR_PURPLE = Color(0.32, 0.22, 0.65)
const COLOR_YELLOW = Color(1.0, 0.80, 0.25)
const COLOR_ORANGE = Color(1.0, 0.54, 0.13)
const COLOR_GREEN = Color(0.49, 0.82, 0.37)
const COLOR_RED = Color(0.95, 0.34, 0.32)
const COLOR_GOLD = Color(1.0, 0.62, 0.08)

const LEVEL_COSTS = [1, 2, 5, 10, 20, 30, 50, 80, 100]
const LEVEL_STAT_STEP = 0.105

const GACHA_RATES = [
	{"rarity": "common", "label": "绿色", "rate": 80.0},
	{"rarity": "rare", "label": "蓝色", "rate": 16.0},
	{"rarity": "epic", "label": "紫色", "rate": 3.2},
	{"rarity": "legendary", "label": "金色", "rate": 0.8},
]

const UNIT_ART = {
	"rabbit": preload("res://assets/art/units/rabbit.png"),
	"wolf": preload("res://assets/art/units/wolf.png"),
	"bear": preload("res://assets/art/units/bear.png"),
}

const BUILDING_ART = {
	"base": preload("res://assets/art/buildings/base.png"),
	"barracks": preload("res://assets/art/buildings/barracks.png"),
	"tower": preload("res://assets/art/buildings/tower.png"),
	"mine": preload("res://assets/art/buildings/mine.png"),
	"hall": preload("res://assets/art/buildings/hall.png"),
}

const NAV_ITEMS = [
	{"id": "shop", "label": "商店", "locked": true},
	{"id": SCREEN_DECK, "label": "编组", "locked": false},
	{"id": SCREEN_LOBBY, "label": "战斗", "locked": false},
	{"id": SCREEN_GACHA, "label": "抽卡", "locked": false},
	{"id": "more", "label": "更多", "locked": true},
]

const NEIGHBORS_EVEN = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]
const NEIGHBORS_ODD = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)
]

var tiles = {}
var units = []
var effects = []
var cards = []
var deck = []

var card_counts = {}
var card_levels = {}
var gacha_tickets = 0
var last_gacha_cards = []

var screen = SCREEN_LOBBY
var selected_tile = Vector2i(-99, -99)
var selected_slot = 0
var selected_card_id = ""
var deck_scroll = 0.0

var gold = STARTING_GOLD
var enemy_gold = STARTING_GOLD
var battle_timer = BATTLE_TIME
var income_timer = INCOME_INTERVAL
var enemy_timer = 1.0
var game_over = false
var pause_open = false
var battle_reward_given = false
var result_text = ""
var toast_text = ""
var toast_timer = 0.0
var ui_time = 0.0
var board_origin = Vector2.ZERO
var canvas_scale = 1.0
var canvas_offset = Vector2.ZERO
var next_unit_id = 1

var font: Font
var texture_cache = {}


func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	_load_cards()
	_init_player_collection()
	_init_deck()
	_reset_battle()


func _process(delta: float) -> void:
	ui_time += delta
	if toast_timer > 0.0:
		toast_timer -= delta

	if screen == SCREEN_BATTLE and not game_over and not pause_open:
		_update_battle(delta)

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if screen == SCREEN_DECK and event.pressed:
			_layout(get_viewport_rect().size)
			var deck_pos = _screen_to_canvas(event.position)
			var in_collection_frame = _collection_frame_rect().has_point(deck_pos)
			if in_collection_frame and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_deck(-82.0)
				return
			if in_collection_frame and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_deck(82.0)
				return
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)
	elif screen == SCREEN_DECK and event is InputEventScreenDrag:
		_layout(get_viewport_rect().size)
		var drag_pos = _screen_to_canvas(event.position)
		if _collection_frame_rect().has_point(drag_pos):
			_scroll_deck(-event.relative.y / maxf(canvas_scale, 0.001))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset_battle()
		elif event.keycode == KEY_ESCAPE and screen == SCREEN_BATTLE:
			pause_open = not pause_open


func _handle_tap(screen_pos: Vector2) -> void:
	_layout(get_viewport_rect().size)
	var pos = _screen_to_canvas(screen_pos)

	if screen != SCREEN_BATTLE:
		if _handle_nav(pos):
			return
		if screen == SCREEN_LOBBY and _start_rect().has_point(pos):
			screen = SCREEN_BATTLE
			_reset_battle()
			return
		if screen == SCREEN_DECK:
			_handle_deck_tap(pos)
			return
		if screen == SCREEN_GACHA:
			_handle_gacha_tap(pos)
			return

	if game_over:
		screen = SCREEN_LOBBY
		_reset_battle()
		return

	if pause_open:
		if _pause_continue_rect().has_point(pos):
			pause_open = false
		elif _pause_exit_rect().has_point(pos):
			_finish_battle("失败")
			screen = SCREEN_LOBBY
		return

	if _pause_button_rect().has_point(pos):
		pause_open = true
		return

	var key = _tile_at(pos)
	selected_tile = key
	if key.x == -99:
		return

	if _try_unlock(key):
		return

	if tiles.has(key) and int(tiles[key]["team"]) == PLAYER:
		_pulse(_hex_center(key), Color(0.75, 0.95, 1.0))


func _draw() -> void:
	_layout(get_viewport_rect().size)
	draw_set_transform(canvas_offset, 0.0, Vector2(canvas_scale, canvas_scale))

	if screen == SCREEN_DECK:
		_draw_deck_screen()
	elif screen == SCREEN_BATTLE:
		_draw_battle_screen()
	elif screen == SCREEN_GACHA:
		_draw_gacha_screen()
	else:
		_draw_lobby_screen()

	if screen != SCREEN_BATTLE:
		_draw_nav()

	_draw_toast()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _layout(view_size: Vector2) -> void:
	canvas_scale = minf(view_size.x / DESIGN_SIZE.x, view_size.y / DESIGN_SIZE.y)
	canvas_scale = maxf(canvas_scale, 0.001)
	canvas_offset = (view_size - DESIGN_SIZE * canvas_scale) * 0.5
	var board_width = sqrt(3.0) * HEX_SIZE * (GRID_COLS + 0.5)
	board_origin = Vector2((DESIGN_SIZE.x - board_width) * 0.5 + HEX_SIZE * 0.72, 120.0)


func _screen_to_canvas(pos: Vector2) -> Vector2:
	return (pos - canvas_offset) / maxf(canvas_scale, 0.001)


func _load_cards() -> void:
	cards.clear()
	if ConfigDB.has_table("cards"):
		var rows = ConfigDB.get_table("cards")
		if typeof(rows) == TYPE_ARRAY:
			for row in rows:
				if typeof(row) == TYPE_DICTIONARY:
					var card = _card_from_row(row)
					if String(card["id"]) != "":
						cards.append(card)

	if not cards.is_empty():
		return

	var fallback = [
		{"id": "rabbit", "name": "兔子", "rarity": "common", "tier": 1, "art_path": "res://assets/card_art/animals/rabbit.png"},
		{"id": "wolf", "name": "狼", "rarity": "rare", "tier": 4, "art_path": "res://assets/card_art/animals/wolf.png"},
		{"id": "bear", "name": "熊", "rarity": "epic", "tier": 5, "art_path": "res://assets/card_art/animals/bear.png"},
		{"id": "cat", "name": "猫", "rarity": "common", "tier": 2, "art_path": "res://assets/card_art/animals/cat.png"},
		{"id": "dog", "name": "狗", "rarity": "common", "tier": 2, "art_path": "res://assets/card_art/animals/dog.png"},
		{"id": "tiger", "name": "老虎", "rarity": "epic", "tier": 5, "art_path": "res://assets/card_art/animals/tiger.png"},
		{"id": "eagle", "name": "老鹰", "rarity": "epic", "tier": 5, "art_path": "res://assets/card_art/animals/eagle.png"},
		{"id": "elephant", "name": "大象", "rarity": "legendary", "tier": 6, "art_path": "res://assets/card_art/animals/elephant.png"},
	]
	for row in fallback:
		cards.append(_card_from_row(row))


func _card_from_row(row: Dictionary) -> Dictionary:
	var tier = int(row.get("tier", 1))
	var attack = int(row.get("attack", 5 + tier * 2))
	var skill_id = row.get("skill_id", "")
	var skill_text = row.get("skill_text", "")
	return {
		"id": String(row.get("id", "")),
		"name": String(row.get("name", row.get("id", ""))),
		"rarity": String(row.get("rarity", _rarity_for_tier(tier))),
		"tier": tier,
		"art_path": String(row.get("art_path", "")),
		"base_attack": attack,
		"base_max_hp": int(row.get("max_hp", 40 + tier * 18)),
		"base_move_speed": float(row.get("move_speed", 58.0 + tier * 2.0)),
		"base_attack_range": float(row.get("attack_range", 42.0)),
		"base_summon_interval_sec": float(row.get("summon_interval_sec", maxf(2.2, 4.2 - tier * 0.18))),
		"skill_id": "" if skill_id == null else String(skill_id),
		"skill_text": "" if skill_text == null else String(skill_text),
	}


func _rarity_for_tier(tier: int) -> String:
	if tier >= 6:
		return "legendary"
	if tier >= 5:
		return "epic"
	if tier >= 3:
		return "rare"
	return "common"


func _init_player_collection() -> void:
	card_counts.clear()
	card_levels.clear()
	var common_count = 0
	for card in cards:
		var id = String(card["id"])
		card_counts[id] = 0
		card_levels[id] = 1
		if String(card["rarity"]) == "common" and common_count < 8:
			card_counts[id] = 1
			common_count += 1


func _init_deck() -> void:
	deck.clear()
	var owned = _owned_card_ids()
	for i in range(DECK_SIZE):
		deck.append(String(owned[i % owned.size()]) if not owned.is_empty() else "")
	selected_card_id = String(deck[0]) if not deck.is_empty() else ""


func _owned_card_ids() -> Array:
	var owned = []
	for card in cards:
		var id = String(card["id"])
		if int(card_counts.get(id, 0)) > 0:
			owned.append(id)
	return owned


func _card_level(card_id: String) -> int:
	return int(card_levels.get(card_id, 1))


func _card_total_count(card_id: String) -> int:
	return int(card_counts.get(card_id, 0))


func _card_spare_count(card_id: String) -> int:
	return max(0, _card_total_count(card_id) - 1)


func _next_upgrade_cost(card_id: String) -> int:
	var level = _card_level(card_id)
	if level > LEVEL_COSTS.size():
		return -1
	return int(LEVEL_COSTS[level - 1])


func _card_multiplier(card_id: String) -> float:
	return 1.0 + float(_card_level(card_id) - 1) * LEVEL_STAT_STEP


func _card_stats(card: Dictionary) -> Dictionary:
	var id = String(card.get("id", ""))
	var mult = _card_multiplier(id)
	return {
		"attack": maxi(1, roundi(float(card.get("base_attack", 1)) * mult)),
		"max_hp": maxi(1, roundi(float(card.get("base_max_hp", 1)) * mult)),
		"move_speed": float(card.get("base_move_speed", 60.0)) * mult,
		"attack_range": float(card.get("base_attack_range", 42.0)) * mult,
		"summon_interval_sec": maxf(1.0, float(card.get("base_summon_interval_sec", 3.5)) / mult),
	}


func _try_upgrade_selected_card() -> void:
	var card_id = selected_card_id
	if card_id == "" or _card_total_count(card_id) <= 0:
		_toast("未拥有该卡牌")
		return
	var cost = _next_upgrade_cost(card_id)
	if cost < 0:
		_toast("已满级")
		return
	if _card_spare_count(card_id) < cost:
		_toast("碎片不足：需要%d，当前%d" % [cost, _card_spare_count(card_id)])
		return
	card_counts[card_id] = _card_total_count(card_id) - cost
	card_levels[card_id] = _card_level(card_id) + 1
	_toast("升级成功 Lv.%d" % _card_level(card_id))


func _reset_battle() -> void:
	tiles.clear()
	units.clear()
	effects.clear()
	selected_tile = Vector2i(-99, -99)
	gold = STARTING_GOLD
	enemy_gold = STARTING_GOLD
	battle_timer = BATTLE_TIME
	income_timer = INCOME_INTERVAL
	enemy_timer = 1.0
	game_over = false
	pause_open = false
	battle_reward_given = false
	result_text = ""
	next_unit_id = 1

	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var key = Vector2i(x, y)
			var tile = {
				"team": NEUTRAL,
				"building": "",
				"hp": 0.0,
				"max_hp": 0.0,
				"spawn_timer": 0.0,
				"site": "",
				"site_cost": 0,
				"site_reward": "",
				"site_card": "",
			}
			if key != PLAYER_BASE and key != ENEMY_BASE:
				_generate_site_once(key, tile)
			tiles[key] = tile

	_set_building(PLAYER_BASE, PLAYER, "base", "")
	_set_building(ENEMY_BASE, ENEMY, "base", "wolf")


func _generate_site_once(key: Vector2i, tile: Dictionary) -> void:
	var site_seed = absi(hash("%d:%d" % [key.x, key.y]))
	var roll = site_seed % 100
	var site = "mystery"
	var cost = QUESTION_PRICE
	if roll < 50:
		site = "mystery"
		cost = QUESTION_PRICE
	elif roll < 70:
		cost = _price_for_seed(site_seed)
		site = "hall" if cost >= UNIT_HIGH_PRICE else "barracks"
	elif roll < 90:
		site = "tower"
		cost = TOWER_PRICE
	else:
		site = "mine"
		cost = MINE_PRICE
	tile["site"] = site
	tile["site_cost"] = cost
	tile["site_reward"] = _site_reward(site, site_seed)
	tile["site_card"] = _site_card_for_site(site, cost, site_seed, String(tile["site_reward"]))


func _price_for_seed(site_seed: int) -> int:
	var roll = floori(float(site_seed) / 7.0) % 100
	if roll < 30:
		return UNIT_LOW_PRICE
	if roll < 80:
		return UNIT_MID_PRICE
	return UNIT_HIGH_PRICE


func _site_reward(site: String, site_seed: int) -> String:
	if site != "mystery":
		return site
	var roll = floori(float(site_seed) / 13.0) % 100
	if roll < 70:
		return "empty"
	if roll < 80:
		return "barracks"
	return "hall"


func _site_card_for_site(site: String, cost: int, site_seed: int, reward: String) -> String:
	if site == "mystery":
		var roll = floori(float(site_seed) / 13.0) % 100
		if roll < 70:
			return ""
		if roll < 80:
			return _card_for_tier_range(3, 4, site_seed)
		if roll < 95:
			return _card_for_tier_range(5, 5, site_seed)
		return _card_for_tier_range(6, 6, site_seed)
	if reward == "barracks" or reward == "hall":
		return _card_for_cost(cost, site_seed)
	return ""


func _set_building(key: Vector2i, team: int, building: String, card_id: String) -> void:
	if not tiles.has(key):
		return
	var tile = tiles[key]
	tile["team"] = team
	tile["building"] = building
	tile["hp"] = _building_hp(building)
	tile["max_hp"] = _building_hp(building)
	tile["spawn_timer"] = _building_delay(building, team, String(tile.get("site_card", card_id)))
	if card_id != "":
		tile["site_card"] = card_id
	tiles[key] = tile


func _set_empty_tile(key: Vector2i, team: int) -> void:
	if not tiles.has(key):
		return
	var tile = tiles[key]
	tile["team"] = team
	tile["building"] = ""
	tile["hp"] = 0.0
	tile["max_hp"] = 0.0
	tile["spawn_timer"] = 0.0
	tile["site"] = ""
	tile["site_cost"] = 0
	tile["site_reward"] = ""
	tile["site_card"] = ""
	tiles[key] = tile


func _apply_unlock(key: Vector2i, team: int, fallback_card_id: String) -> String:
	if not tiles.has(key):
		return ""
	var tile = tiles[key]
	var result = _resolved_site(tile)
	var card_id = String(tile.get("site_card", fallback_card_id))
	match result:
		"empty":
			_set_empty_tile(key, team)
			return "空地"
		"gold":
			if team == PLAYER:
				gold += 30
			else:
				enemy_gold += 30
			_set_empty_tile(key, team)
			return "金币 +30"
		_:
			_set_building(key, team, result, card_id)
			return _site_name(result, card_id)


func _update_battle(delta: float) -> void:
	battle_timer = maxf(0.0, battle_timer - delta)
	if battle_timer <= 0.0:
		var won = _tile_count(PLAYER) >= _tile_count(ENEMY)
		_finish_battle("胜利" if won else "失败")
		return

	income_timer -= delta
	if income_timer <= 0.0:
		income_timer = INCOME_INTERVAL
		gold += _building_count(PLAYER, "base") * BASE_INCOME + _building_count(PLAYER, "mine") * MINE_INCOME
		enemy_gold += _building_count(ENEMY, "base") * BASE_INCOME + _building_count(ENEMY, "mine") * MINE_INCOME

	_update_buildings(delta)
	_update_enemy(delta)
	_update_units(delta)
	_update_effects(delta)


func _update_buildings(delta: float) -> void:
	for key in tiles.keys():
		var tile = tiles[key]
		var building = String(tile["building"])
		if building == "" or building == "mine":
			continue
		var team = int(tile["team"])
		tile["spawn_timer"] = float(tile.get("spawn_timer", 0.0)) - delta
		if float(tile["spawn_timer"]) <= 0.0:
			tile["spawn_timer"] = _building_delay(building, team, String(tile.get("site_card", "")))
			if building == "tower":
				_tower_attack(key, team)
			else:
				_spawn_unit(team, key, _spawn_card_for_tile(tile, team))
		tiles[key] = tile


func _update_enemy(delta: float) -> void:
	enemy_timer -= delta
	if enemy_timer > 0.0:
		return
	enemy_timer = 1.4
	var best_key = Vector2i(-99, -99)
	var best_y = -999
	for key in tiles.keys():
		if _can_unlock(key, ENEMY) and key.y > best_y:
			best_y = key.y
			best_key = key
	if best_key.x == -99:
		return
	var tile = tiles[best_key]
	var cost = int(tile["site_cost"])
	if enemy_gold < cost:
		return
	enemy_gold -= cost
	_apply_unlock(best_key, ENEMY, "wolf")


func _update_units(delta: float) -> void:
	var alive = []
	for unit in units:
		if float(unit["hp"]) <= 0.0:
			continue
		var target_key = _nearest_target(Vector2(unit["pos"]), int(unit["team"]))
		if target_key.x == -99:
			alive.append(unit)
			continue
		var target_pos = _hex_center(target_key)
		var offset = target_pos - Vector2(unit["pos"])
		var distance = offset.length()
		unit["cooldown"] = maxf(0.0, float(unit.get("cooldown", 0.0)) - delta)
		if distance <= float(unit["range"]):
			if float(unit["cooldown"]) <= 0.0:
				_damage_tile(target_key, int(unit["team"]), float(unit["attack"]))
				unit["cooldown"] = 0.85
		elif distance > 1.0:
			unit["pos"] = Vector2(unit["pos"]) + offset.normalized() * float(unit["speed"]) * delta
		alive.append(unit)
	units = alive


func _update_effects(delta: float) -> void:
	var kept = []
	for effect in effects:
		effect["time"] = float(effect["time"]) - delta
		if float(effect["time"]) > 0.0:
			kept.append(effect)
	effects = kept


func _tower_attack(key: Vector2i, team: int) -> void:
	var center = _hex_center(key)
	var best_index = -1
	var best_distance = 999999.0
	for i in range(units.size()):
		if int(units[i]["team"]) == team:
			continue
		var distance = center.distance_to(Vector2(units[i]["pos"]))
		if distance < 150.0 and distance < best_distance:
			best_distance = distance
			best_index = i
	if best_index >= 0:
		units[best_index]["hp"] = float(units[best_index]["hp"]) - 22.0
		_pulse(Vector2(units[best_index]["pos"]), COLOR_YELLOW)


func _damage_tile(key: Vector2i, attacker: int, damage: float) -> void:
	if not tiles.has(key):
		return
	var tile = tiles[key]
	if int(tile["team"]) == attacker:
		return
	if String(tile["building"]) == "":
		_set_empty_tile(key, attacker)
		_pulse(_hex_center(key), COLOR_GREEN if attacker == PLAYER else COLOR_RED)
		return
	tile["hp"] = float(tile["hp"]) - damage
	if float(tile["hp"]) <= 0.0:
		if String(tile["building"]) == "base":
			_finish_battle("胜利" if attacker == PLAYER else "失败")
			return
		tiles[key] = tile
		_set_empty_tile(key, attacker)
		_pulse(_hex_center(key), COLOR_GREEN if attacker == PLAYER else COLOR_RED)
		return
	tiles[key] = tile


func _spawn_unit(team: int, key: Vector2i, card_id: String) -> void:
	if card_id == "":
		card_id = "wolf" if team == ENEMY else String(deck[0])
	var card = _card_by_id(card_id)
	if card.is_empty():
		card = _card_by_id("wolf" if team == ENEMY else "rabbit")
	var stats = _card_stats(card)
	units.append({
		"id": next_unit_id,
		"team": team,
		"card": String(card.get("id", card_id)),
		"pos": _hex_center(key),
		"hp": float(stats["max_hp"]),
		"max_hp": float(stats["max_hp"]),
		"attack": float(stats["attack"]),
		"speed": float(stats["move_speed"]),
		"range": float(stats["attack_range"]),
		"cooldown": randf_range(0.05, 0.35),
	})
	next_unit_id += 1
	_pulse(_hex_center(key), Color(0.75, 0.95, 1.0))


func _nearest_target(pos: Vector2, team: int) -> Vector2i:
	var best = Vector2i(-99, -99)
	var best_score = 999999.0
	for key in tiles.keys():
		var tile = tiles[key]
		if int(tile["team"]) == team:
			continue
		var score = pos.distance_to(_hex_center(key))
		if String(tile["building"]) == "base":
			score -= 120.0
		elif String(tile["building"]) != "":
			score -= 60.0
		if score < best_score:
			best_score = score
			best = key
	return best


func _try_unlock(key: Vector2i) -> bool:
	if not _can_unlock(key, PLAYER):
		return false
	var tile = tiles[key]
	var cost = int(tile["site_cost"])
	if gold < cost:
		_toast("金币不足，还差%d" % [cost - gold])
		return true
	gold -= cost
	var result_label = _apply_unlock(key, PLAYER, String(tile.get("site_card", "")))
	_toast("已解锁 " + result_label)
	return true


func _can_unlock(key: Vector2i, team: int) -> bool:
	if not tiles.has(key):
		return false
	var tile = tiles[key]
	if int(tile["team"]) == team:
		return false
	if String(tile["building"]) != "" or String(tile["site"]) == "":
		return false
	for neighbor in _neighbors(key):
		if tiles.has(neighbor) and int(tiles[neighbor]["team"]) == team:
			return true
	return false


func _resolved_site(tile: Dictionary) -> String:
	if String(tile.get("site", "")) == "mystery":
		return String(tile.get("site_reward", "barracks"))
	return String(tile.get("site", ""))


func _spawn_card_for_tile(tile: Dictionary, team: int) -> String:
	var card_id = String(tile.get("site_card", ""))
	if card_id != "":
		return card_id
	return "wolf" if team == ENEMY else String(deck[0])


func _card_for_cost(cost: int, site_seed: int = 0) -> String:
	if cost >= UNIT_HIGH_PRICE:
		return _card_for_tier_range(5, 6, site_seed)
	if cost >= UNIT_MID_PRICE:
		return _card_for_tier_range(3, 5, site_seed)
	return _card_for_tier_range(1, 3, site_seed)


func _card_for_tier_range(min_tier: int, max_tier: int, site_seed: int) -> String:
	var options = []
	for card_id in deck:
		var card = _card_by_id(String(card_id))
		var tier = int(card.get("tier", 1))
		if tier >= min_tier and tier <= max_tier:
			options.append(String(card_id))
	if options.is_empty():
		for card in cards:
			var tier = int(card.get("tier", 1))
			if tier >= min_tier and tier <= max_tier:
				options.append(String(card.get("id", "")))
	if options.is_empty():
		return String(deck[0]) if not deck.is_empty() else ""
	var pick_seed = absi(site_seed + min_tier * 17 + max_tier * 31)
	return String(options[pick_seed % options.size()])


func _card_by_id(card_id: String) -> Dictionary:
	for card in cards:
		if String(card.get("id", "")) == card_id:
			return card
	return {}


func _tile_count(team: int) -> int:
	var count = 0
	for tile in tiles.values():
		if int(tile["team"]) == team:
			count += 1
	return count


func _building_count(team: int, building: String) -> int:
	var count = 0
	for tile in tiles.values():
		if int(tile["team"]) == team and String(tile["building"]) == building:
			count += 1
	return count


func _building_hp(building: String) -> float:
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


func _building_delay(building: String, team: int, card_id: String) -> float:
	if building == "barracks" or building == "hall":
		var card = _card_by_id(card_id)
		if not card.is_empty():
			return float(_card_stats(card)["summon_interval_sec"])
	match building:
		"base":
			return 4.6 if team == PLAYER else 4.2
		"tower":
			return 1.1
		"hall":
			return 4.8
		"barracks":
			return 3.5
		_:
			return 1.0


func _finish_battle(text: String) -> void:
	result_text = text
	game_over = true
	pause_open = false
	if not battle_reward_given:
		battle_reward_given = true
		gacha_tickets += BATTLE_REWARD_TICKETS
		_toast("获得%d张抽卡券" % BATTLE_REWARD_TICKETS)


func _roll_gacha() -> Dictionary:
	var rarity = _roll_rarity()
	var pool = []
	for card in cards:
		if String(card.get("rarity", "common")) == rarity:
			pool.append(card)
	if pool.is_empty():
		pool = cards.duplicate()
	if pool.is_empty():
		return {}
	var card = pool[randi() % pool.size()]
	var card_id = String(card["id"])
	card_counts[card_id] = _card_total_count(card_id) + 1
	if not card_levels.has(card_id):
		card_levels[card_id] = 1
	_ensure_deck_valid()
	return card


func _roll_rarity() -> String:
	var roll = randf() * 100.0
	var acc = 0.0
	for entry in GACHA_RATES:
		acc += float(entry["rate"])
		if roll < acc:
			return String(entry["rarity"])
	return "legendary"


func _handle_gacha_tap(pos: Vector2) -> void:
	if _gacha_ten_draw_rect().has_point(pos):
		_draw_gacha_rewards(10)
		return
	if _gacha_draw_rect().has_point(pos):
		_draw_gacha_rewards(1)
		return


func _draw_gacha_rewards(count: int) -> void:
	if gacha_tickets < count:
		_toast("抽卡券不足")
		return
	gacha_tickets -= count
	last_gacha_cards.clear()
	for i in range(count):
		var card = _roll_gacha()
		if card.is_empty():
			continue
		last_gacha_cards.append(String(card["id"]))
		selected_card_id = String(card["id"])
	if last_gacha_cards.is_empty():
		return
	_toast("获得%d张卡牌" % last_gacha_cards.size())


func _handle_deck_tap(pos: Vector2) -> void:
	for i in range(DECK_SIZE):
		if _deck_slot_rect(i).has_point(pos):
			selected_slot = i
			selected_card_id = String(deck[i])
			return

	if _upgrade_button_rect().has_point(pos):
		_try_upgrade_selected_card()
		return

	var card_index = _collection_index_at(pos)
	if card_index < 0 or card_index >= cards.size():
		return
	var card = cards[card_index]
	var card_id = String(card["id"])
	selected_card_id = card_id
	if _card_total_count(card_id) <= 0:
		_toast("尚未拥有该卡牌")
		return
	if selected_slot >= 0 and selected_slot < deck.size():
		deck[selected_slot] = card_id
		_toast("已加入出战编组")


func _handle_nav(pos: Vector2) -> bool:
	for i in range(NAV_ITEMS.size()):
		if not _nav_rect(i).has_point(pos):
			continue
		var item = NAV_ITEMS[i]
		if bool(item.get("locked", false)):
			_toast(String(item["label"]) + "暂未开放")
			return true
		var id = String(item["id"])
		if id == SCREEN_DECK:
			screen = SCREEN_DECK
		elif id == SCREEN_GACHA:
			screen = SCREEN_GACHA
		elif id == SCREEN_LOBBY:
			screen = SCREEN_LOBBY
		return true
	return false


func _ensure_deck_valid() -> void:
	var owned = _owned_card_ids()
	if owned.is_empty():
		return
	for i in range(deck.size()):
		if _card_total_count(String(deck[i])) <= 0:
			deck[i] = String(owned[i % owned.size()])


func _scroll_deck(amount: float) -> void:
	var rows = ceili(float(cards.size()) / 4.0)
	var content_height = maxf(0.0, float(rows - 1) * 176.0 + 158.0)
	deck_scroll = clampf(deck_scroll + amount, 0.0, maxf(0.0, content_height - _collection_view_rect().size.y))


func _collection_view_rect() -> Rect2:
	var frame = _collection_frame_rect()
	return Rect2(frame.position + Vector2(20, 14), frame.size - Vector2(40, 28))


func _collection_frame_rect() -> Rect2:
	return Rect2(34, 714, 652, 414)


func _draw_lobby_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_text_center("占城大师", Rect2(40, 66, 640, 64), 46, Color.WHITE)
	var scene_rect = Rect2(58, 154, 604, 744)
	_box(scene_rect, Color(0.39, 0.63, 0.87), COLOR_LINE, 5)
	draw_rect(scene_rect.grow(-14), Color(0.48, 0.78, 0.39))
	draw_texture_rect(BUILDING_ART["base"], Rect2(260, 260, 200, 200), false)
	draw_texture_rect(UNIT_ART["rabbit"], Rect2(190, 570, 120, 120), false)
	draw_texture_rect(UNIT_ART["wolf"], Rect2(410, 570, 120, 120), false)
	_cta(_start_rect(), "开始战斗", true)


func _draw_gacha_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_text_center("抽卡", Rect2(40, 68, 640, 58), 46, Color.WHITE)
	_resource(Rect2(238, 130, 244, 48), "抽卡券", str(gacha_tickets), COLOR_YELLOW)

	var reward_panel = Rect2(46, 220, 628, 560)
	_box(reward_panel, Color(0.19, 0.16, 0.45), COLOR_LINE, 5)
	_draw_text_center("最近获得", Rect2(reward_panel.position + Vector2(0, 28), Vector2(reward_panel.size.x, 42)), 30, Color.WHITE)
	if last_gacha_cards.is_empty():
		_draw_text_center("暂无记录", Rect2(reward_panel.position + Vector2(0, 238), Vector2(reward_panel.size.x, 42)), 24, Color.WHITE)
	else:
		for i in range(last_gacha_cards.size()):
			var card = _card_by_id(String(last_gacha_cards[i]))
			_draw_gacha_reward_card(i, card)

	_cta(_gacha_draw_rect(), "抽1次", gacha_tickets > 0)
	_cta(_gacha_ten_draw_rect(), "抽10次", gacha_tickets >= 10)


func _draw_gacha_reward_card(index: int, card: Dictionary) -> void:
	var count = max(1, last_gacha_cards.size())
	if count == 1:
		_draw_card(Rect2(292, 410, 136, 166), card, true)
		return
	var columns = 5 if count > 4 else count
	var card_size = Vector2(106, 134)
	var gap = Vector2(16, 18)
	var row = floori(float(index) / float(columns))
	var col = index % columns
	var rows = ceili(float(count) / float(columns))
	var row_count = columns
	if row == rows - 1:
		row_count = count - row * columns
	var row_width = float(row_count) * card_size.x + float(row_count - 1) * gap.x
	var start_x = (DESIGN_SIZE.x - row_width) * 0.5
	var start_y = 318.0 if rows > 1 else 396.0
	_draw_card(Rect2(Vector2(start_x + float(col) * (card_size.x + gap.x), start_y + float(row) * (card_size.y + gap.y)), card_size), card, true)


func _draw_deck_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_text_center("出战编组", Rect2(40, 68, 640, 58), 42, Color.WHITE)
	_box(Rect2(34, 140, 652, 360), COLOR_PURPLE, COLOR_LINE, 5)
	for i in range(DECK_SIZE):
		_draw_card(_deck_slot_rect(i), _card_by_id(String(deck[i])), i == selected_slot)
	_draw_card_detail(Rect2(34, 520, 652, 128))
	_draw_text_center("所有卡牌", Rect2(0, 670, DESIGN_SIZE.x, 42), 34, Color.WHITE)
	var collection_frame = _collection_frame_rect()
	_box(collection_frame, Color(0.55, 0.78, 0.43, 0.68), COLOR_LINE, 4)
	var collection_view = _collection_view_rect()
	var origin = Vector2(collection_view.position.x, collection_view.position.y - deck_scroll)
	for i in range(cards.size()):
		var col = i % 4
		var row = floori(float(i) / 4.0)
		var rect = Rect2(origin + Vector2(col * 156.0, row * 176.0), Vector2(132, 158))
		if rect.position.y < collection_view.position.y or rect.position.y + rect.size.y > collection_view.position.y + collection_view.size.y:
			continue
		var card = cards[i]
		_draw_card(rect, card, String(card["id"]) == selected_card_id)


func _draw_battle_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_board_frame()
	for key in tiles.keys():
		_draw_tile(key, tiles[key])
	for unit in units:
		_draw_unit(unit)
	for effect in effects:
		_draw_effect(effect)
	_draw_selection_panel()
	_draw_pause_button()
	if pause_open:
		_draw_pause_overlay()
	elif game_over:
		_draw_result_overlay()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.60, 0.85, 0.50))
	draw_rect(Rect2(0, 0, DESIGN_SIZE.x, 220), Color(0.68, 0.90, 0.60))
	for i in range(12):
		var x = 40.0 + fmod(float(i) * 96.0 + ui_time * 8.0, DESIGN_SIZE.x)
		_grass(Vector2(x, 82.0 + float(i % 4) * 36.0))


func _draw_top_bar() -> void:
	_resource(Rect2(46, 18, 186, 44), "金币", str(gold), COLOR_YELLOW)
	_resource(Rect2(488, 18, 186, 44), "券", str(gacha_tickets), COLOR_BLUE)


func _draw_nav() -> void:
	draw_rect(Rect2(0, 1138, DESIGN_SIZE.x, 142), Color(0.24, 0.21, 0.58))
	for i in range(NAV_ITEMS.size()):
		var item = NAV_ITEMS[i]
		var rect = _nav_rect(i)
		var id = String(item["id"])
		var active = (screen == id) or (screen == SCREEN_LOBBY and id == SCREEN_LOBBY)
		_box(rect, COLOR_BLUE if active else COLOR_PURPLE, COLOR_LINE, 3)
		_draw_nav_icon(rect, i, bool(item.get("locked", false)))
		_draw_text_center(String(item["label"]), Rect2(rect.position + Vector2(0, 84), Vector2(rect.size.x, 34)), 23, Color.WHITE)


func _draw_nav_icon(rect: Rect2, index: int, locked: bool) -> void:
	var c = rect.position + Vector2(rect.size.x * 0.5, 42)
	if index == 0:
		_box(Rect2(c + Vector2(-28, -10), Vector2(56, 42)), Color(0.92, 0.74, 0.38), COLOR_LINE, 3)
		draw_rect(Rect2(c + Vector2(-32, -28), Vector2(64, 20)), COLOR_RED)
	elif index == 1:
		_box(Rect2(c + Vector2(-28, -26), Vector2(46, 58)), COLOR_YELLOW, COLOR_LINE, 3)
		_box(Rect2(c + Vector2(-8, -22), Vector2(46, 58)), Color(0.65, 0.28, 0.95), COLOR_LINE, 3)
	elif index == 2:
		draw_line(c + Vector2(-26, -22), c + Vector2(22, 22), Color.WHITE, 8, true)
		draw_line(c + Vector2(26, -22), c + Vector2(-22, 22), Color.WHITE, 8, true)
	elif index == 3:
		draw_circle(c, 30, COLOR_GOLD)
		draw_circle(c, 18, Color(1.0, 0.95, 0.55))
		_draw_text_center("抽", Rect2(c + Vector2(-24, -22), Vector2(48, 44)), 24, COLOR_LINE)
	else:
		_box(Rect2(c + Vector2(-26, -24), Vector2(52, 52)), COLOR_ORANGE, COLOR_LINE, 3)
	if locked:
		_draw_lock(c + Vector2(34, -30))


func _draw_board_frame() -> void:
	_box(Rect2(36, 82, 648, 1038), Color(0.95, 0.80, 0.50), Color(0.37, 0.55, 0.25), 5)
	_box(Rect2(64, 110, 592, 982), Color(0.62, 0.88, 0.45), Color(0.25, 0.48, 0.22), 4)


func _draw_tile(key: Vector2i, tile: Dictionary) -> void:
	var center = _hex_center(key)
	var points = _hex_points(center)
	var team = int(tile["team"])
	var can_unlock = _can_unlock(key, PLAYER)
	var fill = Color(0.86, 0.92, 0.78, 0.38)
	var line = Color(0.54, 0.64, 0.44, 0.42)
	var line_width = 2.0
	if team == PLAYER:
		fill = Color(0.49, 0.80, 0.39)
		line = fill.darkened(0.34)
		line_width = 3.0
	elif team == ENEMY:
		fill = Color(0.95, 0.43, 0.39)
		line = fill.darkened(0.34)
		line_width = 3.0
	elif can_unlock:
		fill = Color(0.98, 0.88, 0.48, 0.92)
		line = COLOR_YELLOW if gold >= int(tile["site_cost"]) else Color(0.78, 0.72, 0.62)
		line_width = 4.0
	draw_polygon(points, PackedColorArray([fill, fill, fill, fill, fill, fill]))
	draw_polyline(_closed_points(points), line, line_width)
	if String(tile["building"]) != "":
		_draw_building(center, tile)
	elif can_unlock:
		_draw_site(center, tile)


func _draw_site(center: Vector2, tile: Dictionary) -> void:
	var site = String(tile.get("site", ""))
	_draw_site_icon(center + Vector2(0, -9), site)
	var price_rect = Rect2(center + Vector2(-38, 22), Vector2(76, 26))
	var affordable = gold >= int(tile["site_cost"])
	_box(price_rect, Color(1, 1, 1, 0.88) if affordable else Color(0.62, 0.64, 0.66, 0.85), COLOR_LINE, 2)
	draw_circle(price_rect.position + Vector2(14, 13), 7, COLOR_YELLOW)
	_draw_text_right(str(int(tile["site_cost"])), Rect2(price_rect.position + Vector2(24, 0), Vector2(46, 26)), 18, COLOR_LINE if affordable else Color(0.65, 0.10, 0.10))


func _draw_site_icon(center: Vector2, site: String) -> void:
	draw_circle(center + Vector2(0, 4), 24, Color(0, 0, 0, 0.18))
	draw_circle(center, 24, Color(1.0, 0.96, 0.72, 0.92))
	draw_arc(center, 25, 0.0, TAU, 32, COLOR_LINE, 2.5, true)
	if site == "mystery":
		_draw_text_center("?", Rect2(center + Vector2(-20, -21), Vector2(40, 38)), 30, COLOR_LINE)
		return
	var icon_building = _site_icon_building(site)
	var icon_size = Vector2(34, 34)
	if site == "tower":
		icon_size = Vector2(34, 42)
	draw_texture_rect(_building_texture(icon_building), Rect2(center - icon_size * 0.5 + Vector2(0, -2), icon_size), false)


func _site_icon_building(site: String) -> String:
	match site:
		"mine":
			return "mine"
		"tower":
			return "tower"
		"hall":
			return "hall"
		_:
			return "barracks"


func _draw_building(center: Vector2, tile: Dictionary) -> void:
	var building = String(tile["building"])
	var size = Vector2(66, 66)
	if building == "base":
		size = Vector2(78, 78)
	elif building == "tower":
		size = Vector2(66, 82)
	draw_texture_rect(_building_texture(building), Rect2(center - size * 0.5 + Vector2(0, -8), size), false)
	var max_hp = float(tile.get("max_hp", 0.0))
	if max_hp <= 0.0:
		return
	var pct = clampf(float(tile["hp"]) / max_hp, 0.0, 1.0)
	_box(Rect2(center + Vector2(-32, 30), Vector2(64, 8)), COLOR_LINE, Color(0, 0, 0, 0), 0)
	_box(Rect2(center + Vector2(-31, 31), Vector2(62.0 * pct, 6)), COLOR_GREEN, Color(0, 0, 0, 0), 0)


func _draw_unit(unit: Dictionary) -> void:
	var pos = Vector2(unit["pos"])
	var team = int(unit["team"])
	draw_circle(pos + Vector2(0, 14), 17, Color(0, 0, 0, 0.18))
	draw_texture_rect(_card_texture(_card_by_id(String(unit["card"]))), Rect2(pos + Vector2(-22, -30), Vector2(44, 44)), false)
	draw_circle(pos + Vector2(0, -30), 7, Color(0.65, 0.86, 1.0) if team == PLAYER else Color(1.0, 0.60, 0.56))
	var pct = clampf(float(unit["hp"]) / float(unit["max_hp"]), 0.0, 1.0)
	_box(Rect2(pos + Vector2(-18, 20), Vector2(36, 6)), COLOR_LINE, Color(0, 0, 0, 0), 0)
	_box(Rect2(pos + Vector2(-17, 21), Vector2(34.0 * pct, 4)), COLOR_GREEN, Color(0, 0, 0, 0), 0)


func _draw_effect(effect: Dictionary) -> void:
	var t = clampf(float(effect["time"]) / 0.45, 0.0, 1.0)
	var color = effect["color"]
	color.a = t * 0.55
	draw_circle(Vector2(effect["pos"]), 8.0 + 30.0 * (1.0 - t), color)


func _draw_selection_panel() -> void:
	var rect = Rect2(26, 1132, 668, 118)
	_box(rect, Color(0.12, 0.10, 0.31, 0.92), Color(0.30, 0.28, 0.62), 4)
	var title = "点击与己方地块接壤的卡牌地块解锁"
	var detail = "可解锁地块会显示类型和价格，生成后不会因其它地块改变。"
	if tiles.has(selected_tile):
		var tile = tiles[selected_tile]
		if String(tile["building"]) != "":
			title = _site_name(String(tile["building"]), String(tile.get("site_card", "")))
			detail = "生命 %.0f / %.0f" % [float(tile["hp"]), float(tile["max_hp"])]
		elif int(tile["team"]) == PLAYER:
			title = "空地"
			detail = "已解锁区域，可作为继续扩张的连接点。"
		elif int(tile["team"]) == ENEMY:
			title = "敌方区域"
			detail = "派出单位推进后可占领。"
		elif _can_unlock(selected_tile, PLAYER):
			var site = String(tile.get("site", ""))
			title = "可解锁：%s  价格 %d" % [_site_name(site, String(tile.get("site_card", ""))), int(tile["site_cost"])]
			if gold < int(tile["site_cost"]):
				detail = "金币不足，还差%d。" % [int(tile["site_cost"]) - gold]
			elif site == "mystery":
				detail = "问号地块购买后翻开，可能为空地或高级单位建筑。"
			else:
				detail = "购买后立刻变为己方区域。"
		else:
			title = "未连接地块"
			detail = "先扩张到相邻地块。"
	_draw_text_fit(title, Rect2(rect.position + Vector2(24, 18), Vector2(620, 34)), 24, Color.WHITE)
	_draw_text_fit(detail, Rect2(rect.position + Vector2(24, 60), Vector2(620, 32)), 20, Color(0.84, 0.88, 1.0))


func _draw_pause_button() -> void:
	var rect = _pause_button_rect()
	_box(rect, Color(1, 1, 1, 0.92), COLOR_LINE, 3)
	draw_rect(Rect2(rect.position + Vector2(19, 15), Vector2(8, 26)), COLOR_LINE)
	draw_rect(Rect2(rect.position + Vector2(35, 15), Vector2(8, 26)), COLOR_LINE)


func _draw_pause_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0, 0, 0, 0.48))
	var panel = Rect2(120, 430, 480, 330)
	_box(panel, Color(1.0, 0.96, 0.78), COLOR_LINE, 5)
	_draw_text_center("战斗暂停", Rect2(panel.position + Vector2(0, 38), Vector2(panel.size.x, 52)), 38, COLOR_LINE)
	_cta(_pause_continue_rect(), "继续战斗", true)
	_cta(_pause_exit_rect(), "退出战斗", false)


func _draw_result_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0, 0, 0, 0.42))
	var panel = Rect2(110, 438, 500, 300)
	_box(panel, Color(1.0, 0.96, 0.78), COLOR_LINE, 5)
	_draw_text_center(result_text, Rect2(panel.position + Vector2(0, 48), Vector2(panel.size.x, 68)), 52, COLOR_YELLOW if result_text == "胜利" else COLOR_RED)
	_draw_text_center("奖励：+%d 抽卡券" % BATTLE_REWARD_TICKETS, Rect2(panel.position + Vector2(0, 128), Vector2(panel.size.x, 36)), 24, COLOR_LINE)
	_draw_text_center("点击任意位置返回主界面", Rect2(panel.position + Vector2(0, 176), Vector2(panel.size.x, 40)), 24, COLOR_LINE)


func _draw_card(rect: Rect2, card: Dictionary, selected: bool) -> void:
	if card.is_empty():
		_box(rect, Color(0.35, 0.36, 0.40), COLOR_LINE, 4)
		_draw_text_center("空", rect, 18, Color.WHITE)
		return
	var owned = _card_total_count(String(card.get("id", ""))) > 0
	var fill = _rarity_color(String(card.get("rarity", "common")))
	_box(rect, fill.darkened(0.06) if owned else Color(0.35, 0.36, 0.40), COLOR_LINE, 4)
	if selected:
		_box(rect.grow(5), Color(1.0, 0.91, 0.22, 0.28), COLOR_YELLOW, 4)
	var tint = Color.WHITE if owned else Color(0.35, 0.35, 0.35, 0.85)
	var card_id = String(card.get("id", ""))
	var name_rect = Rect2(rect.position + Vector2(8, rect.size.y - 48), Vector2(rect.size.x - 16, 22))
	var progress_rect = Rect2(rect.position + Vector2(12, rect.size.y - 22), Vector2(rect.size.x - 24, 14))
	var art_top = rect.position.y + 12.0
	var art_bottom = name_rect.position.y - 5.0
	var art_size = minf(rect.size.x - 30.0, maxf(44.0, art_bottom - art_top))
	var art_rect = Rect2(Vector2(rect.position.x + (rect.size.x - art_size) * 0.5, art_top), Vector2(art_size, art_size))
	draw_texture_rect(_card_texture(card), art_rect, false, tint)
	_box(name_rect, Color(0, 0, 0, 0.30), Color(1, 1, 1, 0.18), 1)
	if owned:
		_draw_text_center("Lv.%d  %s" % [_card_level(card_id), String(card.get("name", ""))], name_rect, 15, Color.WHITE)
		_draw_upgrade_progress(progress_rect, card_id, false)
	else:
		_draw_text_center("未拥有", name_rect, 15, Color.WHITE)
		_draw_empty_progress(progress_rect)


func _draw_card_detail(rect: Rect2) -> void:
	var card = _card_by_id(selected_card_id)
	_box(rect, Color(1, 1, 1, 0.92), COLOR_LINE, 3)
	if card.is_empty():
		return
	var card_id = String(card["id"])
	var stats = _card_stats(card)
	draw_texture_rect(_card_texture(card), Rect2(rect.position + Vector2(14, 16), Vector2(92, 92)), false)
	_draw_text_fit(String(card.get("name", "")), Rect2(rect.position + Vector2(118, 12), Vector2(180, 30)), 23, COLOR_LINE)
	_draw_text_fit("%s  Lv.%d" % [_rarity_label(String(card.get("rarity", ""))), _card_level(card_id)], Rect2(rect.position + Vector2(310, 12), Vector2(170, 30)), 19, _rarity_color(String(card.get("rarity", ""))).darkened(0.30))
	_draw_text_fit("拥有 %d" % _card_total_count(card_id), Rect2(rect.position + Vector2(500, 12), Vector2(120, 30)), 17, COLOR_LINE)
	var stat_text = "攻 %d  血 %d  速 %.0f  距 %.0f  召 %.1fs" % [
		int(stats["attack"]),
		int(stats["max_hp"]),
		float(stats["move_speed"]),
		float(stats["attack_range"]),
		float(stats["summon_interval_sec"]),
	]
	_draw_text_fit(stat_text, Rect2(rect.position + Vector2(118, 46), Vector2(500, 28)), 18, COLOR_LINE)
	var cost = _next_upgrade_cost(card_id)
	_draw_upgrade_progress(Rect2(rect.position + Vector2(118, 82), Vector2(360, 26)), card_id, true)
	_cta(_upgrade_button_rect(), "升级", cost >= 0 and _card_spare_count(card_id) >= cost)


func _draw_upgrade_progress(rect: Rect2, card_id: String, show_label: bool) -> void:
	var spare = _card_spare_count(card_id)
	var cost = _next_upgrade_cost(card_id)
	var max_value = max(1, cost)
	var pct = 1.0 if cost < 0 else clampf(float(spare) / float(max_value), 0.0, 1.0)
	var fill = COLOR_GREEN if cost >= 0 and spare >= cost else Color(0.26, 0.54, 0.92)
	if cost < 0:
		fill = COLOR_GOLD
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.22))
	draw_rect(rect, Color(0.08, 0.10, 0.18, 0.82))
	var inner = Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6))
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * pct, inner.size.y)), fill)
	draw_rect(rect, COLOR_LINE, false, 2)
	if show_label:
		var label = "满级" if cost < 0 else "碎片 %d/%d" % [spare, cost]
		_draw_text_center(label, rect, 16, Color.WHITE)


func _draw_empty_progress(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.18))
	draw_rect(rect, Color(0.08, 0.10, 0.18, 0.55))
	draw_rect(rect, COLOR_LINE, false, 2)


func _draw_toast() -> void:
	if toast_timer <= 0.0:
		return
	var alpha = clampf(toast_timer / 1.4, 0.0, 1.0)
	var rect = Rect2(130, 1018, 460, 58)
	_box(rect, Color(0.05, 0.06, 0.10, 0.82 * alpha), Color(1, 1, 1, 0.18 * alpha), 2)
	_draw_text_center(toast_text, rect, 23, Color(1, 1, 1, alpha))


func _resource(rect: Rect2, label: String, value: String, color: Color) -> void:
	_box(rect, Color(1, 1, 1, 0.92), COLOR_LINE, 3)
	draw_circle(rect.position + Vector2(22, rect.size.y * 0.5), 12, color)
	_draw_text_fit(label, Rect2(rect.position + Vector2(40, 0), Vector2(50, rect.size.y)), 16, COLOR_LINE)
	_draw_text_right(value, Rect2(rect.position + Vector2(86, 0), Vector2(rect.size.x - 96, rect.size.y)), 20, COLOR_LINE)


func _cta(rect: Rect2, label: String, primary: bool) -> void:
	_box(rect, COLOR_ORANGE if primary else Color(0.46, 0.50, 0.62), COLOR_LINE, 5)
	_draw_text_center(label, rect, 26, Color.WHITE)


func _box(rect: Rect2, fill: Color, line: Color, width: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 5), rect.size), Color(0, 0, 0, 0.20))
	draw_rect(rect, fill)
	if width > 0.0 and line.a > 0.0:
		draw_rect(rect, line, false, width)


func _draw_text_fit(text: String, rect: Rect2, size: int, color: Color) -> void:
	var label = _fit_text(text, rect.size.x, size)
	var y = rect.position.y + rect.size.y * 0.5 + size * 0.36
	draw_string(font, Vector2(rect.position.x, y), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, color)


func _draw_text_right(text: String, rect: Rect2, size: int, color: Color) -> void:
	var label = _fit_text(text, rect.size.x, size)
	var y = rect.position.y + rect.size.y * 0.5 + size * 0.36
	draw_string(font, Vector2(rect.position.x, y), label, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, size, color)


func _draw_text_center(text: String, rect: Rect2, size: int, color: Color) -> void:
	var label = _fit_text(text, rect.size.x, size)
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pos = rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y + text_size.y * 0.55) * 0.5)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _fit_text(text: String, max_width: float, size: int) -> String:
	if text == "" or max_width <= 0.0:
		return ""
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_width:
		return text
	var clipped = text
	while clipped.length() > 0:
		var candidate = clipped + "..."
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_width:
			return candidate
		clipped = clipped.substr(0, clipped.length() - 1)
	return "..."


func _grass(pos: Vector2) -> void:
	var c = Color(0.28, 0.58, 0.25, 0.55)
	draw_line(pos, pos + Vector2(-4, -10), c, 2.0, true)
	draw_line(pos + Vector2(3, 0), pos + Vector2(3, -9), c, 2.0, true)
	draw_line(pos + Vector2(6, 0), pos + Vector2(10, -10), c, 2.0, true)


func _draw_lock(center: Vector2) -> void:
	_box(Rect2(center + Vector2(-10, -1), Vector2(20, 14)), COLOR_LINE, Color(0.88, 0.91, 1.0), 2)
	draw_arc(center + Vector2(0, -1), 8, PI, TAU, 14, Color(0.88, 0.91, 1.0), 2.5)


func _hex_center(key: Vector2i) -> Vector2:
	var w = sqrt(3.0) * HEX_SIZE
	var x = board_origin.x + w * (float(key.x) + 0.5 * float(key.y % 2))
	var y = board_origin.y + HEX_SIZE * 1.5 * float(key.y)
	return Vector2(x, y)


func _hex_points(center: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * float(i) - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * HEX_SIZE)
	return points


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed = PackedVector2Array(points)
	if not points.is_empty():
		closed.append(points[0])
	return closed


func _neighbors(key: Vector2i) -> Array:
	var result = []
	var offsets = NEIGHBORS_ODD if key.y % 2 == 1 else NEIGHBORS_EVEN
	for offset in offsets:
		var next = key + offset
		if next.x >= 0 and next.x < GRID_COLS and next.y >= 0 and next.y < GRID_ROWS:
			result.append(next)
	return result


func _tile_at(pos: Vector2) -> Vector2i:
	for key in tiles.keys():
		if Geometry2D.is_point_in_polygon(pos, _hex_points(_hex_center(key))):
			return key
	return Vector2i(-99, -99)


func _deck_slot_rect(index: int) -> Rect2:
	var col = index % 4
	var row = floori(float(index) / 4.0)
	return Rect2(64 + col * 150.0, 202 + row * 142.0, 124, 132)


func _collection_index_at(pos: Vector2) -> int:
	var collection_view = _collection_view_rect()
	if not collection_view.has_point(pos):
		return -1
	var origin = Vector2(collection_view.position.x, collection_view.position.y - deck_scroll)
	for i in range(cards.size()):
		var col = i % 4
		var row = floori(float(i) / 4.0)
		var rect = Rect2(origin + Vector2(col * 156.0, row * 176.0), Vector2(132, 158))
		if rect.position.y < collection_view.position.y or rect.position.y + rect.size.y > collection_view.position.y + collection_view.size.y:
			continue
		if rect.has_point(pos):
			return i
	return -1


func _start_rect() -> Rect2:
	return Rect2(190, 958, 340, 76)


func _gacha_draw_rect() -> Rect2:
	return Rect2(104, 830, 240, 76)


func _gacha_ten_draw_rect() -> Rect2:
	return Rect2(376, 830, 240, 76)


func _upgrade_button_rect() -> Rect2:
	return Rect2(522, 602, 116, 36)


func _pause_button_rect() -> Rect2:
	return Rect2(610, 78, 62, 56)


func _pause_continue_rect() -> Rect2:
	return Rect2(184, 552, 352, 68)


func _pause_exit_rect() -> Rect2:
	return Rect2(184, 644, 352, 68)


func _nav_rect(index: int) -> Rect2:
	var w = DESIGN_SIZE.x / float(NAV_ITEMS.size())
	return Rect2(index * w + 3, 1148, w - 6, 122)


func _card_texture(card: Dictionary) -> Texture2D:
	var path = String(card.get("art_path", ""))
	if path != "":
		if texture_cache.has(path):
			return texture_cache[path]
		if ResourceLoader.exists(path):
			var texture = load(path) as Texture2D
			if texture != null:
				texture_cache[path] = texture
				return texture
	return UNIT_ART["rabbit"]


func _building_texture(building: String) -> Texture2D:
	return BUILDING_ART.get(building, BUILDING_ART["barracks"])


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return COLOR_GOLD
		"epic":
			return Color(0.67, 0.26, 0.90)
		"rare":
			return Color(0.24, 0.62, 1.0)
		_:
			return Color(0.34, 0.78, 0.38)


func _rarity_label(rarity: String) -> String:
	match rarity:
		"legendary":
			return "金色"
		"epic":
			return "紫色"
		"rare":
			return "蓝色"
		_:
			return "绿色"


func _site_name(building: String, card_id: String = "") -> String:
	match building:
		"base":
			return "基地"
		"mystery":
			return "问号地块"
		"empty":
			return "空地"
		"gold":
			return "金币"
		"barracks":
			return _unit_name(card_id) + "营地"
		"hall":
			return _unit_name(card_id) + "大厅"
		"tower":
			return "防御塔"
		"mine":
			return "金矿"
		_:
			return building


func _unit_name(card_id: String) -> String:
	var card = _card_by_id(card_id)
	if card.is_empty():
		return "动物"
	return String(card.get("name", "动物"))


func _format_time(value: float) -> String:
	var seconds = int(ceil(value))
	return "%d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]


func _toast(text: String) -> void:
	toast_text = text
	toast_timer = 1.4


func _pulse(pos: Vector2, color: Color) -> void:
	effects.append({
		"pos": pos,
		"color": color,
		"time": 0.45,
	})
