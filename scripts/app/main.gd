extends Node2D

const CardRules = preload("res://scripts/app/systems/card_rules.gd")
const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const RankingRules = preload("res://scripts/app/systems/ranking_rules.gd")

const DESIGN_SIZE = Vector2(720.0, 1280.0)
const HEX_SIZE = 43.0
const GRID_COLS = BoardRules.GRID_COLS
const GRID_ROWS = BoardRules.GRID_ROWS
const PLAYER = BoardRules.PLAYER
const ENEMY = BoardRules.ENEMY
const NEUTRAL = BoardRules.NEUTRAL

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
const TOWER_DAMAGE = 44.0
const TOWER_RANGE = 150.0
const STARTING_GACHA_TICKETS = 10
const BATTLE_WIN_REWARD_TICKETS = 3
const BATTLE_LOSS_REWARD_TICKETS = 1
const RANK_DB_PATH = "user://rank_mirror_db.json"
const MIRROR_LIMIT_PER_RANK = 20
const ENEMY_FIRST_UNLOCK_DELAY = 4.0
const ENEMY_UNLOCK_INTERVAL = 2.2
const PROJECTILE_TIME = 0.30
const RANGED_PROJECTILE_MIN_DISTANCE = HEX_SIZE * 1.35

const UNIT_LOW_PRICE = BoardRules.UNIT_LOW_PRICE
const UNIT_MID_PRICE = BoardRules.UNIT_MID_PRICE
const UNIT_HIGH_PRICE = BoardRules.UNIT_HIGH_PRICE

const PLAYER_BASE = BoardRules.PLAYER_BASE
const ENEMY_BASE = BoardRules.ENEMY_BASE

const COLOR_LINE = Color(0.07, 0.09, 0.14)
const COLOR_BLUE = Color(0.25, 0.55, 0.95)
const COLOR_PURPLE = Color(0.32, 0.22, 0.65)
const COLOR_YELLOW = Color(1.0, 0.80, 0.25)
const COLOR_ORANGE = Color(1.0, 0.54, 0.13)
const COLOR_GREEN = Color(0.49, 0.82, 0.37)
const COLOR_RED = Color(0.95, 0.34, 0.32)
const COLOR_GOLD = Color(1.0, 0.62, 0.08)

const COLLECTION_COLUMNS = 4
const COLLECTION_CARD_SIZE = Vector2(132.0, 158.0)
const COLLECTION_CARD_GAP = Vector2(24.0, 18.0)
const DETAIL_PULSE_SECONDS = 0.28
const GACHA_FX_SECONDS = 0.72
const GACHA_CARD_REVEAL_INTERVAL = 0.18
const GACHA_CARD_FLIP_SECONDS = 0.34

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

var tiles = {}
var units = []
var effects = []
var cards = []
var deck = []
var enemy_deck = []
var enemy_card_levels = {}

var card_counts = {}
var card_levels = {}
var gacha_tickets = STARTING_GACHA_TICKETS
var last_gacha_cards = []
var gacha_pending_cards = []
var gacha_card_flip_timers = []
var gacha_fx_timer = 0.0
var gacha_reveal_timer = 0.0
var rank_db = {}
var active_match_mirror = {}
var active_match_rank_key = ""
var active_match_player_elo = RankingRules.INITIAL_ELO
var last_rank_result = {}

var screen = SCREEN_LOBBY
var selected_tile = Vector2i(-99, -99)
var selected_slot = 0
var selected_card_id = ""
var pending_equip_card_id = ""
var deck_scroll = 0.0

var gold = STARTING_GOLD
var enemy_gold = STARTING_GOLD
var battle_timer = BATTLE_TIME
var income_timer = INCOME_INTERVAL
var enemy_timer = 1.0
var game_over = false
var pause_open = false
var battle_reward_given = false
var last_battle_reward_tickets = 0
var result_text = ""
var toast_text = ""
var toast_timer = 0.0
var detail_pulse_timer = 0.0
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
	_init_enemy_deck()
	_load_rank_database()
	_reset_battle()


func _process(delta: float) -> void:
	ui_time += delta
	if toast_timer > 0.0:
		toast_timer -= delta
	if detail_pulse_timer > 0.0:
		detail_pulse_timer = maxf(0.0, detail_pulse_timer - delta)
	_update_gacha_animation(delta)

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
	elif screen == SCREEN_DECK and event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
			_start_match()
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
	return CardRules.card_from_row(row)


func _rarity_for_tier(tier: int) -> String:
	return CardRules.rarity_for_tier(tier)


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


func _init_enemy_deck() -> void:
	enemy_deck.clear()
	enemy_card_levels.clear()
	var common_cards = []
	for card in cards:
		if String(card.get("rarity", "common")) == "common":
			common_cards.append(String(card.get("id", "")))
	for i in range(DECK_SIZE):
		if common_cards.is_empty():
			enemy_deck.append("rabbit")
		else:
			enemy_deck.append(String(common_cards[i % common_cards.size()]))
	for card_id in enemy_deck:
		enemy_card_levels[String(card_id)] = 1


