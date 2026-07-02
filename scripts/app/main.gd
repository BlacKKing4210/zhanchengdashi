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
const DECK_SIZE = 8
const BATTLE_TIME = 180.0

const PLAYER_BASE = Vector2i(3, 11)
const ENEMY_BASE = Vector2i(3, 1)

const COLOR_LINE = Color(0.07, 0.09, 0.14)
const COLOR_BLUE = Color(0.25, 0.55, 0.95)
const COLOR_PURPLE = Color(0.32, 0.22, 0.65)
const COLOR_YELLOW = Color(1.0, 0.80, 0.25)
const COLOR_ORANGE = Color(1.0, 0.54, 0.13)
const COLOR_GREEN = Color(0.49, 0.82, 0.37)
const COLOR_RED = Color(0.95, 0.34, 0.32)

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
	{"id": "gacha", "label": "抽卡", "locked": true},
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

var screen = SCREEN_LOBBY
var selected_tile = Vector2i(-99, -99)
var selected_slot = 0
var selected_card_id = ""
var deck_scroll = 0.0

var gold = 70
var enemy_gold = 70
var battle_timer = BATTLE_TIME
var income_timer = 0.0
var enemy_timer = 1.0
var game_over = false
var pause_open = false
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
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_deck(-82.0)
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_deck(82.0)
				return
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)
	elif screen == SCREEN_DECK and event is InputEventScreenDrag:
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
		"attack": attack,
		"max_hp": int(row.get("max_hp", 40 + tier * 18)),
		"move_speed": float(row.get("move_speed", 58.0 + tier * 2.0)),
		"attack_range": float(row.get("attack_range", 42.0)),
		"summon_interval_sec": float(row.get("summon_interval_sec", maxf(2.2, 4.2 - tier * 0.18))),
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


func _init_deck() -> void:
	deck.clear()
	for i in range(DECK_SIZE):
		if cards.is_empty():
			deck.append("")
		else:
			deck.append(String(cards[i % cards.size()]["id"]))
	if not deck.is_empty():
		selected_card_id = String(deck[0])


func _reset_battle() -> void:
	tiles.clear()
	units.clear()
	effects.clear()
	selected_tile = Vector2i(-99, -99)
	gold = 70
	enemy_gold = 70
	battle_timer = BATTLE_TIME
	income_timer = 0.0
	enemy_timer = 1.0
	game_over = false
	pause_open = false
	result_text = ""
	next_unit_id = 1

	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var key = Vector2i(x, y)
			var team = NEUTRAL
			if y <= 4:
				team = ENEMY
			elif y >= 10:
				team = PLAYER
			var tile = {
				"team": team,
				"building": "",
				"hp": 0.0,
				"max_hp": 0.0,
				"spawn_timer": 0.0,
				"site": "",
				"site_cost": 0,
				"site_reward": "",
				"site_card": "",
			}
			if team == NEUTRAL:
				_generate_site_once(key, tile)
			tiles[key] = tile

	_set_building(PLAYER_BASE, PLAYER, "base", "")
	_set_building(ENEMY_BASE, ENEMY, "base", "wolf")


func _generate_site_once(key: Vector2i, tile: Dictionary) -> void:
	var site_seed = absi(hash("%d:%d" % [key.x, key.y]))
	var types = ["barracks", "mine", "tower", "barracks", "mystery", "hall"]
	var costs = [45, 55, 70, 90, 120, 150]
	var site = String(types[site_seed % types.size()])
	var cost = int(costs[floori(float(site_seed) / 7.0) % costs.size()])
	tile["site"] = site
	tile["site_cost"] = cost
	tile["site_reward"] = _site_reward(site, site_seed)
	tile["site_card"] = _card_for_cost(cost)


func _site_reward(site: String, site_seed: int) -> String:
	if site != "mystery":
		return site
	var rewards = ["barracks", "mine", "tower", "hall"]
	return String(rewards[floori(float(site_seed) / 13.0) % rewards.size()])


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


func _update_battle(delta: float) -> void:
	battle_timer = maxf(0.0, battle_timer - delta)
	if battle_timer <= 0.0:
		var won = _tile_count(PLAYER) >= _tile_count(ENEMY)
		_finish_battle("胜利" if won else "失败")
		return

	income_timer -= delta
	if income_timer <= 0.0:
		income_timer = 1.0
		gold += 4 + _building_count(PLAYER, "mine") * 8
		enemy_gold += 4 + _building_count(ENEMY, "mine") * 7

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
	_set_building(best_key, ENEMY, _resolved_site(tile), "wolf")


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
		if distance < 180.0 and distance < best_distance:
			best_distance = distance
			best_index = i
	if best_index >= 0:
		units[best_index]["hp"] = float(units[best_index]["hp"]) - 20.0
		_pulse(Vector2(units[best_index]["pos"]), COLOR_YELLOW)