func _load_rank_database() -> void:
	rank_db = {}
	if FileAccess.file_exists(RANK_DB_PATH):
		var file = FileAccess.open(RANK_DB_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				rank_db = parsed
	_ensure_rank_database_shape()
	_save_rank_database()


func _ensure_rank_database_shape() -> void:
	if typeof(rank_db) != TYPE_DICTIONARY:
		rank_db = {}
	if not rank_db.has("version"):
		rank_db["version"] = RankingRules.DB_VERSION
	if not rank_db.has("player") or typeof(rank_db["player"]) != TYPE_DICTIONARY:
		rank_db["player"] = RankingRules.default_profile()
	if not rank_db.has("mirrors") or typeof(rank_db["mirrors"]) != TYPE_DICTIONARY:
		rank_db["mirrors"] = {}


func _save_rank_database() -> void:
	_ensure_rank_database_shape()
	var file = FileAccess.open(RANK_DB_PATH, FileAccess.WRITE)
	if file == null:
		_toast("段位数据保存失败")
		return
	file.store_string(JSON.stringify(rank_db, "\t"))


func _player_profile() -> Dictionary:
	_ensure_rank_database_shape()
	return rank_db["player"]


func _player_elo() -> int:
	return int(_player_profile().get("elo", RankingRules.INITIAL_ELO))


func _current_rank_key() -> String:
	return RankingRules.rank_key_for_elo(_player_elo())


func _mirror_count_for_rank(rank_key: String) -> int:
	_ensure_rank_database_shape()
	var mirrors = rank_db["mirrors"]
	if mirrors.has(rank_key) and typeof(mirrors[rank_key]) == TYPE_ARRAY:
		return mirrors[rank_key].size()
	return 0


func _start_match() -> void:
	active_match_player_elo = _player_elo()
	active_match_rank_key = RankingRules.rank_key_for_elo(active_match_player_elo)
	active_match_mirror = _select_match_mirror(active_match_rank_key)
	_apply_match_mirror(active_match_mirror)
	last_rank_result = {}
	screen = SCREEN_BATTLE
	_reset_battle()
	_toast("匹配到" + String(active_match_mirror.get("rank_display", RankingRules.display_for_elo(active_match_player_elo))) + "对手")


func _select_match_mirror(rank_key: String) -> Dictionary:
	_ensure_rank_database_shape()
	var mirrors = rank_db["mirrors"]
	var pool = []
	var other_player_pool = []
	var current_player_id = String(_player_profile().get("player_id", "local_player"))
	if mirrors.has(rank_key) and typeof(mirrors[rank_key]) == TYPE_ARRAY:
		for mirror in mirrors[rank_key]:
			if typeof(mirror) == TYPE_DICTIONARY:
				pool.append(mirror)
				if String(mirror.get("player_id", "")) != current_player_id:
					other_player_pool.append(mirror)
	if not other_player_pool.is_empty():
		return other_player_pool[randi() % other_player_pool.size()].duplicate(true)
	if not pool.is_empty():
		return pool[randi() % pool.size()].duplicate(true)
	return _generated_match_mirror(rank_key)


func _generated_match_mirror(rank_key: String) -> Dictionary:
	var rank = RankingRules.rank_for_key(rank_key)
	var generated_deck = enemy_deck.duplicate()
	if generated_deck.is_empty():
		generated_deck = ["rabbit"]
	var levels = {}
	for card_id in generated_deck:
		levels[String(card_id)] = 1
	return {
		"mirror_id": "generated_%s" % rank_key,
		"player_id": "generated",
		"name": String(rank["name"]) + "镜像",
		"rank_key": rank_key,
		"rank_display": RankingRules.display_for_elo(int(rank["min_elo"])),
		"elo": int(rank["min_elo"]),
		"deck": generated_deck,
		"card_levels": levels,
		"created_at_unix": 0,
	}


func _apply_match_mirror(mirror: Dictionary) -> void:
	enemy_deck.clear()
	enemy_card_levels.clear()
	var mirror_deck = mirror.get("deck", [])
	if typeof(mirror_deck) != TYPE_ARRAY or mirror_deck.is_empty():
		_init_enemy_deck()
		return
	for i in range(DECK_SIZE):
		enemy_deck.append(String(mirror_deck[i % mirror_deck.size()]))
	var levels = mirror.get("card_levels", {})
	for card_id in enemy_deck:
		enemy_card_levels[String(card_id)] = max(1, int(levels.get(String(card_id), 1))) if typeof(levels) == TYPE_DICTIONARY else 1


func _owned_card_ids() -> Array:
	var owned = []
	for card in _collection_cards():
		var id = String(card["id"])
		if int(card_counts.get(id, 0)) > 0:
			owned.append(id)
	return owned


func _collection_cards() -> Array:
	var sorted = cards.duplicate()
	sorted.sort_custom(Callable(self, "_is_collection_card_before"))
	return sorted


func _available_collection_cards() -> Array:
	var used = {}
	for card_id in deck:
		var id = String(card_id)
		if id != "":
			used[id] = true
	var available = []
	for card in _collection_cards():
		if not used.has(String(card.get("id", ""))):
			available.append(card)
	return available


func _is_card_in_deck(card_id: String) -> bool:
	for deck_card_id in deck:
		if String(deck_card_id) == card_id:
			return true
	return false


func _is_collection_card_before(a, b) -> bool:
	var a_id = String(a.get("id", ""))
	var b_id = String(b.get("id", ""))
	var a_owned = _card_total_count(a_id) > 0
	var b_owned = _card_total_count(b_id) > 0
	if a_owned != b_owned:
		return a_owned
	var a_rarity = _rarity_sort_rank(String(a.get("rarity", "common")))
	var b_rarity = _rarity_sort_rank(String(b.get("rarity", "common")))
	if a_rarity != b_rarity:
		return a_rarity > b_rarity
	var a_tier = int(a.get("tier", 0))
	var b_tier = int(b.get("tier", 0))
	if a_tier != b_tier:
		return a_tier > b_tier
	return a_id < b_id


func _card_level(card_id: String) -> int:
	return CardRules.card_level(card_levels, card_id)


func _card_level_for_team(card_id: String, team: int) -> int:
	if team == ENEMY:
		return CardRules.card_level(enemy_card_levels, card_id)
	return _card_level(card_id)


func _card_total_count(card_id: String) -> int:
	return CardRules.card_total_count(card_counts, card_id)


func _card_spare_count(card_id: String) -> int:
	return CardRules.card_spare_count(card_counts, card_id)


func _next_upgrade_cost(card_id: String) -> int:
	return CardRules.next_upgrade_cost(card_levels, card_id)


func _card_multiplier(card_id: String) -> float:
	return CardRules.card_multiplier(card_levels, card_id)


func _card_stats(card: Dictionary) -> Dictionary:
	return CardRules.card_stats(card, card_levels)


func _card_stats_for_team(card: Dictionary, team: int) -> Dictionary:
	if team == ENEMY:
		return CardRules.card_stats(card, enemy_card_levels)
	return _card_stats(card)


func _card_skill_text(card: Dictionary) -> String:
	var skill_text = String(card.get("skill_text", ""))
	return skill_text if skill_text != "" else "无技能"


func _attack_range_label(value: float) -> String:
	return CardRules.attack_range_label(value, HEX_SIZE)


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
	enemy_timer = ENEMY_FIRST_UNLOCK_DELAY
	game_over = false
	pause_open = false
	battle_reward_given = false
	last_battle_reward_tickets = 0
	result_text = ""
	next_unit_id = 1

	tiles = BoardRules.create_initial_tiles(Callable(self, "_card_for_cost"), Callable(self, "_card_for_tier_range"))

	_set_building(PLAYER_BASE, PLAYER, "base", "")
	_set_building(ENEMY_BASE, ENEMY, "base", "")


func _set_building(key: Vector2i, team: int, building: String, card_id: String) -> void:
	if not tiles.has(key):
		return
	var tile = tiles[key]
	var spawn_card_id = card_id if card_id != "" else String(tile.get("site_card", ""))
	tiles[key] = BoardRules.with_building(
		tile,
		team,
		building,
		card_id,
		_building_hp(building, spawn_card_id, team),
		_building_delay(building, team, spawn_card_id)
	)


func _set_empty_tile(key: Vector2i, team: int) -> void:
	if not tiles.has(key):
		return
	tiles[key] = BoardRules.as_unlocked_empty(tiles[key], team)


func _mark_occupied_tile(key: Vector2i, team: int) -> void:
	if not tiles.has(key):
		return
	tiles[key] = BoardRules.with_occupier(tiles[key], team)


func _apply_unlock(key: Vector2i, team: int, fallback_card_id: String) -> String:
	if not tiles.has(key):
		return ""
	var tile = tiles[key]
	var unlock_roll = BoardRules.roll_unlock_result(tile)
	var result = String(unlock_roll.get("result", String(tile.get("site", ""))))
	tile = BoardRules.with_unlock_roll(
		tile,
		result,
		String(unlock_roll.get("target_rarity", "")),
		int(unlock_roll.get("roll_seed", 0))
	)
	tiles[key] = tile
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
			var site_card_id = ""
			if result == "barracks" or result == "hall":
				site_card_id = _site_card_for_team(key, tile, team, card_id)
				if site_card_id == "":
					_set_empty_tile(key, team)
					return "空地"
			_set_building(key, team, result, site_card_id)
			return _site_name(result, site_card_id)


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
			if building == "tower" or building == "base":
				_tower_attack(key, team)
			else:
				_spawn_unit(team, key, _spawn_card_for_tile(tile, team))
		tiles[key] = tile


func _update_enemy(delta: float) -> void:
	enemy_timer -= delta
	if enemy_timer > 0.0:
		return
	enemy_timer = ENEMY_UNLOCK_INTERVAL
	var best_key = Vector2i(-99, -99)
	var best_y = -999
	for key in tiles.keys():
		if _can_unlock(key, ENEMY) and int(tiles[key]["site_cost"]) <= enemy_gold and key.y > best_y:
			best_y = key.y
			best_key = key
	if best_key.x == -99:
		return
	var tile = tiles[best_key]
	var cost = int(tile["site_cost"])
	if enemy_gold < cost:
		return
	enemy_gold -= cost
	_apply_unlock(best_key, ENEMY, _enemy_deck_card(0))


func _update_units(delta: float) -> void:
	for i in range(units.size()):
		var unit = units[i]
		if float(unit["hp"]) <= 0.0:
			continue
		var target = _nearest_combat_target(Vector2(unit["pos"]), int(unit["team"]), int(unit["id"]))
		if target.is_empty():
			units[i] = unit
			continue
		var target_pos = Vector2(target["pos"])
		var offset = target_pos - Vector2(unit["pos"])
		var distance = offset.length()
		unit["cooldown"] = maxf(0.0, float(unit.get("cooldown", 0.0)) - delta)
		if distance <= float(unit["range"]):
			if float(unit["cooldown"]) <= 0.0:
				if distance >= RANGED_PROJECTILE_MIN_DISTANCE:
					_projectile(Vector2(unit["pos"]), target_pos, int(unit["team"]))
				if String(target["kind"]) == "unit":
					_damage_unit(int(target["index"]), float(unit["attack"]))
				elif String(target["kind"]) == "building":
					var target_key: Vector2i = target["key"]
					_damage_tile(target_key, int(unit["team"]), float(unit["attack"]))
				unit["cooldown"] = 0.85
		elif distance > 1.0:
			unit["pos"] = Vector2(unit["pos"]) + offset.normalized() * float(unit["speed"]) * delta
		units[i] = unit
	var alive = []
	for unit in units:
		if float(unit["hp"]) > 0.0:
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
		if int(units[i]["team"]) == team or float(units[i]["hp"]) <= 0.0:
			continue
		var distance = center.distance_to(Vector2(units[i]["pos"]))
		if distance < TOWER_RANGE and distance < best_distance:
			best_distance = distance
			best_index = i
	if best_index >= 0:
		_projectile(center, Vector2(units[best_index]["pos"]), team)
		_damage_unit(best_index, TOWER_DAMAGE)


func _damage_unit(index: int, damage: float) -> void:
	if index < 0 or index >= units.size():
		return
	units[index]["hp"] = float(units[index]["hp"]) - damage
	_pulse(Vector2(units[index]["pos"]), COLOR_YELLOW)


func _damage_tile(key: Vector2i, attacker: int, damage: float) -> void:
	if not tiles.has(key):
		return
	var tile = tiles[key]
	if int(tile["team"]) == attacker:
		return
	if String(tile["building"]) == "":
		return
	tile["hp"] = float(tile["hp"]) - damage
	if float(tile["hp"]) <= 0.0:
		if String(tile["building"]) == "base":
			_finish_battle("胜利" if attacker == PLAYER else "失败")
			return
		tiles[key] = BoardRules.as_destroyed_building(tile, attacker)
		_pulse(_hex_center(key), COLOR_GREEN if attacker == PLAYER else COLOR_RED)
		return
	tiles[key] = tile


func _spawn_unit(team: int, key: Vector2i, card_id: String) -> void:
	if card_id == "":
		card_id = _enemy_deck_card(0) if team == ENEMY else String(deck[0])
	var card = _card_by_id(card_id)
	if card.is_empty():
		card = _card_by_id(_enemy_deck_card(0) if team == ENEMY else "rabbit")
	var stats = _card_stats_for_team(card, team)
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


func _nearest_combat_target(pos: Vector2, team: int, self_id: int) -> Dictionary:
	var best = {}
	var best_score = 999999.0
	for i in range(units.size()):
		var unit = units[i]
		if int(unit["id"]) == self_id or int(unit["team"]) == team or float(unit["hp"]) <= 0.0:
			continue
		var unit_pos = Vector2(unit["pos"])
		var score = pos.distance_to(unit_pos) - 80.0
		if score < best_score:
			best_score = score
			best = {
				"kind": "unit",
				"index": i,
				"pos": unit_pos,
			}
	for key in tiles.keys():
		var tile = tiles[key]
		if int(tile["team"]) == team or String(tile["building"]) == "":
			continue
		var score = pos.distance_to(_hex_center(key))
		if String(tile["building"]) == "base":
			score -= 120.0
		else:
			score -= 60.0
		if score < best_score:
			best_score = score
			best = {
				"kind": "building",
				"key": key,
				"pos": _hex_center(key),
			}
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
	return BoardRules.can_unlock(tiles, key, team)


func _resolved_site(tile: Dictionary) -> String:
	return BoardRules.resolved_site(tile)


func _spawn_card_for_tile(tile: Dictionary, team: int) -> String:
	var card_id = String(tile.get("site_card", ""))
	if card_id != "":
		return card_id
	if team == ENEMY:
		return _enemy_deck_card(0)
	return String(deck[0])


func _site_card_for_team(key: Vector2i, tile: Dictionary, team: int, fallback_card_id: String) -> String:
	var site = _resolved_site(tile)
	if site != "barracks" and site != "hall":
		return fallback_card_id
	var site_seed = int(tile.get("site_roll_seed", BoardRules.site_seed_for_key(key)))
	var target_rarity = String(tile.get("site_target_rarity", ""))
	if target_rarity == "":
		target_rarity = BoardRules.target_rarity_for_price(int(tile.get("site_cost", UNIT_LOW_PRICE)), site_seed)
	var roster = enemy_deck if team == ENEMY else deck
	return _deck_card_for_target_rarity(roster, target_rarity, site_seed)


func _enemy_card_for_cost(cost: int, site_seed: int) -> String:
	return _deck_card_for_target_rarity(enemy_deck, BoardRules.target_rarity_for_price(cost, site_seed), site_seed)


func _enemy_deck_card(index: int) -> String:
	if enemy_deck.is_empty():
		return "rabbit"
	return String(enemy_deck[index % enemy_deck.size()])


func _card_for_cost(cost: int, site_seed: int = 0) -> String:
	return _deck_card_for_target_rarity(deck, BoardRules.target_rarity_for_price(cost, site_seed), site_seed)


func _card_for_tier_range(min_tier: int, max_tier: int, site_seed: int) -> String:
	return _deck_card_for_target_rarity(deck, _rarity_for_tier(max_tier), site_seed + min_tier * 17 + max_tier * 31)


func _deck_card_for_target_rarity(roster: Array, target_rarity: String, site_seed: int) -> String:
	var target_rank = _rarity_sort_rank(target_rarity)
	for rank in range(target_rank, 0, -1):
		var rarity = _rarity_for_rank(rank)
		var options = []
		for card_id in roster:
			var id = String(card_id)
			if id == "":
				continue
			var card = _card_by_id(id)
			if not card.is_empty() and String(card.get("rarity", "common")) == rarity:
				options.append(id)
		if not options.is_empty():
			var pick_seed = absi(site_seed + rank * 97 + roster.size() * 13)
			return String(options[pick_seed % options.size()])
	return ""


func _rarity_for_rank(rank: int) -> String:
	match rank:
		4:
			return "legendary"
		3:
			return "epic"
		2:
			return "rare"
		_:
			return "common"


func _card_by_id(card_id: String) -> Dictionary:
	for card in cards:
		if String(card.get("id", "")) == card_id:
			return card
	return {}


func _tile_count(team: int) -> int:
	return BoardRules.tile_count(tiles, team)


func _building_count(team: int, building: String) -> int:
	return BoardRules.building_count(tiles, team, building)


func _building_hp(building: String, card_id: String = "", team: int = PLAYER) -> float:
	if building == "barracks" or building == "hall":
		var card = _card_by_id(card_id)
		if not card.is_empty():
			return float(_card_stats_for_team(card, team)["max_hp"]) * 3.0
	return BoardRules.building_hp(building)


func _building_delay(building: String, team: int, card_id: String) -> float:
	var card_interval = -1.0
	if building == "barracks" or building == "hall":
		var card = _card_by_id(card_id)
		if not card.is_empty():
			card_interval = float(_card_stats_for_team(card, team)["summon_interval_sec"])
	return BoardRules.building_delay(building, team, card_interval)


func _battle_reward_tickets(text: String) -> int:
	return BATTLE_WIN_REWARD_TICKETS if text == "胜利" else BATTLE_LOSS_REWARD_TICKETS


func _finish_battle(text: String) -> void:
	if game_over:
		return
	result_text = text
	game_over = true
	pause_open = false
	_apply_rank_result(text == "胜利")
	if not battle_reward_given:
		battle_reward_given = true
		last_battle_reward_tickets = _battle_reward_tickets(text)
		gacha_tickets += last_battle_reward_tickets
		_toast("获得%d张抽卡券" % last_battle_reward_tickets)


func _apply_rank_result(won: bool) -> void:
	var profile = _player_profile()
	var player_elo = int(profile.get("elo", RankingRules.INITIAL_ELO))
	if active_match_rank_key == "":
		active_match_player_elo = player_elo
		active_match_rank_key = RankingRules.rank_key_for_elo(player_elo)
	if active_match_mirror.is_empty():
		active_match_mirror = _generated_match_mirror(active_match_rank_key)
	var opponent_elo = int(active_match_mirror.get("elo", player_elo))
	var result = RankingRules.elo_result(player_elo, opponent_elo, won)
	profile["elo"] = int(result["new_elo"])
	profile["matches"] = int(profile.get("matches", 0)) + 1
	if won:
		profile["wins"] = int(profile.get("wins", 0)) + 1
	else:
		profile["losses"] = int(profile.get("losses", 0)) + 1
	rank_db["player"] = profile
	last_rank_result = result
	if won:
		_record_victory_mirror(active_match_rank_key, active_match_player_elo)
	_save_rank_database()


func _record_victory_mirror(rank_key: String, match_elo: int) -> void:
	_ensure_rank_database_shape()
	var mirrors = rank_db["mirrors"]
	if not mirrors.has(rank_key) or typeof(mirrors[rank_key]) != TYPE_ARRAY:
		mirrors[rank_key] = []
	var rank_state = RankingRules.rank_state_for_elo(match_elo)
	var profile = _player_profile()
	var now = int(Time.get_unix_time_from_system())
	var mirror = {
		"mirror_id": "local_%d_%d" % [now, randi()],
		"player_id": String(profile.get("player_id", "local_player")),
		"name": String(profile.get("name", "玩家")) + "镜像",
		"rank_key": rank_key,
		"rank_display": String(rank_state["display"]),
		"elo": match_elo,
		"deck": _snapshot_deck(),
		"card_levels": _snapshot_card_levels(),
		"created_at_unix": now,
	}
	mirrors[rank_key].append(mirror)
	while mirrors[rank_key].size() > MIRROR_LIMIT_PER_RANK:
		mirrors[rank_key].remove_at(0)
	rank_db["mirrors"] = mirrors


func _snapshot_deck() -> Array:
	var result = []
	for card_id in deck:
		var id = String(card_id)
		if id != "":
			result.append(id)
	return result


func _snapshot_card_levels() -> Dictionary:
	var result = {}
	for card_id in deck:
		var id = String(card_id)
		if id != "":
			result[id] = _card_level(id)
	return result


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
	return CardRules.roll_rarity(randf() * 100.0)


func _handle_gacha_tap(pos: Vector2) -> void:
	if _is_gacha_animating():
		return
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
	gacha_pending_cards.clear()
	gacha_card_flip_timers.clear()
	for i in range(count):
		var card = _roll_gacha()
		if card.is_empty():
			continue
		gacha_pending_cards.append(String(card["id"]))
		selected_card_id = String(card["id"])
	if gacha_pending_cards.is_empty():
		return
	gacha_fx_timer = GACHA_FX_SECONDS
	gacha_reveal_timer = 0.0


func _is_gacha_animating() -> bool:
	return gacha_fx_timer > 0.0 or not gacha_pending_cards.is_empty() or _has_active_gacha_flip()


func _has_active_gacha_flip() -> bool:
	for timer in gacha_card_flip_timers:
		if float(timer) > 0.0:
			return true
	return false


func _update_gacha_animation(delta: float) -> void:
	for i in range(gacha_card_flip_timers.size()):
		gacha_card_flip_timers[i] = maxf(0.0, float(gacha_card_flip_timers[i]) - delta)
	if gacha_fx_timer > 0.0:
		gacha_fx_timer = maxf(0.0, gacha_fx_timer - delta)
		if gacha_fx_timer <= 0.0:
			_reveal_next_gacha_card()
		return
	if gacha_pending_cards.is_empty():
		return
	gacha_reveal_timer -= delta
	if gacha_reveal_timer <= 0.0:
		_reveal_next_gacha_card()


func _reveal_next_gacha_card() -> void:
	if gacha_pending_cards.is_empty():
		return
	var card_id = String(gacha_pending_cards.pop_front())
	last_gacha_cards.append(card_id)
	gacha_card_flip_timers.append(GACHA_CARD_FLIP_SECONDS)
	selected_card_id = card_id
	if gacha_pending_cards.is_empty():
		_toast("获得%d张卡牌" % last_gacha_cards.size())
	else:
		gacha_reveal_timer = GACHA_CARD_REVEAL_INTERVAL


func _handle_deck_tap(pos: Vector2) -> void:
	for i in range(DECK_SIZE):
		if _deck_slot_rect(i).has_point(pos):
			if pending_equip_card_id != "":
				_equip_pending_card_to_slot(i)
			else:
				selected_slot = i
				_show_card_detail(String(deck[i]))
			return

	if _equip_button_rect().has_point(pos) and _can_show_equip_button(selected_card_id):
		_start_equip_selected_card()
		return

	if _upgrade_button_rect().has_point(pos):
		_try_upgrade_selected_card()
		return

	var card = _collection_card_at(pos)
	if card.is_empty():
		return
	var card_id = String(card["id"])
	selected_slot = -1
	_show_card_detail(card_id)
	if _card_total_count(card_id) <= 0:
		_toast("尚未拥有该卡牌")


func _show_card_detail(card_id: String) -> void:
	selected_card_id = card_id
	pending_equip_card_id = ""
	detail_pulse_timer = DETAIL_PULSE_SECONDS


func _start_equip_selected_card() -> void:
	var card_id = selected_card_id
	if card_id == "":
		return
	if _card_total_count(card_id) <= 0:
		_toast("尚未拥有该卡牌")
		return
	if _is_card_in_deck(card_id):
		_toast("已在出战编组")
		return
	pending_equip_card_id = card_id
	detail_pulse_timer = DETAIL_PULSE_SECONDS
	_toast("选择要替换的出战动物")


func _equip_pending_card_to_slot(slot_index: int) -> void:
	if pending_equip_card_id == "" or slot_index < 0 or slot_index >= deck.size():
		return
	var card_id = pending_equip_card_id
	deck[slot_index] = card_id
	selected_slot = slot_index
	selected_card_id = card_id
	pending_equip_card_id = ""
	detail_pulse_timer = DETAIL_PULSE_SECONDS
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
			pending_equip_card_id = ""
		elif id == SCREEN_LOBBY:
			screen = SCREEN_LOBBY
			pending_equip_card_id = ""
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
	deck_scroll = clampf(deck_scroll + amount, 0.0, _collection_max_scroll_for_count(_available_collection_cards().size()))


func _collection_view_rect() -> Rect2:
	var frame = _collection_frame_rect()
	return Rect2(frame.position + Vector2(20, 14), frame.size - Vector2(40, 28))


func _collection_frame_rect() -> Rect2:
	return Rect2(34, 714, 652, 414)


func _collection_content_height(count: int) -> float:
	if count <= 0:
		return 0.0
	var rows = ceili(float(count) / float(COLLECTION_COLUMNS))
	return COLLECTION_CARD_SIZE.y + float(rows - 1) * (COLLECTION_CARD_SIZE.y + COLLECTION_CARD_GAP.y)


func _collection_max_scroll_for_count(count: int) -> float:
	return maxf(0.0, _collection_content_height(count) - _collection_view_rect().size.y)


func _collection_card_rect(index: int, origin: Vector2) -> Rect2:
	var col = index % COLLECTION_COLUMNS
	var row = floori(float(index) / float(COLLECTION_COLUMNS))
	var step = COLLECTION_CARD_SIZE + COLLECTION_CARD_GAP
	return Rect2(origin + Vector2(float(col) * step.x, float(row) * step.y), COLLECTION_CARD_SIZE)


func _collection_card_at(pos: Vector2) -> Dictionary:
	var collection_view = _collection_view_rect()
	if not collection_view.has_point(pos):
		return {}
	var collection_cards = _available_collection_cards()
	var origin = Vector2(collection_view.position.x, collection_view.position.y - deck_scroll)
	for i in range(collection_cards.size()):
		var rect = _collection_card_rect(i, origin)
		if rect.has_point(pos):
			return collection_cards[i]
	return {}


func _draw_lobby_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_text_center("丛林法则", Rect2(40, 66, 640, 64), 46, Color.WHITE)
	var scene_rect = Rect2(58, 144, 604, 680)
	_box(scene_rect, Color(0.39, 0.63, 0.87), COLOR_LINE, 5)
	draw_rect(scene_rect.grow(-14), Color(0.48, 0.78, 0.39))
	draw_texture_rect(BUILDING_ART["base"], Rect2(260, 260, 200, 200), false)
	_draw_lobby_deck_animals(scene_rect.grow(-34))
	_draw_rank_panel(Rect2(58, 842, 604, 92))
	_cta(_start_rect(), "匹配", true)


func _draw_lobby_deck_animals(area: Rect2) -> void:
	if deck.is_empty():
		return
	var points = [
		Vector2(0.28, 0.68), Vector2(0.50, 0.70), Vector2(0.72, 0.68), Vector2(0.38, 0.56),
		Vector2(0.62, 0.56), Vector2(0.22, 0.82), Vector2(0.50, 0.84), Vector2(0.78, 0.82)
	]
	for i in range(min(deck.size(), points.size())):
		var card = _card_by_id(String(deck[i]))
		if card.is_empty():
			continue
		_draw_lobby_animal(area, card, points[i], i)


func _draw_lobby_animal(area: Rect2, card: Dictionary, anchor: Vector2, index: int) -> void:
	var card_id = String(card.get("id", ""))
	var motion_seed = float(absi(hash(card_id)) % 1000) / 1000.0
	var phase = ui_time * (0.75 + motion_seed * 0.35) + motion_seed * TAU
	var wander = Vector2(cos(phase * 1.17), sin(phase * 0.91)) * 18.0
	var bob = sin(phase * 2.2) * 5.0
	var base_pos = area.position + Vector2(area.size.x * anchor.x, area.size.y * anchor.y)
	var pos = base_pos + wander + Vector2(0, bob)
	var size = Vector2(92, 92) * (0.92 + 0.06 * sin(phase + float(index)))
	draw_circle(pos + Vector2(0, size.y * 0.35), size.x * 0.26, Color(0, 0, 0, 0.16))
	draw_texture_rect(_card_texture(card), Rect2(pos - size * 0.5, size), false)


func _draw_rank_panel(rect: Rect2) -> void:
	var elo = _player_elo()
	var state = RankingRules.rank_state_for_elo(elo)
	_box(rect, Color(0.16, 0.13, 0.38, 0.94), COLOR_LINE, 4)
	_draw_text_fit(String(state["display"]), Rect2(rect.position + Vector2(22, 10), Vector2(260, 34)), 28, Color.WHITE)
	_draw_text_right("段位赛", Rect2(rect.position + Vector2(350, 12), Vector2(228, 28)), 20, Color(0.88, 0.92, 1.0))
	_draw_star_track(Rect2(rect.position + Vector2(22, 52), Vector2(176, 20)), int(state["stars"]), int(state["max_stars"]))
	var profile = _player_profile()
	_draw_text_fit("胜 %d  负 %d" % [int(profile.get("wins", 0)), int(profile.get("losses", 0))], Rect2(rect.position + Vector2(224, 52), Vector2(160, 24)), 18, Color(0.88, 0.92, 1.0))


func _draw_star_track(rect: Rect2, stars: int, max_stars: int) -> void:
	if max_stars <= 0:
		_draw_text_fit("王者星数 " + str(stars), rect, 18, COLOR_YELLOW)
		return
	var gap = 10.0
	var radius = 7.5
	for i in range(max_stars):
		var center = rect.position + Vector2(radius + float(i) * (radius * 2.0 + gap), rect.size.y * 0.5)
		draw_circle(center + Vector2(0, 2), radius, Color(0, 0, 0, 0.22))
		draw_circle(center, radius, COLOR_YELLOW if i < stars else Color(0.35, 0.34, 0.48))
		draw_arc(center, radius + 0.8, 0.0, TAU, 18, COLOR_LINE, 1.2, true)


func _draw_gacha_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_text_center("抽卡", Rect2(40, 68, 640, 58), 46, Color.WHITE)
	_resource(Rect2(238, 130, 244, 48), "抽卡券", str(gacha_tickets), COLOR_YELLOW)

	var reward_panel = Rect2(46, 220, 628, 560)
	_box(reward_panel, Color(0.19, 0.16, 0.45), COLOR_LINE, 5)
	_draw_text_center("最近获得", Rect2(reward_panel.position + Vector2(0, 28), Vector2(reward_panel.size.x, 42)), 30, Color.WHITE)
	var display_count = last_gacha_cards.size() + gacha_pending_cards.size()
	if gacha_fx_timer > 0.0:
		_draw_gacha_fx(reward_panel)
	elif last_gacha_cards.is_empty() and display_count <= 0:
		_draw_text_center("暂无记录", Rect2(reward_panel.position + Vector2(0, 238), Vector2(reward_panel.size.x, 42)), 24, Color.WHITE)
	else:
		for i in range(display_count):
			if i < last_gacha_cards.size():
				var card = _card_by_id(String(last_gacha_cards[i]))
				_draw_gacha_reward_card(i, card, display_count)
			else:
				_draw_gacha_card_back(_gacha_reward_card_rect(i, display_count), i)

	var can_draw = not _is_gacha_animating()
	_cta(_gacha_draw_rect(), "抽1次", can_draw and gacha_tickets > 0)
	_cta(_gacha_ten_draw_rect(), "抽10次", can_draw and gacha_tickets >= 10)


func _draw_gacha_reward_card(index: int, card: Dictionary, count: int) -> void:
	var rect = _gacha_reward_card_rect(index, count)
	var flip_timer = float(gacha_card_flip_timers[index]) if index < gacha_card_flip_timers.size() else 0.0
	if flip_timer > 0.0:
		var progress = 1.0 - flip_timer / GACHA_CARD_FLIP_SECONDS
		var width_scale = maxf(0.08, absf(cos(progress * PI)))
		var flipped_rect = Rect2(
			Vector2(rect.position.x + rect.size.x * (1.0 - width_scale) * 0.5, rect.position.y),
			Vector2(rect.size.x * width_scale, rect.size.y)
		)
		if progress < 0.5:
			_draw_gacha_card_back(flipped_rect, index)
		else:
			_draw_card(flipped_rect, card, true)
			_draw_gacha_card_glow(rect, progress)
		return
	_draw_card(rect, card, true)


func _gacha_reward_card_rect(index: int, count: int) -> Rect2:
	count = max(1, count)
	if count == 1:
		return Rect2(292, 410, 136, 166)
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
	return Rect2(Vector2(start_x + float(col) * (card_size.x + gap.x), start_y + float(row) * (card_size.y + gap.y)), card_size)


func _draw_gacha_fx(panel: Rect2) -> void:
	var progress = 1.0 - gacha_fx_timer / GACHA_FX_SECONDS
	var center = panel.get_center() + Vector2(0, 16)
	var pulse = sin(progress * PI)
	var ring_radius = 56.0 + progress * 150.0
	draw_circle(center, 58.0 + pulse * 22.0, Color(1.0, 0.70, 0.15, 0.16 + pulse * 0.10))
	draw_arc(center, ring_radius, 0.0, TAU, 72, Color(1.0, 0.88, 0.25, 0.95 - progress * 0.65), 7.0, true)
	draw_arc(center, 34.0 + pulse * 46.0, ui_time * 4.0, ui_time * 4.0 + TAU * 0.82, 48, COLOR_BLUE, 8.0, true)
	for i in range(12):
		var angle = float(i) / 12.0 * TAU + ui_time * 1.5
		var distance = 38.0 + progress * 190.0 + sin(ui_time * 5.0 + float(i)) * 8.0
		var pos = center + Vector2(cos(angle), sin(angle)) * distance
		var size = 5.0 + float(i % 3) * 2.0
		draw_circle(pos, size, COLOR_YELLOW if i % 2 == 0 else COLOR_ORANGE)
		draw_arc(pos, size + 1.5, 0.0, TAU, 12, COLOR_LINE, 1.2, true)
	_draw_gacha_star(center, 28.0 + pulse * 14.0, Color.WHITE)


func _draw_gacha_card_back(rect: Rect2, index: int) -> void:
	var wave = (sin(ui_time * TAU * 1.1 + float(index) * 0.4) + 1.0) * 0.5
	_box(rect, Color(0.18, 0.34, 0.88).lerp(COLOR_PURPLE, 0.35), COLOR_LINE, 4)
	var inner = rect.grow(-10)
	draw_rect(inner, Color(1.0, 0.78, 0.18, 0.20 + wave * 0.08))
	draw_rect(inner, COLOR_YELLOW, false, 3)
	_draw_gacha_star(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.18, COLOR_YELLOW)


func _draw_gacha_card_glow(rect: Rect2, progress: float) -> void:
	var alpha = maxf(0.0, 1.0 - progress)
	draw_rect(rect.grow(8.0), Color(COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, alpha * 0.22))
	draw_rect(rect.grow(8.0), Color(COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, alpha * 0.75), false, 4)


func _draw_gacha_star(center: Vector2, radius: float, color: Color) -> void:
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	for i in range(10):
		var r = radius if i % 2 == 0 else radius * 0.45
		var angle = -PI * 0.5 + float(i) / 10.0 * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
		colors.append(color)
	draw_polygon(points, colors)


func _draw_deck_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_text_center("出战编组", Rect2(40, 68, 640, 58), 42, Color.WHITE)
	_box(Rect2(34, 140, 652, 360), COLOR_PURPLE, COLOR_LINE, 5)
	for i in range(DECK_SIZE):
		var slot_rect = _deck_slot_rect(i)
		var card_id = String(deck[i])
		_draw_card(slot_rect, _card_by_id(card_id), pending_equip_card_id == "" and card_id == selected_card_id)
		if pending_equip_card_id != "":
			_draw_deck_slot_breath(slot_rect, i)
	_draw_card_detail(Rect2(34, 520, 652, 128))
	_draw_text_center("所有卡牌", Rect2(0, 670, DESIGN_SIZE.x, 42), 34, Color.WHITE)
	var collection_frame = _collection_frame_rect()
	_box(collection_frame, Color(0.55, 0.78, 0.43), COLOR_LINE, 4)
	var collection_view = _collection_view_rect()
	var collection_cards = _available_collection_cards()
	deck_scroll = clampf(deck_scroll, 0.0, _collection_max_scroll_for_count(collection_cards.size()))
	var origin = Vector2(collection_view.position.x, collection_view.position.y - deck_scroll)
	for i in range(collection_cards.size()):
		var rect = _collection_card_rect(i, origin)
		if not rect.intersects(collection_view, true):
			continue
		var card = collection_cards[i]
		_draw_card_clipped(rect, card, String(card["id"]) == selected_card_id, collection_view)
	draw_rect(collection_frame, COLOR_LINE, false, 4)


func _draw_deck_slot_breath(rect: Rect2, index: int) -> void:
	var wave = (sin(ui_time * TAU * 1.25 + float(index) * 0.45) + 1.0) * 0.5
	var glow = rect.grow(5.0 + wave * 4.0)
	var fill = Color(COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, 0.10 + wave * 0.09)
	var line = Color(COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, 0.55 + wave * 0.30)
	draw_rect(glow, fill)
	draw_rect(glow, line, false, 4.0)


func _draw_battle_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_match_status()
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


func _draw_match_status() -> void:
	var rect = Rect2(250, 18, 220, 44)
	_box(rect, Color(0.15, 0.12, 0.34, 0.92), COLOR_LINE, 3)
	_draw_text_center(_match_status_text(), rect, 17, Color.WHITE)


func _match_status_text() -> String:
	var player_rank = RankingRules.display_for_elo(active_match_player_elo)
	var opponent_rank = String(active_match_mirror.get("rank_display", player_rank))
	return "%s  VS  %s" % [player_rank, opponent_rank]


func _rank_result_text() -> String:
	if last_rank_result.is_empty():
		return "当前段位 " + RankingRules.display_for_elo(_player_elo())
	var rank_state = last_rank_result.get("new_rank", RankingRules.rank_state_for_elo(_player_elo()))
	return "当前段位 " + String(rank_state.get("display", RankingRules.display_for_elo(_player_elo())))


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
	var occupier = int(tile.get("occupier", team))
	var territory_team = int(tile.get("territory_team", NEUTRAL))
	var can_unlock = _can_unlock(key, PLAYER)
	var fill = Color(0.88, 0.80, 0.58, 0.68)
	var line = Color(0.61, 0.52, 0.35, 0.48)
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
	elif territory_team == PLAYER:
		line = COLOR_GREEN.darkened(0.28)
		line.a = 0.58
		line_width = 2.4
	elif territory_team == ENEMY:
		line = COLOR_RED.darkened(0.22)
		line.a = 0.58
		line_width = 2.4
	elif occupier == PLAYER:
		line = COLOR_GREEN.darkened(0.24)
		line_width = 3.0
	elif occupier == ENEMY:
		line = COLOR_RED.darkened(0.24)
		line_width = 3.0
	draw_polygon(points, PackedColorArray([fill, fill, fill, fill, fill, fill]))
	draw_polyline(_closed_points(points), line, line_width)
	if String(tile["building"]) != "":
		_draw_building(center, tile)
	elif can_unlock:
		_draw_site(center, tile)


func _draw_site(center: Vector2, tile: Dictionary) -> void:
	var site = String(tile.get("site", ""))
	_draw_site_icon(center + Vector2(0, -11), tile)
	var affordable = gold >= int(tile["site_cost"])
	_draw_site_cost(center + Vector2(0, 18), int(tile["site_cost"]), affordable)


func _draw_site_icon(center: Vector2, tile: Dictionary) -> void:
	var site = String(tile.get("site", ""))
	var ink = Color(0.07, 0.09, 0.14, 0.88)
	var shadow = Color(0, 0, 0, 0.16)
	match site:
		"mystery":
			_draw_mystery_site_icon(center, ink, shadow)
		"tower":
			_draw_quality_tower(center, _tile_visual_rarity(tile), false)
		"mine":
			_draw_mine_site_icon(center, ink, shadow)
		_:
			_draw_quality_camp(center, _tile_visual_rarity(tile), false)


func _draw_site_cost(center: Vector2, cost: int, affordable: bool) -> void:
	var coin_color = COLOR_YELLOW if affordable else Color(0.84, 0.64, 0.28)
	var text_color = COLOR_LINE if affordable else Color(0.50, 0.27, 0.16)
	var coin_center = center + Vector2(-15, 0)
	draw_circle(coin_center + Vector2(0, 2), 6.0, Color(0, 0, 0, 0.16))
	draw_circle(coin_center, 6.0, coin_color)
	draw_arc(coin_center, 6.8, 0.0, TAU, 18, COLOR_LINE, 1.4, true)
	var size = 15 if cost < 100 else 14
	_draw_text_center(str(cost), Rect2(center + Vector2(-2, -12), Vector2(38, 22)), size, text_color)


func _draw_mystery_site_icon(center: Vector2, ink: Color, shadow: Color) -> void:
	_draw_text_center("?", Rect2(center + Vector2(-16, -22), Vector2(32, 38)), 31, shadow)
	_draw_text_center("?", Rect2(center + Vector2(-16, -24), Vector2(32, 38)), 31, ink)
	draw_rect(Rect2(center + Vector2(-3, 13), Vector2(6, 5)), ink)


func _draw_mine_site_icon(center: Vector2, ink: Color, shadow: Color) -> void:
	var c = center + Vector2(0, 2)
	_draw_filled_polygon([c + Vector2(-18, 12), c + Vector2(-9, -6), c + Vector2(2, 2), c + Vector2(11, -11), c + Vector2(20, 12)], shadow)
	_draw_filled_polygon([c + Vector2(-19, 10), c + Vector2(-9, -8), c + Vector2(1, 1), c + Vector2(11, -13), c + Vector2(20, 10)], ink)
	draw_line(c + Vector2(-16, -15), c + Vector2(14, 15), ink, 4.0, true)
	draw_line(c + Vector2(-13, -16), c + Vector2(4, -22), ink, 4.0, true)
	draw_line(c + Vector2(-7, -10), c + Vector2(-14, -1), ink, 3.0, true)


func _draw_quality_camp(center: Vector2, rarity: String, unlocked: bool) -> void:
	var rank = _rarity_sort_rank(rarity)
	var main = _rarity_color(rarity)
	var outline = COLOR_LINE
	var accent = main.lightened(0.34)
	var shade = main.darkened(0.22)
	if not unlocked:
		rank = 1
		main = Color(0.07, 0.09, 0.14, 0.88)
		outline = Color(0.04, 0.05, 0.08, 0.95)
		accent = Color(0.23, 0.25, 0.30, 0.90)
		shade = Color(0.12, 0.13, 0.16, 0.90)
	var scale = 0.78 + float(rank) * 0.10
	if not unlocked:
		scale *= 0.86
	var c = center + Vector2(0, 5.0 - float(rank) * 1.5)
	var body_w = (24.0 + float(rank) * 5.0) * scale
	var body_h = (15.0 + float(rank) * 2.4) * scale
	var roof_h = (14.0 + float(rank) * 3.0) * scale
	var base_y = c.y + (18.0 + float(rank)) * scale
	var body_rect = Rect2(Vector2(c.x - body_w * 0.5, base_y - body_h), Vector2(body_w, body_h))
	var roof = [
		Vector2(c.x - body_w * 0.62, base_y - body_h),
		Vector2(c.x, base_y - body_h - roof_h),
		Vector2(c.x + body_w * 0.62, base_y - body_h),
	]
	draw_rect(Rect2(Vector2(c.x - body_w * 0.58, base_y + 1.0), Vector2(body_w * 1.16, 5.0 * scale)), Color(0, 0, 0, 0.18))
	draw_rect(body_rect, shade)
	draw_rect(body_rect, outline, false, 3.0)
	_draw_shape(roof, main, outline, 3.0)
	draw_rect(Rect2(Vector2(c.x - body_w * 0.16, base_y - body_h * 0.62), Vector2(body_w * 0.32, body_h * 0.62)), Color(0.09, 0.10, 0.16))
	draw_line(Vector2(c.x - body_w * 0.42, base_y - body_h * 0.12), Vector2(c.x + body_w * 0.42, base_y - body_h * 0.12), accent, 2.0, true)
	if rank >= 2:
		var pole_top = Vector2(c.x + body_w * 0.34, base_y - body_h - roof_h - 8.0 * scale)
		draw_line(Vector2(c.x + body_w * 0.34, base_y - body_h - roof_h + 1.0), pole_top, outline, 2.0, true)
		_draw_shape([pole_top, pole_top + Vector2(12.0 * scale, 4.0 * scale), pole_top + Vector2(0, 8.0 * scale)], accent, outline, 2.0)
	if rank >= 3:
		draw_circle(Vector2(c.x - body_w * 0.34, base_y - body_h * 0.45), 3.5 * scale, accent)
		draw_circle(Vector2(c.x + body_w * 0.34, base_y - body_h * 0.45), 3.5 * scale, accent)
		draw_line(Vector2(c.x - body_w * 0.48, base_y - body_h - roof_h * 0.16), Vector2(c.x + body_w * 0.48, base_y - body_h - roof_h * 0.16), accent, 2.2, true)
	if rank >= 4:
		var crown_y = base_y - body_h - roof_h - 4.0 * scale
		_draw_shape([
			Vector2(c.x - 11.0 * scale, crown_y + 7.0 * scale),
			Vector2(c.x - 6.0 * scale, crown_y),
			Vector2(c.x, crown_y + 6.0 * scale),
			Vector2(c.x + 6.0 * scale, crown_y),
			Vector2(c.x + 11.0 * scale, crown_y + 7.0 * scale),
		], accent, outline, 2.0)


func _draw_quality_tower(center: Vector2, rarity: String, unlocked: bool) -> void:
	var rank = _rarity_sort_rank(rarity)
	var main = _rarity_color(rarity)
	var outline = COLOR_LINE
	var accent = main.lightened(0.36)
	var shade = main.darkened(0.20)
	if not unlocked:
		rank = 1
		main = Color(0.07, 0.09, 0.14, 0.88)
		outline = Color(0.04, 0.05, 0.08, 0.95)
		accent = Color(0.23, 0.25, 0.30, 0.90)
		shade = Color(0.12, 0.13, 0.16, 0.90)
	var scale = 0.76 + float(rank) * 0.10
	if not unlocked:
		scale *= 0.86
	var c = center + Vector2(0, 4.0 - float(rank) * 1.8)
	var base_y = c.y + (21.0 + float(rank)) * scale
	var tower_w = (17.0 + float(rank) * 4.5) * scale
	var tower_h = (30.0 + float(rank) * 5.0) * scale
	var top_y = base_y - tower_h
	draw_rect(Rect2(Vector2(c.x - tower_w * 0.70, base_y + 1.0), Vector2(tower_w * 1.40, 5.0 * scale)), Color(0, 0, 0, 0.18))
	if rank <= 2:
		var body_rect = Rect2(Vector2(c.x - tower_w * 0.5, top_y + 8.0 * scale), Vector2(tower_w, tower_h - 8.0 * scale))
		draw_rect(body_rect, shade)
		draw_rect(body_rect, outline, false, 3.0)
		_draw_shape([
			Vector2(c.x - tower_w * 0.62, top_y + 9.0 * scale),
			Vector2(c.x, top_y - 4.0 * scale),
			Vector2(c.x + tower_w * 0.62, top_y + 9.0 * scale),
		], main, outline, 3.0)
	else:
		_draw_shape([
			Vector2(c.x - tower_w * 0.54, base_y),
			Vector2(c.x - tower_w * 0.36, top_y + 11.0 * scale),
			Vector2(c.x, top_y - 8.0 * scale),
			Vector2(c.x + tower_w * 0.36, top_y + 11.0 * scale),
			Vector2(c.x + tower_w * 0.54, base_y),
		], shade, outline, 3.0)
	draw_rect(Rect2(Vector2(c.x - tower_w * 0.18, base_y - tower_h * 0.50), Vector2(tower_w * 0.36, tower_h * 0.40)), main)
	draw_rect(Rect2(Vector2(c.x - tower_w * 0.18, base_y - tower_h * 0.50), Vector2(tower_w * 0.36, tower_h * 0.40)), outline, false, 2.0)
	draw_line(Vector2(c.x - tower_w * 0.42, base_y - tower_h * 0.18), Vector2(c.x + tower_w * 0.42, base_y - tower_h * 0.18), accent, 2.0, true)
	if rank >= 2:
		draw_line(Vector2(c.x - tower_w * 0.58, base_y - tower_h * 0.68), Vector2(c.x - tower_w * 0.58, base_y - tower_h * 0.36), outline, 3.0, true)
		draw_line(Vector2(c.x + tower_w * 0.58, base_y - tower_h * 0.68), Vector2(c.x + tower_w * 0.58, base_y - tower_h * 0.36), outline, 3.0, true)
	if rank >= 3:
		draw_circle(Vector2(c.x, top_y + 4.0 * scale), 5.0 * scale, accent)
		draw_circle(Vector2(c.x, top_y + 4.0 * scale), 5.0 * scale, outline, false, 2.0)
	if rank >= 4:
		draw_circle(Vector2(c.x, top_y - 9.0 * scale), 4.0 * scale, accent)
		_draw_shape([
			Vector2(c.x - tower_w * 0.74, base_y - tower_h * 0.18),
			Vector2(c.x - tower_w * 0.48, base_y - tower_h * 0.38),
			Vector2(c.x - tower_w * 0.48, base_y - tower_h * 0.02),
		], main, outline, 2.0)
		_draw_shape([
			Vector2(c.x + tower_w * 0.74, base_y - tower_h * 0.18),
			Vector2(c.x + tower_w * 0.48, base_y - tower_h * 0.38),
			Vector2(c.x + tower_w * 0.48, base_y - tower_h * 0.02),
		], main, outline, 2.0)


func _draw_building(center: Vector2, tile: Dictionary) -> void:
	var building = String(tile["building"])
	if building == "barracks" or building == "hall":
		_draw_quality_camp(center + Vector2(0, -7), _building_visual_rarity(tile), true)
	elif building == "tower":
		_draw_quality_tower(center + Vector2(0, -7), _building_visual_rarity(tile), true)
	else:
		var size = Vector2(66, 66)
		if building == "base":
			size = Vector2(78, 78)
		draw_texture_rect(_building_texture(building), Rect2(center - size * 0.5 + Vector2(0, -8), size), false)
	var max_hp = float(tile.get("max_hp", 0.0))
	if max_hp <= 0.0:
		return
	var pct = clampf(float(tile["hp"]) / max_hp, 0.0, 1.0)
	_box(Rect2(center + Vector2(-32, 30), Vector2(64, 8)), COLOR_LINE, Color(0, 0, 0, 0), 0)
	_box(Rect2(center + Vector2(-31, 31), Vector2(62.0 * pct, 6)), _team_health_color(int(tile["team"])), Color(0, 0, 0, 0), 0)


func _building_visual_rarity(tile: Dictionary) -> String:
	var building = String(tile.get("building", ""))
	if building == "barracks" or building == "hall":
		var card = _card_by_id(String(tile.get("site_card", "")))
		if not card.is_empty():
			return String(card.get("rarity", "common"))
	var target = String(tile.get("site_target_rarity", ""))
	return target if target != "" else "common"


func _tile_visual_rarity(tile: Dictionary) -> String:
	var target = String(tile.get("site_target_rarity", ""))
	return target if target != "" else "common"


func _draw_shape(points: Array, fill: Color, line: Color, width: float) -> void:
	var polygon = PackedVector2Array()
	var colors = PackedColorArray()
	for point in points:
		polygon.append(point)
		colors.append(fill)
	draw_polygon(polygon, colors)
	if width > 0.0:
		draw_polyline(_closed_points(polygon), line, width)


func _draw_unit(unit: Dictionary) -> void:
	var pos = Vector2(unit["pos"])
	var team = int(unit["team"])
	draw_circle(pos + Vector2(0, 14), 17, Color(0, 0, 0, 0.18))
	draw_texture_rect(_card_texture(_card_by_id(String(unit["card"]))), Rect2(pos + Vector2(-22, -30), Vector2(44, 44)), false)
	var pct = clampf(float(unit["hp"]) / float(unit["max_hp"]), 0.0, 1.0)
	_box(Rect2(pos + Vector2(-18, 20), Vector2(36, 6)), COLOR_LINE, Color(0, 0, 0, 0), 0)
	_box(Rect2(pos + Vector2(-17, 21), Vector2(34.0 * pct, 4)), _team_health_color(team), Color(0, 0, 0, 0), 0)


func _team_health_color(team: int) -> Color:
	if team == PLAYER:
		return COLOR_GREEN
	if team == ENEMY:
		return COLOR_RED
	return COLOR_YELLOW


func _draw_effect(effect: Dictionary) -> void:
	var kind = String(effect.get("kind", "pulse"))
	if kind == "projectile":
		var duration = maxf(0.01, float(effect.get("duration", PROJECTILE_TIME)))
		var progress = clampf(1.0 - float(effect["time"]) / duration, 0.0, 1.0)
		var start = Vector2(effect["from"])
		var end = Vector2(effect["to"])
		var head = start.lerp(end, progress)
		var tail = start.lerp(end, maxf(0.0, progress - 0.28))
		var color = effect["color"]
		color.a = 0.95
		var glow = Color(1.0, 0.96, 0.62, 0.38)
		draw_line(tail, head, glow, 9.0, true)
		draw_line(tail, head, color, 5.0, true)
		draw_circle(head, 6.0, Color(1.0, 1.0, 0.82, 0.96))
		draw_circle(head, 3.2, color)
		return
	var t = clampf(float(effect["time"]) / 0.45, 0.0, 1.0)
	var color = effect["color"]
	color.a = t * 0.55
	draw_circle(Vector2(effect["pos"]), 8.0 + 30.0 * (1.0 - t), color)


func _draw_selection_panel() -> void:
	var rect = Rect2(26, 1132, 668, 118)
	_box(rect, Color(0.12, 0.10, 0.31, 0.92), Color(0.30, 0.28, 0.62), 4)
	var title = "点击与己方地块接壤的卡牌地块解锁"
	var detail = "可解锁地块只显示类型和价格，品质会在解锁时随机。"
	var detail_extra = ""
	if tiles.has(selected_tile):
		var tile = tiles[selected_tile]
		if String(tile["building"]) != "":
			var building = String(tile["building"])
			var card_id = String(tile.get("site_card", ""))
			title = _site_name(building, card_id)
			if building == "barracks" or building == "hall":
				var card = _card_by_id(card_id)
				if card.is_empty():
					title = "动物卡牌"
					detail = "动物信息缺失。"
				else:
					title = "动物卡牌：%s" % String(card.get("name", "动物"))
					var stats = _card_stats_for_team(card, int(tile["team"]))
					detail = "%s Lv.%d  攻%d 血%d 速%.0f 距%s 召%.1fs" % [
						_rarity_label(String(card.get("rarity", "common"))),
						_card_level_for_team(card_id, int(tile["team"])),
						int(stats["attack"]),
						int(stats["max_hp"]),
						float(stats["move_speed"]),
						_attack_range_label(float(stats["attack_range"])),
						float(stats["summon_interval_sec"]),
					]
					detail_extra = "技能：" + _card_skill_text(card)
			else:
				detail = "生命 %.0f / %.0f" % [float(tile["hp"]), float(tile["max_hp"])]
		elif int(tile["team"]) == PLAYER:
			title = "空地"
			detail = "已解锁区域，可作为继续扩张的连接点。"
		elif int(tile["team"]) == ENEMY:
			title = "敌方区域"
			detail = "派出单位推进后可占领。"
		elif _can_unlock(selected_tile, PLAYER):
			var site = String(tile.get("site", ""))
			title = "可解锁：%s  价格 %d" % [_locked_site_name(site), int(tile["site_cost"])]
			if gold < int(tile["site_cost"]):
				detail = "金币不足，还差%d。" % [int(tile["site_cost"]) - gold]
			elif site == "mystery":
				detail = "问号地块购买后翻开，可能为空地或高级单位建筑。"
			else:
				detail = "购买后才随机品质并变为己方区域。"
		else:
			title = "未连接地块"
			detail = "先扩张到相邻地块。"
	_draw_text_fit(title, Rect2(rect.position + Vector2(24, 14), Vector2(620, 32)), 24, Color.WHITE)
	_draw_text_fit(detail, Rect2(rect.position + Vector2(24, 52), Vector2(620, 26)), 19, Color(0.84, 0.88, 1.0))
	if detail_extra != "":
		_draw_text_fit(detail_extra, Rect2(rect.position + Vector2(24, 80), Vector2(620, 24)), 18, Color(0.78, 0.86, 1.0))


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
	var panel = Rect2(110, 420, 500, 340)
	_box(panel, Color(1.0, 0.96, 0.78), COLOR_LINE, 5)
	_draw_text_center(result_text, Rect2(panel.position + Vector2(0, 48), Vector2(panel.size.x, 68)), 52, COLOR_YELLOW if result_text == "胜利" else COLOR_RED)
	var reward_tickets = last_battle_reward_tickets if last_battle_reward_tickets > 0 else _battle_reward_tickets(result_text)
	_draw_text_center("奖励：+%d 抽卡券" % reward_tickets, Rect2(panel.position + Vector2(0, 128), Vector2(panel.size.x, 36)), 24, COLOR_LINE)
	_draw_text_center(_rank_result_text(), Rect2(panel.position + Vector2(0, 170), Vector2(panel.size.x, 36)), 24, COLOR_PURPLE)
	_draw_text_center("点击任意位置返回主界面", Rect2(panel.position + Vector2(0, 220), Vector2(panel.size.x, 40)), 24, COLOR_LINE)


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


func _draw_card_clipped(rect: Rect2, card: Dictionary, selected: bool, clip_rect: Rect2) -> void:
	if not rect.intersects(clip_rect, true):
		return
	if card.is_empty():
		_box_clipped(rect, Color(0.35, 0.36, 0.40), COLOR_LINE, 4, clip_rect)
		_draw_text_center_clipped("空", rect, 18, Color.WHITE, clip_rect)
		return
	var owned = _card_total_count(String(card.get("id", ""))) > 0
	var fill = _rarity_color(String(card.get("rarity", "common")))
	_box_clipped(rect, fill.darkened(0.06) if owned else Color(0.35, 0.36, 0.40), COLOR_LINE, 4, clip_rect)
	if selected:
		_box_clipped(rect.grow(5), Color(1.0, 0.91, 0.22, 0.28), COLOR_YELLOW, 4, clip_rect)
	var tint = Color.WHITE if owned else Color(0.35, 0.35, 0.35, 0.85)
	var card_id = String(card.get("id", ""))
	var name_rect = Rect2(rect.position + Vector2(8, rect.size.y - 48), Vector2(rect.size.x - 16, 22))
	var progress_rect = Rect2(rect.position + Vector2(12, rect.size.y - 22), Vector2(rect.size.x - 24, 14))
	var art_top = rect.position.y + 12.0
	var art_bottom = name_rect.position.y - 5.0
	var art_size = minf(rect.size.x - 30.0, maxf(44.0, art_bottom - art_top))
	var art_rect = Rect2(Vector2(rect.position.x + (rect.size.x - art_size) * 0.5, art_top), Vector2(art_size, art_size))
	_draw_texture_rect_clipped(_card_texture(card), art_rect, clip_rect, tint)
	_box_clipped(name_rect, Color(0, 0, 0, 0.30), Color(1, 1, 1, 0.18), 1, clip_rect)
	if owned:
		_draw_text_center_clipped("Lv.%d  %s" % [_card_level(card_id), String(card.get("name", ""))], name_rect, 15, Color.WHITE, clip_rect)
		_draw_upgrade_progress_clipped(progress_rect, card_id, false, clip_rect)
	else:
		_draw_text_center_clipped("未拥有", name_rect, 15, Color.WHITE, clip_rect)
		_draw_empty_progress_clipped(progress_rect, clip_rect)


func _draw_card_detail(rect: Rect2) -> void:
	var card = _card_by_id(selected_card_id)
	var pop = 0.0
	if detail_pulse_timer > 0.0:
		var progress = 1.0 - detail_pulse_timer / DETAIL_PULSE_SECONDS
		pop = sin(progress * PI) * 6.0
	_box(rect.grow(pop), Color(1, 1, 1, 0.92), COLOR_LINE, 3)
	if card.is_empty():
		return
	var card_id = String(card["id"])
	var stats = _card_stats(card)
	var rarity_fill = _rarity_color(String(card.get("rarity", "common")))
	var art_rect = Rect2(rect.position + Vector2(20, 12), Vector2(88, 78))
	var name_rect = Rect2(rect.position + Vector2(14, 92), Vector2(104, 28))
	draw_texture_rect(_card_texture(card), art_rect, false)
	_box(name_rect, rarity_fill.darkened(0.16), Color(1, 1, 1, 0.18), 1)
	_draw_text_center("Lv.%d  %s" % [_card_level(card_id), String(card.get("name", ""))], name_rect, 15, Color.WHITE)
	_draw_detail_stat_icon_value(rect.position + Vector2(142, 18), "attack", str(int(stats["attack"])), COLOR_RED)
	_draw_detail_stat_icon_value(rect.position + Vector2(232, 18), "hp", str(int(stats["max_hp"])), COLOR_RED)
	_draw_detail_stat_icon_value(rect.position + Vector2(330, 18), "speed", str(roundi(float(stats["move_speed"]))), COLOR_BLUE)
	_draw_text_center(_attack_range_label(float(stats["attack_range"])), Rect2(rect.position + Vector2(434, 20), Vector2(72, 28)), 18, COLOR_LINE)
	var skill_text = _card_detail_skill_text(card)
	if skill_text != "":
		_draw_text_center(skill_text, Rect2(rect.position + Vector2(138, 56), Vector2(370, 28)), 16, COLOR_PURPLE)
	var cost = _next_upgrade_cost(card_id)
	_draw_upgrade_progress(Rect2(rect.position + Vector2(138, 92), Vector2(352, 18)), card_id, true)
	if _can_show_equip_button(card_id):
		_cta(_equip_button_rect(), "选择中" if pending_equip_card_id == card_id else "上阵", true)
	_cta(_upgrade_button_rect(), "升级", cost >= 0 and _card_spare_count(card_id) >= cost)


func _card_detail_skill_text(card: Dictionary) -> String:
	if String(card.get("skill_id", "")) == "":
		return ""
	var skill_text = String(card.get("skill_text", ""))
	if skill_text.begins_with("无技能"):
		return ""
	return skill_text


func _can_show_equip_button(card_id: String) -> bool:
	return card_id != "" and _card_total_count(card_id) > 0 and not _is_card_in_deck(card_id)


func _draw_detail_stat_icon_value(pos: Vector2, icon: String, value: String, color: Color) -> void:
	var center = pos + Vector2(14, 14)
	match icon:
		"attack":
			_draw_paw_icon(center, color)
		"hp":
			_draw_heart_icon(center, color)
		"speed":
			_draw_boot_icon(center, color)
	_draw_text_fit(value, Rect2(pos + Vector2(32, 0), Vector2(54, 28)), 18, COLOR_LINE)


func _draw_paw_icon(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(0, 5), 6.0, color)
	draw_circle(center + Vector2(-8, -2), 3.4, color)
	draw_circle(center + Vector2(-2.5, -7), 3.4, color)
	draw_circle(center + Vector2(3.8, -7), 3.4, color)
	draw_circle(center + Vector2(9, -2), 3.4, color)


func _draw_heart_icon(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-4, -3), 5.2, color)
	draw_circle(center + Vector2(4, -3), 5.2, color)
	var points = PackedVector2Array([
		center + Vector2(-10, -1),
		center + Vector2(10, -1),
		center + Vector2(0, 11),
	])
	draw_polygon(points, PackedColorArray([color, color, color]))