func _damage_tile(key: Vector2i, attacker: int, damage: float) -> void:
	if not tiles.has(key):
		return
	var tile = tiles[key]
	if int(tile["team"]) == attacker:
		return
	if String(tile["building"]) == "":
		tile["team"] = attacker
		tiles[key] = tile
		_pulse(_hex_center(key), COLOR_GREEN if attacker == PLAYER else COLOR_RED)
		return
	tile["hp"] = float(tile["hp"]) - damage
	if float(tile["hp"]) <= 0.0:
		if String(tile["building"]) == "base":
			_finish_battle("胜利" if attacker == PLAYER else "失败")
			return
		tile["team"] = attacker
		tile["building"] = ""
		tile["hp"] = 0.0
		tile["max_hp"] = 0.0
		tile["spawn_timer"] = 0.0
		_pulse(_hex_center(key), COLOR_GREEN if attacker == PLAYER else COLOR_RED)
	tiles[key] = tile


func _spawn_unit(team: int, key: Vector2i, card_id: String) -> void:
	if card_id == "":
		card_id = "wolf" if team == ENEMY else String(deck[0])
	var card = _card_by_id(card_id)
	if card.is_empty():
		card = _card_by_id("wolf" if team == ENEMY else "rabbit")
	var tier = int(card.get("tier", 1))
	units.append({
		"id": next_unit_id,
		"team": team,
		"card": String(card.get("id", card_id)),
		"pos": _hex_center(key),
		"hp": float(card.get("max_hp", 45 + tier * 16)),
		"max_hp": float(card.get("max_hp", 45 + tier * 16)),
		"attack": float(card.get("attack", 6 + tier * 2)),
		"speed": float(card.get("move_speed", 62.0)),
		"range": float(card.get("attack_range", 42.0)),
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
		_toast("金币不足")
		return true
	gold -= cost
	var building = _resolved_site(tile)
	_set_building(key, PLAYER, building, String(tile.get("site_card", "")))
	_toast("已解锁 " + _site_name(building, String(tile.get("site_card", ""))))
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


func _card_for_cost(cost: int) -> String:
	if deck.is_empty():
		return ""
	var min_tier = 1
	var max_tier = 2
	if cost >= 140:
		min_tier = 5
		max_tier = 6
	elif cost >= 100:
		min_tier = 4
		max_tier = 5
	elif cost >= 70:
		min_tier = 2
		max_tier = 4
	var options = []
	for card_id in deck:
		var card = _card_by_id(String(card_id))
		var tier = int(card.get("tier", 1))
		if tier >= min_tier and tier <= max_tier:
			options.append(String(card_id))
	if options.is_empty():
		return String(deck[0])
	return String(options[cost % options.size()])


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
			return 420.0
		"hall":
			return 180.0
		"tower":
			return 150.0
		"mine":
			return 120.0
		"barracks":
			return 130.0
		_:
			return 100.0


func _building_delay(building: String, team: int, card_id: String) -> float:
	if building == "barracks" or building == "hall":
		var card = _card_by_id(card_id)
		if not card.is_empty():
			return float(card.get("summon_interval_sec", 3.5))
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


func _handle_deck_tap(pos: Vector2) -> void:
	for i in range(DECK_SIZE):
		if _deck_slot_rect(i).has_point(pos):
			selected_slot = i
			selected_card_id = String(deck[i])
			return
	var card_index = _collection_index_at(pos)
	if card_index < 0 or card_index >= cards.size():
		return
	var card = cards[card_index]
	if selected_slot >= 0 and selected_slot < deck.size():
		deck[selected_slot] = String(card["id"])
		selected_card_id = String(card["id"])
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
		elif id == SCREEN_LOBBY:
			screen = SCREEN_LOBBY
		return true
	return false


func _scroll_deck(amount: float) -> void:
	var rows = ceili(float(cards.size()) / 4.0)
	deck_scroll = clampf(deck_scroll + amount, 0.0, maxf(0.0, rows * 176.0 - 500.0))


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
	_draw_text_center("当前版本默认开放所有卡牌", Rect2(90, 720, 540, 40), 25, COLOR_LINE)
	_cta(_start_rect(), "开始战斗", true)


func _draw_deck_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_text_center("出战编组", Rect2(40, 68, 640, 58), 42, Color.WHITE)
	_box(Rect2(34, 140, 652, 360), COLOR_PURPLE, COLOR_LINE, 5)
	for i in range(DECK_SIZE):
		_draw_card(_deck_slot_rect(i), _card_by_id(String(deck[i])), i == selected_slot)
	_draw_card_detail(Rect2(34, 520, 652, 128))
	_draw_text_center("所有卡牌", Rect2(0, 670, DESIGN_SIZE.x, 42), 34, Color.WHITE)
	var origin = Vector2(54, 728 - deck_scroll)
	for i in range(cards.size()):
		var col = i % 4
		var row = floori(float(i) / 4.0)
		var rect = Rect2(origin + Vector2(col * 156.0, row * 176.0), Vector2(132, 158))
		if rect.position.y + rect.size.y < 700 or rect.position.y > 1115:
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
	_resource(Rect2(32, 18, 178, 44), "金币", str(gold), COLOR_YELLOW)
	_resource(Rect2(270, 18, 180, 44), "时间", _format_time(battle_timer), Color.WHITE)
	_resource(Rect2(510, 18, 178, 44), "敌方", str(enemy_gold), COLOR_RED)


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
		draw_texture_rect(BUILDING_ART["tower"], Rect2(c + Vector2(-32, -34), Vector2(64, 70)), false)
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
	var fill = Color(0.76, 0.78, 0.54)
	if team == PLAYER:
		fill = Color(0.49, 0.80, 0.39)
	elif team == ENEMY:
		fill = Color(0.95, 0.43, 0.39)
	draw_polygon(points, PackedColorArray([fill, fill, fill, fill, fill, fill]))
	draw_polyline(_closed_points(points), fill.darkened(0.34), 3.0)
	if String(tile["building"]) != "":
		_draw_building(center, tile)
	elif String(tile["site"]) != "" and _can_unlock(key, PLAYER):
		_draw_site(center, tile)


func _draw_site(center: Vector2, tile: Dictionary) -> void:
	var building = _resolved_site(tile)
	draw_texture_rect(_building_texture(building), Rect2(center + Vector2(-27, -36), Vector2(54, 54)), false)
	var price_rect = Rect2(center + Vector2(-38, 22), Vector2(76, 26))
	_box(price_rect, Color(1, 1, 1, 0.85), COLOR_LINE, 2)
	draw_circle(price_rect.position + Vector2(14, 13), 7, COLOR_YELLOW)
	_draw_text_right(str(int(tile["site_cost"])), Rect2(price_rect.position + Vector2(24, 0), Vector2(46, 26)), 18, COLOR_LINE)


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
	_box(Rect2(center + Vector2(-32, 30), Vector2(64, 8)), COLOR_LINE, Color.TRANSPARENT, 0)
	_box(Rect2(center + Vector2(-31, 31), Vector2(62.0 * pct, 6)), COLOR_GREEN, Color.TRANSPARENT, 0)


func _draw_unit(unit: Dictionary) -> void:
	var pos = Vector2(unit["pos"])
	var team = int(unit["team"])
	draw_circle(pos + Vector2(0, 14), 17, Color(0, 0, 0, 0.18))
	draw_texture_rect(_card_texture(_card_by_id(String(unit["card"]))), Rect2(pos + Vector2(-22, -30), Vector2(44, 44)), false)
	draw_circle(pos + Vector2(0, -30), 7, Color(0.65, 0.86, 1.0) if team == PLAYER else Color(1.0, 0.60, 0.56))
	var pct = clampf(float(unit["hp"]) / float(unit["max_hp"]), 0.0, 1.0)
	_box(Rect2(pos + Vector2(-18, 20), Vector2(36, 6)), COLOR_LINE, Color.TRANSPARENT, 0)
	_box(Rect2(pos + Vector2(-17, 21), Vector2(34.0 * pct, 4)), COLOR_GREEN, Color.TRANSPARENT, 0)


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
		elif _can_unlock(selected_tile, PLAYER):
			title = "可解锁：%s  价格 %d" % [_site_name(_resolved_site(tile), String(tile.get("site_card", ""))), int(tile["site_cost"])]
			detail = "类型和价格已在开局生成并固定。"
		else:
			title = "未连接地块"
			detail = "先占领或购买相邻地块。"
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
	_draw_text_center(result_text, Rect2(panel.position + Vector2(0, 60), Vector2(panel.size.x, 68)), 52, COLOR_YELLOW if result_text == "胜利" else COLOR_RED)
	_draw_text_center("点击任意位置返回主界面", Rect2(panel.position + Vector2(0, 166), Vector2(panel.size.x, 40)), 24, COLOR_LINE)


func _draw_card(rect: Rect2, card: Dictionary, selected: bool) -> void:
	var fill = _rarity_color(String(card.get("rarity", "common")))
	_box(rect, fill.darkened(0.06), COLOR_LINE, 4)
	if selected:
		_box(rect.grow(5), Color(1.0, 0.91, 0.22, 0.28), COLOR_YELLOW, 4)
	draw_texture_rect(_card_texture(card), Rect2(rect.position + Vector2(14, 16), Vector2(rect.size.x - 28, rect.size.x - 26)), false)
	_draw_text_center(String(card.get("name", "")), Rect2(rect.position + Vector2(8, rect.size.y - 52), Vector2(rect.size.x - 16, 26)), 17, Color.WHITE)
	var stat_rect = Rect2(rect.position + Vector2(10, rect.size.y - 28), Vector2(rect.size.x - 20, 22))
	_box(stat_rect, Color(0, 0, 0, 0.30), Color(1, 1, 1, 0.18), 1)
	_draw_text_center("攻%d 血%d" % [int(card.get("attack", 0)), int(card.get("max_hp", 0))], stat_rect, 15, Color.WHITE)


func _draw_card_detail(rect: Rect2) -> void:
	var card = _card_by_id(selected_card_id)
	_box(rect, Color(1, 1, 1, 0.92), COLOR_LINE, 3)
	if card.is_empty():
		return
	draw_texture_rect(_card_texture(card), Rect2(rect.position + Vector2(14, 16), Vector2(92, 92)), false)
	_draw_text_fit(String(card.get("name", "")), Rect2(rect.position + Vector2(118, 14), Vector2(180, 32)), 24, COLOR_LINE)
	_draw_text_fit(_rarity_label(String(card.get("rarity", ""))), Rect2(rect.position + Vector2(310, 14), Vector2(120, 32)), 20, _rarity_color(String(card.get("rarity", ""))).darkened(0.30))
	var stats = "攻击 %d  生命 %d  移速 %.0f  距离 %.0f  召唤 %.1fs" % [
		int(card.get("attack", 0)),
		int(card.get("max_hp", 0)),
		float(card.get("move_speed", 0.0)),
		float(card.get("attack_range", 0.0)),
		float(card.get("summon_interval_sec", 0.0)),
	]
	_draw_text_fit(stats, Rect2(rect.position + Vector2(118, 50), Vector2(500, 28)), 18, COLOR_LINE)
	var skill = String(card.get("skill_text", ""))
	if skill == "":
		skill = "无技能：基础属性更高。"
	_draw_text_fit(skill, Rect2(rect.position + Vector2(118, 82), Vector2(500, 28)), 17, Color(0.20, 0.22, 0.30))


func _draw_toast() -> void:
	if toast_timer <= 0.0:
		return
	var alpha = clampf(toast_timer / 1.4, 0.0, 1.0)
	var rect = Rect2(130, 1018, 460, 58)
	_box(rect, Color(0.05, 0.06, 0.10, 0.82 * alpha), Color(1, 1, 1, 0.18 * alpha), 2)
	_draw_text_center(toast_text, rect, 23, Color(1, 1, 1, alpha))


func _resource(rect: Rect2, label: String, value: String, color: Color) -> void:
	_box(rect, Color(1, 1, 1, 0.92), COLOR_LINE, 3)
	draw_circle(rect.position + Vector2(24, rect.size.y * 0.5), 13, color)
	_draw_text_fit(label, Rect2(rect.position + Vector2(45, 0), Vector2(58, rect.size.y)), 17, COLOR_LINE)
	_draw_text_right(value, Rect2(rect.position + Vector2(94, 0), Vector2(rect.size.x - 108, rect.size.y)), 22, COLOR_LINE)


func _cta(rect: Rect2, label: String, primary: bool) -> void:
	_box(rect, COLOR_ORANGE if primary else Color(0.46, 0.50, 0.62), COLOR_LINE, 5)
	_draw_text_center(label, rect, 30, Color.WHITE)


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
	var origin = Vector2(54, 728 - deck_scroll)
	for i in range(cards.size()):
		var col = i % 4
		var row = floori(float(i) / 4.0)
		var rect = Rect2(origin + Vector2(col * 156.0, row * 176.0), Vector2(132, 158))
		if rect.has_point(pos):
			return i
	return -1


func _start_rect() -> Rect2:
	return Rect2(190, 958, 340, 76)


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
			return Color(1.0, 0.64, 0.12)
		"epic":
			return Color(0.67, 0.26, 0.90)
		"rare":
			return Color(0.24, 0.62, 1.0)
		_:
			return Color(0.34, 0.78, 0.38)


func _rarity_label(rarity: String) -> String:
	match rarity:
		"legendary":
			return "传说"
		"epic":
			return "史诗"
		"rare":
			return "稀有"
		_:
			return "普通"


func _site_name(building: String, card_id: String = "") -> String:
	match building:
		"base":
			return "基地"
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