func _draw_boot_icon(center: Vector2, color: Color) -> void:
	var points = PackedVector2Array([
		center + Vector2(-8, -9),
		center + Vector2(2, -9),
		center + Vector2(4, 1),
		center + Vector2(12, 4),
		center + Vector2(11, 9),
		center + Vector2(-9, 9),
		center + Vector2(-5, 3),
	])
	draw_polygon(points, PackedColorArray([color, color, color, color, color, color, color]))
	draw_line(center + Vector2(-4, -4), center + Vector2(3, -4), Color.WHITE, 2.0)


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
		var label = "满级" if cost < 0 else "%d/%d" % [spare, cost]
		var label_size = 13 if rect.size.y <= 18.0 else 16
		_draw_text_center(label, rect, label_size, Color.WHITE)


func _draw_empty_progress(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.18))
	draw_rect(rect, Color(0.08, 0.10, 0.18, 0.55))
	draw_rect(rect, COLOR_LINE, false, 2)


func _draw_upgrade_progress_clipped(rect: Rect2, card_id: String, show_label: bool, clip_rect: Rect2) -> void:
	var spare = _card_spare_count(card_id)
	var cost = _next_upgrade_cost(card_id)
	var max_value = max(1, cost)
	var pct = 1.0 if cost < 0 else clampf(float(spare) / float(max_value), 0.0, 1.0)
	var fill = COLOR_GREEN if cost >= 0 and spare >= cost else Color(0.26, 0.54, 0.92)
	if cost < 0:
		fill = COLOR_GOLD
	_draw_rect_clipped(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.22), clip_rect)
	_draw_rect_clipped(rect, Color(0.08, 0.10, 0.18, 0.82), clip_rect)
	var inner = Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6))
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		_draw_rect_clipped(Rect2(inner.position, Vector2(inner.size.x * pct, inner.size.y)), fill, clip_rect)
	_draw_rect_outline_clipped(rect, COLOR_LINE, 2, clip_rect)
	if show_label:
		var label = "满级" if cost < 0 else "%d/%d" % [spare, cost]
		var label_size = 13 if rect.size.y <= 18.0 else 16
		_draw_text_center_clipped(label, rect, label_size, Color.WHITE, clip_rect)


func _draw_empty_progress_clipped(rect: Rect2, clip_rect: Rect2) -> void:
	_draw_rect_clipped(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.18), clip_rect)
	_draw_rect_clipped(rect, Color(0.08, 0.10, 0.18, 0.55), clip_rect)
	_draw_rect_outline_clipped(rect, COLOR_LINE, 2, clip_rect)


func _box_clipped(rect: Rect2, fill: Color, line: Color, width: float, clip_rect: Rect2) -> void:
	_draw_rect_clipped(Rect2(rect.position + Vector2(0, 5), rect.size), Color(0, 0, 0, 0.20), clip_rect)
	_draw_rect_clipped(rect, fill, clip_rect)
	if width > 0.0 and line.a > 0.0:
		_draw_rect_outline_clipped(rect, line, width, clip_rect)


func _draw_texture_rect_clipped(texture: Texture2D, rect: Rect2, clip_rect: Rect2, tint: Color = Color.WHITE) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var clipped = _rect_intersection(rect, clip_rect)
	if not _rect_has_area(clipped):
		return
	var texture_size = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var src_pos = Vector2(
		(clipped.position.x - rect.position.x) / rect.size.x * texture_size.x,
		(clipped.position.y - rect.position.y) / rect.size.y * texture_size.y
	)
	var src_size = Vector2(
		clipped.size.x / rect.size.x * texture_size.x,
		clipped.size.y / rect.size.y * texture_size.y
	)
	draw_texture_rect_region(texture, clipped, Rect2(src_pos, src_size), tint)


func _draw_text_center_clipped(text: String, rect: Rect2, size: int, color: Color, clip_rect: Rect2) -> void:
	if not _rect_contains_rect(clip_rect, rect):
		return
	_draw_text_center(text, rect, size, color)


func _draw_rect_clipped(rect: Rect2, color: Color, clip_rect: Rect2) -> void:
	var clipped = _rect_intersection(rect, clip_rect)
	if _rect_has_area(clipped):
		draw_rect(clipped, color)


func _draw_rect_outline_clipped(rect: Rect2, color: Color, width: float, clip_rect: Rect2) -> void:
	if width <= 0.0 or color.a <= 0.0:
		return
	_draw_rect_clipped(Rect2(rect.position, Vector2(rect.size.x, width)), color, clip_rect)
	_draw_rect_clipped(Rect2(rect.position + Vector2(0, rect.size.y - width), Vector2(rect.size.x, width)), color, clip_rect)
	_draw_rect_clipped(Rect2(rect.position, Vector2(width, rect.size.y)), color, clip_rect)
	_draw_rect_clipped(Rect2(rect.position + Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y)), color, clip_rect)


func _rect_intersection(a: Rect2, b: Rect2) -> Rect2:
	var left = maxf(a.position.x, b.position.x)
	var top = maxf(a.position.y, b.position.y)
	var right = minf(a.position.x + a.size.x, b.position.x + b.size.x)
	var bottom = minf(a.position.y + a.size.y, b.position.y + b.size.y)
	if right <= left or bottom <= top:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


func _rect_contains_rect(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x and inner.position.y >= outer.position.y and inner.position.x + inner.size.x <= outer.position.x + outer.size.x and inner.position.y + inner.size.y <= outer.position.y + outer.size.y


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
	return BoardRules.hex_center(key, board_origin, HEX_SIZE)


func _hex_points(center: Vector2) -> PackedVector2Array:
	return BoardRules.hex_points(center, HEX_SIZE)


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed = PackedVector2Array(points)
	if not points.is_empty():
		closed.append(points[0])
	return closed


func _draw_filled_polygon(points: Array, color: Color) -> void:
	if points.size() < 3:
		return
	var polygon = PackedVector2Array()
	var colors = PackedColorArray()
	for point in points:
		polygon.append(point)
		colors.append(color)
	draw_polygon(polygon, colors)


func _neighbors(key: Vector2i) -> Array:
	return BoardRules.neighbors(key)


func _tile_at(pos: Vector2) -> Vector2i:
	return BoardRules.tile_at(tiles, pos, board_origin, HEX_SIZE)


func _deck_slot_rect(index: int) -> Rect2:
	var col = index % 4
	var row = floori(float(index) / 4.0)
	return Rect2(64 + col * 150.0, 202 + row * 142.0, 124, 132)


func _start_rect() -> Rect2:
	return Rect2(190, 958, 340, 76)


func _gacha_draw_rect() -> Rect2:
	return Rect2(104, 830, 240, 76)


func _gacha_ten_draw_rect() -> Rect2:
	return Rect2(376, 830, 240, 76)


func _upgrade_button_rect() -> Rect2:
	return Rect2(522, 602, 116, 36)


func _equip_button_rect() -> Rect2:
	return Rect2(522, 560, 116, 34)


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


func _rarity_sort_rank(rarity: String) -> int:
	return CardRules.rarity_sort_rank(rarity)


func _rarity_label(rarity: String) -> String:
	return CardRules.rarity_label(rarity)


func _locked_site_name(site: String) -> String:
	if site == "barracks" or site == "hall":
		return "动物营地"
	return _site_name(site, "")


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
		"kind": "pulse",
		"pos": pos,
		"color": color,
		"time": 0.45,
	})


func _projectile(start: Vector2, end: Vector2, team: int) -> void:
	var color = COLOR_YELLOW if team == PLAYER else COLOR_ORANGE
	effects.append({
		"kind": "projectile",
		"from": start,
		"to": end,
		"color": color,
		"time": PROJECTILE_TIME,
		"duration": PROJECTILE_TIME,
	})
