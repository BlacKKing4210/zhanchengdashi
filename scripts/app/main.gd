extends Node2D

const CardRules = preload("res://scripts/app/systems/card_rules.gd")
const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")
const RankingRules = preload("res://scripts/app/systems/ranking_rules.gd")
const RankAIDecks = preload("res://scripts/app/systems/rank_ai_decks.gd")
const UnitMotionFeedback = preload("res://scripts/app/systems/unit_motion_feedback.gd")

const DESIGN_SIZE = Vector2(720.0, 1280.0)
const HEX_SIZE = 43.0
const DEFENSE_TOWER_RANGE_BONUS = HEX_SIZE * 0.5
const DEFENSE_TOWER_ATTACK_INTERVAL = 1.0
const GRID_COLS = BoardRules.GRID_COLS
const GRID_ROWS = BoardRules.GRID_ROWS
const PLAYER = BoardRules.PLAYER
const ENEMY = BoardRules.ENEMY
const NEUTRAL = BoardRules.NEUTRAL

const SCREEN_LOBBY = "lobby"
const SCREEN_DECK = "deck"
const SCREEN_BATTLE = "battle"
const SCREEN_GACHA = "gacha"
const SCREEN_ROOM = "room"

const BATTLE_MODE_CLASSIC = "classic"
const BATTLE_MODE_MULTIPLAYER = "multiplayer"
const MULTIPLAYER_HOT_BADGE_TEXT = "HOT!"

const DECK_SIZE = 8
const BATTLE_TIME = 180.0
const STARTING_GOLD = 60
const INCOME_INTERVAL = 3.0
const BASE_INCOME = 12
const MINE_INCOME = 10
const TOWER_DAMAGE = 44.0
const BASE_ATTACK_DAMAGE = 2.0
const TOWER_RANGE = 210.0
const UNIT_MOVE_SPEED_MULT = 0.5
const UNIT_ATTACK_SPEED_MULT = 0.5
const UNIT_BASE_ATTACK_COOLDOWN = 0.85
const ANIMAL_RARITY_VISUAL_SCALES = {
	"common": 1.0,
	"rare": 1.2,
	"epic": 1.5,
	"legendary": 1.8,
}
const CARD_SPEED_FAST_THRESHOLD = 65.0
const CARD_SPEED_SUPER_FAST_THRESHOLD = 75.0
const SKILL_AURA_RADIUS = HEX_SIZE * 3.2
const SKILL_AOE_RADIUS = HEX_SIZE * 1.45
const SKILL_SUPPORT_RADIUS = HEX_SIZE * 3.4
const SKILL_SLOW_SECONDS = 2.4
const SKILL_STUN_SECONDS = 0.72
const STARTING_GACHA_TICKETS = 10
const BATTLE_WIN_REWARD_TICKETS = 3
const BATTLE_LOSS_REWARD_TICKETS = 1
const RANK_DB_PATH = "user://rank_mirror_db.json"
const MIRROR_LIMIT_PER_RANK = 20
const ENEMY_FIRST_UNLOCK_DELAY = 4.0
const ENEMY_UNLOCK_INTERVAL = 2.2
const PROJECTILE_TIME = 0.30
const RANGED_PROJECTILE_MIN_DISTANCE = HEX_SIZE * 1.35
const MULTIPLAYER_BATTLE_TIME = 360.0
const MULTIPLAYER_FREE_FOR_ALL_TIME = MULTIPLAYER_BATTLE_TIME
const MULTIPLAYER_AI_UNLOCK_INTERVAL = 4.5
const MULTIPLAYER_MAX_UNITS_PER_TEAM = 12
const BOARD_DRAG_THRESHOLD = 12.0
const TOWER_BASE_COST = 50
const TOWER_COST_STEP = 50
const ONLINE_SIMULATION_STEP = 0.05
const ONLINE_SNAPSHOT_INTERVAL = 0.20
const ONLINE_ROOM_CODE_LENGTH = 6
const GOLD_GAIN_FEEDBACK_DURATION = 0.90
const GOLD_GAIN_FEEDBACK_RISE = 38.0
const GOLD_GAIN_FEEDBACK_MERGE_WINDOW = 0.18
const UNIT_VALUE_FEEDBACK_DURATION = 0.90
const UNIT_VALUE_FEEDBACK_RISE = 38.0
const UNIT_VALUE_FEEDBACK_MERGE_WINDOW = 0.18
const RESULT_PLAYER_ROW_HEIGHT = 72.0
const RESULT_PLAYER_ROW_GAP = 10.0
const ROOM_WARM_HUES = [0.015, 0.075, 0.135]
const ROOM_COOL_HUES = [0.50, 0.59, 0.69]

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
const DETAIL_UPGRADE_MOTION_SECONDS = 0.55
const GACHA_FX_SECONDS = 0.72
const GACHA_CARD_REVEAL_INTERVAL = 0.18
const GACHA_CARD_FLIP_SECONDS = 0.34
const UNLOCK_CARD_POPUP_SECONDS = 1.08
const MINE_CARD_ID = "gold_mine_card"
const COMMON_DEFENSE_CARD_ID = "defense_watch_tower"
const CARD_KIND_ANIMAL = "animal"
const CARD_KIND_DEFENSE = "defense"
const CARD_KIND_MINE = "mine"

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

const RANK_CASTLE_ART = {
	"bronze": preload("res://assets/art/buildings/rank_castles/castle_bronze.png"),
	"silver": preload("res://assets/art/buildings/rank_castles/castle_silver.png"),
	"gold": preload("res://assets/art/buildings/rank_castles/castle_gold.png"),
	"platinum": preload("res://assets/art/buildings/rank_castles/castle_platinum.png"),
	"diamond": preload("res://assets/art/buildings/rank_castles/castle_diamond.png"),
	"star": preload("res://assets/art/buildings/rank_castles/castle_star.png"),
	"king": preload("res://assets/art/buildings/rank_castles/castle_king.png"),
}

const NAV_ITEMS = [
	{"id": "shop", "label": "商店", "locked": true},
	{"id": SCREEN_DECK, "label": "编组", "locked": false},
	{"id": SCREEN_LOBBY, "label": "战斗", "locked": false},
	{"id": SCREEN_GACHA, "label": "抽卡", "locked": false},
	{"id": SCREEN_ROOM, "label": "房间", "locked": false},
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
var active_match_player_stars = RankingRules.INITIAL_STARS
var last_rank_result = {}

var screen = SCREEN_LOBBY
var battle_mode = BATTLE_MODE_CLASSIC
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
var multiplayer_gold = {}
var multiplayer_ai_timers = {}
var multiplayer_alive = {}
var multiplayer_placements = {}
var multiplayer_team_decks = {}
var multiplayer_team_card_levels = {}
var multiplayer_placement = 0
var multiplayer_free_for_all = false
var last_multiplayer_star_delta = 0
var room_players_per_side = 1
var room_fill_with_ai = true
var room_invite_code = ""
var room_human_teams = {PLAYER: "我"}
var room_pending_invites = {}
var room_active_team_ids = []
var room_base_keys = {}
var room_map_id = ""
var room_map_name = ""
var room_match_data = {}
var room_requested_map_id = ""
var room_match_seed = 0
var room_result = ""
var authority_room_result = ""
var free_for_all_room_snapshot = {}
var online_room_service: Node
var online_connection_state = "offline"
var online_room_active = false
var online_room_is_host = false
var online_room_can_start = false
var online_room_ready = false
var online_room_join_code = ""
var online_room_slots = []
var online_match_id = ""
var online_match_authority = false
var online_snapshot_timer = 0.0
var online_simulation_accumulator = 0.0
var online_snapshot_sequence = 0
var online_last_received_sequence = -1
var online_command_sequence = 0
var online_last_command_sequences = {}
var local_team_id = PLAYER
var classic_map_id = ""
var classic_map_name = ""
var classic_requested_map_id = ""
var classic_base_keys = {}
var battle_match_seed = 0
var team_territory_colors = {}
var team_unlocked_colors = {}
var tower_purchase_counts = {}
var combat_building_keys = []
var game_over = false
var pause_open = false
var account_center_open = false
var player_agreement_open = false
var account_name_field: LineEdit
var account_password_field: LineEdit
var account_pending_register_password = ""
var account_profile_sync_timer = 0.0
var account_profile_signature = ""
var battle_reward_given = false
var last_battle_reward_tickets = 0
var result_text = ""
var result_player_entries = []
var result_players_scroll = 0.0
var toast_text = ""
var toast_timer = 0.0
var detail_pulse_timer = 0.0
var detail_upgrade_motion_timer = 0.0
var ui_time = 0.0
var board_origin = Vector2.ZERO # Classic-mode board origin only.
var board_pan = Vector2.ZERO # Multiplayer camera pan; never store it in world state.
var multiplayer_board_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
var ground_navigation: AStar2D = AStar2D.new()
var ground_navigation_ids = {}
var canvas_scale = 1.0
var canvas_offset = Vector2.ZERO
var next_unit_id = 1
var board_pointer_down = false
var board_pointer_dragged = false
var board_pointer_started_in_view = false
var board_pointer_start = Vector2.ZERO
var board_pointer_last = Vector2.ZERO
var board_pointer_distance = 0.0

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
	_reset_room()
	_reset_battle()
	_setup_online_room()
	_setup_account_fields()
	call_deferred("_auto_login_saved_account_on_startup")


func _process(delta: float) -> void:
	ui_time += delta
	if toast_timer > 0.0:
		toast_timer -= delta
	if detail_pulse_timer > 0.0:
		detail_pulse_timer = maxf(0.0, detail_pulse_timer - delta)
	if detail_upgrade_motion_timer > 0.0:
		detail_upgrade_motion_timer = maxf(0.0, detail_upgrade_motion_timer - delta)
	_update_gacha_animation(delta)
	_update_account_fields_layout()
	_update_server_profile_sync(delta)

	if screen == SCREEN_BATTLE and not pause_open:
		if _is_online_match_active():
			if game_over or not online_match_authority:
				_update_effects(delta)
			else:
				_update_online_authority_battle(delta)
			if online_match_authority:
				_update_online_authority_snapshot(delta)
		elif game_over:
			_update_effects(delta)
		else:
			_update_battle(delta)

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if screen == SCREEN_ROOM and _handle_online_room_keyboard(event):
		return
	if _handle_result_scroll_input(event):
		return
	if _handle_multiplayer_pointer_input(event):
		return
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
		if event.keycode == KEY_R and screen == SCREEN_BATTLE:
			_restart_battle()
		elif event.keycode == KEY_ESCAPE and screen == SCREEN_BATTLE:
			pause_open = not pause_open
			GameAudio.set_paused_mix(pause_open)


func _restart_battle() -> void:
	if screen != SCREEN_BATTLE:
		return
	if _is_online_match_active():
		_toast("互联网对战不能由单个客户端重开")
		return
	_reset_battle()
	GameAudio.play_battle_music()


func _handle_result_scroll_input(event: InputEvent) -> bool:
	if screen != SCREEN_BATTLE or not game_over:
		return false
	_layout(get_viewport_rect().size)
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var canvas_pos = _screen_to_canvas(event.position)
		if _result_other_players_rect().has_point(canvas_pos):
			_scroll_result_players(-82.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 82.0)
			return true
	if event is InputEventScreenDrag:
		var touch_pos = _screen_to_canvas(event.position)
		if _result_other_players_rect().has_point(touch_pos):
			_scroll_result_players(-event.relative.y / maxf(canvas_scale, 0.001))
			return true
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_pos = _screen_to_canvas(event.position)
		if _result_other_players_rect().has_point(mouse_pos):
			_scroll_result_players(-event.relative.y / maxf(canvas_scale, 0.001))
			return true
	return false


func _handle_multiplayer_pointer_input(event: InputEvent) -> bool:
	if screen != SCREEN_BATTLE or not _uses_axial_battle_map():
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_board_pointer(event.position)
			else:
				_end_board_pointer(event.position)
			return true
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_layout(get_viewport_rect().size)
			if _battle_view_rect().has_point(_screen_to_canvas(event.position)):
				board_pan.y += 84.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -84.0
				_clamp_board_pan()
				return true
	if event is InputEventMouseMotion and board_pointer_down:
		_move_board_pointer(event.position, event.relative)
		return true
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_board_pointer(event.position)
		else:
			_end_board_pointer(event.position)
		return true
	if event is InputEventScreenDrag and board_pointer_down:
		_move_board_pointer(event.position, event.relative)
		return true
	return false


func _begin_board_pointer(screen_pos: Vector2) -> void:
	_layout(get_viewport_rect().size)
	board_pointer_down = true
	board_pointer_dragged = false
	board_pointer_start = screen_pos
	board_pointer_last = screen_pos
	board_pointer_distance = 0.0
	var canvas_pos = _screen_to_canvas(screen_pos)
	board_pointer_started_in_view = _battle_view_rect().has_point(canvas_pos) and not pause_open and not game_over


func _move_board_pointer(screen_pos: Vector2, relative: Vector2) -> void:
	if not board_pointer_down:
		return
	board_pointer_distance = screen_pos.distance_to(board_pointer_start) / maxf(canvas_scale, 0.001)
	if board_pointer_started_in_view and board_pointer_distance >= BOARD_DRAG_THRESHOLD:
		board_pointer_dragged = true
	if board_pointer_dragged:
		board_pan += relative / maxf(canvas_scale, 0.001)
		_clamp_board_pan()
	board_pointer_last = screen_pos


func _end_board_pointer(screen_pos: Vector2) -> void:
	if not board_pointer_down:
		return
	var should_tap = not board_pointer_dragged
	board_pointer_down = false
	board_pointer_started_in_view = false
	board_pointer_distance = 0.0
	if should_tap:
		_handle_tap(screen_pos)


func _handle_tap(screen_pos: Vector2) -> void:
	_layout(get_viewport_rect().size)
	var pos = _screen_to_canvas(screen_pos)
	if account_center_open:
		_handle_account_center_tap(pos)
		return

	if screen != SCREEN_BATTLE:
		if screen == SCREEN_LOBBY and _lobby_base_rect().has_point(pos):
			account_center_open = true
			player_agreement_open = false
			_set_account_fields_visible(OnlineRoom.current_user_id == "")
			_ensure_online_room_connection()
			GameAudio.play_sfx("ui_confirm")
			return
		if _handle_nav(pos):
			return
		if screen == SCREEN_LOBBY and _multiplayer_start_rect().has_point(pos):
			GameAudio.play_sfx("ui_confirm")
			_start_lobby_multiplayer_match()
			return
		if screen == SCREEN_LOBBY and _start_rect().has_point(pos):
			_start_match()
			return
		if screen == SCREEN_ROOM:
			_handle_room_tap(pos)
			return
		if screen == SCREEN_DECK:
			_handle_deck_tap(pos)
			return
		if screen == SCREEN_GACHA:
			_handle_gacha_tap(pos)
			return

	if game_over:
		if _result_return_rect().has_point(pos):
			GameAudio.play_sfx("ui_confirm")
			_return_to_lobby()
		return

	if pause_open:
		if _pause_continue_rect().has_point(pos):
			pause_open = false
			GameAudio.set_paused_mix(false)
		elif _pause_exit_rect().has_point(pos):
			GameAudio.set_paused_mix(false)
			if _is_online_match_active():
				_return_to_lobby()
				return
			elif battle_mode == BATTLE_MODE_MULTIPLAYER:
				if multiplayer_free_for_all:
					_finish_multiplayer_free_for_all(_multiplayer_timeout_placement(), false)
				else:
					_finish_multiplayer_battle("loss", false)
			else:
				_finish_battle("失败", false)
			_return_to_lobby()
		return

	if _pause_button_rect().has_point(pos):
		pause_open = true
		GameAudio.set_paused_mix(true)
		return
	if _uses_axial_battle_map() and not _battle_view_rect().has_point(pos):
		return

	var key = _tile_at_canvas(pos)
	selected_tile = key
	if key.x == -99:
		return

	if _try_unlock(key):
		return

	var controlled_team = _local_control_team()
	if tiles.has(key) and int(tiles[key]["team"]) == controlled_team:
		_pulse(_hex_center(key), _team_color(controlled_team).lightened(0.22))


func _draw() -> void:
	_layout(get_viewport_rect().size)
	draw_set_transform(canvas_offset, 0.0, Vector2(canvas_scale, canvas_scale))

	if screen == SCREEN_DECK:
		_draw_deck_screen()
	elif screen == SCREEN_BATTLE:
		_draw_battle_screen()
	elif screen == SCREEN_GACHA:
		_draw_gacha_screen()
	elif screen == SCREEN_ROOM:
		_draw_room_screen()
	else:
		_draw_lobby_screen()

	if screen != SCREEN_BATTLE:
		_draw_nav()
	if account_center_open:
		_draw_account_center()

	_draw_toast()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _layout(view_size: Vector2) -> void:
	canvas_scale = minf(view_size.x / DESIGN_SIZE.x, view_size.y / DESIGN_SIZE.y)
	canvas_scale = maxf(canvas_scale, 0.001)
	canvas_offset = (view_size - DESIGN_SIZE * canvas_scale) * 0.5
	var play_rect = _battle_view_rect()
	if _uses_axial_battle_map():
		_clamp_board_pan()
		return
	var board_bounds = _board_hex_bounds(Vector2.ZERO)
	board_origin = play_rect.get_center() - board_bounds.get_center()


func _board_hex_bounds(origin: Vector2) -> Rect2:
	var min_pos = Vector2(999999.0, 999999.0)
	var max_pos = Vector2(-999999.0, -999999.0)
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var center = BoardRules.hex_center(Vector2i(x, y), origin, HEX_SIZE)
			for point in BoardRules.hex_points(center, HEX_SIZE):
				min_pos.x = minf(min_pos.x, point.x)
				min_pos.y = minf(min_pos.y, point.y)
				max_pos.x = maxf(max_pos.x, point.x)
				max_pos.y = maxf(max_pos.y, point.y)
	return Rect2(min_pos, max_pos - min_pos)


func _screen_to_canvas(pos: Vector2) -> Vector2:
	return (pos - canvas_offset) / maxf(canvas_scale, 0.001)


func _battle_view_rect() -> Rect2:
	return Rect2(64, 110, 592, 982)


func _reset_multiplayer_board_pan() -> void:
	var view_rect = _battle_view_rect()
	var player_base = _battle_base_key(_local_control_team())
	var base_pos = MultiplayerRules.hex_center(player_base, Vector2.ZERO, HEX_SIZE)
	var desired_pos = view_rect.position + Vector2(view_rect.size.x * 0.5, view_rect.size.y * 0.76)
	board_pan = desired_pos - view_rect.get_center() - base_pos
	_clamp_board_pan()


func _clamp_board_pan() -> void:
	if not _uses_axial_battle_map():
		return
	var view_rect = _battle_view_rect()
	var bounds = multiplayer_board_bounds
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		bounds = MultiplayerRules.board_bounds(tiles, Vector2.ZERO, HEX_SIZE)
	var view_center = view_rect.get_center()
	var margin = HEX_SIZE * 1.5
	var bounds_right = bounds.position.x + bounds.size.x
	var bounds_bottom = bounds.position.y + bounds.size.y
	var min_x = view_rect.position.x + margin - view_center.x - bounds_right
	var max_x = view_rect.position.x + view_rect.size.x - margin - view_center.x - bounds.position.x
	var min_y = view_rect.position.y + margin - view_center.y - bounds_bottom
	var max_y = view_rect.position.y + view_rect.size.y - margin - view_center.y - bounds.position.y
	board_pan.x = clampf(board_pan.x, min_x, max_x)
	board_pan.y = clampf(board_pan.y, min_y, max_y)


func _uses_axial_battle_map() -> bool:
	return battle_mode == BATTLE_MODE_MULTIPLAYER or classic_map_id != ""


func _battle_base_key(team: int) -> Vector2i:
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		return _multiplayer_base_key(team)
	return classic_base_keys.get(team, MultiplayerRules.INVALID_KEY)


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
		if _card_kind(card) == CARD_KIND_ANIMAL and String(card["rarity"]) == "common" and common_count < 8:
			card_counts[id] = 1
			common_count += 1
	if _card_by_id(MINE_CARD_ID).is_empty() == false:
		card_counts[MINE_CARD_ID] = max(1, _card_total_count(MINE_CARD_ID))
		card_levels[MINE_CARD_ID] = max(1, _card_level(MINE_CARD_ID))
	if _card_by_id(COMMON_DEFENSE_CARD_ID).is_empty() == false:
		card_counts[COMMON_DEFENSE_CARD_ID] = max(1, _card_total_count(COMMON_DEFENSE_CARD_ID))
		card_levels[COMMON_DEFENSE_CARD_ID] = max(1, _card_level(COMMON_DEFENSE_CARD_ID))


func _init_deck() -> void:
	deck.clear()
	var owned = _owned_card_ids()
	if owned.is_empty():
		for i in range(DECK_SIZE):
			deck.append("")
		selected_card_id = ""
		return
	for card_id in _mandatory_card_ids():
		if owned.has(card_id) and not deck.has(card_id):
			deck.append(card_id)
	for card_id in owned:
		var id = String(card_id)
		if deck.size() >= DECK_SIZE:
			break
		if id != "" and not deck.has(id):
			deck.append(id)
	for i in range(DECK_SIZE):
		if deck.size() >= DECK_SIZE:
			break
		deck.append(String(owned[i % owned.size()]) if not owned.is_empty() else "")
	_ensure_deck_valid()
	selected_card_id = String(deck[0]) if not deck.is_empty() else ""


func _init_enemy_deck() -> void:
	enemy_deck.clear()
	enemy_card_levels.clear()
	for required_id in _mandatory_card_ids():
		if not _card_by_id(String(required_id)).is_empty() and not enemy_deck.has(required_id):
			enemy_deck.append(String(required_id))
	var common_cards = []
	for card in cards:
		if _card_kind(card) == CARD_KIND_ANIMAL and String(card.get("rarity", "common")) == "common":
			common_cards.append(String(card.get("id", "")))
	var animal_index = 0
	while enemy_deck.size() < DECK_SIZE:
		if common_cards.is_empty():
			enemy_deck.append("rabbit")
		else:
			enemy_deck.append(String(common_cards[animal_index % common_cards.size()]))
		animal_index += 1
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
	rank_db["version"] = RankingRules.DB_VERSION
	if not rank_db.has("player") or typeof(rank_db["player"]) != TYPE_DICTIONARY:
		rank_db["player"] = RankingRules.default_profile()
	rank_db["player"] = RankingRules.normalize_profile(rank_db["player"])
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


func _player_rank_state() -> Dictionary:
	return RankingRules.rank_state_for_profile(_player_profile())


func _current_rank_key() -> String:
	return String(_player_rank_state()["key"])


func _mirror_count_for_rank(rank_key: String) -> int:
	_ensure_rank_database_shape()
	var mirrors = rank_db["mirrors"]
	if mirrors.has(rank_key) and typeof(mirrors[rank_key]) == TYPE_ARRAY:
		return mirrors[rank_key].size()
	return 0


func _start_match(map_id: String = "") -> void:
	battle_mode = BATTLE_MODE_CLASSIC
	classic_requested_map_id = map_id
	var player_rank_state = _player_rank_state()
	active_match_rank_key = String(player_rank_state["key"])
	active_match_player_stars = int(player_rank_state["stars"])
	active_match_mirror = _select_match_mirror(active_match_rank_key)
	_apply_match_mirror(active_match_mirror)
	last_rank_result = {}
	screen = SCREEN_BATTLE
	_reset_battle()
	GameAudio.play_battle_music()
	_toast("%s · %s" % [classic_map_name, "匹配到" + String(active_match_mirror.get("rank_display", String(player_rank_state["display"]))) + "对手"])


func _setup_online_room() -> void:
	online_room_service = get_node_or_null("/root/OnlineRoom")
	if online_room_service == null:
		return
	_connect_online_signal("server_connected", "_on_online_server_connected")
	_connect_online_signal("server_connection_failed", "_on_online_server_connection_failed")
	_connect_online_signal("server_disconnected", "_on_online_server_disconnected")
	_connect_online_signal("operation_completed", "_on_online_operation_completed")
	_connect_online_signal("operation_failed", "_on_online_operation_failed")
	_connect_online_signal("room_snapshot_changed", "_on_online_room_snapshot")
	_connect_online_signal("room_left", "_on_online_room_left")
	_connect_online_signal("match_started", "_on_online_match_started")
	_connect_online_signal("authority_changed", "_on_online_authority_changed")
	_connect_online_signal("battle_command_received", "_on_online_battle_command")
	_connect_online_signal("authority_snapshot_received", "_on_online_authority_snapshot")
	_connect_online_signal("account_state_changed", "_on_account_state_changed")
	if bool(online_room_service.call("is_connected_to_server")):
		online_connection_state = "connected"


func _auto_login_saved_account_on_startup() -> void:
	if get_tree().current_scene != self:
		return
	_auto_login_saved_account()


func _auto_login_saved_account() -> void:
	if online_room_service == null or not online_room_service.has_method("has_saved_login"):
		return
	if bool(online_room_service.call("has_saved_login")):
		_ensure_online_room_connection()


func _connect_online_signal(signal_name: String, method_name: String) -> void:
	if online_room_service == null or not online_room_service.has_signal(signal_name):
		return
	var callback = Callable(self, method_name)
	if not online_room_service.is_connected(signal_name, callback):
		online_room_service.connect(signal_name, callback)


func _open_online_room() -> void:
	screen = SCREEN_ROOM
	pending_equip_card_id = ""
	_ensure_online_room_connection()


func _ensure_online_room_connection() -> bool:
	if online_room_service == null:
		_setup_online_room()
	if online_room_service == null:
		online_connection_state = "unavailable"
		_toast("联网模块未加载")
		return false
	if bool(online_room_service.call("is_connected_to_server")):
		online_connection_state = "connected"
		return true
	if online_connection_state == "connecting":
		return false
	online_connection_state = "connecting"
	var error = int(online_room_service.call("connect_to_server", "", -1, _online_player_name()))
	if error != OK:
		online_connection_state = "error"
		_toast("无法连接互联网房间服务器")
		return false
	_toast("正在连接互联网房间服务器…")
	return false


func _online_player_name() -> String:
	var profile = _player_profile()
	var player_name = String(profile.get("name", "")).strip_edges()
	return player_name if player_name != "" else "玩家"


func _on_online_server_connected(host: String, port: int, _peer_id: int) -> void:
	online_connection_state = "connected"
	_toast("已连接 %s:%d" % [host, port])


func _on_online_server_connection_failed(message: String) -> void:
	online_connection_state = "error"
	_toast(message)


func _on_online_server_disconnected() -> void:
	online_connection_state = "offline"
	_reset_online_room_state()
	if _is_online_match_active():
		_clear_online_match_state()
		screen = SCREEN_ROOM
	_toast("互联网房间服务器已断开")


func _on_online_operation_completed(operation: String, _result: Dictionary) -> void:
	match operation:
		"register_account":
			_toast("账号注册成功，正在登录")
			if account_name_field != null and not account_pending_register_password.is_empty():
				OnlineRoom.login_account(account_name_field.text, account_pending_register_password)
			account_pending_register_password = ""
		"login_account":
			_toast("登录成功，服务器资料已同步")
			if account_password_field != null:
				account_password_field.clear()
			_set_account_fields_visible(false)
		"save_player_profile":
			account_profile_signature = JSON.stringify(_server_profile_snapshot())
		"logout_account":
			_toast("已注销账号")
			if account_name_field != null:
				account_name_field.clear()
			if account_password_field != null:
				account_password_field.clear()
			_set_account_fields_visible(account_center_open)
		"create_room":
			_toast("互联网房间创建成功")
		"join_room":
			GameAudio.play_sfx("room_join")
			_toast("已加入互联网房间")
		"set_ready":
			_toast("准备状态已同步")


func _on_online_operation_failed(operation: String, error: String) -> void:
	if operation == "register_account":
		account_pending_register_password = ""
	GameAudio.play_sfx("ui_error")
	_toast(_online_error_message(operation, error))


func _on_account_state_changed(state: Dictionary) -> void:
	if bool(state.get("logged_in", false)):
		var remote_profile = state.get("profile", {})
		_apply_server_profile(remote_profile)
		account_profile_signature = JSON.stringify(remote_profile)
		_set_account_fields_visible(false)
	else:
		account_profile_signature = ""
		_set_account_fields_visible(account_center_open and not player_agreement_open)


func _online_error_message(operation: String, error: String) -> String:
	var messages = {
		"account_exists": "该账号已经存在",
		"invalid_account": "账号长度需为 3-32 个字符",
		"invalid_password": "密码长度需为 8-72 个字符",
		"invalid_credentials": "账号或密码错误",
		"invalid_session": "登录已失效，请重新登录",
		"storage_error": "服务器保存失败，请稍后重试",
		"room_not_found": "房间码不存在或已经失效",
		"room_full": "房间已满",
		"room_running": "房间已经开战",
		"host_only": "只有房主可以执行此操作",
		"players_not_ready": "仍有真人玩家未准备",
		"room_not_full": "真人未满且电脑补位未开启",
		"room_size_conflict": "目标规模外仍有真人玩家",
		"slot_occupied": "该槽位已被其他玩家占用",
		"inactive_team_slot": "该槽位在当前规模中未启用",
	}
	if messages.has(error):
		return String(messages[error])
	if error != "":
		return error
	return "%s 操作失败" % operation


func _on_online_room_snapshot(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("ok", false)):
		return
	online_room_active = true
	room_invite_code = String(snapshot.get("room_code", ""))
	room_players_per_side = clampi(int(snapshot.get("players_per_side", 1)), 1, 3)
	room_fill_with_ai = bool(snapshot.get("fill_with_ai", false))
	online_room_is_host = bool(snapshot.get("is_host", false))
	online_room_can_start = bool(snapshot.get("can_start", false))
	local_team_id = int(snapshot.get("local_team_id", PLAYER))
	online_room_slots = (snapshot.get("slots", []) as Array).duplicate(true)
	room_active_team_ids = _room_active_teams()
	room_human_teams.clear()
	room_pending_invites.clear()
	online_room_ready = false
	for slot_value in online_room_slots:
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = slot_value
		if String(slot.get("kind", "")) != "human":
			continue
		var team = int(slot.get("team_id", NEUTRAL))
		room_human_teams[team] = String(slot.get("display_name", "玩家%d" % team))
		if bool(slot.get("is_local", false)):
			online_room_ready = bool(slot.get("ready", false))
	if screen != SCREEN_BATTLE:
		screen = SCREEN_ROOM


func _on_online_room_left() -> void:
	_reset_online_room_state()
	_clear_online_match_state()
	screen = SCREEN_ROOM
	_toast("已离开互联网房间")


func _reset_online_room_state() -> void:
	online_room_active = false
	online_room_is_host = false
	online_room_can_start = false
	online_room_ready = false
	online_room_slots.clear()
	room_invite_code = ""
	room_human_teams.clear()
	room_pending_invites.clear()
	local_team_id = PLAYER
	room_active_team_ids = _room_active_teams()


func _on_online_match_started(match_data: Dictionary) -> void:
	var match_id = String(match_data.get("match_id", ""))
	var map_id = String(match_data.get("map_id", ""))
	if match_id == "" or map_id == "":
		_on_online_operation_failed("start_room", "比赛初始化数据不完整")
		return
	var room_snapshot = match_data.get("room_snapshot", {})
	if typeof(room_snapshot) == TYPE_DICTIONARY:
		_on_online_room_snapshot(room_snapshot)
	online_match_id = match_id
	online_match_authority = bool(match_data.get("is_authority", false))
	local_team_id = int(match_data.get("local_team_id", local_team_id))
	online_snapshot_timer = 0.0
	online_simulation_accumulator = 0.0
	online_snapshot_sequence = 0
	online_last_received_sequence = -1
	online_command_sequence = 0
	online_last_command_sequences.clear()
	multiplayer_free_for_all = false
	battle_mode = BATTLE_MODE_MULTIPLAYER
	room_players_per_side = clampi(int(match_data.get("players_per_side", room_players_per_side)), 1, 3)
	room_requested_map_id = map_id
	room_match_seed = int(match_data.get("match_seed", 0))
	var player_rank_state = _player_rank_state()
	active_match_rank_key = String(player_rank_state["key"])
	active_match_player_stars = int(player_rank_state["stars"])
	active_match_mirror = {}
	_init_enemy_deck()
	last_rank_result = {}
	screen = SCREEN_BATTLE
	_reset_battle()
	GameAudio.play_battle_music()
	_toast("互联网 %dV%d · %s" % [room_players_per_side, room_players_per_side, room_map_name])


func _on_online_authority_changed(match_data: Dictionary) -> void:
	if String(match_data.get("match_id", "")) != online_match_id:
		return
	var was_authority = online_match_authority
	online_match_authority = bool(match_data.get("is_authority", false))
	if online_match_authority and not was_authority:
		online_snapshot_timer = 0.0
		online_simulation_accumulator = 0.0
		_toast("房主已离开，你已接管战斗同步")
	elif was_authority and not online_match_authority:
		_toast("战斗同步权威已迁移")


func _on_online_battle_command(envelope: Dictionary) -> void:
	if not online_match_authority or String(envelope.get("match_id", "")) != online_match_id:
		return
	var command_value = envelope.get("command", {})
	if typeof(command_value) != TYPE_DICTIONARY:
		return
	var command: Dictionary = command_value
	if String(command.get("action", "")) != "unlock_tile":
		return
	var peer_id = int(envelope.get("sender_peer_id", 0))
	var sequence = int(command.get("sequence", -1))
	if peer_id <= 1 or sequence <= int(online_last_command_sequences.get(peer_id, -1)):
		return
	online_last_command_sequences[peer_id] = sequence
	var team = int(envelope.get("sender_team_id", NEUTRAL))
	if not room_active_team_ids.has(team) or not _is_multiplayer_team_alive(team):
		return
	var key = Vector2i(int(command.get("q", -9999)), int(command.get("r", -9999)))
	if not tiles.has(key):
		return
	_try_unlock_for_team(key, team, team == local_team_id)
	online_snapshot_timer = 0.0
	online_simulation_accumulator = 0.0


func _on_online_authority_snapshot(envelope: Dictionary) -> void:
	if online_match_authority or String(envelope.get("match_id", "")) != online_match_id:
		return
	var sequence = int(envelope.get("sequence", -1))
	if sequence <= online_last_received_sequence:
		return
	var snapshot_value = envelope.get("snapshot", {})
	if typeof(snapshot_value) != TYPE_DICTIONARY:
		return
	online_last_received_sequence = sequence
	_apply_online_battle_snapshot(snapshot_value)


func _is_online_match_active() -> bool:
	return online_match_id != "" and battle_mode == BATTLE_MODE_MULTIPLAYER


func _local_control_team() -> int:
	return local_team_id if _is_online_match_active() else PLAYER


func _clear_online_match_state() -> void:
	online_match_id = ""
	online_match_authority = false
	online_snapshot_timer = 0.0
	online_snapshot_sequence = 0
	online_last_received_sequence = -1
	online_command_sequence = 0
	online_last_command_sequences.clear()
	local_team_id = PLAYER
	room_match_seed = 0


func _update_online_authority_snapshot(delta: float) -> void:
	if online_room_service == null or not bool(online_room_service.call("is_connected_to_server")):
		return
	online_snapshot_timer -= delta
	if online_snapshot_timer > 0.0:
		return
	online_snapshot_timer = ONLINE_SNAPSHOT_INTERVAL
	online_snapshot_sequence += 1
	var snapshot = _online_battle_snapshot()
	snapshot["sequence"] = online_snapshot_sequence
	online_room_service.call("send_authority_snapshot", snapshot)


func _update_online_authority_battle(delta: float) -> void:
	online_simulation_accumulator += minf(delta, 0.25)
	while online_simulation_accumulator >= ONLINE_SIMULATION_STEP and not game_over:
		online_simulation_accumulator -= ONLINE_SIMULATION_STEP
		_update_battle(ONLINE_SIMULATION_STEP)


func _online_battle_snapshot() -> Dictionary:
	return {
		"match_id": online_match_id,
		"battle_timer": battle_timer,
		"income_timer": income_timer,
		"tiles": tiles.duplicate(true),
		"units": units.duplicate(true),
		"effects": effects.duplicate(true),
		"battle_match_seed": battle_match_seed,
		"team_territory_colors": team_territory_colors.duplicate(true),
		"team_unlocked_colors": team_unlocked_colors.duplicate(true),
		"gold": gold,
		"enemy_gold": enemy_gold,
		"multiplayer_gold": multiplayer_gold.duplicate(true),
		"multiplayer_ai_timers": multiplayer_ai_timers.duplicate(true),
		"multiplayer_alive": multiplayer_alive.duplicate(true),
		"multiplayer_placements": multiplayer_placements.duplicate(true),
		"multiplayer_team_decks": multiplayer_team_decks.duplicate(true),
		"multiplayer_team_card_levels": multiplayer_team_card_levels.duplicate(true),
		"enemy_deck": enemy_deck.duplicate(),
		"enemy_card_levels": enemy_card_levels.duplicate(true),
		"multiplayer_placement": multiplayer_placement,
		"tower_purchase_counts": tower_purchase_counts.duplicate(true),
		"next_unit_id": next_unit_id,
		"game_over": game_over,
		"room_result": room_result,
		"authority_room_result": authority_room_result,
		"result_text": result_text,
	}


func _apply_online_battle_snapshot(snapshot: Dictionary) -> void:
	if String(snapshot.get("match_id", "")) != online_match_id:
		return
	var was_game_over = game_over
	if typeof(snapshot.get("tiles", null)) == TYPE_DICTIONARY:
		tiles = (snapshot["tiles"] as Dictionary).duplicate(true)
	if typeof(snapshot.get("units", null)) == TYPE_ARRAY:
		units = (snapshot["units"] as Array).duplicate(true)
	if typeof(snapshot.get("effects", null)) == TYPE_ARRAY:
		effects = (snapshot["effects"] as Array).duplicate(true)
	battle_match_seed = int(snapshot.get("battle_match_seed", battle_match_seed))
	if typeof(snapshot.get("team_territory_colors", null)) == TYPE_DICTIONARY:
		team_territory_colors = (snapshot["team_territory_colors"] as Dictionary).duplicate(true)
	if typeof(snapshot.get("team_unlocked_colors", null)) == TYPE_DICTIONARY:
		team_unlocked_colors = (snapshot["team_unlocked_colors"] as Dictionary).duplicate(true)
	battle_timer = maxf(0.0, float(snapshot.get("battle_timer", battle_timer)))
	income_timer = float(snapshot.get("income_timer", income_timer))
	gold = int(snapshot.get("gold", gold))
	enemy_gold = int(snapshot.get("enemy_gold", enemy_gold))
	if typeof(snapshot.get("multiplayer_gold", null)) == TYPE_DICTIONARY:
		multiplayer_gold = (snapshot["multiplayer_gold"] as Dictionary).duplicate(true)
	if typeof(snapshot.get("multiplayer_ai_timers", null)) == TYPE_DICTIONARY:
		multiplayer_ai_timers = (snapshot["multiplayer_ai_timers"] as Dictionary).duplicate(true)
	if typeof(snapshot.get("multiplayer_alive", null)) == TYPE_DICTIONARY:
		multiplayer_alive = (snapshot["multiplayer_alive"] as Dictionary).duplicate(true)
	if typeof(snapshot.get("multiplayer_placements", null)) == TYPE_DICTIONARY:
		multiplayer_placements = (snapshot["multiplayer_placements"] as Dictionary).duplicate(true)
	if typeof(snapshot.get("multiplayer_team_decks", null)) == TYPE_DICTIONARY:
		multiplayer_team_decks = (snapshot["multiplayer_team_decks"] as Dictionary).duplicate(true)
	if typeof(snapshot.get("multiplayer_team_card_levels", null)) == TYPE_DICTIONARY:
		multiplayer_team_card_levels = (snapshot["multiplayer_team_card_levels"] as Dictionary).duplicate(true)
	if typeof(snapshot.get("enemy_deck", null)) == TYPE_ARRAY:
		enemy_deck = (snapshot["enemy_deck"] as Array).duplicate()
	if typeof(snapshot.get("enemy_card_levels", null)) == TYPE_DICTIONARY:
		enemy_card_levels = (snapshot["enemy_card_levels"] as Dictionary).duplicate(true)
	multiplayer_placement = int(snapshot.get("multiplayer_placement", multiplayer_placement))
	if typeof(snapshot.get("tower_purchase_counts", null)) == TYPE_DICTIONARY:
		tower_purchase_counts = (snapshot["tower_purchase_counts"] as Dictionary).duplicate(true)
	next_unit_id = int(snapshot.get("next_unit_id", next_unit_id))
	game_over = bool(snapshot.get("game_over", game_over))
	_refresh_combat_building_keys()
	multiplayer_board_bounds = MultiplayerRules.board_bounds(tiles, Vector2.ZERO, HEX_SIZE)
	if game_over and not was_game_over:
		_apply_online_local_result(String(snapshot.get("authority_room_result", snapshot.get("room_result", "draw"))))
	elif not game_over:
		room_result = ""
		authority_room_result = ""
		result_text = ""


func _apply_online_local_result(authority_outcome: String) -> void:
	authority_room_result = authority_outcome
	var local_outcome = _local_outcome_for_authority_result(authority_outcome)
	room_result = local_outcome
	result_text = "胜利" if local_outcome == "win" else ("平局" if local_outcome == "draw" else "失败")
	GameAudio.play_result("victory" if local_outcome == "win" else ("draw" if local_outcome == "draw" else "defeat"))
	var reward = _room_result_rewards(local_outcome)
	last_multiplayer_star_delta = int(reward.get("star_delta", -1))
	last_battle_reward_tickets = int(reward.get("gacha_tickets", 1))
	if battle_reward_given:
		return
	battle_reward_given = true
	gacha_tickets += last_battle_reward_tickets
	_apply_multiplayer_rank_result(local_outcome, last_multiplayer_star_delta)
	_rebuild_result_player_entries()


func _local_outcome_for_authority_result(authority_outcome: String) -> String:
	var local_outcome = authority_outcome
	if _multiplayer_side_for_team(local_team_id) == 1:
		if authority_outcome == "win":
			local_outcome = "loss"
		elif authority_outcome == "loss":
			local_outcome = "win"
	return local_outcome if local_outcome in ["win", "draw", "loss"] else "draw"


func _handle_online_room_keyboard(event: InputEvent) -> bool:
	if online_room_active or not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.keycode == KEY_BACKSPACE:
		online_room_join_code = online_room_join_code.left(maxi(0, online_room_join_code.length() - 1))
		return true
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_request_online_join()
		return true
	if event.ctrl_pressed and event.keycode == KEY_V:
		online_room_join_code = _sanitize_online_room_code(DisplayServer.clipboard_get())
		return true
	var character = String.chr(event.unicode)
	if character >= "0" and character <= "9" and online_room_join_code.length() < ONLINE_ROOM_CODE_LENGTH:
		online_room_join_code += character
		return true
	return false


func _sanitize_online_room_code(value: String) -> String:
	var result = ""
	for index in range(value.length()):
		var character = String.chr(value.unicode_at(index))
		if character >= "0" and character <= "9":
			result += character
			if result.length() >= ONLINE_ROOM_CODE_LENGTH:
				break
	return result


func _request_online_create_room() -> void:
	if not _ensure_online_room_connection():
		return
	online_room_service.call(
		"create_room",
		_online_player_name(),
		room_players_per_side,
		{"fill_with_ai": room_fill_with_ai}
	)


func _request_online_join() -> void:
	if online_room_join_code.length() != ONLINE_ROOM_CODE_LENGTH:
		_toast("请输入6位房间码")
		return
	if not _ensure_online_room_connection():
		return
	online_room_service.call("join_room", online_room_join_code, _online_player_name())


func _reset_room() -> void:
	room_players_per_side = 1
	room_fill_with_ai = true
	room_invite_code = _generate_room_invite_code()
	room_human_teams.clear()
	room_human_teams[PLAYER] = "我"
	room_pending_invites.clear()
	room_active_team_ids = _room_active_teams()
	room_base_keys.clear()
	room_map_id = ""
	room_map_name = ""
	room_match_data.clear()
	room_requested_map_id = ""
	room_match_seed = 0
	free_for_all_room_snapshot.clear()


func _capture_room_state_for_free_for_all() -> Dictionary:
	return {
		"players_per_side": room_players_per_side,
		"fill_with_ai": room_fill_with_ai,
		"invite_code": room_invite_code,
		"human_teams": room_human_teams.duplicate(true),
		"pending_invites": room_pending_invites.duplicate(true),
		"active_team_ids": room_active_team_ids.duplicate(),
		"base_keys": room_base_keys.duplicate(true),
		"map_id": room_map_id,
		"map_name": room_map_name,
		"match_data": room_match_data.duplicate(true),
		"requested_map_id": room_requested_map_id,
		"match_seed": room_match_seed,
	}


func _restore_room_state_after_free_for_all() -> void:
	if free_for_all_room_snapshot.is_empty():
		_reset_room()
		return
	room_players_per_side = int(free_for_all_room_snapshot.get("players_per_side", 1))
	room_fill_with_ai = bool(free_for_all_room_snapshot.get("fill_with_ai", true))
	room_invite_code = String(free_for_all_room_snapshot.get("invite_code", ""))
	room_human_teams = (free_for_all_room_snapshot.get("human_teams", {PLAYER: "我"}) as Dictionary).duplicate(true)
	room_pending_invites = (free_for_all_room_snapshot.get("pending_invites", {}) as Dictionary).duplicate(true)
	room_active_team_ids = (free_for_all_room_snapshot.get("active_team_ids", [PLAYER, 4]) as Array).duplicate()
	room_base_keys = (free_for_all_room_snapshot.get("base_keys", {}) as Dictionary).duplicate(true)
	room_map_id = String(free_for_all_room_snapshot.get("map_id", ""))
	room_map_name = String(free_for_all_room_snapshot.get("map_name", ""))
	room_match_data = (free_for_all_room_snapshot.get("match_data", {}) as Dictionary).duplicate(true)
	room_requested_map_id = String(free_for_all_room_snapshot.get("requested_map_id", ""))
	room_match_seed = int(free_for_all_room_snapshot.get("match_seed", 0))
	free_for_all_room_snapshot.clear()


func _generate_room_invite_code() -> String:
	const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	for _index in range(6):
		code += CODE_ALPHABET[randi() % CODE_ALPHABET.length()]
	return code


func _room_active_teams() -> Array:
	var result = []
	for index in range(room_players_per_side):
		result.append(1 + index)
	for index in range(room_players_per_side):
		result.append(4 + index)
	return result


func _set_room_size(players_per_side: int) -> void:
	if online_room_active:
		if not online_room_is_host:
			_toast("只有房主可以切换房间规模")
			return
		online_room_service.call("update_room_options", {
			"players_per_side": clampi(players_per_side, 1, 3),
			"fill_with_ai": room_fill_with_ai,
		})
		return
	room_players_per_side = clampi(players_per_side, 1, 3)
	GameAudio.play_sfx("ui_click")
	room_active_team_ids = _room_active_teams()
	for team in room_human_teams.keys().duplicate():
		if int(team) != PLAYER and not room_active_team_ids.has(int(team)):
			room_human_teams.erase(team)
	for team in room_pending_invites.keys().duplicate():
		if not room_active_team_ids.has(int(team)):
			room_pending_invites.erase(team)
	_toast("已切换为%dV%d" % [room_players_per_side, room_players_per_side])


func room_accept_invite(player_name: String, side: String = "A", slot_index: int = -1) -> bool:
	var first_team = 1 if side.to_upper() == "A" else 4
	var start_index = 1 if first_team == 1 else 0
	var candidate_indices = []
	if slot_index >= 0:
		candidate_indices.append(slot_index)
	else:
		for index in range(start_index, room_players_per_side):
			candidate_indices.append(index)
	for index in candidate_indices:
		if index < start_index or index >= room_players_per_side:
			continue
		var team = first_team + index
		if room_human_teams.has(team):
			continue
		room_human_teams[team] = player_name.strip_edges() if player_name.strip_edges() != "" else "玩家%d" % team
		room_pending_invites.erase(team)
		GameAudio.play_sfx("room_join")
		_toast("%s 已加入%s方" % [String(room_human_teams[team]), "我" if first_team == 1 else "对"])
		return true
	return false


func _copy_room_invite(team: int) -> void:
	if not room_active_team_ids.has(team) or room_human_teams.has(team):
		return
	if online_room_active:
		DisplayServer.clipboard_set(room_invite_code)
		GameAudio.play_sfx("ui_confirm")
		_toast("房间码已复制，发给其他玩家即可加入")
		return
	room_pending_invites[team] = true
	DisplayServer.clipboard_set(room_invite_code)
	GameAudio.play_sfx("ui_confirm")
	_toast("房间码已复制，等待玩家加入")


func _room_can_start() -> bool:
	if online_room_active:
		return online_room_is_host and online_room_can_start
	if room_fill_with_ai:
		return true
	for team in room_active_team_ids:
		if not room_human_teams.has(team):
			return false
	return true


func _start_lobby_multiplayer_match() -> void:
	_start_multiplayer_match("", MultiplayerRules.MAX_PLAYERS_PER_SIDE, true)


func _start_multiplayer_match(map_id: String = "", players_per_side: int = -1, free_for_all: bool = false) -> void:
	multiplayer_free_for_all = free_for_all
	if multiplayer_free_for_all:
		free_for_all_room_snapshot = _capture_room_state_for_free_for_all()
		room_players_per_side = MultiplayerRules.MAX_PLAYERS_PER_SIDE
		room_fill_with_ai = true
		room_human_teams.clear()
		room_human_teams[PLAYER] = "我"
		room_pending_invites.clear()
	elif players_per_side > 0:
		_set_room_size(players_per_side)
	if not multiplayer_free_for_all and not _room_can_start():
		GameAudio.play_sfx("ui_error")
		_toast("仍有空位，请邀请玩家或开启电脑补位")
		return
	battle_mode = BATTLE_MODE_MULTIPLAYER
	room_requested_map_id = map_id
	room_active_team_ids = _room_active_teams()
	var player_rank_state = _player_rank_state()
	active_match_rank_key = String(player_rank_state["key"])
	active_match_player_stars = int(player_rank_state["stars"])
	active_match_mirror = {}
	_init_enemy_deck()
	last_rank_result = {}
	screen = SCREEN_BATTLE
	_reset_battle()
	GameAudio.play_battle_music()
	if multiplayer_free_for_all:
		_toast("6人自由混战 · %s" % [room_map_name if room_map_name != "" else "随机地图"])
	else:
		_toast("%dV%d · %s" % [room_players_per_side, room_players_per_side, room_map_name if room_map_name != "" else "随机地图"])


func _return_to_lobby() -> void:
	if _is_online_match_active():
		if online_room_service != null and bool(online_room_service.call("is_connected_to_server")):
			online_room_service.call("leave_room")
		_clear_online_match_state()
		screen = SCREEN_ROOM
		battle_mode = BATTLE_MODE_CLASSIC
		_reset_battle()
		GameAudio.play_menu_music()
		return
	var was_free_for_all = battle_mode == BATTLE_MODE_MULTIPLAYER and multiplayer_free_for_all
	var return_to_room = battle_mode == BATTLE_MODE_MULTIPLAYER and not multiplayer_free_for_all
	screen = SCREEN_ROOM if return_to_room else SCREEN_LOBBY
	battle_mode = BATTLE_MODE_CLASSIC
	_reset_battle()
	if was_free_for_all:
		_restore_room_state_after_free_for_all()
	multiplayer_free_for_all = false
	GameAudio.play_menu_music()


func _select_match_mirror(rank_key: String) -> Dictionary:
	_ensure_rank_database_shape()
	var mirrors = rank_db["mirrors"]
	var pool = []
	var other_player_pool = []
	var signatures = {}
	var current_player_id = String(_player_profile().get("player_id", "local_player"))
	if mirrors.has(rank_key) and typeof(mirrors[rank_key]) == TYPE_ARRAY:
		for mirror in mirrors[rank_key]:
			if typeof(mirror) == TYPE_DICTIONARY:
				var signature = RankAIDecks.deck_signature(mirror.get("deck", []))
				if signature.is_empty() or signatures.has(signature):
					continue
				signatures[signature] = true
				pool.append(mirror)
				if String(mirror.get("player_id", "")) != current_player_id:
					other_player_pool.append(mirror)
	var baseline_pool = RankAIDecks.mirrors_for_rank(rank_key)
	for mirror in baseline_pool:
		mirror["rank_display"] = RankingRules.display_for_key_and_stars(rank_key, 1)
	if rank_key not in ["bronze", "silver"] and not baseline_pool.is_empty() and (other_player_pool.is_empty() or randf() < 0.75):
		return baseline_pool[randi() % baseline_pool.size()].duplicate(true)
	if not other_player_pool.is_empty():
		return other_player_pool[randi() % other_player_pool.size()].duplicate(true)
	if not pool.is_empty():
		return pool[randi() % pool.size()].duplicate(true)
	if not baseline_pool.is_empty():
		return baseline_pool[randi() % baseline_pool.size()].duplicate(true)
	return _generated_match_mirror(rank_key)


func _generated_match_mirror(rank_key: String) -> Dictionary:
	var rank = RankingRules.rank_for_key(rank_key)
	var stars = 1
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
		"rank_display": RankingRules.display_for_key_and_stars(rank_key, stars),
		"stars": stars,
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


func _card_kind(card: Dictionary) -> String:
	var id = String(card.get("id", ""))
	if id == MINE_CARD_ID:
		return CARD_KIND_MINE
	if id.begins_with("defense_"):
		return CARD_KIND_DEFENSE
	var tags = card.get("tags", [])
	if typeof(tags) == TYPE_ARRAY:
		for tag in tags:
			var text = String(tag)
			if text == "mine" or text == "gold_mine":
				return CARD_KIND_MINE
			if text == "defense" or text == "tower":
				return CARD_KIND_DEFENSE
	return CARD_KIND_ANIMAL


func _card_has_tag(card: Dictionary, required_tag: String) -> bool:
	var tags = card.get("tags", [])
	if typeof(tags) != TYPE_ARRAY:
		return false
	for tag in tags:
		if String(tag) == required_tag:
			return true
	return false


func _card_is_flying(card: Dictionary) -> bool:
	return _card_has_tag(card, "flying")


func _card_kind_by_id(card_id: String) -> String:
	var card = _card_by_id(card_id)
	if card.is_empty():
		return CARD_KIND_ANIMAL
	return _card_kind(card)


func _is_animal_card_id(card_id: String) -> bool:
	return _card_kind_by_id(card_id) == CARD_KIND_ANIMAL


func _is_defense_card_id(card_id: String) -> bool:
	return _card_kind_by_id(card_id) == CARD_KIND_DEFENSE


func _is_mine_card_id(card_id: String) -> bool:
	return _card_kind_by_id(card_id) == CARD_KIND_MINE


func _mandatory_card_ids() -> Array:
	var result = []
	if not _card_by_id(MINE_CARD_ID).is_empty():
		result.append(MINE_CARD_ID)
	if not _card_by_id(COMMON_DEFENSE_CARD_ID).is_empty():
		result.append(COMMON_DEFENSE_CARD_ID)
	return result


func _deck_defense_count(candidate_deck: Array) -> int:
	var count = 0
	for card_id in candidate_deck:
		if _is_defense_card_id(String(card_id)):
			count += 1
	return count


func _deck_has_mine(candidate_deck: Array) -> bool:
	for card_id in candidate_deck:
		if _is_mine_card_id(String(card_id)):
			return true
	return false


func _deck_has_common_defense(candidate_deck: Array) -> bool:
	for card_id in candidate_deck:
		var card = _card_by_id(String(card_id))
		if not card.is_empty() and _card_kind(card) == CARD_KIND_DEFENSE and String(card.get("rarity", "common")) == "common":
			return true
	return false


func _deck_meets_required_cards(candidate_deck: Array) -> bool:
	return _deck_has_mine(candidate_deck) and _deck_has_common_defense(candidate_deck)


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


func _uses_enemy_roster(team: int) -> bool:
	return team == ENEMY or (battle_mode == BATTLE_MODE_MULTIPLAYER and team != PLAYER)


func _team_deck(team: int) -> Array:
	if battle_mode == BATTLE_MODE_MULTIPLAYER and multiplayer_team_decks.has(team):
		var team_roster = multiplayer_team_decks[team]
		return team_roster if typeof(team_roster) == TYPE_ARRAY else []
	return enemy_deck if _uses_enemy_roster(team) else deck


func _team_deck_card(team: int, index: int) -> String:
	var roster = _team_deck(team)
	if roster.is_empty():
		return "rabbit"
	return String(roster[index % roster.size()])


func _card_level_for_team(card_id: String, team: int) -> int:
	if battle_mode == BATTLE_MODE_MULTIPLAYER and multiplayer_team_card_levels.has(team):
		var levels = multiplayer_team_card_levels[team]
		if typeof(levels) == TYPE_DICTIONARY:
			return CardRules.card_level(levels, card_id)
	if _uses_enemy_roster(team):
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
	return _card_stats_with_levels(card, card_levels)


func _card_stats_for_team(card: Dictionary, team: int) -> Dictionary:
	if battle_mode == BATTLE_MODE_MULTIPLAYER and multiplayer_team_card_levels.has(team):
		var levels = multiplayer_team_card_levels[team]
		if typeof(levels) == TYPE_DICTIONARY:
			return _card_stats_with_levels(card, levels)
	if _uses_enemy_roster(team):
		return _card_stats_with_levels(card, enemy_card_levels)
	return _card_stats(card)


func _card_stats_with_levels(card: Dictionary, levels: Dictionary) -> Dictionary:
	var stats = CardRules.card_stats(card, levels)
	if _card_kind(card) != CARD_KIND_DEFENSE:
		return stats
	stats["attack_range"] = float(stats.get("attack_range", 0.0)) + DEFENSE_TOWER_RANGE_BONUS
	stats["summon_interval_sec"] = DEFENSE_TOWER_ATTACK_INTERVAL
	return stats


func _card_skill_text(card: Dictionary) -> String:
	var skill_text = _card_display_skill_text(card, true)
	return skill_text if skill_text != "" else "无技能"


func _card_display_skill_text(card: Dictionary, include_no_skill: bool) -> String:
	var base_skill_text = String(card.get("skill_text", ""))
	if String(card.get("skill_effect", "")) == "summon":
		var summon_text = _card_extra_summon_skill_text(card)
		if summon_text != "":
			return summon_text
	var is_no_skill = base_skill_text == "" or base_skill_text.begins_with("无技能")
	if not is_no_skill:
		return base_skill_text
	var parts = []
	var structured_text = _card_structured_skill_text(card)
	if structured_text != "":
		parts.append(structured_text)
	else:
		var speed_text = _card_speed_skill_text(card)
		if speed_text != "":
			parts.append(speed_text)
	if parts.is_empty() and include_no_skill:
		parts.append("无技能")
	return "；".join(parts)


func _card_structured_skill_text(card: Dictionary) -> String:
	if _card_kind(card) != CARD_KIND_ANIMAL:
		return ""
	var trigger = String(card.get("skill_trigger", ""))
	var effect = String(card.get("skill_effect", ""))
	if effect == "":
		return _card_speed_skill_text(card)
	match effect:
		"summon":
			return _card_extra_summon_skill_text(card)
		"slow":
			return "攻击时减速目标" if trigger == "on_attack" else "减速目标"
		"stun":
			return "登场时眩晕附近敌人" if trigger == "on_spawn" else "眩晕目标"
		"shield":
			return "获得护盾" if trigger == "on_spawn" else "提供护盾"
		"buff_attack":
			return "提高友军攻击"
		"buff_hp":
			return "提高友军生命"
		"buff_speed":
			return "提高移动速度"
		"gold":
			return _card_gold_skill_text(card, trigger)
		"heal", "repair":
			return "治疗友军"
		"thorns":
			return "受到伤害时反击"
		"execute":
			return "攻击低生命目标时斩杀"
		"copy":
			return "复制友军效果"
		"revive":
			return "阵亡后返回战场"
		_:
			return _card_speed_skill_text(card)


func _card_gold_skill_text(card: Dictionary, trigger: String) -> String:
	var amount = maxi(1, roundi(float(card.get("skill_power", 1.0))))
	var chance = clampf(float(card.get("skill_chance", 1.0)), 0.0, 1.0)
	match trigger:
		"on_death":
			return "阵亡时，获得%d金币" % amount
		"on_ally_death":
			return "友军阵亡时，获得%d金币" % amount
		"on_capture":
			return "参与占领后，获得%d金币" % amount
		"on_interval":
			return "每%d秒，获得%d金币" % [maxi(1, roundi(float(card.get("skill_cooldown_sec", 1.0)))), amount]
		"on_attack":
			if chance < 1.0:
				return "攻击后，%d%%概率获得%d金币" % [roundi(chance * 100.0), amount]
			return "攻击后，获得%d金币" % amount
		"on_damage":
			return "受伤后，获得%d金币" % amount
		"on_spawn":
			return "登场时，获得%d金币" % amount
	return "获得%d金币" % amount


func _card_speed_skill_text(card: Dictionary) -> String:
	if _card_kind(card) != CARD_KIND_ANIMAL:
		return ""
	var speed = float(card.get("base_move_speed", card.get("move_speed", 0.0)))
	if speed >= CARD_SPEED_SUPER_FAST_THRESHOLD:
		return "速度超快"
	if speed >= CARD_SPEED_FAST_THRESHOLD:
		return "速度快"
	return ""


func _card_extra_summon_skill_text(card: Dictionary) -> String:
	if _card_kind(card) != CARD_KIND_ANIMAL or String(card.get("skill_effect", "")) != "summon":
		return ""
	var animal_name = String(card.get("name", ""))
	if String(card.get("skill_trigger", "")) == "on_death":
		return "阵亡时，在原位置召唤1只%s" % animal_name
	return "召唤时，额外召唤1只%s" % animal_name


func _attack_range_label(value: float) -> String:
	return CardRules.attack_range_label(value, HEX_SIZE)


func _try_upgrade_selected_card() -> void:
	var card_id = selected_card_id
	if card_id == "" or _card_total_count(card_id) <= 0:
		GameAudio.play_sfx("ui_error")
		_toast("未拥有该卡牌")
		return
	var cost = _next_upgrade_cost(card_id)
	if cost < 0:
		GameAudio.play_sfx("ui_error")
		_toast("已满级")
		return
	if _card_spare_count(card_id) < cost:
		GameAudio.play_sfx("ui_error")
		_toast("碎片不足：需要%d，当前%d" % [cost, _card_spare_count(card_id)])
		return
	card_counts[card_id] = _card_total_count(card_id) - cost
	card_levels[card_id] = _card_level(card_id) + 1
	detail_pulse_timer = DETAIL_PULSE_SECONDS
	detail_upgrade_motion_timer = DETAIL_UPGRADE_MOTION_SECONDS
	GameAudio.play_sfx("card_upgrade")
	_toast("升级成功 Lv.%d" % _card_level(card_id))


func _reset_battle() -> void:
	tiles.clear()
	units.clear()
	effects.clear()
	selected_tile = Vector2i(-99, -99)
	combat_building_keys.clear()
	gold = STARTING_GOLD
	enemy_gold = STARTING_GOLD
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		battle_timer = MULTIPLAYER_FREE_FOR_ALL_TIME if multiplayer_free_for_all else MULTIPLAYER_BATTLE_TIME
	else:
		battle_timer = BATTLE_TIME
	income_timer = INCOME_INTERVAL
	enemy_timer = ENEMY_FIRST_UNLOCK_DELAY
	game_over = false
	pause_open = false
	battle_reward_given = false
	last_battle_reward_tickets = 0
	result_player_entries.clear()
	result_players_scroll = 0.0
	result_text = ""
	next_unit_id = 1
	board_pointer_down = false
	board_pointer_dragged = false
	board_pointer_started_in_view = false
	board_pointer_distance = 0.0
	multiplayer_placement = 0
	last_multiplayer_star_delta = 0
	room_result = ""
	authority_room_result = ""
	tower_purchase_counts.clear()
	team_territory_colors.clear()
	team_unlocked_colors.clear()

	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		var requested_seed = room_match_seed if _is_online_match_active() else 0
		if multiplayer_free_for_all:
			room_match_data = MultiplayerRules.create_free_for_all_match(
				_board_cell_type_rows(),
				requested_seed
			)
		else:
			room_match_data = MultiplayerRules.create_match(
				room_players_per_side,
				room_requested_map_id,
				_board_cell_type_rows(),
				requested_seed
			)
		if room_match_data.is_empty():
			if multiplayer_free_for_all:
				room_match_data = MultiplayerRules.create_free_for_all_match([], requested_seed)
			else:
				room_players_per_side = 1
				room_match_data = MultiplayerRules.create_match(
					1,
					"",
					_board_cell_type_rows(),
					requested_seed
				)
		tiles = room_match_data.get("tiles", {})
		room_active_team_ids = room_match_data.get("team_ids", _room_active_teams()).duplicate()
		room_base_keys = room_match_data.get("base_keys", {}).duplicate(true)
		room_map_id = String(room_match_data.get("map_id", ""))
		room_map_name = String(room_match_data.get("map_name", room_map_id))
		room_requested_map_id = room_map_id
		room_match_seed = int(room_match_data.get("match_seed", requested_seed))
		battle_match_seed = room_match_seed
		_initialize_battle_team_colors(battle_match_seed)
		_init_multiplayer_state()
		multiplayer_board_bounds = MultiplayerRules.board_bounds(tiles, Vector2.ZERO, HEX_SIZE)
		_rebuild_ground_navigation()
		_reset_multiplayer_board_pan()
		return

	_reset_classic_map()


func _reset_classic_map() -> void:
	var match_data = MultiplayerRules.create_match(
		1,
		classic_requested_map_id,
		_board_cell_type_rows()
	)
	if match_data.is_empty():
		match_data = MultiplayerRules.create_match(1, "", _board_cell_type_rows())
	classic_map_id = String(match_data.get("map_id", ""))
	classic_map_name = String(match_data.get("map_name", classic_map_id))
	battle_match_seed = int(match_data.get("match_seed", 0))
	var generated_base_keys: Dictionary = match_data.get("base_keys", {})
	classic_base_keys = {
		PLAYER: generated_base_keys.get(1, MultiplayerRules.INVALID_KEY),
		ENEMY: generated_base_keys.get(4, MultiplayerRules.INVALID_KEY),
	}
	var generated_tiles: Dictionary = match_data.get("tiles", {})
	for key in generated_tiles.keys():
		var tile: Dictionary = generated_tiles[key].duplicate(true)
		for field in ["team", "occupier", "territory_team"]:
			if int(tile.get(field, NEUTRAL)) == 4:
				tile[field] = ENEMY
		tiles[key] = tile
	_initialize_battle_team_colors(battle_match_seed)
	multiplayer_board_bounds = MultiplayerRules.board_bounds(tiles, Vector2.ZERO, HEX_SIZE)
	_rebuild_ground_navigation()
	_reset_multiplayer_board_pan()


func _init_multiplayer_state() -> void:
	multiplayer_gold.clear()
	multiplayer_ai_timers.clear()
	multiplayer_alive.clear()
	multiplayer_placements.clear()
	multiplayer_team_decks.clear()
	multiplayer_team_card_levels.clear()
	for team in _active_multiplayer_teams():
		multiplayer_gold[team] = STARTING_GOLD
		multiplayer_alive[team] = true
		var roster = _multiplayer_roster_for_team(int(team))
		multiplayer_team_decks[team] = (roster.get("deck", []) as Array).duplicate()
		multiplayer_team_card_levels[team] = (roster.get("card_levels", {}) as Dictionary).duplicate(true)
		if not room_human_teams.has(team):
			multiplayer_ai_timers[team] = ENEMY_FIRST_UNLOCK_DELAY + float(team - 2) * 0.35


func _multiplayer_roster_for_team(team: int) -> Dictionary:
	if team == _local_control_team():
		return {"deck": deck.duplicate(), "card_levels": card_levels.duplicate(true)}
	for slot_value in online_room_slots:
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = slot_value
		if int(slot.get("team_id", NEUTRAL)) != team or String(slot.get("kind", "")) != "human":
			continue
		var slot_deck = slot.get("deck", [])
		var slot_levels = slot.get("card_levels", {})
		if typeof(slot_deck) == TYPE_ARRAY and not (slot_deck as Array).is_empty():
			return {
				"deck": (slot_deck as Array).duplicate(),
				"card_levels": (slot_levels as Dictionary).duplicate(true) if typeof(slot_levels) == TYPE_DICTIONARY else {},
			}
	return {"deck": enemy_deck.duplicate(), "card_levels": enemy_card_levels.duplicate(true)}


func _board_cell_type_rows() -> Array:
	if not ConfigDB.has_table("board_cells"):
		return []
	var rows = ConfigDB.get_table("board_cells")
	return rows if typeof(rows) == TYPE_ARRAY else []


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
	tiles[key] = BoardRules.with_soft_occupation(tiles[key], team)


func _apply_unlock(key: Vector2i, team: int, fallback_card_id: String) -> String:
	if not tiles.has(key):
		return ""
	var tile = tiles[key]
	var unlock_roll = _roll_unlock_result_from_config(key, tile, team)
	var result = String(unlock_roll.get("result", String(tile.get("site", ""))))
	tile = BoardRules.with_unlock_roll(
		tile,
		result,
		String(unlock_roll.get("target_rarity", "")),
		int(unlock_roll.get("roll_seed", 0))
	)
	tiles[key] = tile
	var card_id = String(unlock_roll.get("card_id", String(tile.get("site_card", fallback_card_id))))
	match result:
		"empty":
			_set_empty_tile(key, team)
			return "空地"
		"gold":
			var amount = int(unlock_roll.get("amount", 30))
			_add_gold(team, amount, _hex_center(key) + Vector2(0, -30))
			_set_empty_tile(key, team)
			return "金币 +%d" % amount
		_:
			var site_card_id = ""
			if result == "barracks" or result == "hall":
				site_card_id = card_id
				if site_card_id == "":
					site_card_id = _site_card_for_team(key, tile, team, fallback_card_id)
				if site_card_id == "":
					_set_empty_tile(key, team)
					return "空地"
			elif result == "tower":
				site_card_id = _defense_card_for_team(key, tile, team, card_id)
				if site_card_id == "":
					_set_empty_tile(key, team)
					return _site_name("empty")
			elif result == "mine":
				site_card_id = MINE_CARD_ID
			_set_building(key, team, result, site_card_id)
			return _site_name(result, site_card_id)


func _roll_unlock_result_from_config(key: Vector2i, tile: Dictionary, team: int) -> Dictionary:
	var roll_seed = int(randi())
	var site = String(tile.get("site", ""))
	var reveal_pool_id = _reveal_pool_id_for_site(site)
	var reveal_entry = _roll_config_pool_entry("cell_reveal_pools", reveal_pool_id)
	if reveal_entry.is_empty():
		return {
			"result": _default_unlock_result_for_site(site),
			"target_rarity": "common",
			"roll_seed": roll_seed,
		}

	var entry_type = String(reveal_entry.get("entry_type", "empty"))
	var entry_id = String(reveal_entry.get("entry_id", "empty"))
	var result = "empty"
	var card_id = ""
	var target_rarity = ""
	var amount = _roll_entry_count(reveal_entry)

	match entry_type:
		"empty":
			result = "empty"
		"currency":
			result = entry_id
		"gold_mine":
			result = "mine"
		"unit_pool":
			var unit_pool_id = _card_pool_id_for_reveal_entry(reveal_entry, tile, CARD_KIND_ANIMAL)
			var unit_pick = _roll_card_from_config_pool(unit_pool_id, team, CARD_KIND_ANIMAL, roll_seed)
			card_id = String(unit_pick.get("card_id", ""))
			target_rarity = String(unit_pick.get("rarity", "common"))
			result = _unit_building_result_for_site(site, target_rarity)
		"defense_pool":
			var defense_pool_id = _card_pool_id_for_reveal_entry(reveal_entry, tile, CARD_KIND_DEFENSE)
			var defense_pick = _roll_card_from_config_pool(defense_pool_id, team, CARD_KIND_DEFENSE, roll_seed)
			card_id = String(defense_pick.get("card_id", ""))
			target_rarity = String(defense_pick.get("rarity", "common"))
			result = "tower"
		"fixed":
			result = _default_unlock_result_for_site(site)
		_:
			result = _default_unlock_result_for_site(site)

	if result != "gold":
		amount = 0
	return {
		"result": result,
		"target_rarity": target_rarity,
		"roll_seed": roll_seed,
		"card_id": card_id,
		"amount": amount,
	}


func _reveal_pool_id_for_site(site: String) -> String:
	match site:
		"mystery":
			return "reveal_pool_question"
		"barracks", "hall":
			return "reveal_pool_unit_tile"
		"tower":
			return "reveal_pool_defense_tile"
		"mine":
			return "reveal_pool_gold_mine"
		"base":
			return "reveal_pool_home_base"
		_:
			return ""


func _default_unlock_result_for_site(site: String) -> String:
	match site:
		"mystery":
			return "empty"
		"barracks", "hall", "tower":
			return site
		"mine":
			return "mine"
		_:
			return "empty"


func _unit_building_result_for_site(site: String, target_rarity: String) -> String:
	if site == "hall":
		return "hall"
	if site == "mystery" and _rarity_sort_rank(target_rarity) >= _rarity_sort_rank("epic"):
		return "hall"
	return "barracks"


func _roll_config_pool_entry(table_name: String, pool_id: String) -> Dictionary:
	if pool_id == "" or not ConfigDB.has_table(table_name):
		return {}
	var entries = []
	var total_weight = 0
	var rows = ConfigDB.get_table(table_name)
	if typeof(rows) != TYPE_ARRAY:
		return {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY or String(row.get("pool_id", "")) != pool_id:
			continue
		var weight = maxi(0, int(row.get("weight", 0)))
		if weight <= 0:
			continue
		entries.append(row)
		total_weight += weight
	if entries.is_empty() or total_weight <= 0:
		return {}
	var roll = int(randi() % total_weight)
	var cursor = 0
	for entry in entries:
		cursor += maxi(0, int(entry.get("weight", 0)))
		if roll < cursor:
			return entry
	return entries[entries.size() - 1]


func _roll_entry_count(entry: Dictionary) -> int:
	var min_count = int(entry.get("min_count", 0))
	var max_count = int(entry.get("max_count", min_count))
	if max_count <= min_count:
		return min_count
	return min_count + int(randi() % (max_count - min_count + 1))


func _card_pool_id_for_reveal_entry(reveal_entry: Dictionary, tile: Dictionary, required_kind: String) -> String:
	var entry_id = String(reveal_entry.get("entry_id", ""))
	if entry_id != "selected_price_unit_pool" and entry_id != "selected_price_defense_pool":
		return entry_id
	var price_row = _price_pool_row_for_cost(int(tile.get("site_cost", UNIT_LOW_PRICE)))
	if price_row.is_empty():
		return ""
	if required_kind == CARD_KIND_DEFENSE:
		return String(price_row.get("defense_card_pool_id", ""))
	return String(price_row.get("unit_card_pool_id", ""))


func _price_pool_row_for_cost(cost: int) -> Dictionary:
	if not ConfigDB.has_table("cell_price_pools"):
		return {}
	var rows = ConfigDB.get_table("cell_price_pools")
	if typeof(rows) != TYPE_ARRAY:
		return {}
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and int(row.get("price", 0)) == cost:
			return row
	return {}


func _roll_card_from_config_pool(pool_id: String, team: int, required_kind: String, roll_seed: int) -> Dictionary:
	var entry = _roll_config_pool_entry("card_random_pools", pool_id)
	var target_rarity = String(entry.get("rarity", "common")) if not entry.is_empty() else "common"
	var entry_card_id = String(entry.get("entry_id", "")) if not entry.is_empty() else ""
	var roster = _team_deck(team)
	var card_id = _deck_card_for_target_rarity(roster, target_rarity, roll_seed, required_kind)
	var resolved_rarity = target_rarity
	if card_id != "":
		resolved_rarity = String(_card_by_id(card_id).get("rarity", target_rarity))
	return {
		"card_id": card_id,
		"rarity": resolved_rarity,
		"entry_id": entry_card_id,
	}


func _can_use_config_card(card_id: String, roster: Array, required_kind: String) -> bool:
	if card_id == "":
		return false
	var card = _card_by_id(card_id)
	if card.is_empty() or (required_kind != "" and _card_kind(card) != required_kind):
		return false
	return roster.has(card_id)


func _update_battle(delta: float) -> void:
	battle_timer = maxf(0.0, battle_timer - delta)
	if battle_timer <= 0.0:
		if battle_mode == BATTLE_MODE_MULTIPLAYER:
			if multiplayer_free_for_all:
				_finish_multiplayer_free_for_all(_multiplayer_timeout_placement())
			else:
				_finish_multiplayer_battle(_multiplayer_timeout_result())
		else:
			var won = _tile_count(PLAYER) >= _tile_count(ENEMY)
			_finish_battle("胜利" if won else "失败")
		return

	income_timer -= delta
	if income_timer <= 0.0:
		income_timer = INCOME_INTERVAL
		if battle_mode == BATTLE_MODE_MULTIPLAYER:
			for team in _active_multiplayer_teams():
				if _is_multiplayer_team_alive(team):
					_add_gold(team, _building_count(team, "base") * BASE_INCOME + _building_count(team, "mine") * MINE_INCOME)
		else:
			gold += _building_count(PLAYER, "base") * BASE_INCOME + _building_count(PLAYER, "mine") * MINE_INCOME
			enemy_gold += _building_count(ENEMY, "base") * BASE_INCOME + _building_count(ENEMY, "mine") * MINE_INCOME

	_update_buildings(delta)
	if game_over:
		return
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		_update_multiplayer_ai(delta)
	else:
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
		if battle_mode == BATTLE_MODE_MULTIPLAYER and not _is_multiplayer_team_alive(team):
			continue
		tile["spawn_timer"] = float(tile.get("spawn_timer", 0.0)) - delta
		if float(tile["spawn_timer"]) <= 0.0:
			tile["spawn_timer"] = _building_delay(building, team, String(tile.get("site_card", "")))
			if building == "tower" or building == "base":
				_tower_attack(key, team)
			elif _can_spawn_multiplayer_unit(team):
				_spawn_unit(team, key, _spawn_card_for_tile(tile, team))
		tiles[key] = tile


func _update_enemy(delta: float) -> void:
	enemy_timer -= delta
	if enemy_timer > 0.0:
		return
	enemy_timer = ENEMY_UNLOCK_INTERVAL
	var best_key = Vector2i(-99, -99)
	var best_score = INF
	var target_key = _battle_base_key(PLAYER)
	var target_pos = _hex_center(target_key) if tiles.has(target_key) else Vector2.ZERO
	for key in tiles.keys():
		var cost = _unlock_cost(key, ENEMY)
		if not _can_unlock(key, ENEMY) or cost <= 0 or cost > enemy_gold:
			continue
		var score = _hex_center(key).distance_to(target_pos) + float(cost) * 0.08
		if score < best_score:
			best_score = score
			best_key = key
	if best_key.x == -99:
		return
	var tile = tiles[best_key]
	var cost = _unlock_cost(best_key, ENEMY)
	if not _spend_team_gold(ENEMY, cost):
		return
	var was_direct_tower = String(tile.get("site", "")) == "tower"
	_apply_unlock(best_key, ENEMY, _enemy_deck_card(0))
	_record_tower_purchase_if_built(best_key, ENEMY, was_direct_tower)


func _update_multiplayer_ai(delta: float) -> void:
	for team in _active_multiplayer_teams():
		if room_human_teams.has(team) or not _is_multiplayer_team_alive(team):
			continue
		var timer = float(multiplayer_ai_timers.get(team, ENEMY_FIRST_UNLOCK_DELAY)) - delta
		if timer > 0.0:
			multiplayer_ai_timers[team] = timer
			continue
		multiplayer_ai_timers[team] = MULTIPLAYER_AI_UNLOCK_INTERVAL
		var best_key = MultiplayerRules.INVALID_KEY
		var best_score = INF
		var target_key = _nearest_alive_enemy_base(team)
		var own_base_key = _multiplayer_base_key(team)
		var target_pos = _hex_center(target_key) if tiles.has(target_key) else _hex_center(own_base_key)
		for key in tiles.keys():
			var cost = _unlock_cost(key, team)
			if cost <= 0 or cost > _gold_for_team(team) or not _can_unlock(key, team):
				continue
			var score = _hex_center(key).distance_to(target_pos) + float(cost) * 0.08
			if score < best_score:
				best_score = score
				best_key = key
		if best_key == MultiplayerRules.INVALID_KEY:
			continue
		var cost = _unlock_cost(best_key, team)
		if _spend_team_gold(team, cost):
			var was_direct_tower = String(tiles[best_key].get("site", "")) == "tower"
			_apply_unlock(best_key, team, _team_deck_card(team, 0))
			_record_tower_purchase_if_built(best_key, team, was_direct_tower)


func _can_spawn_multiplayer_unit(team: int) -> bool:
	if battle_mode != BATTLE_MODE_MULTIPLAYER:
		return true
	var count = 0
	for unit in units:
		if int(unit.get("team", NEUTRAL)) == team and float(unit.get("hp", 0.0)) > 0.0:
			count += 1
	return count < MULTIPLAYER_MAX_UNITS_PER_TEAM


func _nearest_alive_enemy_base(team: int) -> Vector2i:
	var source_key = _multiplayer_base_key(team)
	if source_key == MultiplayerRules.INVALID_KEY:
		return MultiplayerRules.INVALID_KEY
	var source_pos = MultiplayerRules.hex_center(source_key, Vector2.ZERO, HEX_SIZE)
	var best_key = MultiplayerRules.INVALID_KEY
	var best_distance = INF
	for other_team in _active_multiplayer_teams():
		if _are_allies(other_team, team) or not _is_multiplayer_team_alive(other_team):
			continue
		var candidate = _multiplayer_base_key(other_team)
		if candidate == MultiplayerRules.INVALID_KEY:
			continue
		var distance = source_pos.distance_to(MultiplayerRules.hex_center(candidate, Vector2.ZERO, HEX_SIZE))
		if distance < best_distance:
			best_distance = distance
			best_key = candidate
	return best_key


func _update_units(delta: float) -> void:
	_refresh_unit_skill_state(delta)
	_refresh_combat_building_keys()
	for i in range(units.size()):
		if game_over:
			break
		var unit = units[i]
		UnitMotionFeedback.begin_frame(unit, delta)
		units[i] = unit
		if float(unit["hp"]) <= 0.0:
			continue
		var previous_tile = unit.get("tile", _tile_at_world(Vector2(unit["pos"])))
		unit["tile"] = previous_tile
		unit = _ensure_unit_navigation_target(unit)
		if float(unit.get("stun_timer", 0.0)) > 0.0:
			units[i] = unit
			continue
		var attack_target = _locked_unit_attack_target(unit)
		if attack_target.is_empty():
			unit = _clear_unit_attack_target(unit)
			attack_target = _nearest_attack_target_in_range(unit)
			if not attack_target.is_empty():
				unit = _lock_unit_attack_target(unit, attack_target)
		unit["cooldown"] = maxf(0.0, float(unit.get("cooldown", 0.0)) - delta)
		units[i] = unit
		var attacked = false
		if not attack_target.is_empty():
			var attack_distance = Vector2(unit["pos"]).distance_to(Vector2(attack_target["pos"]))
			if attack_distance <= float(unit["range"]):
				attacked = true
				if float(unit["cooldown"]) <= 0.0:
					_unit_attack_target(i, attack_target, attack_distance)
					if i >= units.size():
						continue
					unit = units[i]
					unit["cooldown"] = _unit_attack_cooldown(unit)
		if not attacked:
			unit = units[i]
			var navigation_target = _unit_navigation_target(unit)
			if not navigation_target.is_empty():
				var navigation_pos = Vector2(navigation_target["pos"])
				if Vector2(unit["pos"]).distance_to(navigation_pos) > 1.0:
					unit = _move_unit_toward_target(unit, navigation_target, navigation_pos, delta)
		var current_tile = _tile_at_world(Vector2(unit["pos"]))
		if current_tile != previous_tile:
			_try_paint_crossed_tile(previous_tile, int(unit["team"]), i)
			if i < units.size():
				unit = units[i]
			unit["tile"] = current_tile
		units[i] = unit
	var alive = []
	for unit in units:
		if float(unit["hp"]) > 0.0:
			alive.append(unit)
	units = alive


func _move_unit_toward_target(unit: Dictionary, target: Dictionary, target_pos: Vector2, delta: float) -> Dictionary:
	var unit_pos = Vector2(unit.get("pos", Vector2.ZERO))
	var speed = maxf(0.0, float(unit.get("speed", 0.0)))
	if bool(unit.get("flying", false)):
		var flying_direction = unit_pos.direction_to(target_pos)
		unit["pos"] = unit_pos.move_toward(target_pos, speed * delta)
		if flying_direction != Vector2.ZERO:
			UnitMotionFeedback.mark_moving(unit, flying_direction, delta)
		return unit

	var current_tile: Vector2i = unit.get("tile", MultiplayerRules.INVALID_KEY)
	if not tiles.has(current_tile):
		current_tile = _tile_at_world(unit_pos)
	var target_tile: Vector2i = target.get("tile", _tile_at_world(target_pos))
	if not tiles.has(current_tile) or not tiles.has(target_tile):
		return unit
	if current_tile == target_tile:
		var local_direction = unit_pos.direction_to(target_pos)
		var local_pos = unit_pos.move_toward(target_pos, speed * delta)
		if tiles.has(_tile_at_world(local_pos)):
			unit["pos"] = local_pos
			if local_direction != Vector2.ZERO:
				UnitMotionFeedback.mark_moving(unit, local_direction, delta)
		return unit

	var path: PackedVector2Array = unit.get("ground_path", PackedVector2Array())
	var path_index = int(unit.get("ground_path_index", 0))
	var path_target: Vector2i = unit.get("ground_path_target", MultiplayerRules.INVALID_KEY)
	if path_target != target_tile or path.is_empty() or path_index >= path.size():
		path = _ground_path_between(current_tile, target_tile)
		path_index = 0
		path_target = target_tile
	if path.is_empty():
		return unit

	var remaining = speed * delta
	var last_direction = Vector2.ZERO
	while remaining > 0.0 and path_index < path.size():
		var waypoint = Vector2(path[path_index])
		var waypoint_distance = unit_pos.distance_to(waypoint)
		if waypoint_distance <= 0.5:
			unit_pos = waypoint
			path_index += 1
			continue
		last_direction = unit_pos.direction_to(waypoint)
		var step = minf(remaining, waypoint_distance)
		unit_pos += last_direction * step
		remaining -= step
		if step >= waypoint_distance - 0.01:
			unit_pos = waypoint
			path_index += 1
		else:
			break
	unit["pos"] = unit_pos
	unit["ground_path"] = path
	unit["ground_path_index"] = path_index
	unit["ground_path_target"] = path_target
	if last_direction != Vector2.ZERO:
		UnitMotionFeedback.mark_moving(unit, last_direction, delta)
	return unit


func _try_paint_crossed_tile(key: Vector2i, team: int, unit_index: int = -1) -> bool:
	if not tiles.has(key):
		return false
	var tile = tiles[key]
	var visual_owner = BoardRules.visual_owner(tile)
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		if _are_allies(visual_owner, team):
			return false
	else:
		var opponent = ENEMY if team == PLAYER else PLAYER
		if visual_owner != opponent:
			return false
	if String(tile.get("building", "")) != "":
		return false
	if _has_enemy_unit_on_tile(key, team):
		return false
	tiles[key] = BoardRules.with_soft_occupation(tile, team)
	_pulse(_hex_center(key), _team_color(team))
	_play_world_sfx("territory_capture", _hex_center(key), team, -5.0, 0.92)
	if unit_index >= 0:
		_apply_unit_capture_skill(unit_index, key)
	return true


func _has_enemy_unit_on_tile(key: Vector2i, team: int) -> bool:
	for unit in units:
		if _are_allies(int(unit.get("team", NEUTRAL)), team) or float(unit.get("hp", 0.0)) <= 0.0:
			continue
		var unit_key = unit.get("tile", _tile_at_world(Vector2(unit["pos"])))
		if unit_key == key:
			return true
	return false


func _update_effects(delta: float) -> void:
	var kept = []
	for effect in effects:
		effect["time"] = float(effect["time"]) - delta
		if float(effect["time"]) > 0.0:
			kept.append(effect)
	effects = kept


func _trigger_unit_motion(index: int, kind: String, direction: Vector2 = Vector2.ZERO) -> void:
	if index < 0 or index >= units.size():
		return
	var unit = units[index]
	UnitMotionFeedback.trigger(unit, kind, direction)
	units[index] = unit


func _play_world_sfx(event_id: String, world_pos: Vector2, team: int = NEUTRAL, volume_offset_db: float = 0.0, pitch_override: float = -1.0) -> bool:
	if not _is_world_pos_visible(world_pos, 140.0):
		return false
	var adjusted_volume = volume_offset_db
	if team != NEUTRAL and not _are_allies(team, PLAYER):
		if event_id in ["unit_spawn", "unit_attack", "ranged_attack", "tower_attack", "stat_gain", "power_up"]:
			return false
		adjusted_volume -= 3.0
	elif team != NEUTRAL and team != PLAYER:
		adjusted_volume -= 2.0
	return GameAudio.play_sfx(event_id, adjusted_volume, pitch_override)


func _unit_hit_direction(index: int, source_index: int, _source_team: int) -> Vector2:
	if index < 0 or index >= units.size():
		return Vector2.RIGHT
	var target_pos = Vector2(units[index].get("pos", Vector2.ZERO))
	if source_index >= 0 and source_index < units.size() and source_index != index:
		var from_source = target_pos - Vector2(units[source_index].get("pos", target_pos))
		if from_source.length_squared() > 0.0001:
			return from_source.normalized()
	var last_direction = Vector2(units[index].get("motion_move_direction", units[index].get("motion_direction", Vector2.ZERO)))
	if last_direction.length_squared() > 0.0001:
		return -last_direction.normalized()
	var target_team = int(units[index].get("team", NEUTRAL))
	return _unit_motion_fallback_direction(target_team)


func _unit_motion_fallback_direction(team: int) -> Vector2:
	var faces_down = team == PLAYER
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		faces_down = team >= 1 and team <= 3
	return Vector2(0.35, 1.0 if faces_down else -1.0).normalized()


func _queue_unit_death_snapshot(dead: Dictionary, source_index: int = -1, source_team: int = NEUTRAL) -> void:
	var card_id = String(dead.get("card", ""))
	if card_id == "":
		return
	var direction = Vector2.ZERO
	if source_index >= 0 and source_index < units.size():
		direction = Vector2(dead.get("pos", Vector2.ZERO)) - Vector2(units[source_index].get("pos", Vector2.ZERO))
	if direction.length_squared() <= 0.0001:
		var dead_team = int(dead.get("team", NEUTRAL))
		direction = _unit_motion_fallback_direction(dead_team)
		if source_team == NEUTRAL:
			direction.x *= -1.0
	direction = direction.normalized()
	effects.append({
		"kind": UnitMotionFeedback.KIND_DEATH,
		"unit_id": int(dead.get("id", -1)),
		"card_id": card_id,
		"team": int(dead.get("team", NEUTRAL)),
		"pos": Vector2(dead.get("pos", Vector2.ZERO)),
		"tile": dead.get("tile", Vector2i(-99, -99)),
		"direction": direction,
		"duration": UnitMotionFeedback.DEATH_DURATION,
		"time": UnitMotionFeedback.DEATH_DURATION,
	})


func _tower_attack(key: Vector2i, team: int) -> void:
	var center = _hex_center(key)
	var tile = tiles.get(key, {})
	var building = String(tile.get("building", "")) if typeof(tile) == TYPE_DICTIONARY else ""
	var damage = BASE_ATTACK_DAMAGE if building == "base" else TOWER_DAMAGE
	var attack_range = TOWER_RANGE + DEFENSE_TOWER_RANGE_BONUS if building == "tower" else TOWER_RANGE
	var tower_card = _card_by_id(String(tile.get("site_card", ""))) if building == "tower" else {}
	if not tower_card.is_empty() and _card_kind(tower_card) == CARD_KIND_DEFENSE:
		var stats = _card_stats_for_team(tower_card, team)
		damage = float(stats["attack"])
		attack_range = float(stats["attack_range"])
	var best_index = -1
	var best_key = Vector2i(-99, -99)
	var best_kind = ""
	var best_distance = 999999.0
	for i in range(units.size()):
		if _are_allies(int(units[i]["team"]), team) or float(units[i]["hp"]) <= 0.0:
			continue
		var distance = center.distance_to(Vector2(units[i]["pos"]))
		if distance < attack_range and distance < best_distance:
			best_distance = distance
			best_index = i
			best_key = Vector2i(-99, -99)
			best_kind = "unit"
	if building == "tower":
		var target_keys = tiles.keys()
		if battle_mode == BATTLE_MODE_MULTIPLAYER:
			var search_radius = ceili(attack_range / (HEX_SIZE * 1.5)) + 1
			target_keys = _keys_in_hex_radius(key, search_radius)
		for target_key in target_keys:
			var target_tile = tiles[target_key]
			var target_team = int(target_tile.get("team", NEUTRAL))
			if target_team == NEUTRAL or _are_allies(target_team, team):
				continue
			if String(target_tile.get("building", "")) == "" or float(target_tile.get("hp", 0.0)) <= 0.0:
				continue
			var distance = center.distance_to(_hex_center(target_key))
			if distance < attack_range and distance < best_distance:
				best_distance = distance
				best_index = -1
				best_key = target_key
				best_kind = "building"
	if best_kind == "unit" and best_index >= 0:
		_play_world_sfx("tower_attack", center, team, -3.0)
		_projectile(center, Vector2(units[best_index]["pos"]), team)
		_damage_unit(best_index, damage, -1, team if battle_mode == BATTLE_MODE_MULTIPLAYER else NEUTRAL)
	elif best_kind == "building" and best_key.x != -99:
		_play_world_sfx("tower_attack", center, team, -3.0)
		_projectile(center, _hex_center(best_key), team)
		_damage_tile(best_key, team, damage)


func _damage_unit(index: int, damage: float, source_index: int = -1, source_team: int = NEUTRAL, trigger_reactive: bool = true) -> bool:
	if index < 0 or index >= units.size():
		return false
	var unit = units[index]
	if float(unit.get("hp", 0.0)) <= 0.0:
		return false
	if source_team != NEUTRAL and _are_allies(int(unit.get("team", NEUTRAL)), source_team):
		return false
	if trigger_reactive:
		var guardian_index = _damage_guardian_index(index, source_team)
		if guardian_index >= 0:
			_pulse(Vector2(units[index]["pos"]), COLOR_BLUE)
			_damage_unit(guardian_index, damage, source_index, source_team, false)
			return false
	var final_damage = _incoming_unit_damage(index, damage)
	var impact_damage = final_damage
	var absorbed_damage = 0.0
	var shield = float(unit.get("shield", 0.0))
	if shield > 0.0 and final_damage > 0.0:
		var absorbed = minf(shield, final_damage)
		absorbed_damage = absorbed
		shield -= absorbed
		final_damage -= absorbed
		unit["shield"] = shield
	unit["hp"] = float(unit["hp"]) - final_damage
	units[index] = unit
	if impact_damage > 0.0:
		_trigger_unit_motion(index, UnitMotionFeedback.KIND_HIT, _unit_hit_direction(index, source_index, source_team))
		_play_world_sfx("shield_hit" if absorbed_damage > 0.0 else "unit_hit", Vector2(units[index]["pos"]), int(units[index].get("team", NEUTRAL)), -5.0)
	_pulse(Vector2(units[index]["pos"]), COLOR_YELLOW)
	if trigger_reactive and final_damage > 0.0 and float(units[index]["hp"]) > 0.0:
		_apply_unit_damage_skill(index, source_index, source_team)
	if float(units[index]["hp"]) <= 0.0 and not bool(units[index].get("death_handled", false)):
		units[index]["death_handled"] = true
		_handle_unit_death(index, source_index, source_team)
		return true
	return false


func _damage_tile(key: Vector2i, attacker: int, damage: float) -> bool:
	if not tiles.has(key):
		return false
	var tile = tiles[key]
	if _are_allies(int(tile["team"]), attacker):
		return false
	if String(tile["building"]) == "":
		return false
	tile["hp"] = float(tile["hp"]) - damage
	if float(tile["hp"]) <= 0.0:
		_play_world_sfx("building_break", _hex_center(key), attacker, -2.0)
		if String(tile["building"]) == "base":
			if battle_mode == BATTLE_MODE_MULTIPLAYER:
				var original_team = _original_multiplayer_base_team(key)
				tiles[key] = BoardRules.as_captured_base(tile, attacker)
				_pulse(_hex_center(key), _team_color(attacker))
				if original_team != NEUTRAL and _is_multiplayer_team_alive(original_team):
					_eliminate_multiplayer_team(original_team, attacker, key)
			else:
				var defeated_team = int(tile.get("team", NEUTRAL))
				tiles[key] = BoardRules.as_captured_base(tile, attacker)
				_clear_eliminated_team_units(defeated_team, attacker)
				_transfer_eliminated_territory(defeated_team, attacker, key)
				_pulse(_hex_center(key), _team_color(attacker))
				_finish_battle("胜利" if attacker == PLAYER else "失败")
			return true
		tiles[key] = BoardRules.as_destroyed_building(tile, attacker)
		_pulse(_hex_center(key), _team_color(attacker))
		return true
	tiles[key] = tile
	return false


func _spawn_unit(team: int, key: Vector2i, card_id: String, is_extra: bool = false, extra_index: int = 0, spawn_context: Dictionary = {}) -> void:
	if not _can_spawn_multiplayer_unit(team):
		return
	if card_id == "":
		card_id = _team_deck_card(team, 0)
	var card = _card_by_id(card_id)
	if card.is_empty():
		card = _card_by_id(_team_deck_card(team, 0))
	var stats = _card_stats_for_team(card, team)
	var base_pos = _hex_center(key)
	var spawn_pos = base_pos
	if is_extra:
		var angle = float(extra_index) * TAU / 6.0
		spawn_pos += Vector2(cos(angle), sin(angle)) * 12.0
	var skill_cooldown = _card_skill_cooldown(card)
	var skill_timer = randf_range(0.35, maxf(0.45, skill_cooldown)) if _card_uses_interval_skill(card) else 0.0
	var navigation_target = _nearest_enemy_building_target(spawn_pos, team)
	var skill_triggers_enabled = bool(spawn_context.get("skill_triggers_enabled", true))
	var death_summon_lineage: Array = []
	var raw_lineage = spawn_context.get("death_summon_lineage", [])
	if typeof(raw_lineage) == TYPE_ARRAY:
		death_summon_lineage = (raw_lineage as Array).duplicate()
	units.append({
		"id": next_unit_id,
		"team": team,
		"card": String(card.get("id", card_id)),
		"skill_trigger": String(card.get("skill_trigger", "")),
		"skill_effect": String(card.get("skill_effect", "")),
		"skill_power": float(card.get("skill_power", 0.0)),
		"skill_cooldown_sec": float(card.get("skill_cooldown_sec", 0.0)),
		"skill_chance": float(card.get("skill_chance", 1.0)),
		"skill_triggers_enabled": skill_triggers_enabled,
		"death_summon_lineage": death_summon_lineage,
		"pos": spawn_pos,
		"hp": float(stats["max_hp"]),
		"max_hp": float(stats["max_hp"]),
		"base_max_hp": float(stats["max_hp"]),
		"attack": float(stats["attack"]),
		"base_attack": float(stats["attack"]),
		"attack_bonus": 0.0,
		"speed": float(stats["move_speed"]) * UNIT_MOVE_SPEED_MULT,
		"base_speed": float(stats["move_speed"]) * UNIT_MOVE_SPEED_MULT,
		"range": float(stats["attack_range"]),
		"base_range": float(stats["attack_range"]),
		"shield": 0.0,
		"stun_timer": 0.0,
		"slow_timer": 0.0,
		"haste_timer": 0.0,
		"skill_timer": skill_timer,
		"cooldown": 0.0 if String(card.get("skill_text", "")).contains("会比敌人优先攻击") else randf_range(0.08, 0.55),
		"tile": key,
		"flying": _card_is_flying(card),
		"navigation_target_key": navigation_target.get("key", MultiplayerRules.INVALID_KEY),
		"attack_target_kind": "",
		"attack_target_unit_id": -1,
		"attack_target_key": MultiplayerRules.INVALID_KEY,
		"ground_path": PackedVector2Array(),
		"ground_path_index": 0,
		"ground_path_target": MultiplayerRules.INVALID_KEY,
	})
	var spawned_index = units.size() - 1
	next_unit_id += 1
	if skill_triggers_enabled:
		_apply_unit_spawn_skill(spawned_index)
	_pulse(base_pos, Color(0.75, 0.95, 1.0))
	_play_world_sfx("unit_spawn", spawn_pos, team, -7.0 if is_extra else 0.0)
	if not is_extra:
		for n in range(_card_extra_spawn_count(card)):
			_spawn_unit(team, key, String(card.get("id", card_id)), true, n + 1)


func _ensure_unit_navigation_target(unit: Dictionary) -> Dictionary:
	var key: Vector2i = unit.get("navigation_target_key", MultiplayerRules.INVALID_KEY)
	if _is_enemy_building_target_valid(key, int(unit.get("team", NEUTRAL))):
		return unit
	var target = _nearest_enemy_building_target(Vector2(unit.get("pos", Vector2.ZERO)), int(unit.get("team", NEUTRAL)))
	var next_key: Vector2i = target.get("key", MultiplayerRules.INVALID_KEY)
	unit["navigation_target_key"] = next_key
	unit["ground_path"] = PackedVector2Array()
	unit["ground_path_index"] = 0
	unit["ground_path_target"] = MultiplayerRules.INVALID_KEY
	return unit


func _unit_navigation_target(unit: Dictionary) -> Dictionary:
	var key: Vector2i = unit.get("navigation_target_key", MultiplayerRules.INVALID_KEY)
	if not _is_enemy_building_target_valid(key, int(unit.get("team", NEUTRAL))):
		return {}
	return {
		"kind": "building",
		"key": key,
		"pos": _hex_center(key),
		"tile": key,
	}


func _nearest_enemy_building_target(pos: Vector2, team: int) -> Dictionary:
	var best = {}
	var best_distance = INF
	for key_value in tiles.keys():
		var key: Vector2i = key_value
		if not _is_enemy_building_target_valid(key, team):
			continue
		var target_pos = _hex_center(key)
		var distance = pos.distance_to(target_pos)
		if distance < best_distance:
			best_distance = distance
			best = {
				"kind": "building",
				"key": key,
				"pos": target_pos,
				"tile": key,
			}
	return best


func _is_enemy_building_target_valid(key: Vector2i, team: int) -> bool:
	if key == MultiplayerRules.INVALID_KEY or not tiles.has(key):
		return false
	var tile: Dictionary = tiles[key]
	return (
		String(tile.get("building", "")) != ""
		and float(tile.get("hp", 0.0)) > 0.0
		and not _are_allies(int(tile.get("team", NEUTRAL)), team)
	)


func _locked_unit_attack_target(unit: Dictionary) -> Dictionary:
	var team = int(unit.get("team", NEUTRAL))
	match String(unit.get("attack_target_kind", "")):
		"unit":
			var target_index = _unit_index_by_id(int(unit.get("attack_target_unit_id", -1)))
			if target_index < 0:
				return {}
			var target_unit: Dictionary = units[target_index]
			if float(target_unit.get("hp", 0.0)) <= 0.0 or _are_allies(int(target_unit.get("team", NEUTRAL)), team):
				return {}
			var target_pos = Vector2(target_unit.get("pos", Vector2.ZERO))
			return {
				"kind": "unit",
				"index": target_index,
				"pos": target_pos,
				"tile": target_unit.get("tile", _tile_at_world(target_pos)),
			}
		"building":
			var key: Vector2i = unit.get("attack_target_key", MultiplayerRules.INVALID_KEY)
			if not _is_enemy_building_target_valid(key, team):
				return {}
			return {
				"kind": "building",
				"key": key,
				"pos": _hex_center(key),
				"tile": key,
			}
	return {}


func _nearest_attack_target_in_range(unit: Dictionary) -> Dictionary:
	var pos = Vector2(unit.get("pos", Vector2.ZERO))
	var team = int(unit.get("team", NEUTRAL))
	var self_id = int(unit.get("id", -1))
	var attack_range = maxf(0.0, float(unit.get("range", 0.0)))
	var best = {}
	var best_score = INF
	for i in range(units.size()):
		var candidate: Dictionary = units[i]
		if int(candidate.get("id", -1)) == self_id or float(candidate.get("hp", 0.0)) <= 0.0:
			continue
		if _are_allies(int(candidate.get("team", NEUTRAL)), team):
			continue
		var candidate_pos = Vector2(candidate.get("pos", Vector2.ZERO))
		var distance = pos.distance_to(candidate_pos)
		if distance > attack_range:
			continue
		var target = {
			"kind": "unit",
			"index": i,
			"pos": candidate_pos,
			"tile": candidate.get("tile", _tile_at_world(candidate_pos)),
		}
		var score = distance + _target_preference_adjustment(self_id, target)
		if score < best_score:
			best_score = score
			best = target
	for key_value in tiles.keys():
		var key: Vector2i = key_value
		if not _is_enemy_building_target_valid(key, team):
			continue
		var candidate_pos = _hex_center(key)
		var distance = pos.distance_to(candidate_pos)
		if distance > attack_range:
			continue
		var target = {
			"kind": "building",
			"key": key,
			"pos": candidate_pos,
			"tile": key,
		}
		var score = distance + _target_preference_adjustment(self_id, target)
		if score < best_score:
			best_score = score
			best = target
	return best


func _lock_unit_attack_target(unit: Dictionary, target: Dictionary) -> Dictionary:
	var kind = String(target.get("kind", ""))
	unit["attack_target_kind"] = kind
	unit["attack_target_unit_id"] = -1
	unit["attack_target_key"] = MultiplayerRules.INVALID_KEY
	if kind == "unit":
		var index = int(target.get("index", -1))
		if index >= 0 and index < units.size():
			unit["attack_target_unit_id"] = int(units[index].get("id", -1))
	elif kind == "building":
		unit["attack_target_key"] = target.get("key", MultiplayerRules.INVALID_KEY)
	return unit


func _clear_unit_attack_target(unit: Dictionary) -> Dictionary:
	unit["attack_target_kind"] = ""
	unit["attack_target_unit_id"] = -1
	unit["attack_target_key"] = MultiplayerRules.INVALID_KEY
	return unit


func _nearest_combat_target(pos: Vector2, team: int, self_id: int, can_cross_void: bool = true, attack_range: float = 0.0) -> Dictionary:
	var best = {}
	var best_score = 999999.0
	for i in range(units.size()):
		var unit = units[i]
		if int(unit["id"]) == self_id or _are_allies(int(unit["team"]), team) or float(unit["hp"]) <= 0.0:
			continue
		var unit_pos = Vector2(unit["pos"])
		var unit_tile: Vector2i = unit.get("tile", _tile_at_world(unit_pos))
		if not can_cross_void and not tiles.has(unit_tile) and pos.distance_to(unit_pos) > attack_range:
			continue
		var score = pos.distance_to(unit_pos) - 80.0
		score += _target_preference_adjustment(self_id, {
			"kind": "unit",
			"index": i,
			"pos": unit_pos,
			"tile": unit_tile,
		})
		if score < best_score:
			best_score = score
			best = {
				"kind": "unit",
				"index": i,
				"pos": unit_pos,
				"tile": unit_tile,
			}
	for key in combat_building_keys:
		var tile = tiles[key]
		if _are_allies(int(tile["team"]), team) or String(tile["building"]) == "":
			continue
		var score = pos.distance_to(_hex_center(key))
		if String(tile["building"]) == "base":
			score -= 120.0
		else:
			score -= 60.0
		score += _target_preference_adjustment(self_id, {
			"kind": "building",
			"key": key,
			"pos": _hex_center(key),
			"tile": key,
		})
		if score < best_score:
			best_score = score
			best = {
				"kind": "building",
				"key": key,
				"pos": _hex_center(key),
				"tile": key,
			}
	return best


func _refresh_combat_building_keys() -> void:
	combat_building_keys.clear()
	for key in tiles.keys():
		var tile = tiles[key]
		if String(tile.get("building", "")) != "" and float(tile.get("hp", 0.0)) > 0.0:
			combat_building_keys.append(key)


func _keys_in_hex_radius(center: Vector2i, radius: int) -> Array:
	var result = []
	for delta_q in range(-radius, radius + 1):
		var min_delta_r = maxi(-radius, -delta_q - radius)
		var max_delta_r = mini(radius, -delta_q + radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			var key = center + Vector2i(delta_q, delta_r)
			if tiles.has(key):
				result.append(key)
	return result


func _refresh_unit_skill_state(delta: float) -> void:
	for i in range(units.size()):
		var unit = units[i]
		if float(unit.get("hp", 0.0)) <= 0.0:
			continue
		unit["stun_timer"] = maxf(0.0, float(unit.get("stun_timer", 0.0)) - delta)
		unit["slow_timer"] = maxf(0.0, float(unit.get("slow_timer", 0.0)) - delta)
		unit["haste_timer"] = maxf(0.0, float(unit.get("haste_timer", 0.0)) - delta)
		if _unit_uses_interval_skill(unit):
			unit["skill_timer"] = maxf(0.0, float(unit.get("skill_timer", 0.0)) - delta)
		units[i] = unit
	_refresh_unit_aura_bonuses()
	for i in range(units.size()):
		if i >= units.size() or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		if _unit_uses_interval_skill(units[i]) and float(units[i].get("skill_timer", 0.0)) <= 0.0:
			_apply_unit_interval_skill(i)
			if i < units.size():
				units[i]["skill_timer"] = _unit_skill_cooldown(units[i])


func _refresh_unit_aura_bonuses() -> void:
	for i in range(units.size()):
		var unit = units[i]
		if float(unit.get("hp", 0.0)) <= 0.0:
			continue
		var speed_mult = 1.0
		if float(unit.get("slow_timer", 0.0)) > 0.0:
			speed_mult *= 0.55
		if float(unit.get("haste_timer", 0.0)) > 0.0:
			speed_mult *= 1.35
		unit["attack"] = maxf(0.0, float(unit.get("base_attack", unit.get("attack", 0.0))) + float(unit.get("attack_bonus", 0.0)))
		unit["speed"] = float(unit.get("base_speed", unit.get("speed", 0.0))) * speed_mult
		unit["range"] = float(unit.get("base_range", unit.get("range", HEX_SIZE)))
		unit["max_hp"] = maxf(1.0, float(unit.get("base_max_hp", unit.get("max_hp", 1.0))) + float(unit.get("max_hp_bonus", 0.0)))
		unit["hp"] = minf(float(unit.get("hp", 0.0)), float(unit["max_hp"]))
		units[i] = unit
	for source_index in range(units.size()):
		if float(units[source_index].get("hp", 0.0)) <= 0.0 or not _unit_skill_triggers_enabled(units[source_index]):
			continue
		var text = _unit_skill_text(units[source_index])
		var team = int(units[source_index].get("team", NEUTRAL))
		var pos = Vector2(units[source_index].get("pos", Vector2.ZERO))
		if text.contains("我方动物攻击+1") or text.contains("所有动物攻击+1"):
			_add_aura_attack(team, pos, 1.0, true)
		if text.contains("每20点速度"):
			var amount = max(1, floori(float(units[source_index].get("base_speed", 0.0)) / maxf(1.0, 20.0 * UNIT_MOVE_SPEED_MULT)))
			_add_aura_attack(team, pos, float(amount), true)
		if text.contains("速度+20%"):
			_add_aura_speed(team, pos, 1.20, true)


func _unit_attack_cooldown(unit: Dictionary) -> float:
	var cooldown = UNIT_BASE_ATTACK_COOLDOWN / maxf(0.01, UNIT_ATTACK_SPEED_MULT)
	if _unit_skill_text(unit).contains("会比敌人优先攻击"):
		cooldown *= 0.65
	return cooldown


func _unit_attack_target(attacker_index: int, target: Dictionary, distance: float) -> void:
	if attacker_index < 0 or attacker_index >= units.size():
		return
	var attacker = units[attacker_index]
	if float(attacker.get("hp", 0.0)) <= 0.0:
		return
	var target_pos = Vector2(target.get("pos", Vector2.ZERO))
	_trigger_unit_motion(attacker_index, UnitMotionFeedback.KIND_ATTACK, target_pos - Vector2(attacker["pos"]))
	if distance >= RANGED_PROJECTILE_MIN_DISTANCE:
		_play_world_sfx("ranged_attack", Vector2(attacker["pos"]), int(attacker["team"]), -4.0)
		_projectile(Vector2(attacker["pos"]), target_pos, int(attacker["team"]))
	else:
		_play_world_sfx("unit_attack", Vector2(attacker["pos"]), int(attacker["team"]), -3.0)
	var killed = false
	var damage = _unit_attack_damage_against_target(attacker_index, target)
	if String(target["kind"]) == "unit":
		var target_index = int(target["index"])
		killed = _damage_unit(target_index, damage, attacker_index, int(attacker["team"]))
	elif String(target["kind"]) == "building":
		var target_key: Vector2i = target["key"]
		killed = _damage_tile(target_key, int(attacker["team"]), damage)
	_apply_unit_attack_skill(attacker_index, target)
	if killed:
		_apply_unit_kill_skill(attacker_index, target)


func _unit_attack_damage_against_target(attacker_index: int, target: Dictionary) -> float:
	if attacker_index < 0 or attacker_index >= units.size():
		return 0.0
	var attacker = units[attacker_index]
	var damage = float(attacker.get("attack", 0.0))
	var text = _unit_skill_text(attacker)
	if String(target.get("kind", "")) == "unit":
		var target_index = int(target.get("index", -1))
		if target_index >= 0 and target_index < units.size():
			var defender = units[target_index]
			if (text.contains("生命低于敌人") or text.contains("生命值低于对方")) and float(attacker.get("hp", 0.0)) < float(defender.get("hp", 0.0)):
				damage *= 2.0
			if text.contains("生命高于对方") and float(attacker.get("hp", 0.0)) > float(defender.get("hp", 0.0)) and text.contains("额外50%"):
				damage *= 1.5
	return maxf(0.0, damage)


func _target_preference_adjustment(self_id: int, target: Dictionary) -> float:
	var attacker_index = _unit_index_by_id(self_id)
	if attacker_index < 0:
		return 0.0
	var unit = units[attacker_index]
	var text = _unit_skill_text(unit)
	var score = 0.0
	if text.contains("优先攻击敌方建筑"):
		score += -220.0 if String(target.get("kind", "")) == "building" else 70.0
	if String(target.get("kind", "")) == "unit":
		var target_index = int(target.get("index", -1))
		if target_index >= 0 and target_index < units.size():
			var target_unit = units[target_index]
			if text.contains("优先攻击远程"):
				score += -180.0 if float(target_unit.get("range", 0.0)) > HEX_SIZE * 1.45 else 40.0
			if text.contains("优先攻击后排"):
				score += -150.0 if float(target_unit.get("range", 0.0)) > HEX_SIZE * 1.45 or float(target_unit.get("max_hp", 1.0)) <= 3.0 else 40.0
			if text.contains("优先攻击前排"):
				score += -150.0 if float(target_unit.get("max_hp", 1.0)) >= 8.0 else 45.0
	return score


func _incoming_unit_damage(index: int, damage: float) -> float:
	var result = maxf(0.0, damage)
	if index < 0 or index >= units.size():
		return result
	var text = _unit_skill_text(units[index])
	if text.contains("受到伤害-1"):
		result = maxf(0.0, result - 1.0)
	return result


func _damage_guardian_index(target_index: int, source_team: int) -> int:
	if target_index < 0 or target_index >= units.size() or source_team == NEUTRAL:
		return -1
	var target = units[target_index]
	var target_team = int(target.get("team", NEUTRAL))
	if _are_allies(source_team, target_team) or _unit_skill_text(target).contains("承受伤害"):
		return -1
	var target_pos = Vector2(target.get("pos", Vector2.ZERO))
	var best_index = -1
	var best_distance = 999999.0
	for i in range(units.size()):
		if i == target_index or not _are_allies(int(units[i].get("team", NEUTRAL)), target_team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		if not _unit_skill_text(units[i]).contains("承受伤害"):
			continue
		var distance = target_pos.distance_to(Vector2(units[i].get("pos", Vector2.ZERO)))
		if distance <= SKILL_SUPPORT_RADIUS and distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func _lose_unit_hp(index: int, amount: float, source_index: int = -1, source_team: int = NEUTRAL) -> bool:
	if index < 0 or index >= units.size() or amount <= 0.0:
		return false
	if float(units[index].get("hp", 0.0)) <= 0.0:
		return false
	units[index]["hp"] = float(units[index].get("hp", 0.0)) - amount
	_trigger_unit_motion(index, UnitMotionFeedback.KIND_HIT, _unit_hit_direction(index, source_index, source_team))
	_pulse(Vector2(units[index]["pos"]), COLOR_YELLOW)
	if float(units[index]["hp"]) <= 0.0 and not bool(units[index].get("death_handled", false)):
		units[index]["death_handled"] = true
		_handle_unit_death(index, source_index, source_team)
		return true
	return false


func _apply_unit_spawn_skill(index: int) -> void:
	if index < 0 or index >= units.size():
		return
	var unit = units[index]
	if not _unit_skill_triggers_enabled(unit):
		return
	var text = _unit_skill_text(unit)
	if text.contains("随机友军") and text.contains("攻击"):
		_buff_random_allies(int(unit["team"]), index, 1, "attack", 1.0)
	if text.contains("随机友军") and text.contains("生命"):
		_buff_random_allies(int(unit["team"]), index, 1, "hp", 2.0)
	if text.contains("所有友军生命+1") or text.contains("提高所有友军生命值1点"):
		_buff_allies(int(unit["team"]), index, "hp", 1.0)
	if text.contains("护盾"):
		_add_shield_to_unit(index, _unit_shield_amount(unit))
	if text.contains("移速提高"):
		units[index]["haste_timer"] = maxf(float(units[index].get("haste_timer", 0.0)), 3.0)
		_trigger_unit_motion(index, UnitMotionFeedback.KIND_STAT_GAIN)
		_show_unit_value_feedback(index, "speed", 3.0, "s")
	if _unit_uses_structured_skill(unit) and String(unit.get("skill_trigger", "")) == "on_spawn":
		match String(unit.get("skill_effect", "")):
			"gold":
				var gold_amount = _unit_gold_skill_amount(unit)
				if gold_amount > 0:
					_add_gold(int(unit["team"]), gold_amount, _unit_gold_feedback_position(unit))
			"shield":
				_add_shield_to_unit(index, _unit_shield_amount(unit))
			"buff_attack":
				_buff_nearby_allies(int(unit["team"]), Vector2(unit["pos"]), "attack", _unit_buff_amount(unit, 1.0))
			"buff_hp":
				_buff_nearby_allies(int(unit["team"]), Vector2(unit["pos"]), "hp", _unit_buff_amount(unit, 1.0))
			"buff_speed":
				units[index]["haste_timer"] = maxf(float(units[index].get("haste_timer", 0.0)), 3.0)
				_trigger_unit_motion(index, UnitMotionFeedback.KIND_STAT_GAIN)
				_show_unit_value_feedback(index, "speed", 3.0, "s")
			"stun":
				_stun_enemy_units_in_radius(int(unit["team"]), Vector2(unit["pos"]), SKILL_AURA_RADIUS, _unit_stun_seconds(unit))


func _apply_unit_attack_skill(index: int, target: Dictionary) -> void:
	if index < 0 or index >= units.size() or float(units[index].get("hp", 0.0)) <= 0.0:
		return
	var unit = units[index]
	if not _unit_skill_triggers_enabled(unit):
		return
	var text = _unit_skill_text(unit)
	if text.contains("攻击后，攻击+1"):
		_add_attack_bonus(index, 1.0)
	if text.contains("攻击后提高2攻击") and _target_unit_has_less_hp(index, target):
		_add_attack_bonus(index, 2.0)
	if text.contains("每次攻击造成360°AOE伤害"):
		_damage_enemy_units_in_radius(int(unit["team"]), Vector2(unit["pos"]), SKILL_AOE_RADIUS, maxf(1.0, float(unit["attack"]) * 0.55), index, int(target.get("index", -1)))
	if text.contains("额外攻击2个目标"):
		_attack_extra_targets(index, 2, target)
	elif text.contains("额外攻击1个敌人"):
		_attack_extra_targets(index, 1, target)
	if text.contains("攻击施加剧毒减速"):
		_slow_target(target, SKILL_SLOW_SECONDS)
	if text.contains("每次攻击降低自身1生命值") and _lose_unit_hp(index, 1.0):
		return
	if _unit_uses_structured_skill(unit) and String(unit.get("skill_trigger", "")) == "on_attack":
		match String(unit.get("skill_effect", "")):
			"gold":
				var gold_amount = _unit_gold_skill_amount(unit)
				if gold_amount > 0:
					_add_gold(int(unit["team"]), gold_amount, _unit_gold_feedback_position(unit))
			"slow":
				_slow_target(target, SKILL_SLOW_SECONDS)
			"stun":
				_stun_target(target, _unit_stun_seconds(unit))
			"damage":
				_damage_target(target, _unit_effect_damage(unit), index, int(unit["team"]))
			"shield":
				_add_shield_to_unit(index, _unit_shield_amount(unit))
			"execute":
				_execute_target_if_low(target, index, int(unit["team"]))


func _apply_unit_damage_skill(index: int, source_index: int, source_team: int) -> void:
	if index < 0 or index >= units.size() or float(units[index].get("hp", 0.0)) <= 0.0:
		return
	var unit = units[index]
	if not _unit_skill_triggers_enabled(unit):
		return
	var text = _unit_skill_text(unit)
	if text.contains("受到近战伤害") and source_index >= 0 and source_index < units.size():
		_damage_unit(source_index, 1.0, index, int(unit["team"]), false)
	if text.contains("受到伤害后，攻击力+1") or (text.contains("受到攻击后") and text.contains("提高1攻击")):
		_add_attack_bonus(index, 1.0)
	if text.contains("受到攻击后") and text.contains("降低1生命值") and _lose_unit_hp(index, 1.0, source_index, source_team):
		return
	if _unit_uses_structured_skill(unit) and String(unit.get("skill_trigger", "")) == "on_damage":
		match String(unit.get("skill_effect", "")):
			"gold":
				var gold_amount = _unit_gold_skill_amount(unit)
				if gold_amount > 0:
					_add_gold(int(unit["team"]), gold_amount, _unit_gold_feedback_position(unit))
			"heal":
				_heal_unit(index, _unit_heal_amount(unit))
			"shield":
				_add_shield_to_unit(index, _unit_shield_amount(unit))
			"thorns":
				if source_index >= 0 and source_index < units.size():
					_damage_unit(source_index, 1.0, index, int(unit["team"]), false)


func _handle_unit_death(index: int, source_index: int, source_team: int) -> void:
	if index < 0 or index >= units.size():
		return
	var dead = units[index].duplicate(true)
	_queue_unit_death_snapshot(dead, source_index, source_team)
	_play_world_sfx("unit_death", Vector2(dead.get("pos", Vector2.ZERO)), int(dead.get("team", NEUTRAL)), -3.0)
	var team = int(dead.get("team", NEUTRAL))
	var text = _unit_skill_text(dead)
	if _unit_skill_triggers_enabled(dead):
		if _unit_uses_structured_skill(dead) and String(dead.get("skill_trigger", "")) == "on_death" and String(dead.get("skill_effect", "")) == "gold":
			var gold_amount = _unit_gold_skill_amount(dead)
			if gold_amount > 0:
				_add_gold(team, gold_amount, _unit_gold_feedback_position(dead))
		if text.contains("阵亡时，我方2只随机动物攻击+1"):
			_buff_random_allies(team, index, 2, "attack", 1.0)
		if text.contains("阵亡时召唤") or (_unit_uses_structured_skill(dead) and String(dead.get("skill_trigger", "")) == "on_death" and String(dead.get("skill_effect", "")) == "summon"):
			var spawn_card_id = _death_summon_card_id(dead)
			var death_summon_lineage: Array = []
			var raw_lineage = dead.get("death_summon_lineage", [])
			if typeof(raw_lineage) == TYPE_ARRAY:
				death_summon_lineage = (raw_lineage as Array).duplicate()
			death_summon_lineage.append(String(dead.get("card", "")))
			var is_cycle = death_summon_lineage.has(spawn_card_id)
			var spawn_index = units.size()
			_spawn_unit(
				team,
				dead.get("tile", _tile_at_world(Vector2(dead.get("pos", Vector2.ZERO)))),
				spawn_card_id,
				true,
				1,
				{
					"skill_triggers_enabled": not is_cycle,
					"death_summon_lineage": death_summon_lineage,
				}
			)
			if spawn_index < units.size():
				_show_unit_value_feedback(spawn_index, "summon", 1.0)
	_notify_unit_death(dead, index)


func _notify_unit_death(dead: Dictionary, dead_index: int) -> void:
	var dead_team = int(dead.get("team", NEUTRAL))
	for i in range(units.size()):
		if i == dead_index or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		var observer = units[i]
		if not _unit_skill_triggers_enabled(observer):
			continue
		var text = _unit_skill_text(observer)
		if text.contains("每当有动物死亡时") and text.contains("生命值+1"):
			_add_max_hp_bonus(i, 1.0, true)
		if _are_allies(int(observer.get("team", NEUTRAL)), dead_team) and _unit_uses_structured_skill(observer) and String(observer.get("skill_trigger", "")) == "on_ally_death" and String(observer.get("skill_effect", "")) == "gold":
			var gold_amount = _unit_gold_skill_amount(observer)
			if gold_amount > 0:
				_add_gold(int(observer.get("team", dead_team)), gold_amount, _unit_gold_feedback_position(observer))


func _apply_unit_kill_skill(index: int, target: Dictionary) -> void:
	if index < 0 or index >= units.size() or float(units[index].get("hp", 0.0)) <= 0.0:
		return
	if not _unit_skill_triggers_enabled(units[index]):
		return
	var attack_before = float(units[index].get("attack", 0.0))
	var max_hp_before = float(units[index].get("max_hp", 0.0))
	var text = _unit_skill_text(units[index])
	if text.contains("击杀") and text.contains("金币"):
		_add_gold(
			int(units[index]["team"]),
			maxi(1, roundi(float(units[index].get("skill_power", 1.0)))),
			_unit_gold_feedback_position(units[index])
		)
	elif _unit_uses_structured_skill(units[index]) and String(units[index].get("skill_trigger", "")) == "on_kill" and String(units[index].get("skill_effect", "")) == "gold":
		_add_gold(
			int(units[index]["team"]),
			maxi(1, roundi(float(units[index].get("skill_power", 1.0)))),
			_unit_gold_feedback_position(units[index])
		)
	if text.contains("击杀后，50%概率攻击+1") and randf() < 0.5:
		_add_attack_bonus(index, 1.0, false)
	if text.contains("击杀后，攻击+1/生命+1"):
		_add_attack_bonus(index, 1.0, false)
		_add_max_hp_bonus(index, 1.0, true, false)
	if text.contains("击杀时，提高3生命"):
		_add_max_hp_bonus(index, 3.0, true, false)
	if text.contains("击杀后，提高最大生命值"):
		var gained = 1.0
		if String(target.get("kind", "")) == "unit":
			var target_index = int(target.get("index", -1))
			if target_index >= 0 and target_index < units.size():
				gained = maxf(1.0, float(units[target_index].get("max_hp", 1.0)))
		_add_max_hp_bonus(index, gained, true, false)
	if index < units.size() and (float(units[index].get("attack", 0.0)) > attack_before or float(units[index].get("max_hp", 0.0)) > max_hp_before):
		_trigger_unit_motion(index, UnitMotionFeedback.KIND_POWER_UP)
		_play_world_sfx("power_up", Vector2(units[index]["pos"]), int(units[index].get("team", NEUTRAL)), -3.0)


func _apply_unit_capture_skill(index: int, key: Vector2i) -> void:
	if index < 0 or index >= units.size():
		return
	var unit = units[index]
	if not _unit_skill_triggers_enabled(unit):
		return
	if _unit_uses_structured_skill(unit) and String(unit.get("skill_trigger", "")) == "on_capture" and String(unit.get("skill_effect", "")) == "gold":
		var gold_amount = _unit_gold_skill_amount(unit)
		if gold_amount > 0:
			_add_gold(int(unit["team"]), gold_amount, _unit_gold_feedback_position(unit))


func _apply_unit_interval_skill(index: int) -> void:
	if index < 0 or index >= units.size() or float(units[index].get("hp", 0.0)) <= 0.0:
		return
	var unit = units[index]
	if not _unit_skill_triggers_enabled(unit):
		return
	if not _unit_uses_structured_skill(unit):
		return
	match String(unit.get("skill_effect", "")):
		"gold":
			var gold_amount = _unit_gold_skill_amount(unit)
			if gold_amount > 0:
				_add_gold(int(unit["team"]), gold_amount, _unit_gold_feedback_position(unit))
		"heal":
			_heal_lowest_ally(int(unit["team"]), _unit_heal_amount(unit))
		"shield":
			_shield_nearby_allies(int(unit["team"]), Vector2(unit["pos"]), _unit_shield_amount(unit))
		"repair":
			_repair_nearby_building(int(unit["team"]), Vector2(unit["pos"]), _unit_heal_amount(unit))


func _card_skill_cooldown(card: Dictionary) -> float:
	return maxf(1.0, float(card.get("skill_cooldown_sec", 0.0)))


func _card_uses_interval_skill(card: Dictionary) -> bool:
	return String(card.get("skill_trigger", "")) == "on_interval"


func _unit_uses_interval_skill(unit: Dictionary) -> bool:
	return String(unit.get("skill_trigger", "")) == "on_interval"


func _unit_skill_triggers_enabled(unit: Dictionary) -> bool:
	return bool(unit.get("skill_triggers_enabled", true))


func _unit_uses_structured_skill(unit: Dictionary) -> bool:
	return (
		_unit_skill_triggers_enabled(unit)
		and String(unit.get("skill_trigger", "")) != ""
		and String(unit.get("skill_effect", "")) != ""
		and _unit_skill_text(unit) == ""
	)


func _unit_gold_skill_amount(unit: Dictionary) -> int:
	if String(unit.get("skill_effect", "")) != "gold":
		return 0
	var chance = clampf(float(unit.get("skill_chance", 1.0)), 0.0, 1.0)
	if chance <= 0.0 or randf() > chance:
		return 0
	return maxi(1, roundi(float(unit.get("skill_power", 1.0))))


func _unit_skill_cooldown(unit: Dictionary) -> float:
	return maxf(1.0, float(unit.get("skill_cooldown_sec", 0.0)))


func _unit_card(unit: Dictionary) -> Dictionary:
	return _card_by_id(String(unit.get("card", "")))


func _unit_skill_text(unit: Dictionary) -> String:
	var card = _unit_card(unit)
	if card.is_empty():
		return ""
	return String(card.get("skill_text", "")).strip_edges()


func _card_extra_spawn_count(card: Dictionary) -> int:
	var text = String(card.get("skill_text", ""))
	if text.contains("数量+2"):
		return 2
	if text.contains("数量+1") or text.contains("额外召唤一个"):
		return 1
	return 0


func _unit_index_by_id(unit_id: int) -> int:
	for i in range(units.size()):
		if int(units[i].get("id", -1)) == unit_id:
			return i
	return -1


func _add_gold(team: int, amount: int, feedback_anchor: Variant = null) -> void:
	if amount <= 0:
		return
	if team == PLAYER:
		gold += amount
	elif battle_mode == BATTLE_MODE_MULTIPLAYER:
		multiplayer_gold[team] = int(multiplayer_gold.get(team, STARTING_GOLD)) + amount
	else:
		enemy_gold += amount
	if typeof(feedback_anchor) == TYPE_DICTIONARY:
		_show_gold_gain_feedback(feedback_anchor, amount, team)
	elif typeof(feedback_anchor) == TYPE_VECTOR2:
		_show_gold_gain_feedback({"pos": Vector2(feedback_anchor), "unit_id": -1}, amount, team)


func _unit_gold_feedback_position(unit: Dictionary) -> Dictionary:
	return {
		"pos": Vector2(unit.get("pos", Vector2.ZERO)) + Vector2(0, -34),
		"unit_id": int(unit.get("id", -1)),
	}


func _show_gold_gain_feedback(anchor: Dictionary, amount: int, team: int) -> void:
	if amount <= 0:
		return
	var pos = Vector2(anchor.get("pos", Vector2.ZERO))
	var unit_id = int(anchor.get("unit_id", -1))
	for index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[index]
		if String(effect.get("kind", "")) != "gold_gain" or int(effect.get("team", NEUTRAL)) != team or int(effect.get("unit_id", -1)) != unit_id:
			continue
		var duration = maxf(0.01, float(effect.get("duration", GOLD_GAIN_FEEDBACK_DURATION)))
		var elapsed = duration - float(effect.get("time", 0.0))
		if elapsed > GOLD_GAIN_FEEDBACK_MERGE_WINDOW or (unit_id < 0 and Vector2(effect.get("pos", pos)).distance_to(pos) > 18.0):
			continue
		effect["amount"] = int(effect.get("amount", 0)) + amount
		effect["time"] = duration
		effects[index] = effect
		return
	effects.append({
		"kind": "gold_gain",
		"pos": pos,
		"unit_id": unit_id,
		"team": team,
		"amount": amount,
		"time": GOLD_GAIN_FEEDBACK_DURATION,
		"duration": GOLD_GAIN_FEEDBACK_DURATION,
	})


func _show_unit_value_feedback(index: int, stat: String, amount: float, suffix: String = "") -> void:
	if index < 0 or index >= units.size() or is_zero_approx(amount):
		return
	var unit_id = int(units[index].get("id", -1))
	var pos = Vector2(units[index].get("pos", Vector2.ZERO)) + Vector2(0, -34)
	for effect_index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[effect_index]
		if String(effect.get("kind", "")) != "unit_value" or String(effect.get("stat", "")) != stat or int(effect.get("unit_id", -1)) != unit_id:
			continue
		var duration = maxf(0.01, float(effect.get("duration", UNIT_VALUE_FEEDBACK_DURATION)))
		var elapsed = duration - float(effect.get("time", 0.0))
		if elapsed > UNIT_VALUE_FEEDBACK_MERGE_WINDOW:
			continue
		effect["amount"] = float(effect.get("amount", 0.0)) + amount
		effect["suffix"] = suffix
		effect["time"] = duration
		effects[effect_index] = effect
		return
	effects.append({
		"kind": "unit_value",
		"stat": stat,
		"unit_id": unit_id,
		"pos": pos,
		"amount": amount,
		"suffix": suffix,
		"time": UNIT_VALUE_FEEDBACK_DURATION,
		"duration": UNIT_VALUE_FEEDBACK_DURATION,
	})


func _effect_world_position(effect: Dictionary) -> Vector2:
	var unit_id = int(effect.get("unit_id", -1))
	if unit_id >= 0:
		var index = _unit_index_by_id(unit_id)
		if index >= 0 and index < units.size():
			return Vector2(units[index].get("pos", Vector2.ZERO)) + Vector2(0, -34)
	return Vector2(effect.get("pos", Vector2.ZERO))


func _gold_for_team(team: int) -> int:
	if team == PLAYER:
		return gold
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		return int(multiplayer_gold.get(team, 0))
	return enemy_gold


func _display_gold() -> int:
	return _gold_for_team(_local_control_team()) if screen == SCREEN_BATTLE else gold


func _spend_team_gold(team: int, amount: int) -> bool:
	if amount < 0 or _gold_for_team(team) < amount:
		return false
	if team == PLAYER:
		gold -= amount
	elif battle_mode == BATTLE_MODE_MULTIPLAYER:
		multiplayer_gold[team] = int(multiplayer_gold.get(team, 0)) - amount
	else:
		enemy_gold -= amount
	return true


func _add_attack_bonus(index: int, amount: float, play_audio: bool = true) -> void:
	if index < 0 or index >= units.size() or amount == 0.0:
		return
	units[index]["attack_bonus"] = float(units[index].get("attack_bonus", 0.0)) + amount
	units[index]["attack"] = maxf(0.0, float(units[index].get("attack", 0.0)) + amount)
	if amount > 0.0:
		_trigger_unit_motion(index, UnitMotionFeedback.KIND_STAT_GAIN)
		_show_unit_value_feedback(index, "attack", amount)
		if play_audio:
			_play_world_sfx("stat_gain", Vector2(units[index]["pos"]), int(units[index].get("team", NEUTRAL)), -6.0)
	_pulse(Vector2(units[index]["pos"]), COLOR_ORANGE)


func _add_max_hp_bonus(index: int, amount: float, heal: bool, play_audio: bool = true) -> void:
	if index < 0 or index >= units.size() or amount == 0.0:
		return
	units[index]["max_hp_bonus"] = float(units[index].get("max_hp_bonus", 0.0)) + amount
	units[index]["max_hp"] = float(units[index].get("max_hp", 1.0)) + amount
	if heal:
		units[index]["hp"] = minf(float(units[index].get("max_hp", 1.0)), float(units[index].get("hp", 0.0)) + amount)
	if amount > 0.0:
		_trigger_unit_motion(index, UnitMotionFeedback.KIND_STAT_GAIN)
		_show_unit_value_feedback(index, "hp", amount)
		if play_audio:
			_play_world_sfx("stat_gain", Vector2(units[index]["pos"]), int(units[index].get("team", NEUTRAL)), -6.0)
	_pulse(Vector2(units[index]["pos"]), COLOR_GREEN)


func _add_shield_to_unit(index: int, amount: float) -> void:
	if index < 0 or index >= units.size() or amount <= 0.0:
		return
	units[index]["shield"] = float(units[index].get("shield", 0.0)) + amount
	_trigger_unit_motion(index, UnitMotionFeedback.KIND_STAT_GAIN)
	_show_unit_value_feedback(index, "shield", amount)
	_play_world_sfx("stat_gain", Vector2(units[index]["pos"]), int(units[index].get("team", NEUTRAL)), -6.0)
	_pulse(Vector2(units[index]["pos"]), COLOR_BLUE)


func _heal_unit(index: int, amount: float) -> void:
	if index < 0 or index >= units.size() or amount <= 0.0:
		return
	var hp_before = float(units[index].get("hp", 0.0))
	units[index]["hp"] = minf(float(units[index].get("max_hp", 1.0)), float(units[index].get("hp", 0.0)) + amount)
	if float(units[index].get("hp", 0.0)) > hp_before:
		var healed = float(units[index].get("hp", 0.0)) - hp_before
		_trigger_unit_motion(index, UnitMotionFeedback.KIND_STAT_GAIN)
		_show_unit_value_feedback(index, "heal", healed)
		_play_world_sfx("stat_gain", Vector2(units[index]["pos"]), int(units[index].get("team", NEUTRAL)), -6.0)
	_pulse(Vector2(units[index]["pos"]), COLOR_GREEN)


func _buff_random_allies(team: int, source_index: int, count: int, stat: String, amount: float) -> void:
	var options = []
	for i in range(units.size()):
		if i == source_index or not _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		options.append(i)
	for n in range(min(count, options.size())):
		var pick_pos = randi() % options.size()
		var target_index = int(options[pick_pos])
		options.remove_at(pick_pos)
		_apply_unit_stat_buff(target_index, stat, amount)


func _buff_allies(team: int, source_index: int, stat: String, amount: float) -> void:
	for i in range(units.size()):
		if i == source_index or not _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		_apply_unit_stat_buff(i, stat, amount)


func _buff_nearby_allies(team: int, pos: Vector2, stat: String, amount: float) -> void:
	for i in range(units.size()):
		if not _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		if pos.distance_to(Vector2(units[i]["pos"])) <= SKILL_SUPPORT_RADIUS:
			_apply_unit_stat_buff(i, stat, amount)


func _apply_unit_stat_buff(index: int, stat: String, amount: float) -> void:
	match stat:
		"attack":
			_add_attack_bonus(index, amount)
		"hp":
			_add_max_hp_bonus(index, amount, true)
		"shield":
			_add_shield_to_unit(index, amount)


func _add_aura_attack(team: int, pos: Vector2, amount: float, global: bool) -> void:
	for i in range(units.size()):
		if not _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		if global or pos.distance_to(Vector2(units[i]["pos"])) <= SKILL_AURA_RADIUS:
			units[i]["attack"] = maxf(0.0, float(units[i].get("attack", 0.0)) + amount)
			_show_unit_value_feedback(i, "attack", amount)


func _add_aura_speed(team: int, pos: Vector2, mult: float, global: bool) -> void:
	for i in range(units.size()):
		if not _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		if global or pos.distance_to(Vector2(units[i]["pos"])) <= SKILL_AURA_RADIUS:
			var speed_before = float(units[i].get("speed", 0.0))
			units[i]["speed"] = speed_before * mult
			_show_unit_value_feedback(i, "speed", float(units[i]["speed"]) - speed_before)


func _stun_enemy_units_in_radius(team: int, pos: Vector2, radius: float, seconds: float) -> void:
	for i in range(units.size()):
		if _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		if pos.distance_to(Vector2(units[i]["pos"])) <= radius:
			units[i]["stun_timer"] = maxf(float(units[i].get("stun_timer", 0.0)), seconds)
			_show_unit_value_feedback(i, "stun", seconds, "s")
			_pulse(Vector2(units[i]["pos"]), COLOR_PURPLE)


func _slow_target(target: Dictionary, seconds: float) -> void:
	if String(target.get("kind", "")) != "unit":
		return
	var target_index = int(target.get("index", -1))
	if target_index >= 0 and target_index < units.size():
		units[target_index]["slow_timer"] = maxf(float(units[target_index].get("slow_timer", 0.0)), seconds)
		_show_unit_value_feedback(target_index, "slow", seconds, "s")
		_pulse(Vector2(units[target_index]["pos"]), COLOR_BLUE)


func _stun_target(target: Dictionary, seconds: float) -> void:
	if String(target.get("kind", "")) != "unit":
		return
	var target_index = int(target.get("index", -1))
	if target_index >= 0 and target_index < units.size():
		units[target_index]["stun_timer"] = maxf(float(units[target_index].get("stun_timer", 0.0)), seconds)
		_show_unit_value_feedback(target_index, "stun", seconds, "s")
		_pulse(Vector2(units[target_index]["pos"]), COLOR_PURPLE)


func _damage_target(target: Dictionary, damage: float, source_index: int, source_team: int) -> void:
	if damage <= 0.0:
		return
	if String(target.get("kind", "")) == "unit":
		_damage_unit(int(target.get("index", -1)), damage, source_index, source_team)
	elif String(target.get("kind", "")) == "building":
		_damage_tile(target.get("key", Vector2i(-99, -99)), source_team, damage)


func _damage_enemy_units_in_radius(team: int, pos: Vector2, radius: float, damage: float, source_index: int, excluded_index: int = -1) -> void:
	for i in range(units.size()):
		if i == excluded_index or _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		if pos.distance_to(Vector2(units[i]["pos"])) <= radius:
			_damage_unit(i, damage, source_index, team)


func _attack_extra_targets(index: int, count: int, primary_target: Dictionary) -> void:
	if index < 0 or index >= units.size():
		return
	var unit = units[index]
	var excluded_index = int(primary_target.get("index", -1)) if String(primary_target.get("kind", "")) == "unit" else -1
	var picked = []
	for n in range(count):
		var best_index = -1
		var best_distance = 999999.0
		for i in range(units.size()):
			if i == excluded_index or picked.has(i) or _are_allies(int(units[i].get("team", NEUTRAL)), int(unit["team"])) or float(units[i].get("hp", 0.0)) <= 0.0:
				continue
			var distance = Vector2(unit["pos"]).distance_to(Vector2(units[i]["pos"]))
			if distance <= float(unit["range"]) * 1.35 and distance < best_distance:
				best_distance = distance
				best_index = i
		if best_index < 0:
			return
		picked.append(best_index)
		_projectile(Vector2(unit["pos"]), Vector2(units[best_index]["pos"]), int(unit["team"]))
		_damage_unit(best_index, maxf(1.0, float(unit["attack"]) * 0.75), index, int(unit["team"]))


func _execute_target_if_low(target: Dictionary, source_index: int, source_team: int) -> void:
	if String(target.get("kind", "")) != "unit":
		return
	var target_index = int(target.get("index", -1))
	if target_index < 0 or target_index >= units.size():
		return
	if float(units[target_index].get("hp", 0.0)) <= float(units[target_index].get("max_hp", 1.0)) * 0.25:
		_damage_unit(target_index, float(units[target_index].get("hp", 0.0)) + 999.0, source_index, source_team)


func _heal_lowest_ally(team: int, amount: float) -> void:
	var best_index = -1
	var best_ratio = 2.0
	for i in range(units.size()):
		if not _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		var ratio = float(units[i].get("hp", 0.0)) / maxf(1.0, float(units[i].get("max_hp", 1.0)))
		if ratio < best_ratio:
			best_ratio = ratio
			best_index = i
	if best_index >= 0:
		_heal_unit(best_index, amount)


func _shield_nearby_allies(team: int, pos: Vector2, amount: float) -> void:
	for i in range(units.size()):
		if not _are_allies(int(units[i].get("team", NEUTRAL)), team) or float(units[i].get("hp", 0.0)) <= 0.0:
			continue
		if pos.distance_to(Vector2(units[i]["pos"])) <= SKILL_SUPPORT_RADIUS:
			_add_shield_to_unit(i, amount)


func _repair_nearby_building(team: int, pos: Vector2, amount: float) -> void:
	var best_key = Vector2i(-99, -99)
	var best_distance = 999999.0
	for key in tiles.keys():
		var tile = tiles[key]
		if not _are_allies(int(tile.get("team", NEUTRAL)), team) or String(tile.get("building", "")) == "":
			continue
		if float(tile.get("hp", 0.0)) >= float(tile.get("max_hp", 0.0)):
			continue
		var distance = pos.distance_to(_hex_center(key))
		if distance < best_distance and distance <= SKILL_SUPPORT_RADIUS:
			best_distance = distance
			best_key = key
	if best_key.x == -99:
		return
	var tile = tiles[best_key]
	tile["hp"] = minf(float(tile.get("max_hp", 1.0)), float(tile.get("hp", 0.0)) + amount)
	tiles[best_key] = tile
	_pulse(_hex_center(best_key), COLOR_GREEN)


func _target_unit_has_less_hp(index: int, target: Dictionary) -> bool:
	if index < 0 or index >= units.size() or String(target.get("kind", "")) != "unit":
		return false
	var target_index = int(target.get("index", -1))
	if target_index < 0 or target_index >= units.size():
		return false
	return float(units[index].get("hp", 0.0)) > float(units[target_index].get("hp", 0.0))


func _death_summon_card_id(unit: Dictionary) -> String:
	var text = _unit_skill_text(unit)
	if text.contains("大猩猩") and not _card_by_id("gorilla").is_empty():
		return "gorilla"
	return String(unit.get("card", ""))


func _unit_shield_amount(unit: Dictionary) -> float:
	return maxf(1.0, roundf(float(unit.get("skill_power", 12.0)) / 18.0))


func _unit_heal_amount(unit: Dictionary) -> float:
	return maxf(1.0, roundf(float(unit.get("skill_power", 12.0)) / 20.0))


func _unit_buff_amount(unit: Dictionary, fallback: float) -> float:
	return maxf(fallback, minf(3.0, roundf(float(unit.get("skill_power", fallback)))))


func _unit_effect_damage(unit: Dictionary) -> float:
	return maxf(1.0, roundf(float(unit.get("skill_power", 8.0)) / 8.0))


func _unit_stun_seconds(unit: Dictionary) -> float:
	var value = float(unit.get("skill_power", SKILL_STUN_SECONDS))
	if value > 0.0 and value <= 3.0:
		return value
	return SKILL_STUN_SECONDS


func _try_unlock(key: Vector2i) -> bool:
	var team = _local_control_team()
	if not _can_unlock(key, team):
		return false
	if _is_online_match_active():
		if online_room_service == null or not bool(online_room_service.call("is_connected_to_server")):
			_toast("网络已断开，无法执行操作")
			return true
		online_command_sequence += 1
		online_room_service.call("send_battle_command", {
			"action": "unlock_tile",
			"sequence": online_command_sequence,
			"q": key.x,
			"r": key.y,
		})
		_pulse(_hex_center(key), _team_color(team).lightened(0.28))
		return true
	return _try_unlock_for_team(key, team, true)


func _try_unlock_for_team(key: Vector2i, team: int, show_feedback: bool = false) -> bool:
	if not _can_unlock(key, team):
		return false
	var tile = tiles[key]
	var cost = _unlock_cost(key, team)
	var available_gold = _gold_for_team(team)
	if available_gold < cost:
		if show_feedback:
			GameAudio.play_sfx("ui_error")
			_toast("金币不足，还差%d" % [cost - available_gold])
		return true
	_spend_team_gold(team, cost)
	var was_direct_tower = String(tile.get("site", "")) == "tower"
	var result_label = _apply_unlock(key, team, String(tile.get("site_card", "")))
	_record_tower_purchase_if_built(key, team, was_direct_tower)
	if show_feedback:
		_show_unlock_card_popup(key)
		GameAudio.play_sfx("unlock")
		_toast("已解锁 " + result_label)
	return true


func _can_unlock(key: Vector2i, team: int) -> bool:
	if battle_mode == BATTLE_MODE_MULTIPLAYER and not _is_multiplayer_team_alive(team):
		return false
	if _uses_axial_battle_map():
		return MultiplayerRules.can_unlock(tiles, key, team)
	return BoardRules.can_unlock(tiles, key, team)


func _unlock_cost(key: Vector2i, team: int) -> int:
	if not tiles.has(key):
		return 0
	var tile: Dictionary = tiles[key]
	if String(tile.get("site", "")) == "tower" and String(tile.get("building", "")) == "":
		return TOWER_BASE_COST + int(tower_purchase_counts.get(team, 0)) * TOWER_COST_STEP
	return int(tile.get("site_cost", 0))


func _record_tower_purchase_if_built(key: Vector2i, team: int, was_direct_tower: bool) -> void:
	if not was_direct_tower or not tiles.has(key):
		return
	if String(tiles[key].get("building", "")) != "tower" or int(tiles[key].get("team", NEUTRAL)) != team:
		return
	tower_purchase_counts[team] = int(tower_purchase_counts.get(team, 0)) + 1


func _resolved_site(tile: Dictionary) -> String:
	return BoardRules.resolved_site(tile)


func _spawn_card_for_tile(tile: Dictionary, team: int) -> String:
	var card_id = String(tile.get("site_card", ""))
	if card_id != "":
		return card_id
	return _team_deck_card(team, 0)


func _site_card_for_team(key: Vector2i, tile: Dictionary, team: int, fallback_card_id: String) -> String:
	var site = _resolved_site(tile)
	if site != "barracks" and site != "hall":
		return fallback_card_id
	var site_seed = int(tile.get("site_roll_seed", BoardRules.site_seed_for_key(key)))
	var target_rarity = String(tile.get("site_target_rarity", ""))
	if target_rarity == "":
		target_rarity = "common"
	var roster = _team_deck(team)
	return _deck_card_for_target_rarity(roster, target_rarity, site_seed, CARD_KIND_ANIMAL)


func _defense_card_for_team(key: Vector2i, tile: Dictionary, team: int, _candidate_card_id: String = "") -> String:
	var site_seed = int(tile.get("site_roll_seed", BoardRules.site_seed_for_key(key)))
	var target_rarity = String(tile.get("site_target_rarity", ""))
	if target_rarity == "":
		target_rarity = "common"
	return _defense_card_for_target_rarity(target_rarity, site_seed, team)


func _defense_card_for_target_rarity(target_rarity: String, site_seed: int, team: int) -> String:
	return CardRules.defense_card_id_for_target_rarity(_defense_cards_in_team_deck(team), target_rarity, site_seed)


func _defense_cards_in_team_deck(team: int) -> Array:
	var result = []
	var added = {}
	for card_id in _team_deck(team):
		var id = String(card_id)
		if id == "" or added.has(id):
			continue
		var card = _card_by_id(id)
		if card.is_empty() or _card_kind(card) != CARD_KIND_DEFENSE:
			continue
		result.append(card)
		added[id] = true
	return result


func _enemy_card_for_cost(cost: int, site_seed: int) -> String:
	return _deck_card_for_target_rarity(enemy_deck, "common", site_seed + cost, CARD_KIND_ANIMAL)


func _enemy_deck_card(index: int) -> String:
	if enemy_deck.is_empty():
		return "rabbit"
	return String(enemy_deck[index % enemy_deck.size()])


func _card_for_cost(cost: int, site_seed: int = 0) -> String:
	return _deck_card_for_target_rarity(deck, "common", site_seed + cost, CARD_KIND_ANIMAL)


func _card_for_tier_range(min_tier: int, max_tier: int, site_seed: int) -> String:
	return _deck_card_for_target_rarity(deck, _rarity_for_tier(max_tier), site_seed + min_tier * 17 + max_tier * 31, CARD_KIND_ANIMAL)


func _deck_card_for_target_rarity(roster: Array, target_rarity: String, site_seed: int, required_kind: String = "") -> String:
	for rarity in CardRules.rarity_search_order(target_rarity):
		var rank = _rarity_sort_rank(String(rarity))
		var options = []
		for card_id in roster:
			var id = String(card_id)
			if id == "":
				continue
			var card = _card_by_id(id)
			if not card.is_empty() and (required_kind == "" or _card_kind(card) == required_kind) and String(card.get("rarity", "common")) == rarity:
				options.append(id)
		if not options.is_empty():
			var pick_seed = absi(site_seed + rank * 97 + roster.size() * 13)
			return String(options[pick_seed % options.size()])
	return ""


func _all_card_ids_for_kind(kind: String) -> Array:
	var result = []
	for card in _all_cards_for_kind(kind):
		result.append(String(card.get("id", "")))
	return result


func _all_cards_for_kind(kind: String) -> Array:
	var result = []
	for card in cards:
		if _card_kind(card) == kind:
			result.append(card)
	return result


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
	if building == "tower" or building == "mine":
		var card = _card_by_id(card_id)
		if not card.is_empty():
			return float(_card_stats_for_team(card, team)["max_hp"])
	return BoardRules.building_hp(building)


func _building_delay(building: String, team: int, card_id: String) -> float:
	var card_interval = -1.0
	if building == "barracks" or building == "hall" or building == "tower":
		var card = _card_by_id(card_id)
		if not card.is_empty():
			card_interval = float(_card_stats_for_team(card, team)["summon_interval_sec"])
	return BoardRules.building_delay(building, team, card_interval)


func _battle_reward_tickets(text: String) -> int:
	return BATTLE_WIN_REWARD_TICKETS if text == "胜利" else BATTLE_LOSS_REWARD_TICKETS


func _finish_battle(text: String, play_audio: bool = true) -> void:
	if game_over:
		return
	result_text = text
	game_over = true
	pause_open = false
	if play_audio:
		GameAudio.play_result("victory" if text == "胜利" else "defeat")
	_apply_rank_result(text == "胜利")
	_rebuild_result_player_entries()
	if not battle_reward_given:
		battle_reward_given = true
		last_battle_reward_tickets = _battle_reward_tickets(text)
		gacha_tickets += last_battle_reward_tickets
		_toast("获得%d张抽卡券" % last_battle_reward_tickets)


func _is_multiplayer_team_alive(team: int) -> bool:
	return bool(multiplayer_alive.get(team, false))


func _active_multiplayer_teams() -> Array:
	if not room_active_team_ids.is_empty():
		return room_active_team_ids.duplicate()
	return _room_active_teams()


func _multiplayer_base_key(team: int) -> Vector2i:
	return room_base_keys.get(team, MultiplayerRules.INVALID_KEY)


func _original_multiplayer_base_team(key: Vector2i) -> int:
	for team in room_base_keys.keys():
		if room_base_keys[team] == key:
			return int(team)
	return NEUTRAL


func _are_allies(team_a: int, team_b: int) -> bool:
	if team_a == NEUTRAL or team_b == NEUTRAL:
		return false
	if team_a == team_b:
		return true
	if battle_mode != BATTLE_MODE_MULTIPLAYER:
		return false
	if multiplayer_free_for_all:
		return false
	return (team_a >= 1 and team_a <= 3 and team_b >= 1 and team_b <= 3) or (team_a >= 4 and team_a <= 6 and team_b >= 4 and team_b <= 6)


func _multiplayer_side_for_team(team: int) -> int:
	if team >= 1 and team <= 3:
		return 0
	if team >= 4 and team <= 6:
		return 1
	return -1


func _multiplayer_alive_count() -> int:
	var count = 0
	for team in _active_multiplayer_teams():
		if _is_multiplayer_team_alive(team):
			count += 1
	return count


func _eliminate_multiplayer_team(defeated_team: int, attacker: int, captured_base_key: Vector2i = MultiplayerRules.INVALID_KEY) -> void:
	if battle_mode != BATTLE_MODE_MULTIPLAYER or defeated_team == NEUTRAL or not _is_multiplayer_team_alive(defeated_team):
		return
	if captured_base_key == MultiplayerRules.INVALID_KEY:
		captured_base_key = _multiplayer_base_key(defeated_team)
	multiplayer_alive[defeated_team] = false
	_clear_eliminated_team_units(defeated_team, attacker)
	_transfer_eliminated_territory(defeated_team, attacker, captured_base_key)
	if multiplayer_free_for_all:
		if defeated_team == PLAYER:
			_toast("你已淘汰，等待结算")
		else:
			_toast("%d号玩家被淘汰" % defeated_team)
		if _multiplayer_alive_count() == 1:
			_finish_multiplayer_free_for_all(_multiplayer_timeout_placement())
		return
	_toast("%d号玩家被淘汰" % defeated_team)
	var side_a_alive = _multiplayer_side_alive(0)
	var side_b_alive = _multiplayer_side_alive(1)
	if not side_a_alive and not side_b_alive:
		_finish_multiplayer_battle("draw")
	elif not side_a_alive:
		_finish_multiplayer_battle("loss")
	elif not side_b_alive:
		_finish_multiplayer_battle("win")


func _clear_eliminated_team_units(defeated_team: int, attacker: int) -> void:
	for i in range(units.size()):
		if int(units[i].get("team", NEUTRAL)) != defeated_team:
			continue
		if float(units[i].get("hp", 0.0)) > 0.0:
			_queue_unit_death_snapshot(units[i].duplicate(true), -1, attacker)
		units[i]["hp"] = 0.0
		units[i]["death_handled"] = true


func _transfer_eliminated_territory(defeated_team: int, attacker: int, captured_base_key: Vector2i) -> void:
	for key in tiles.keys():
		var tile: Dictionary = tiles[key]
		if key == captured_base_key:
			tiles[key] = BoardRules.as_captured_base(tile, attacker)
			continue
		var tile_team = int(tile.get("team", NEUTRAL))
		var is_defeated_locked_territory = tile_team == NEUTRAL and BoardRules.visual_owner(tile) == defeated_team
		if tile_team != defeated_team and not is_defeated_locked_territory:
			continue
		tiles[key] = BoardRules.as_transferred_territory(tile, attacker)


func _multiplayer_side_alive(side: int) -> bool:
	for team in _active_multiplayer_teams():
		if _multiplayer_side_for_team(int(team)) == side and _is_multiplayer_team_alive(int(team)):
			return true
	return false


func _multiplayer_side_alive_count(side: int) -> int:
	var count = 0
	for team in _active_multiplayer_teams():
		if _multiplayer_side_for_team(int(team)) == side and _is_multiplayer_team_alive(int(team)):
			count += 1
	return count


func _finish_multiplayer_battle(outcome: String, play_audio: bool = true) -> void:
	if game_over:
		return
	if not outcome in ["win", "draw", "loss"]:
		outcome = "draw"
	authority_room_result = outcome
	var local_outcome = _local_outcome_for_authority_result(outcome)
	room_result = local_outcome
	multiplayer_placement = 1 if local_outcome == "win" else (2 if local_outcome == "draw" else 3)
	result_text = "胜利" if local_outcome == "win" else ("平局" if local_outcome == "draw" else "失败")
	game_over = true
	pause_open = false
	if play_audio:
		GameAudio.play_result("victory" if local_outcome == "win" else ("draw" if local_outcome == "draw" else "defeat"))
	var reward = _room_result_rewards(local_outcome)
	last_multiplayer_star_delta = int(reward.get("star_delta", -1))
	last_battle_reward_tickets = int(reward.get("gacha_tickets", 1))
	if not battle_reward_given:
		battle_reward_given = true
		gacha_tickets += last_battle_reward_tickets
		_apply_multiplayer_rank_result(local_outcome, last_multiplayer_star_delta)
		_rebuild_result_player_entries()
		var star_text = ("+" if last_multiplayer_star_delta > 0 else "") + str(last_multiplayer_star_delta)
		_toast("%s：%s星，%d张抽卡券" % [result_text, star_text, last_battle_reward_tickets])


func _finish_multiplayer_free_for_all(placement: int, play_audio: bool = true) -> void:
	if game_over:
		return
	multiplayer_placement = clampi(placement, 1, MultiplayerRules.TEAM_IDS.size())
	multiplayer_placements[PLAYER] = multiplayer_placement
	room_result = ""
	result_text = "第%d名" % multiplayer_placement
	game_over = true
	pause_open = false
	if play_audio:
		GameAudio.play_result("victory" if multiplayer_placement == 1 else "defeat")
	var reward = MultiplayerRules.placement_rewards(multiplayer_placement)
	last_multiplayer_star_delta = int(reward.get("star_delta", -1))
	last_battle_reward_tickets = int(reward.get("gacha_tickets", 1))
	if not battle_reward_given:
		battle_reward_given = true
		gacha_tickets += last_battle_reward_tickets
		_apply_multiplayer_rank_result("win" if multiplayer_placement == 1 else "loss", last_multiplayer_star_delta)
		_rebuild_result_player_entries()
		var star_text = ("+" if last_multiplayer_star_delta > 0 else "") + str(last_multiplayer_star_delta)
		_toast("第%d名：%s星，%d张抽卡券" % [multiplayer_placement, star_text, last_battle_reward_tickets])


func _room_result_rewards(outcome: String) -> Dictionary:
	if outcome == "win":
		return {"star_delta": 3, "gacha_tickets": 5}
	if outcome == "draw":
		return {"star_delta": 0, "gacha_tickets": 2}
	return {"star_delta": -1, "gacha_tickets": 1}


func _apply_multiplayer_rank_result(outcome: String, star_delta: int) -> void:
	var profile = RankingRules.normalize_profile(_player_profile())
	var result = RankingRules.star_result_for_delta(String(profile["rank_key"]), int(profile["stars"]), star_delta)
	profile["rank_key"] = String(result["new_rank"]["key"])
	profile["stars"] = int(result["new_rank"]["stars"])
	profile["matches"] = int(profile.get("matches", 0)) + 1
	if outcome == "win":
		profile["wins"] = int(profile.get("wins", 0)) + 1
	elif outcome == "loss":
		profile["losses"] = int(profile.get("losses", 0)) + 1
	rank_db["player"] = profile
	last_rank_result = result
	_save_rank_database()


func _rebuild_result_player_entries() -> void:
	result_player_entries.clear()
	result_players_scroll = 0.0
	if battle_mode == BATTLE_MODE_CLASSIC:
		_build_classic_result_entries()
		return
	var local_team = _local_control_team()
	var fallback_rank = RankingRules.rank_state_for_key_and_stars(
		active_match_rank_key if active_match_rank_key != "" else String(_player_rank_state()["key"]),
		active_match_player_stars if active_match_rank_key != "" else int(_player_rank_state()["stars"])
	)
	var live_ranking = _multiplayer_live_ranking()
	for live_entry in live_ranking:
		var team = int(live_entry.get("team", NEUTRAL))
		if not multiplayer_placements.has(team):
			multiplayer_placements[team] = int(live_entry.get("rank", result_player_entries.size() + 1))
	if multiplayer_free_for_all:
		multiplayer_placements[local_team] = multiplayer_placement
	for team_value in _active_multiplayer_teams():
		var team = int(team_value)
		var placement = int(multiplayer_placements.get(team, _multiplayer_team_rank(team)))
		var team_outcome = _result_outcome_for_team(team, local_team)
		var star_delta = int(MultiplayerRules.placement_rewards(placement).get("star_delta", -1)) if multiplayer_free_for_all else int(_room_result_rewards(team_outcome).get("star_delta", -1))
		var old_rank = _result_rank_state_for_team(team, fallback_rank)
		var new_rank = RankingRules.star_result_for_delta(String(old_rank["key"]), int(old_rank["stars"]), star_delta)["new_rank"]
		if team == local_team and not last_rank_result.is_empty():
			old_rank = last_rank_result.get("old_rank", old_rank)
			new_rank = last_rank_result.get("new_rank", new_rank)
		result_player_entries.append(_result_player_entry(
			team,
			placement,
			_result_player_name_for_team(team),
			team == local_team,
			old_rank,
			new_rank,
			star_delta
		))
	result_player_entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("placement", 99)) < int(b.get("placement", 99)))


func _build_classic_result_entries() -> void:
	var local_won = result_text == "胜利"
	var local_old = last_rank_result.get("old_rank", RankingRules.rank_state_for_key_and_stars(active_match_rank_key, active_match_player_stars))
	var local_new = last_rank_result.get("new_rank", local_old)
	result_player_entries.append(_result_player_entry(PLAYER, 1 if local_won else 2, _online_player_name(), true, local_old, local_new, 1 if local_won else -1))
	var opponent_old = RankingRules.rank_state_for_key_and_stars(
		String(active_match_mirror.get("rank_key", active_match_rank_key)),
		int(active_match_mirror.get("stars", active_match_player_stars))
	)
	var opponent_delta = -1 if local_won else 1
	var opponent_new = RankingRules.star_result_for_delta(String(opponent_old["key"]), int(opponent_old["stars"]), opponent_delta)["new_rank"]
	result_player_entries.append(_result_player_entry(ENEMY, 2 if local_won else 1, String(active_match_mirror.get("name", "对手")), false, opponent_old, opponent_new, opponent_delta))
	result_player_entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("placement", 99)) < int(b.get("placement", 99)))


func _result_outcome_for_team(team: int, local_team: int) -> String:
	if multiplayer_free_for_all:
		return "win" if int(multiplayer_placements.get(team, 99)) == 1 else "loss"
	var same_side = _multiplayer_side_for_team(team) == _multiplayer_side_for_team(local_team)
	if room_result == "draw":
		return "draw"
	if same_side:
		return room_result
	return "loss" if room_result == "win" else "win"


func _result_player_name_for_team(team: int) -> String:
	for slot_value in online_room_slots:
		if typeof(slot_value) == TYPE_DICTIONARY and int((slot_value as Dictionary).get("team_id", NEUTRAL)) == team:
			var slot_name = String((slot_value as Dictionary).get("display_name", "")).strip_edges()
			if slot_name != "":
				return slot_name
	if room_human_teams.has(team):
		return String(room_human_teams[team])
	return "AI玩家%d" % team


func _result_rank_state_for_team(team: int, fallback_rank: Dictionary) -> Dictionary:
	for slot_value in online_room_slots:
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = slot_value
		if int(slot.get("team_id", NEUTRAL)) != team:
			continue
		return RankingRules.rank_state_for_key_and_stars(
			String(slot.get("rank_key", fallback_rank.get("key", "bronze"))),
			int(slot.get("rank_stars", fallback_rank.get("stars", 1)))
		)
	return fallback_rank


func _result_player_entry(team: int, placement: int, player_name: String, is_local: bool, old_rank: Dictionary, new_rank: Dictionary, star_delta: int) -> Dictionary:
	return {
		"team": team,
		"placement": maxi(1, placement),
		"name": player_name if player_name.strip_edges() != "" else "玩家%d" % team,
		"is_local": is_local,
		"old_rank_display": String(old_rank.get("display", RankingRules.display_for_key_and_stars(String(old_rank.get("key", "bronze")), int(old_rank.get("stars", 1))))),
		"new_rank_display": String(new_rank.get("display", RankingRules.display_for_key_and_stars(String(new_rank.get("key", "bronze")), int(new_rank.get("stars", 1))))),
		"star_delta": star_delta,
	}


func _result_other_entries() -> Array:
	var others = []
	for entry in result_player_entries:
		if not bool(entry.get("is_local", false)):
			others.append(entry)
	return others


func _result_other_players_rect() -> Rect2:
	return Rect2(92, 530, 536, 328)


func _result_return_rect() -> Rect2:
	return Rect2(190, 900, 340, 64)


func _result_players_max_scroll() -> float:
	var content_height = float(_result_other_entries().size()) * (RESULT_PLAYER_ROW_HEIGHT + RESULT_PLAYER_ROW_GAP) - RESULT_PLAYER_ROW_GAP
	return maxf(0.0, content_height - _result_other_players_rect().size.y)


func _scroll_result_players(delta: float) -> void:
	result_players_scroll = clampf(result_players_scroll + delta, 0.0, _result_players_max_scroll())


func _multiplayer_timeout_result() -> String:
	var comparison = _compare_multiplayer_side_scores(
		_multiplayer_side_score(0),
		_multiplayer_side_score(1)
	)
	if comparison > 0:
		return "win"
	if comparison < 0:
		return "loss"
	return "draw"


func _multiplayer_timeout_placement() -> int:
	var scores = _multiplayer_live_ranking()
	multiplayer_placements.clear()
	var local_placement = maxi(1, _active_multiplayer_teams().size())
	for index in range(scores.size()):
		var team = int(scores[index].get("team", NEUTRAL))
		multiplayer_placements[team] = index + 1
		if team == PLAYER:
			local_placement = index + 1
	return local_placement


func _multiplayer_live_ranking() -> Array:
	var scores = []
	for team in _active_multiplayer_teams():
		scores.append({
			"team": int(team),
			"alive": _is_multiplayer_team_alive(int(team)),
			"tiles": _multiplayer_tile_score(int(team)),
		})
	scores.sort_custom(Callable(self, "_is_multiplayer_tile_score_before"))
	for index in range(scores.size()):
		scores[index]["rank"] = index + 1
	return scores


func _multiplayer_tile_score(team: int) -> int:
	if not _is_multiplayer_team_alive(team):
		return 0
	var score = 0
	for tile in tiles.values():
		if BoardRules.visual_owner(tile) == team:
			score += 1
	return score


func _multiplayer_side_visual_tile_count(side: int) -> int:
	if side not in [0, 1]:
		return 0
	var count = 0
	for tile_value in tiles.values():
		if typeof(tile_value) != TYPE_DICTIONARY:
			continue
		var tile: Dictionary = tile_value
		if _multiplayer_side_for_team(BoardRules.visual_owner(tile)) == side:
			count += 1
	return count


func _multiplayer_side_team_ids(side: int) -> Array:
	var team_ids = []
	for team in _active_multiplayer_teams():
		if _multiplayer_side_for_team(int(team)) == side:
			team_ids.append(int(team))
	return team_ids


func _multiplayer_team_scoreboard_entries() -> Array:
	var local_side = _multiplayer_side_for_team(_local_control_team())
	var entries = []
	for side in [0, 1]:
		var team_ids = _multiplayer_side_team_ids(side)
		var team_colors = []
		for team in team_ids:
			team_colors.append(_team_color(int(team)))
		entries.append({
			"side": side,
			"team_ids": team_ids,
			"team_colors": team_colors,
			"tiles": _multiplayer_side_visual_tile_count(side),
			"is_local": side == local_side,
		})
	return entries


func _multiplayer_side_scoreboard_accent(side: int) -> Color:
	var team_ids = _multiplayer_side_team_ids(side)
	if team_ids.is_empty():
		return COLOR_RED if side == 0 else COLOR_BLUE
	var total = Color(0.0, 0.0, 0.0)
	for team in team_ids:
		var color = _team_color(int(team))
		total.r += color.r
		total.g += color.g
		total.b += color.b
	return Color(total.r / team_ids.size(), total.g / team_ids.size(), total.b / team_ids.size())


func _multiplayer_team_rank(team: int) -> int:
	for entry in _multiplayer_live_ranking():
		if int(entry.get("team", NEUTRAL)) == team:
			return int(entry.get("rank", 0))
	return 0


func _is_multiplayer_tile_score_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("tiles", 0)) != int(b.get("tiles", 0)):
		return int(a.get("tiles", 0)) > int(b.get("tiles", 0))
	return int(a.get("team", 99)) < int(b.get("team", 99))


func _multiplayer_side_score(side: int) -> Dictionary:
	var score = {"alive_bases": 0, "base_hp": 0.0, "tiles": 0, "buildings": 0}
	for team in _active_multiplayer_teams():
		if _multiplayer_side_for_team(int(team)) != side:
			continue
		if _is_multiplayer_team_alive(int(team)):
			score["alive_bases"] = int(score["alive_bases"]) + 1
		score["base_hp"] = float(score["base_hp"]) + _original_base_hp(int(team))
		score["tiles"] = int(score["tiles"]) + _tile_count(int(team))
		for building in ["base", "mine", "tower", "barracks", "hall"]:
			score["buildings"] = int(score["buildings"]) + _building_count(int(team), building)
	return score


func _original_base_hp(team: int) -> float:
	var base_tile = tiles.get(_multiplayer_base_key(team), {})
	if typeof(base_tile) != TYPE_DICTIONARY:
		return 0.0
	if int(base_tile.get("team", NEUTRAL)) != team or String(base_tile.get("building", "")) != "base":
		return 0.0
	return maxf(0.0, float(base_tile.get("hp", 0.0)))


func _compare_multiplayer_side_scores(side_a: Dictionary, side_b: Dictionary) -> int:
	for key in ["alive_bases", "base_hp", "tiles", "buildings"]:
		var a_value = float(side_a.get(key, 0.0))
		var b_value = float(side_b.get(key, 0.0))
		if is_equal_approx(a_value, b_value):
			continue
		return 1 if a_value > b_value else -1
	return 0


func _apply_rank_result(won: bool) -> void:
	var profile = RankingRules.normalize_profile(_player_profile())
	if active_match_rank_key == "":
		var match_rank_state = RankingRules.rank_state_for_profile(profile)
		active_match_rank_key = String(match_rank_state["key"])
		active_match_player_stars = int(match_rank_state["stars"])
	if active_match_mirror.is_empty():
		active_match_mirror = _generated_match_mirror(active_match_rank_key)
	var result = RankingRules.star_result(String(profile["rank_key"]), int(profile["stars"]), won)
	profile["rank_key"] = String(result["new_rank"]["key"])
	profile["stars"] = int(result["new_rank"]["stars"])
	profile["matches"] = int(profile.get("matches", 0)) + 1
	if won:
		profile["wins"] = int(profile.get("wins", 0)) + 1
	else:
		profile["losses"] = int(profile.get("losses", 0)) + 1
	rank_db["player"] = profile
	last_rank_result = result
	if won:
		_record_victory_mirror(active_match_rank_key, active_match_player_stars)
	_save_rank_database()


func _record_victory_mirror(rank_key: String, match_stars: int) -> void:
	_ensure_rank_database_shape()
	var mirrors = rank_db["mirrors"]
	if not mirrors.has(rank_key) or typeof(mirrors[rank_key]) != TYPE_ARRAY:
		mirrors[rank_key] = []
	var rank_state = RankingRules.rank_state_for_key_and_stars(rank_key, match_stars)
	var profile = _player_profile()
	var now = int(Time.get_unix_time_from_system())
	var mirror = {
		"mirror_id": "local_%d_%d" % [now, randi()],
		"player_id": String(profile.get("player_id", "local_player")),
		"name": String(profile.get("name", "玩家")) + "镜像",
		"rank_key": rank_key,
		"rank_display": String(rank_state["display"]),
		"stars": int(rank_state["stars"]),
		"elo": int(rank_state["elo"]),
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
		GameAudio.play_sfx("ui_error")
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
	GameAudio.play_sfx("gacha_open")
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
	GameAudio.play_sfx("gacha_reveal")
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
	GameAudio.play_sfx("card_select")


func _start_equip_selected_card() -> void:
	var card_id = selected_card_id
	if card_id == "":
		return
	if _card_total_count(card_id) <= 0:
		GameAudio.play_sfx("ui_error")
		_toast("尚未拥有该卡牌")
		return
	if _is_card_in_deck(card_id):
		GameAudio.play_sfx("ui_error")
		_toast("已在出战编组")
		return
	pending_equip_card_id = card_id
	detail_pulse_timer = DETAIL_PULSE_SECONDS
	GameAudio.play_sfx("ui_confirm")
	_toast("选择要替换的出战动物")


func _equip_pending_card_to_slot(slot_index: int) -> void:
	if pending_equip_card_id == "" or slot_index < 0 or slot_index >= deck.size():
		return
	var card_id = pending_equip_card_id
	var candidate_deck = deck.duplicate()
	candidate_deck[slot_index] = card_id
	if not _deck_meets_required_cards(candidate_deck):
		GameAudio.play_sfx("ui_error")
		if not _deck_has_mine(candidate_deck):
			_toast("编组必须保留金矿卡")
		else:
			_toast("绿色防御塔必须在卡组中，否则会变成空地")
		return
	deck[slot_index] = card_id
	selected_slot = slot_index
	selected_card_id = card_id
	pending_equip_card_id = ""
	detail_pulse_timer = DETAIL_PULSE_SECONDS
	GameAudio.play_sfx("ui_confirm")
	_toast("已加入出战编组")


func _handle_nav(pos: Vector2) -> bool:
	for i in range(NAV_ITEMS.size()):
		if not _nav_rect(i).has_point(pos):
			continue
		var item = NAV_ITEMS[i]
		if bool(item.get("locked", false)):
			GameAudio.play_sfx("ui_error")
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
		elif id == SCREEN_ROOM:
			screen = SCREEN_ROOM
			pending_equip_card_id = ""
			_ensure_online_room_connection()
		GameAudio.play_sfx("ui_click")
		return true
	return false


func _handle_room_tap(pos: Vector2) -> void:
	for players_per_side in range(1, 4):
		if _room_mode_rect(players_per_side).has_point(pos):
			_set_room_size(players_per_side)
			return
	if not online_room_active:
		if _room_online_create_rect().has_point(pos):
			_request_online_create_room()
			return
		if _room_online_code_input_rect().has_point(pos):
			GameAudio.play_sfx("ui_click")
			return
		if _room_online_join_rect().has_point(pos):
			_request_online_join()
			return
		if _room_online_retry_rect().has_point(pos):
			online_connection_state = "offline"
			_ensure_online_room_connection()
			return
		if _room_entry_ai_fill_rect().has_point(pos):
			room_fill_with_ai = not room_fill_with_ai
			GameAudio.play_sfx("ui_click")
			return
		return
	if _room_code_copy_rect().has_point(pos):
		DisplayServer.clipboard_set(room_invite_code)
		GameAudio.play_sfx("ui_confirm")
		_toast("房间码已复制")
		return
	if _room_leave_rect().has_point(pos):
		online_room_service.call("leave_room")
		return
	for side_index in range(2):
		for slot_index in range(3):
			var team = (1 if side_index == 0 else 4) + slot_index
			if _room_slot_rect(side_index, slot_index).has_point(pos):
				if room_active_team_ids.has(team) and team != local_team_id:
					online_room_service.call("move_to_slot", team)
				return
	if _room_ai_fill_rect().has_point(pos):
		if not online_room_is_host:
			_toast("只有房主可以设置电脑补位")
			return
		online_room_service.call("update_room_options", {
			"players_per_side": room_players_per_side,
			"fill_with_ai": not room_fill_with_ai,
		})
		return
	if _room_ready_rect().has_point(pos):
		online_room_service.call("set_ready", not online_room_ready)
		return
	if _room_start_rect().has_point(pos):
		if online_room_is_host:
			online_room_service.call("start_room")


func _ensure_deck_valid() -> void:
	var owned = _owned_card_ids()
	if owned.is_empty():
		return
	while deck.size() < DECK_SIZE:
		deck.append("")
	for i in range(deck.size()):
		if _card_total_count(String(deck[i])) <= 0:
			deck[i] = String(owned[i % owned.size()])
	for required_id in _mandatory_card_ids():
		if _card_total_count(required_id) > 0 and not deck.has(required_id):
			_force_card_into_deck(required_id)
	if not _deck_has_common_defense(deck) and _card_total_count(COMMON_DEFENSE_CARD_ID) > 0:
		_force_card_into_deck(COMMON_DEFENSE_CARD_ID)


func _force_card_into_deck(card_id: String) -> void:
	if deck.is_empty():
		return
	for i in range(deck.size() - 1, -1, -1):
		var current_id = String(deck[i])
		if current_id == card_id:
			return
		if current_id == MINE_CARD_ID:
			continue
		if _is_defense_card_id(current_id) and not _is_defense_card_id(card_id) and _deck_defense_count(deck) <= 1:
			continue
		deck[i] = card_id
		return


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
	_draw_rank_castle(Rect2(224, 218, 272, 280))
	_draw_lobby_deck_animals(scene_rect.grow(-34))
	_draw_rank_panel(Rect2(58, 842, 604, 92))
	_cta(_start_rect(), "单人对战", true)
	_draw_lobby_multiplayer_button()


func _setup_account_fields() -> void:
	account_name_field = LineEdit.new()
	account_name_field.name = "AccountNameField"
	account_name_field.placeholder_text = "输入账号（3-32位）"
	account_name_field.max_length = 32
	account_name_field.add_theme_font_size_override("font_size", 22)
	add_child(account_name_field)
	account_password_field = LineEdit.new()
	account_password_field.name = "AccountPasswordField"
	account_password_field.placeholder_text = "输入密码（8-72位）"
	account_password_field.max_length = 72
	account_password_field.secret = true
	account_password_field.add_theme_font_size_override("font_size", 22)
	add_child(account_password_field)
	_set_account_fields_visible(false)


func _set_account_fields_visible(visible: bool) -> void:
	var show_fields = visible and account_center_open and not player_agreement_open and OnlineRoom.current_user_id == ""
	if account_name_field != null:
		account_name_field.visible = show_fields
	if account_password_field != null:
		account_password_field.visible = show_fields


func _update_account_fields_layout() -> void:
	if account_name_field == null or account_password_field == null:
		return
	_set_line_edit_canvas_rect(account_name_field, _account_name_input_rect())
	_set_line_edit_canvas_rect(account_password_field, _account_password_input_rect())


func _set_line_edit_canvas_rect(field: LineEdit, rect: Rect2) -> void:
	field.position = canvas_offset + rect.position * canvas_scale
	field.size = rect.size * canvas_scale
	field.add_theme_font_size_override("font_size", maxi(16, roundi(22.0 * canvas_scale)))


func _submit_account_login(register_new: bool) -> void:
	if account_name_field == null or account_password_field == null:
		return
	var account = account_name_field.text.strip_edges()
	var password = account_password_field.text
	if account.length() < 3 or account.length() > 32:
		_toast("账号长度需为 3-32 个字符")
		GameAudio.play_sfx("ui_error")
		return
	if password.length() < 8 or password.length() > 72:
		_toast("密码长度需为 8-72 个字符")
		GameAudio.play_sfx("ui_error")
		return
	if not _ensure_online_room_connection():
		_toast("正在连接服务器，请稍后重试")
		return
	if register_new:
		account_pending_register_password = password
		OnlineRoom.register_account(account, password)
	else:
		OnlineRoom.login_account(account, password)


func _server_profile_snapshot() -> Dictionary:
	var profile = RankingRules.normalize_profile(_player_profile())
	_ensure_rank_database_shape()
	return {
		"card_counts": card_counts.duplicate(true),
		"card_levels": card_levels.duplicate(true),
		"deck": deck.duplicate(),
		"gacha_tickets": gacha_tickets,
		"rank_stars": int(profile.get("stars", RankingRules.INITIAL_STARS)),
		"rank_key": String(profile.get("rank_key", RankingRules.INITIAL_RANK_KEY)),
		"elo": int(profile.get("elo", RankingRules.INITIAL_ELO)),
		"rank_mirrors": (rank_db.get("mirrors", {}) as Dictionary).duplicate(true),
	}


func _apply_server_profile(value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var profile: Dictionary = value
	var remote_card_counts = profile.get("card_counts", {})
	if typeof(remote_card_counts) == TYPE_DICTIONARY and not (remote_card_counts as Dictionary).is_empty():
		card_counts = (remote_card_counts as Dictionary).duplicate(true)
	var remote_card_levels = profile.get("card_levels", {})
	if typeof(remote_card_levels) == TYPE_DICTIONARY and not (remote_card_levels as Dictionary).is_empty():
		card_levels = (remote_card_levels as Dictionary).duplicate(true)
	var remote_deck = profile.get("deck", [])
	if typeof(remote_deck) == TYPE_ARRAY and not (remote_deck as Array).is_empty():
		deck = (remote_deck as Array).duplicate()
	gacha_tickets = maxi(0, int(profile.get("gacha_tickets", gacha_tickets)))
	var rank_profile = RankingRules.normalize_profile(_player_profile())
	rank_profile["player_id"] = OnlineRoom.current_user_id
	rank_profile["rank_key"] = String(profile.get("rank_key", rank_profile["rank_key"]))
	rank_profile["stars"] = int(profile.get("rank_stars", rank_profile["stars"]))
	rank_profile["elo"] = int(profile.get("elo", rank_profile["elo"]))
	rank_db["player"] = RankingRules.normalize_profile(rank_profile)
	var remote_rank_mirrors = profile.get("rank_mirrors", {})
	if typeof(remote_rank_mirrors) == TYPE_DICTIONARY and not (remote_rank_mirrors as Dictionary).is_empty():
		rank_db["mirrors"] = (remote_rank_mirrors as Dictionary).duplicate(true)
	_ensure_deck_valid()
	_save_rank_database()


func _update_server_profile_sync(delta: float) -> void:
	if OnlineRoom.current_user_id == "" or online_room_service == null:
		return
	account_profile_sync_timer -= delta
	if account_profile_sync_timer > 0.0:
		return
	account_profile_sync_timer = 1.0
	var snapshot = _server_profile_snapshot()
	var signature = JSON.stringify(snapshot)
	if signature != account_profile_signature and bool(online_room_service.call("is_connected_to_server")):
		OnlineRoom.save_player_profile(snapshot)


func _handle_account_center_tap(pos: Vector2) -> void:
	if player_agreement_open:
		if _account_close_rect().has_point(pos) or _agreement_back_rect().has_point(pos):
			player_agreement_open = false
			_set_account_fields_visible(OnlineRoom.current_user_id == "")
			GameAudio.play_sfx("ui_click")
		return
	if _account_close_rect().has_point(pos):
		account_center_open = false
		_set_account_fields_visible(false)
		GameAudio.play_sfx("ui_click")
	elif OnlineRoom.current_user_id == "" and _account_login_rect().has_point(pos):
		_submit_account_login(false)
	elif OnlineRoom.current_user_id == "" and _account_register_rect().has_point(pos):
		_submit_account_login(true)
	elif _account_logout_rect().has_point(pos):
		if OnlineRoom.current_user_id == "":
			_toast("当前未登录")
			GameAudio.play_sfx("ui_error")
		else:
			OnlineRoom.logout_account()
			_toast("已注销账号")
			GameAudio.play_sfx("ui_confirm")
	elif _account_agreement_rect().has_point(pos):
		player_agreement_open = true
		_set_account_fields_visible(false)
		GameAudio.play_sfx("ui_click")
	elif _account_music_rect().has_point(pos):
		GameAudio.set_music_enabled(not GameAudio.music_enabled)
		GameAudio.play_sfx("ui_click")
	elif _account_sfx_rect().has_point(pos):
		GameAudio.set_sfx_enabled(not GameAudio.sfx_enabled)
		if GameAudio.sfx_enabled:
			GameAudio.play_sfx("ui_click")


func _draw_account_center() -> void:
	draw_rect(Rect2(0, 0, DESIGN_SIZE.x, DESIGN_SIZE.y), Color(0.03, 0.04, 0.05, 0.72))
	var panel = _account_panel_rect()
	_box(panel, Color(0.93, 0.82, 0.57), COLOR_LINE, 6)
	_draw_text_center("玩家协议" if player_agreement_open else "设置与账号", _account_title_rect(), 34, COLOR_LINE)
	_cta(_account_close_rect(), "关闭", false)
	draw_line(Vector2(92, 264), Vector2(628, 264), Color(0.36, 0.27, 0.16, 0.45), 2.0)
	if player_agreement_open:
		_draw_text_fit("欢迎使用《丛林法则》。请文明游戏并妥善保管账号。游戏进度由服务器保存；禁止利用漏洞、外挂或干扰其他玩家。我们仅处理提供账号与游戏服务所需的数据。注销仅退出当前会话，不会自动删除服务器账号与进度。", Rect2(108, 294, 504, 468), 24, COLOR_LINE)
		_cta(_agreement_back_rect(), "返回账号中心", true)
		return
	var user_id = OnlineRoom.current_user_id
	_draw_text_fit("账号登录" if user_id.is_empty() else "账号信息", Rect2(104, 284, 120, 32), 22, COLOR_LINE)
	draw_line(Vector2(230, 301), Vector2(616, 301), Color(0.36, 0.27, 0.16, 0.34), 2.0)
	if user_id.is_empty():
		_draw_text_fit("账号", Rect2(104, 334, 80, 58), 21, COLOR_LINE)
		_draw_text_fit("密码", Rect2(104, 416, 80, 58), 21, COLOR_LINE)
		_cta(_account_login_rect(), "登录", true)
		_cta(_account_register_rect(), "注册", false)
		_draw_text_fit("连接状态：" + online_connection_state, Rect2(104, 570, 512, 30), 17, COLOR_LINE)
	else:
		_box(Rect2(104, 334, 512, 180), Color(1.0, 0.95, 0.79), COLOR_LINE, 4)
		_draw_text_fit("UserID", Rect2(128, 352, 120, 32), 22, COLOR_PURPLE)
		_draw_text_fit(user_id, Rect2(128, 390, 464, 42), 26, COLOR_LINE)
		_draw_text_fit("服务器已同步", Rect2(128, 454, 464, 26), 18, COLOR_GREEN.darkened(0.35))
	_cta(_account_agreement_rect(), "玩家协议", false)
	_draw_text_fit("声音设置", Rect2(104, 710, 120, 32), 22, COLOR_LINE)
	draw_line(Vector2(230, 727), Vector2(616, 727), Color(0.36, 0.27, 0.16, 0.34), 2.0)
	_cta(_account_music_rect(), "音乐：开" if GameAudio.music_enabled else "音乐：关", false)
	_cta(_account_sfx_rect(), "音效：开" if GameAudio.sfx_enabled else "音效：关", false)
	if not user_id.is_empty():
		_cta(_account_logout_rect(), "注销账号", true)


func _draw_lobby_multiplayer_button() -> void:
	var rect = _multiplayer_start_rect()
	_box(rect, COLOR_BLUE.darkened(0.14), COLOR_LINE, 5)
	_draw_text_center("多人对战", _multiplayer_button_title_rect(), 25, Color.WHITE)
	_draw_multiplayer_hot_badge()


func _draw_multiplayer_hot_badge() -> void:
	var rect = _multiplayer_hot_badge_rect()
	_box(rect, COLOR_RED, COLOR_LINE, 3)
	_draw_text_center(MULTIPLAYER_HOT_BADGE_TEXT, rect.grow(-2.0), 15, Color.WHITE)


func _draw_room_screen() -> void:
	_draw_background()
	_draw_top_bar()
	_draw_text_center("互联网房间", Rect2(40, 68, 640, 58), 42, Color.WHITE)
	_draw_text_center("选择双方人数", Rect2(52, 128, 616, 32), 22, Color.WHITE)
	for players_per_side in range(1, 4):
		var mode_rect = _room_mode_rect(players_per_side)
		var selected = players_per_side == room_players_per_side
		_box(mode_rect, COLOR_ORANGE if selected else COLOR_PURPLE, COLOR_LINE, 4)
		_draw_text_center("%dV%d" % [players_per_side, players_per_side], mode_rect, 24, Color.WHITE)
	if not online_room_active:
		_draw_online_room_entry()
		return

	var code_panel = Rect2(48, 232, 624, 82)
	_box(code_panel, Color(1.0, 0.94, 0.72), COLOR_LINE, 4)
	_draw_text_fit("房间码", Rect2(70, 248, 108, 28), 21, COLOR_LINE)
	_draw_text_center(room_invite_code, Rect2(172, 244, 250, 38), 30, COLOR_PURPLE)
	_cta(_room_code_copy_rect(), "复制", true)
	_draw_text_fit("已连公网服务器 · 其他玩家输入此码即可加入", Rect2(70, 284, 550, 22), 15, Color(0.25, 0.22, 0.27))

	_draw_room_team_panel(0, "A方·暖色", Color(0.94, 0.30, 0.10))
	_draw_room_team_panel(1, "B方·冷色", Color(0.38, 0.56, 0.70))

	var fill_rect = _room_ai_fill_rect()
	_box(fill_rect, Color(1.0, 0.96, 0.82), COLOR_LINE, 4)
	_draw_text_fit("电脑补位", Rect2(fill_rect.position + Vector2(20, 13), Vector2(190, 32)), 24, COLOR_LINE)
	var toggle_rect = Rect2(fill_rect.position + Vector2(fill_rect.size.x - 92, 12), Vector2(72, 36))
	draw_rect(toggle_rect, COLOR_GREEN if room_fill_with_ai else Color(0.48, 0.49, 0.54))
	draw_rect(toggle_rect, COLOR_LINE, false, 3)
	var knob_x = toggle_rect.position.x + (toggle_rect.size.x - 18.0 if room_fill_with_ai else 18.0)
	draw_circle(Vector2(knob_x, toggle_rect.get_center().y), 13, Color.WHITE)
	draw_circle(Vector2(knob_x, toggle_rect.get_center().y), 13, COLOR_LINE, false, 2)

	_cta(_room_ready_rect(), "取消准备" if online_room_ready else "准备", true)
	_cta(_room_leave_rect(), "离开房间", false)
	_draw_text_center("随机地图池：%dV%d 专属 5 张 · 每人 30-100 格" % [room_players_per_side, room_players_per_side], Rect2(48, 966, 624, 28), 18, Color.WHITE)
	var start_label = "开始 %dV%d" % [room_players_per_side, room_players_per_side]
	var waiting_label = "等待所有真人准备" if online_room_is_host else "等待房主开始"
	_cta(_room_start_rect(), start_label if _room_can_start() else waiting_label, _room_can_start())


func _draw_online_room_entry() -> void:
	var panel = Rect2(48, 240, 624, 650)
	_box(panel, Color(0.20, 0.24, 0.46, 0.96), COLOR_LINE, 5)
	var status_text = "正在连接服务器…"
	var status_color = COLOR_YELLOW
	if online_connection_state == "connected":
		status_text = "服务器已连接 · UDP %s:%d" % [
			String(online_room_service.get("server_host")),
			int(online_room_service.get("server_port")),
		]
		status_color = COLOR_GREEN
	elif online_connection_state == "error" or online_connection_state == "unavailable":
		status_text = "服务器连接失败，请检查地址或公网服务"
		status_color = COLOR_RED
	elif online_connection_state == "offline":
		status_text = "尚未连接互联网房间服务器"
	_draw_text_center(status_text, Rect2(72, 264, 576, 34), 19, status_color)

	_cta(_room_online_create_rect(), "创建 %dV%d 房间" % [room_players_per_side, room_players_per_side], online_connection_state == "connected")
	_draw_text_center("或输入房主分享的6位房间码", Rect2(72, 418, 576, 30), 18, Color.WHITE)
	_box(_room_online_code_input_rect(), Color(1.0, 0.96, 0.83), COLOR_LINE, 4)
	var code_text = online_room_join_code
	if code_text == "":
		code_text = "点击后直接输入数字"
	_draw_text_center(code_text, _room_online_code_input_rect(), 28 if online_room_join_code != "" else 17, COLOR_PURPLE)
	_cta(_room_online_join_rect(), "加入房间", online_connection_state == "connected" and online_room_join_code.length() == ONLINE_ROOM_CODE_LENGTH)

	var fill_rect = _room_entry_ai_fill_rect()
	_box(fill_rect, Color(1.0, 0.96, 0.82), COLOR_LINE, 4)
	_draw_text_fit("创建时电脑补位", Rect2(fill_rect.position + Vector2(20, 12), Vector2(250, 32)), 22, COLOR_LINE)
	var toggle_rect = Rect2(fill_rect.position + Vector2(fill_rect.size.x - 92, 10), Vector2(72, 36))
	draw_rect(toggle_rect, COLOR_GREEN if room_fill_with_ai else Color(0.48, 0.49, 0.54))
	draw_rect(toggle_rect, COLOR_LINE, false, 3)
	var knob_x = toggle_rect.position.x + (toggle_rect.size.x - 18.0 if room_fill_with_ai else 18.0)
	draw_circle(Vector2(knob_x, toggle_rect.get_center().y), 13, Color.WHITE)
	draw_circle(Vector2(knob_x, toggle_rect.get_center().y), 13, COLOR_LINE, false, 2)
	_cta(_room_online_retry_rect(), "重新连接", online_connection_state != "connected")
	_draw_text_center("客户端只需出站连接；公网服务器需开放 UDP 24567", Rect2(72, 836, 576, 28), 16, Color(0.84, 0.88, 1.0))


func _draw_room_team_panel(side_index: int, title: String, accent: Color) -> void:
	var panel_rect = _room_team_panel_rect(side_index)
	_box(panel_rect, accent.darkened(0.18), COLOR_LINE, 4)
	_draw_text_center(title, Rect2(panel_rect.position + Vector2(0, 12), Vector2(panel_rect.size.x, 34)), 26, Color.WHITE)
	for slot_index in range(3):
		var team = (1 if side_index == 0 else 4) + slot_index
		_draw_room_slot(_room_slot_rect(side_index, slot_index), team, slot_index < room_players_per_side)


func _draw_room_slot(rect: Rect2, team: int, active: bool) -> void:
	var fill = Color(0.33, 0.34, 0.40)
	var title = "%d号 · 未启用" % team
	var detail = "切换更大规模后开放"
	if active and online_room_active:
		var slot = _online_slot_for_team(team)
		var kind = String(slot.get("kind", "empty"))
		if kind == "human":
			var ready = bool(slot.get("ready", false))
			fill = Color(0.35, 0.72, 0.40) if ready else Color(0.90, 0.65, 0.18)
			title = "%d号 · %s" % [team, String(slot.get("display_name", "玩家"))]
			var tags = []
			if bool(slot.get("is_host", false)):
				tags.append("房主")
			if bool(slot.get("is_local", false)):
				tags.append("本机")
			tags.append("已准备" if ready else "未准备")
			detail = " · ".join(tags)
		elif kind == "ai":
			fill = Color(0.30, 0.52, 0.78)
			title = "%d号 · 电脑补位" % team
			detail = "点击可移动到此槽位"
		else:
			fill = Color(0.48, 0.40, 0.63)
			title = "%d号 · 等待玩家" % team
			detail = "点击可移动到此槽位"
	elif active:
		if room_human_teams.has(team):
			fill = Color(0.35, 0.72, 0.40)
			title = "%d号 · %s" % [team, String(room_human_teams[team])]
			detail = "房主 · 本机" if team == PLAYER else "玩家已加入"
		elif room_pending_invites.has(team):
			fill = Color(0.90, 0.65, 0.18)
			title = "%d号 · 等待加入" % team
			detail = "再次点击可复制房间码"
		elif room_fill_with_ai:
			fill = Color(0.30, 0.52, 0.78)
			title = "%d号 · 电脑补位" % team
			detail = "点击邀请玩家替换"
		else:
			fill = Color(0.48, 0.40, 0.63)
			title = "%d号 · 空位" % team
			detail = "点击复制邀请"
	_box(rect, fill, COLOR_LINE, 3)
	_draw_text_fit(title, Rect2(rect.position + Vector2(14, 10), Vector2(rect.size.x - 28, 26)), 20, Color.WHITE)
	_draw_text_fit(detail, Rect2(rect.position + Vector2(14, 38), Vector2(rect.size.x - 28, 22)), 14, Color(0.94, 0.95, 1.0))


func _online_slot_for_team(team: int) -> Dictionary:
	for slot_value in online_room_slots:
		if typeof(slot_value) == TYPE_DICTIONARY and int(slot_value.get("team_id", NEUTRAL)) == team:
			return slot_value
	return {}


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
	var state = _player_rank_state()
	var visual = RankingRules.visual_for_key(String(state["key"]))
	var panel_color = Color.from_string(String(visual.get("panel_color", "")), Color(0.16, 0.13, 0.38, 0.94))
	var accent_color = Color.from_string(String(visual.get("accent_color", "")), COLOR_YELLOW)
	var text_color = Color.from_string(String(visual.get("text_color", "")), Color.WHITE)
	_box(rect, panel_color, COLOR_LINE, 4)
	draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(7, rect.size.y - 10)), accent_color)
	_draw_text_fit(String(state["display"]), Rect2(rect.position + Vector2(22, 10), Vector2(260, 34)), 28, text_color)
	_draw_text_right("段位赛", Rect2(rect.position + Vector2(350, 12), Vector2(228, 28)), 20, text_color)
	_draw_star_track(Rect2(rect.position + Vector2(22, 52), Vector2(176, 20)), int(state["stars"]), int(state["max_stars"]), accent_color, panel_color.lightened(0.18))
	var profile = _player_profile()
	_draw_text_fit("胜 %d  负 %d" % [int(profile.get("wins", 0)), int(profile.get("losses", 0))], Rect2(rect.position + Vector2(224, 52), Vector2(160, 24)), 18, text_color)


func _draw_rank_castle(rect: Rect2) -> void:
	var state = _player_rank_state()
	var visual = RankingRules.visual_for_key(String(state["key"]))
	var castle_key = String(visual.get("castle_key", RankingRules.INITIAL_RANK_KEY))
	var texture = RANK_CASTLE_ART.get(castle_key, RANK_CASTLE_ART[RankingRules.INITIAL_RANK_KEY]) as Texture2D
	_draw_texture_contained(texture, rect)


func _draw_texture_contained(texture: Texture2D, rect: Rect2) -> void:
	if texture == null:
		return
	var texture_size = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_factor = minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var draw_size = texture_size * scale_factor
	var draw_rect = Rect2(rect.position + (rect.size - draw_size) * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect, false)


func _draw_star_track(rect: Rect2, stars: int, max_stars: int, filled_color: Color = COLOR_YELLOW, empty_color: Color = Color(0.35, 0.34, 0.48)) -> void:
	if max_stars <= 0:
		_draw_text_fit("王者星数 " + str(stars), rect, 18, filled_color)
		return
	var gap = clampf(rect.size.x / float(max_stars * 3), 2.0, 10.0)
	var radius = minf(7.5, (rect.size.x - gap * float(max_stars - 1)) / float(max_stars * 2))
	radius = maxf(2.0, radius)
	for i in range(max_stars):
		var center = rect.position + Vector2(radius + float(i) * (radius * 2.0 + gap), rect.size.y * 0.5)
		draw_circle(center + Vector2(0, 2), radius, Color(0, 0, 0, 0.22))
		draw_circle(center, radius, filled_color if i < stars else empty_color)
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
	_draw_board_frame()
	for key in tiles.keys():
		_draw_tile(key, tiles[key])
	for unit in units:
		_draw_unit(unit)
	for effect in effects:
		_draw_effect(effect)
	if _uses_axial_battle_map():
		_draw_board_view_mask()
	_draw_top_bar()
	_draw_match_status()
	if _should_draw_3v3_team_scoreboard():
		_draw_3v3_team_scoreboard()
	if battle_mode == BATTLE_MODE_MULTIPLAYER and multiplayer_free_for_all:
		_draw_multiplayer_leaderboard()
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
	_resource(Rect2(46, 18, 186, 44), "金币", str(_display_gold()), COLOR_YELLOW)
	_resource(Rect2(488, 18, 186, 44), "券", str(gacha_tickets), COLOR_BLUE)


func _draw_match_status() -> void:
	var rect = Rect2(250, 18, 220, 44)
	_box(rect, Color(0.15, 0.12, 0.34, 0.92), COLOR_LINE, 3)
	_draw_text_center(_match_status_text(), rect, 17, Color.WHITE)


func _should_draw_3v3_team_scoreboard() -> bool:
	return (
		battle_mode == BATTLE_MODE_MULTIPLAYER
		and not multiplayer_free_for_all
		and room_players_per_side == MultiplayerRules.MAX_PLAYERS_PER_SIDE
	)


func _multiplayer_team_scoreboard_rect(side: int) -> Rect2:
	return Rect2(46.0 if side == 0 else 374.0, 70.0, 300.0, 34.0)


func _draw_3v3_team_scoreboard() -> void:
	for entry_value in _multiplayer_team_scoreboard_entries():
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var side = int(entry.get("side", -1))
		var rect = _multiplayer_team_scoreboard_rect(side)
		var accent = _multiplayer_side_scoreboard_accent(side)
		var fill = accent.darkened(0.55)
		fill.a = 0.94
		_box(rect, fill, COLOR_LINE, 2.0)
		var is_local = bool(entry.get("is_local", false))
		if is_local:
			draw_rect(rect.grow(2.0), COLOR_YELLOW, false, 2.5)
		var raw_colors = entry.get("team_colors", [])
		if typeof(raw_colors) == TYPE_ARRAY:
			for index in range(mini((raw_colors as Array).size(), 3)):
				var color_value = (raw_colors as Array)[index]
				if typeof(color_value) != TYPE_COLOR:
					continue
				var team_color: Color = color_value
				var center = rect.position + Vector2(16.0 + float(index) * 15.0, rect.size.y * 0.5)
				draw_circle(center, 5.0, team_color)
				draw_circle(center, 5.0, COLOR_LINE, false, 1.0)
		var label = "%s方 · %s" % ["A" if side == 0 else "B", "我方" if is_local else "敌方"]
		_draw_text_fit(label, Rect2(rect.position + Vector2(64, 7), Vector2(126, 20)), 14, Color.WHITE)
		_draw_text_right("%d 格" % int(entry.get("tiles", 0)), Rect2(rect.position + Vector2(194, 4), Vector2(94, 26)), 20, Color.WHITE)


func _draw_multiplayer_leaderboard() -> void:
	var panel = Rect2(500, 148, 148, 184)
	_box(panel, Color(0.10, 0.11, 0.15, 0.88), Color(0.05, 0.06, 0.08, 0.95), 3.0)
	_draw_text_center("地块排名", Rect2(panel.position + Vector2(8, 5), Vector2(panel.size.x - 16, 28)), 17, Color.WHITE)
	var ranking = _multiplayer_live_ranking()
	for index in range(ranking.size()):
		var entry: Dictionary = ranking[index]
		var team = int(entry.get("team", NEUTRAL))
		var alive = bool(entry.get("alive", false))
		var row = Rect2(panel.position + Vector2(7, 34 + index * 24), Vector2(panel.size.x - 14, 22))
		if team == PLAYER:
			draw_rect(row, Color(1.0, 0.82, 0.28, 0.18))
			draw_rect(row, Color(1.0, 0.82, 0.28, 0.72), false, 1.5)
		var team_color = _team_color(team) if alive else Color(0.50, 0.52, 0.55)
		draw_circle(row.position + Vector2(10, 11), 5.0, team_color)
		var text_color = Color.WHITE if alive else Color(0.68, 0.70, 0.73)
		_draw_text_fit("%d  %d号" % [index + 1, team], Rect2(row.position + Vector2(20, 0), Vector2(64, row.size.y)), 14, text_color)
		_draw_text_right("%d格" % int(entry.get("tiles", 0)), Rect2(row.position + Vector2(82, 0), Vector2(row.size.x - 86, row.size.y)), 14, text_color)


func _match_status_text() -> String:
	if battle_mode == BATTLE_MODE_MULTIPLAYER and multiplayer_free_for_all:
		return "%s  第%d/6" % [_countdown_text(battle_timer), maxi(1, _multiplayer_team_rank(PLAYER))]
	return _legacy_match_status_text()


func _countdown_text(seconds: float) -> String:
	var total_seconds = maxi(0, ceili(seconds))
	return "%02d:%02d" % [int(total_seconds / 60), total_seconds % 60]


func _legacy_match_status_text() -> String:
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		if multiplayer_free_for_all:
			return "自由混战  存活 %d/%d" % [_multiplayer_alive_count(), MultiplayerRules.TEAM_IDS.size()]
		var local_side = _multiplayer_side_for_team(_local_control_team())
		var enemy_side = 1 if local_side == 0 else 0
		return "%dV%d  我%d-敌%d" % [
			room_players_per_side,
			room_players_per_side,
			_multiplayer_side_alive_count(local_side),
			_multiplayer_side_alive_count(enemy_side),
		]
	var player_rank = String(_player_rank_state()["display"])
	if active_match_rank_key != "":
		player_rank = RankingRules.display_for_key_and_stars(active_match_rank_key, active_match_player_stars)
	var opponent_rank = String(active_match_mirror.get("rank_display", player_rank))
	return "%s  VS  %s" % [player_rank, opponent_rank]


func _rank_result_text() -> String:
	if last_rank_result.is_empty():
		return "当前段位 " + String(_player_rank_state()["display"])
	var fallback_rank = _player_rank_state()
	var rank_state = last_rank_result.get("new_rank", fallback_rank)
	return "当前段位 " + String(rank_state.get("display", fallback_rank["display"]))


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


func _draw_board_view_mask() -> void:
	var outer = Rect2(36, 82, 648, 1038)
	var view = _battle_view_rect()
	var frame_fill = Color(0.95, 0.80, 0.50)
	draw_rect(Rect2(0, 0, DESIGN_SIZE.x, outer.position.y), Color(0.68, 0.90, 0.60))
	draw_rect(Rect2(0, outer.end.y, DESIGN_SIZE.x, DESIGN_SIZE.y - outer.end.y), Color(0.60, 0.85, 0.50))
	draw_rect(Rect2(0, outer.position.y, outer.position.x, outer.size.y), Color(0.60, 0.85, 0.50))
	draw_rect(Rect2(outer.end.x, outer.position.y, DESIGN_SIZE.x - outer.end.x, outer.size.y), Color(0.60, 0.85, 0.50))
	draw_rect(Rect2(outer.position, Vector2(outer.size.x, view.position.y - outer.position.y)), frame_fill)
	draw_rect(Rect2(Vector2(outer.position.x, view.end.y), Vector2(outer.size.x, outer.end.y - view.end.y)), frame_fill)
	draw_rect(Rect2(Vector2(outer.position.x, view.position.y), Vector2(view.position.x - outer.position.x, view.size.y)), frame_fill)
	draw_rect(Rect2(Vector2(view.end.x, view.position.y), Vector2(outer.end.x - view.end.x, view.size.y)), frame_fill)
	draw_rect(outer, Color(0.37, 0.55, 0.25), false, 5.0)
	draw_rect(view, Color(0.25, 0.48, 0.22), false, 4.0)


func _draw_tile(key: Vector2i, tile: Dictionary) -> void:
	var world_center = _hex_center(key)
	if _uses_axial_battle_map() and not _is_world_pos_visible(world_center, HEX_SIZE * 1.1):
		return
	var center = _world_to_canvas(world_center)
	var points = _hex_points(center)
	var local_team = _local_control_team()
	var can_unlock = _can_unlock(key, local_team)
	var unlock_cost = _unlock_cost(key, local_team)
	var visual_team = BoardRules.visual_owner(tile)
	var fill = Color(0.88, 0.80, 0.58, 0.68)
	var line = Color(0.61, 0.52, 0.35, 0.48)
	var line_width = 2.0
	var is_eliminated_gray = int(tile.get("eliminated_team", NEUTRAL)) != NEUTRAL and visual_team == NEUTRAL
	if is_eliminated_gray:
		fill = Color(0.48, 0.50, 0.52, 0.82)
		line = Color(0.28, 0.30, 0.32, 0.80)
		line_width = 3.0
	elif visual_team != NEUTRAL:
		fill = _team_color(visual_team)
		line = fill.darkened(0.34)
		line_width = 3.0
	if can_unlock:
		line = COLOR_YELLOW if _gold_for_team(local_team) >= unlock_cost else Color(0.78, 0.72, 0.62)
		line_width = 4.0
	draw_polygon(points, PackedColorArray([fill, fill, fill, fill, fill, fill]))
	draw_polyline(_closed_points(points), line, line_width)
	if String(tile["building"]) != "":
		_draw_building(center, tile)
	elif can_unlock:
		_draw_site(center, tile, unlock_cost)


func _draw_site(center: Vector2, tile: Dictionary, cost: int) -> void:
	_draw_site_icon(center + Vector2(0, -11), tile)
	var affordable = _gold_for_team(_local_control_team()) >= cost
	_draw_site_cost(center + Vector2(0, 18), cost, affordable)


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
	_draw_mine_icon(center, ink, Color(0.04, 0.05, 0.08, 0.95), shadow)


func _draw_quality_camp(center: Vector2, rarity: String, unlocked: bool) -> void:
	var main = _rarity_color(rarity) if unlocked else Color(0.07, 0.09, 0.14, 0.88)
	var outline = COLOR_LINE if unlocked else Color(0.04, 0.05, 0.08, 0.95)
	var accent = main.lightened(0.30) if unlocked else Color(0.26, 0.28, 0.33, 0.90)
	_draw_camp_icon(center, main, outline, accent)


func _draw_quality_tower(center: Vector2, rarity: String, unlocked: bool) -> void:
	var main = _rarity_color(rarity) if unlocked else Color(0.07, 0.09, 0.14, 0.88)
	var outline = COLOR_LINE if unlocked else Color(0.04, 0.05, 0.08, 0.95)
	var accent = main.lightened(0.34) if unlocked else Color(0.26, 0.28, 0.33, 0.90)
	_draw_tower_icon(center, main, outline, accent)


func _draw_quality_mine(center: Vector2, unlocked: bool) -> void:
	var main = _rarity_color("epic") if unlocked else Color(0.07, 0.09, 0.14, 0.88)
	var outline = COLOR_LINE if unlocked else Color(0.04, 0.05, 0.08, 0.95)
	var accent = COLOR_GOLD if unlocked else Color(0.26, 0.28, 0.33, 0.90)
	_draw_mine_icon(center, main, outline, accent)


func _draw_camp_icon(center: Vector2, fill: Color, line: Color, accent: Color) -> void:
	var c = center + Vector2(0, 5)
	var body = Rect2(c + Vector2(-17, -4), Vector2(34, 22))
	draw_rect(Rect2(body.position + Vector2(0, 4), body.size), Color(0, 0, 0, 0.18))
	_draw_shape([
		c + Vector2(-22, -4),
		c + Vector2(0, -22),
		c + Vector2(22, -4),
	], fill, line, 3.0)
	draw_rect(body, fill.darkened(0.16))
	draw_rect(body, line, false, 3.0)
	draw_rect(Rect2(c + Vector2(-5, 5), Vector2(10, 13)), Color(0.06, 0.07, 0.10, 0.92))
	draw_line(c + Vector2(-14, 0), c + Vector2(14, 0), accent, 2.2, true)


func _draw_tower_icon(center: Vector2, fill: Color, line: Color, accent: Color) -> void:
	var c = center + Vector2(0, 4)
	draw_rect(Rect2(c + Vector2(-11, 21), Vector2(22, 5)), Color(0, 0, 0, 0.18))
	_draw_shape([
		c + Vector2(-10, 21),
		c + Vector2(-7, -13),
		c + Vector2(0, -24),
		c + Vector2(7, -13),
		c + Vector2(10, 21),
	], fill.darkened(0.10), line, 3.0)
	draw_rect(Rect2(c + Vector2(-5, -5), Vector2(10, 19)), fill)
	draw_rect(Rect2(c + Vector2(-5, -5), Vector2(10, 19)), line, false, 2.0)
	draw_line(c + Vector2(-14, -12), c + Vector2(14, -12), accent, 2.4, true)
	draw_circle(c + Vector2(0, -20), 4.2, accent)
	draw_circle(c + Vector2(0, -20), 4.2, line, false, 1.6)


func _draw_mine_icon(center: Vector2, fill: Color, line: Color, accent: Color) -> void:
	var c = center + Vector2(0, 5)
	draw_rect(Rect2(c + Vector2(-21, 17), Vector2(42, 5)), Color(0, 0, 0, 0.18))
	_draw_shape([
		c + Vector2(-23, 17),
		c + Vector2(-10, -9),
		c + Vector2(0, 4),
		c + Vector2(11, -17),
		c + Vector2(24, 17),
	], fill, line, 3.0)
	draw_line(c + Vector2(-12, 9), c + Vector2(-4, -3), accent, 3.0, true)
	draw_line(c + Vector2(3, 7), c + Vector2(12, -9), accent, 3.0, true)


func _draw_simple_site_symbol(center: Vector2, symbol: String, ink: Color, shadow: Color) -> void:
	_draw_text_center(symbol, Rect2(center + Vector2(-17, -21), Vector2(34, 38)), 28, shadow)
	_draw_text_center(symbol, Rect2(center + Vector2(-17, -23), Vector2(34, 38)), 28, ink)
	draw_rect(Rect2(center + Vector2(-4, 12), Vector2(8, 5)), ink)


func _draw_simple_building_symbol(center: Vector2, symbol: String, rarity: String, unlocked: bool) -> void:
	if not unlocked:
		_draw_simple_site_symbol(center, symbol, Color(0.07, 0.09, 0.14, 0.88), Color(0, 0, 0, 0.16))
		return
	var rank = _rarity_sort_rank(rarity)
	var main = COLOR_GOLD if symbol == "矿" else _rarity_color(rarity)
	var radius = 17.0 + float(rank) * 2.5
	var c = center + Vector2(0, -2.0 - float(rank) * 0.7)
	draw_circle(c + Vector2(0, 4), radius, Color(0, 0, 0, 0.18))
	draw_circle(c, radius, main.darkened(0.05))
	draw_arc(c, radius + 1.0, 0.0, TAU, 28, COLOR_LINE, 3.0, true)
	_draw_text_center(symbol, Rect2(c + Vector2(-18, -22), Vector2(36, 40)), 26 + rank, Color.WHITE)


func _draw_building(center: Vector2, tile: Dictionary) -> void:
	var building = String(tile["building"])
	if building == "barracks" or building == "hall":
		_draw_quality_camp(center + Vector2(0, -7), _building_visual_rarity(tile), true)
	elif building == "tower":
		_draw_quality_tower(center + Vector2(0, -7), _building_visual_rarity(tile), true)
	elif building == "mine":
		_draw_quality_mine(center + Vector2(0, -7), true)
	else:
		var size = Vector2(66, 66)
		if building == "base":
			size = Vector2(78, 78)
		draw_texture_rect(_building_texture(building), Rect2(center - size * 0.5 + Vector2(0, -8), size), false)
	if building == "barracks" or building == "hall":
		_draw_building_summon_progress(center, tile)
	_draw_building_health_bar(center, tile)


func _draw_building_summon_progress(center: Vector2, tile: Dictionary) -> void:
	var building = String(tile.get("building", ""))
	var delay = _building_delay(building, int(tile.get("team", PLAYER)), String(tile.get("site_card", "")))
	if delay <= 0.0:
		return
	var remaining = clampf(float(tile.get("spawn_timer", 0.0)), 0.0, delay)
	var pct = clampf(1.0 - remaining / delay, 0.0, 1.0)
	_draw_compact_bar(Rect2(center + Vector2(-21, 19), Vector2(42, 5)), pct, COLOR_YELLOW)


func _draw_building_health_bar(center: Vector2, tile: Dictionary) -> void:
	var max_hp = float(tile.get("max_hp", 0.0))
	var team = int(tile["team"])
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		_draw_team_marker(center + Vector2(29, 29), team)
	if not _should_draw_building_health_bar(tile):
		return
	var hp = float(tile.get("hp", 0.0))
	var pct = clampf(hp / max_hp, 0.0, 1.0)
	_draw_compact_bar(Rect2(center + Vector2(-23, 27), Vector2(46, 5)), pct, _team_health_color(team))


func _should_draw_building_health_bar(tile: Dictionary) -> bool:
	var max_hp = float(tile.get("max_hp", 0.0))
	return max_hp > 0.0 and float(tile.get("hp", 0.0)) < max_hp - 0.001


func _draw_compact_bar(rect: Rect2, pct: float, fill: Color) -> void:
	var clamped_pct = clampf(pct, 0.0, 1.0)
	draw_rect(rect, Color(0.04, 0.05, 0.08, 0.78))
	if clamped_pct > 0.0:
		draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2((rect.size.x - 2.0) * clamped_pct, rect.size.y - 2.0)), fill)
	draw_rect(rect, COLOR_LINE, false, 1.0)


func _building_visual_rarity(tile: Dictionary) -> String:
	var building = String(tile.get("building", ""))
	if building == "barracks" or building == "hall" or building == "tower":
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
	var world_pos = Vector2(unit["pos"])
	var card = _unit_card(unit)
	var visual_scale = _animal_rarity_visual_scale(card)
	if _uses_axial_battle_map() and not _is_world_pos_visible(world_pos, 54.0 * visual_scale):
		return
	var pos = _world_to_canvas(world_pos)
	var team = int(unit["team"])
	draw_circle(pos + Vector2(0, 14), 17.0 * visual_scale, Color(0, 0, 0, 0.18))
	_draw_animal_texture_at_foot(
		_card_texture(card),
		pos + Vector2(0, 14),
		Vector2(44, 44),
		UnitMotionFeedback.pose(unit),
		visual_scale
	)
	var pct = clampf(float(unit["hp"]) / float(unit["max_hp"]), 0.0, 1.0)
	_draw_compact_bar(Rect2(pos + Vector2(-18, 20), Vector2(36, 6)), pct, _team_health_color(team))
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		_draw_team_marker(pos + Vector2(23, 23), team)


func _animal_rarity_visual_scale(card: Dictionary) -> float:
	var rarity = String(card.get("rarity", "common")).to_lower()
	return float(ANIMAL_RARITY_VISUAL_SCALES.get(rarity, 1.0))


func _animal_texture_draw_scale(pose: Dictionary, visual_scale: float) -> Vector2:
	return Vector2(pose.get("scale", Vector2.ONE)) * visual_scale


func _draw_animal_texture_at_foot(texture: Texture2D, foot: Vector2, size: Vector2, pose: Dictionary, visual_scale: float = 1.0) -> void:
	var offset = Vector2(pose.get("offset", Vector2.ZERO))
	var draw_scale = _animal_texture_draw_scale(pose, visual_scale)
	var rotation = float(pose.get("rotation", 0.0))
	draw_set_transform(canvas_offset + (foot + offset) * canvas_scale, rotation, draw_scale * canvas_scale)
	draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), false)
	draw_set_transform(canvas_offset, 0.0, Vector2(canvas_scale, canvas_scale))


func _team_health_color(team: int) -> Color:
	return _team_color(team)


func _initialize_battle_team_colors(match_seed: int) -> void:
	team_territory_colors.clear()
	team_unlocked_colors.clear()
	var random = RandomNumberGenerator.new()
	random.seed = posmod(hash("%d:team_palette" % match_seed), 2147483646) + 1
	if battle_mode == BATTLE_MODE_MULTIPLAYER and not multiplayer_free_for_all:
		var warm_rotation = random.randi_range(0, ROOM_WARM_HUES.size() - 1)
		var cool_rotation = random.randi_range(0, ROOM_COOL_HUES.size() - 1)
		for index in range(3):
			var warm_hue = float(ROOM_WARM_HUES[(index + warm_rotation) % ROOM_WARM_HUES.size()])
			var cool_hue = float(ROOM_COOL_HUES[(index + cool_rotation) % ROOM_COOL_HUES.size()])
			_set_team_palette(index + 1, warm_hue + random.randf_range(-0.012, 0.012), random)
			_set_team_palette(index + 4, cool_hue + random.randf_range(-0.012, 0.012), random)
		return
	var teams = MultiplayerRules.TEAM_IDS.duplicate() if battle_mode == BATTLE_MODE_MULTIPLAYER else [PLAYER, ENEMY]
	var hue_offset = random.randf()
	var hue_step = 1.0 / float(teams.size())
	for index in range(teams.size()):
		var hue = hue_offset + float(index) * hue_step + random.randf_range(-0.015, 0.015)
		_set_team_palette(int(teams[index]), hue, random)


func _set_team_palette(team: int, hue: float, random: RandomNumberGenerator) -> void:
	var normalized_hue = fposmod(hue, 1.0)
	var team_color = Color.from_hsv(
		normalized_hue,
		random.randf_range(0.30, 0.36),
		random.randf_range(0.78, 0.84)
	)
	team_territory_colors[team] = team_color
	team_unlocked_colors[team] = team_color


func _team_color(team: int) -> Color:
	if team_unlocked_colors.has(team):
		return team_unlocked_colors[team]
	if battle_mode != BATTLE_MODE_MULTIPLAYER:
		if team == PLAYER:
			return COLOR_GREEN
		if team == ENEMY:
			return COLOR_RED
		return COLOR_YELLOW
	match team:
		1:
			return Color(0.96, 0.22, 0.12)
		2:
			return Color(1.00, 0.50, 0.05)
		3:
			return Color(0.96, 0.76, 0.06)
		4:
			return Color(0.36, 0.54, 0.70)
		5:
			return Color(0.34, 0.59, 0.57)
		6:
			return Color(0.51, 0.47, 0.65)
		_:
			return Color(0.70, 0.70, 0.64)


func _team_territory_color(team: int) -> Color:
	return _team_color(team)


func _team_unlocked_color(team: int) -> Color:
	if team_unlocked_colors.has(team):
		return team_unlocked_colors[team]
	return _team_color(team)


func _draw_team_marker(center: Vector2, team: int) -> void:
	draw_circle(center, 8.0, Color(0.04, 0.05, 0.08, 0.92))
	draw_circle(center, 6.2, _team_color(team))
	var number_color = COLOR_LINE if battle_mode == BATTLE_MODE_MULTIPLAYER and team in [2, 3] else Color.WHITE
	_draw_text_center(str(team), Rect2(center + Vector2(-6, -7), Vector2(12, 12)), 10, number_color)


func _is_world_pos_visible(pos: Vector2, margin: float = 0.0) -> bool:
	return _battle_view_rect().grow(margin).has_point(_world_to_canvas(pos))


func _tile_display_card(tile: Dictionary) -> Dictionary:
	var building = String(tile.get("building", ""))
	if building == "mine":
		var mine_card_id = String(tile.get("site_card", MINE_CARD_ID))
		return _card_by_id(mine_card_id if mine_card_id != "" else MINE_CARD_ID)
	if building == "barracks" or building == "hall" or building == "tower":
		return _card_by_id(String(tile.get("site_card", "")))
	return {}


func _draw_effect(effect: Dictionary) -> void:
	var kind = String(effect.get("kind", "pulse"))
	if _uses_axial_battle_map():
		if kind == "projectile":
			if not _is_world_pos_visible(Vector2(effect.get("from", Vector2.ZERO)), 80.0) and not _is_world_pos_visible(Vector2(effect.get("to", Vector2.ZERO)), 80.0):
				return
		elif effect.has("pos") and not _is_world_pos_visible(_effect_world_position(effect), 120.0):
			return
	if kind == UnitMotionFeedback.KIND_DEATH:
		var dead_card = _card_by_id(String(effect.get("card_id", "")))
		if dead_card.is_empty():
			return
		var dead_pos = _world_to_canvas(Vector2(effect.get("pos", Vector2.ZERO)))
		_draw_animal_texture_at_foot(
			_card_texture(dead_card),
			dead_pos + Vector2(0, 14),
			Vector2(44, 44),
			UnitMotionFeedback.death_pose(effect),
			_animal_rarity_visual_scale(dead_card)
		)
		return
	if kind == "card_popup":
		var duration = maxf(0.01, float(effect.get("duration", UNLOCK_CARD_POPUP_SECONDS)))
		var progress = clampf(1.0 - float(effect["time"]) / duration, 0.0, 1.0)
		var card = _card_by_id(String(effect.get("card_id", "")))
		if card.is_empty():
			return
		var popup_scale = 1.0 + sin(progress * PI) * 0.12
		var size = Vector2(88, 108) * popup_scale
		var pos = _world_to_canvas(Vector2(effect["pos"])) + Vector2(0, -18.0 * progress)
		_draw_card(Rect2(pos - size * 0.5, size), card, true)
		return
	if kind == "gold_gain":
		var duration = maxf(0.01, float(effect.get("duration", GOLD_GAIN_FEEDBACK_DURATION)))
		var progress = clampf(1.0 - float(effect.get("time", 0.0)) / duration, 0.0, 1.0)
		var alpha = clampf(float(effect.get("time", 0.0)) / (duration * 0.34), 0.0, 1.0)
		var rise = GOLD_GAIN_FEEDBACK_RISE * (1.0 - pow(1.0 - progress, 2.0))
		var pos = _world_to_canvas(_effect_world_position(effect)) + Vector2(0, -rise)
		var pop = 1.0 + 0.18 * sin(minf(progress / 0.24, 1.0) * PI)
		var coin_center = pos + Vector2(-19, 0)
		var coin_radius = 7.0 * pop
		var shadow = Color(0.04, 0.05, 0.07, 0.34 * alpha)
		var coin = Color(COLOR_GOLD, alpha)
		var highlight = Color(1.0, 0.90, 0.42, alpha)
		var ink = Color(COLOR_LINE, alpha)
		draw_circle(coin_center + Vector2(0, 2), coin_radius + 1.5, shadow)
		draw_circle(coin_center, coin_radius, coin)
		draw_circle(coin_center + Vector2(-2, -2), coin_radius * 0.32, highlight)
		draw_arc(coin_center, coin_radius + 0.8, 0.0, TAU, 18, ink, 1.5, true)
		var amount_rect = Rect2(pos + Vector2(-8, -13), Vector2(58, 25))
		_draw_text_center(
			"+%d" % int(effect.get("amount", 0)),
			Rect2(amount_rect.position + Vector2(1.5, 2.0), amount_rect.size),
			17,
			shadow
		)
		_draw_text_center("+%d" % int(effect.get("amount", 0)), amount_rect, 17, Color(1.0, 0.88, 0.30, alpha))
		return
	if kind == "unit_value":
		var duration = maxf(0.01, float(effect.get("duration", UNIT_VALUE_FEEDBACK_DURATION)))
		var progress = clampf(1.0 - float(effect.get("time", 0.0)) / duration, 0.0, 1.0)
		var alpha = clampf(float(effect.get("time", 0.0)) / (duration * 0.34), 0.0, 1.0)
		var rise = UNIT_VALUE_FEEDBACK_RISE * (1.0 - pow(1.0 - progress, 2.0))
		var pos = _world_to_canvas(_effect_world_position(effect)) + Vector2(0, -rise)
		var stat = String(effect.get("stat", "attack"))
		var color = _unit_value_feedback_color(stat)
		color.a = alpha
		var shadow = Color(0.04, 0.05, 0.07, 0.38 * alpha)
		_draw_unit_value_icon(pos + Vector2(-19, 0), stat, color, shadow)
		var value_rect = Rect2(pos + Vector2(-8, -13), Vector2(64, 25))
		var value_text = _unit_value_feedback_text(stat, float(effect.get("amount", 0.0)), String(effect.get("suffix", "")))
		_draw_text_center(value_text, Rect2(value_rect.position + Vector2(1.5, 2.0), value_rect.size), 17, shadow)
		_draw_text_center(value_text, value_rect, 17, color)
		return
	if kind == "projectile":
		var duration = maxf(0.01, float(effect.get("duration", PROJECTILE_TIME)))
		var progress = clampf(1.0 - float(effect["time"]) / duration, 0.0, 1.0)
		var start = _world_to_canvas(Vector2(effect["from"]))
		var end = _world_to_canvas(Vector2(effect["to"]))
		var head = start.lerp(end, progress)
		var tail = start.lerp(end, maxf(0.0, progress - 0.28))
		var projectile_color = effect["color"]
		projectile_color.a = 0.95
		var glow = Color(1.0, 0.96, 0.62, 0.38)
		draw_line(tail, head, glow, 9.0, true)
		draw_line(tail, head, projectile_color, 5.0, true)
		draw_circle(head, 6.0, Color(1.0, 1.0, 0.82, 0.96))
		draw_circle(head, 3.2, projectile_color)
		return
	var t = clampf(float(effect["time"]) / 0.45, 0.0, 1.0)
	var pulse_color = effect["color"]
	pulse_color.a = t * 0.55
	draw_circle(_world_to_canvas(Vector2(effect["pos"])), 8.0 + 30.0 * (1.0 - t), pulse_color)


func _unit_value_feedback_text(stat: String, amount: float, suffix: String) -> String:
	var magnitude = str(roundi(absf(amount))) if is_equal_approx(absf(amount), float(roundi(absf(amount)))) else "%.1f" % absf(amount)
	var sign_text = "-" if amount < 0.0 or stat in ["slow", "stun"] else "+"
	return "%s%s%s" % [sign_text, magnitude, suffix]


func _unit_value_feedback_color(stat: String) -> Color:
	match stat:
		"attack":
			return Color(1.0, 0.54, 0.20)
		"hp", "heal":
			return Color(0.42, 0.92, 0.48)
		"shield":
			return Color(0.32, 0.68, 1.0)
		"speed":
			return Color(1.0, 0.86, 0.28)
		"slow":
			return Color(0.40, 0.76, 1.0)
		"stun":
			return Color(0.74, 0.50, 1.0)
		"summon":
			return Color(0.96, 0.78, 0.30)
	return Color.WHITE


func _draw_unit_value_icon(center: Vector2, stat: String, color: Color, shadow: Color) -> void:
	draw_circle(center + Vector2(0, 2), 9.0, shadow)
	match stat:
		"attack":
			draw_line(center + Vector2(-5, 6), center + Vector2(5, -6), color, 4.0, true)
			draw_line(center + Vector2(-6, 2), center + Vector2(-1, 7), color, 2.5, true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(3, -7), center + Vector2(8, -8), center + Vector2(6, -3)]), color)
		"hp", "heal":
			draw_circle(center + Vector2(-3.5, -2), 4.5, color)
			draw_circle(center + Vector2(3.5, -2), 4.5, color)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 0), center + Vector2(7, 0), center + Vector2(0, 8)]), color)
		"shield":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -7), center + Vector2(7, -7), center + Vector2(6, 2), center + Vector2(0, 8), center + Vector2(-6, 2)]), color)
		"speed", "slow":
			var direction = -1.0 if stat == "slow" else 1.0
			for offset in [-4.0, 2.0]:
				draw_line(center + Vector2(offset - 3.0 * direction, -5), center + Vector2(offset + 3.0 * direction, 0), color, 2.5, true)
				draw_line(center + Vector2(offset + 3.0 * direction, 0), center + Vector2(offset - 3.0 * direction, 5), color, 2.5, true)
		"stun":
			for angle in range(0, 360, 72):
				var direction = Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				draw_line(center + direction * 3.0, center + direction * 8.0, color, 2.5, true)
			draw_circle(center, 3.5, color)
		"summon":
			draw_circle(center, 7.0, color, false, 2.5, true)
			draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), color, 2.5, true)
			draw_line(center + Vector2(0, -4), center + Vector2(0, 4), color, 2.5, true)


func _draw_selection_panel() -> void:
	var rect = Rect2(26, 1132, 668, 118)
	_box(rect, Color(0.12, 0.10, 0.31, 0.92), Color(0.30, 0.28, 0.62), 4)
	if _draw_selected_tile_card_panel(rect):
		return
	var title = "点击与己方地块接壤的卡牌地块解锁"
	var detail = "可解锁地块只显示类型和价格，品质会在解锁时随机。"
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		title = "拖动查看地图，点击地块查看信息"
		detail = "单位自动选择最近敌人；点击己方可连接地块可购买。"
	elif _uses_axial_battle_map():
		title = "%s · 拖动查看地图" % classic_map_name
		detail = "点击己方可连接地块购买；防御塔价格随本局购买次数递增。"
	var detail_extra = ""
	var local_team = _local_control_team()
	var local_gold = _gold_for_team(local_team)
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
					detail = "%s Lv.%d  攻%d 血%d 距%s 召%.1fs" % [
						_rarity_label(String(card.get("rarity", "common"))),
						_card_level_for_team(card_id, int(tile["team"])),
						int(stats["attack"]),
						int(stats["max_hp"]),
						_attack_range_label(float(stats["attack_range"])),
						float(stats["summon_interval_sec"]),
					]
					detail_extra = "技能：" + _card_skill_text(card)
			else:
				detail = "生命 %.0f / %.0f" % [float(tile["hp"]), float(tile["max_hp"])]
		elif int(tile["team"]) == local_team:
			title = "空地"
			detail = "已解锁区域，可作为继续扩张的连接点。"
		elif battle_mode == BATTLE_MODE_MULTIPLAYER and BoardRules.visual_owner(tile) != local_team:
			var owner = BoardRules.visual_owner(tile)
			title = "中立争夺区域" if owner == NEUTRAL else "%d号玩家区域" % owner
			detail = "单位会自动推进并占领。"
		elif int(tile["team"]) == ENEMY:
			title = "敌方区域"
			detail = "派出单位推进后可占领。"
		elif _can_unlock(selected_tile, local_team):
			var site = String(tile.get("site", ""))
			var unlock_cost = _unlock_cost(selected_tile, local_team)
			title = "可解锁：%s  价格 %d" % [_locked_site_name(site), unlock_cost]
			if local_gold < unlock_cost:
				detail = "金币不足，还差%d。" % [unlock_cost - local_gold]
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


func _draw_selected_tile_card_panel(rect: Rect2) -> bool:
	if not tiles.has(selected_tile):
		return false
	var tile = tiles[selected_tile]
	if int(tile.get("team", NEUTRAL)) == NEUTRAL:
		return false
	var card = _tile_display_card(tile)
	if card.is_empty():
		return false
	var card_rect = Rect2(rect.position + Vector2(18, 10), Vector2(92, 98))
	_draw_card(card_rect, card, true)
	_draw_tile_card_summary(Rect2(rect.position + Vector2(128, 14), Vector2(512, 88)), tile, card)
	return true


func _draw_tile_card_summary(rect: Rect2, tile: Dictionary, card: Dictionary) -> void:
	var card_id = String(card.get("id", ""))
	var kind = _card_kind(card)
	var team = int(tile.get("team", PLAYER))
	var stats = _card_stats_for_team(card, team)
	var title = String(card.get("name", "卡牌"))
	var level = _card_level_for_team(card_id, team)
	_draw_text_fit("%s  %s Lv.%d" % [_rarity_label(String(card.get("rarity", "common"))), title, level], Rect2(rect.position, Vector2(rect.size.x, 28)), 23, Color.WHITE)
	if kind == CARD_KIND_MINE:
		_draw_text_fit("金矿卡  生命%d  每%d秒 +%d金币" % [int(stats["max_hp"]), int(INCOME_INTERVAL), MINE_INCOME], Rect2(rect.position + Vector2(0, 34), Vector2(rect.size.x, 24)), 19, Color(0.84, 0.88, 1.0))
		_draw_text_fit("金矿不产兵，只提供经济收入。", Rect2(rect.position + Vector2(0, 62), Vector2(rect.size.x, 24)), 17, Color(0.78, 0.86, 1.0))
	elif kind == CARD_KIND_DEFENSE:
		_draw_text_fit("防御塔卡  攻%d  生命%d  射程%s  冷却%.1fs" % [int(stats["attack"]), int(stats["max_hp"]), _attack_range_label(float(stats["attack_range"])), float(stats["summon_interval_sec"])], Rect2(rect.position + Vector2(0, 34), Vector2(rect.size.x, 24)), 18, Color(0.84, 0.88, 1.0))
		_draw_text_fit(_card_skill_text(card), Rect2(rect.position + Vector2(0, 62), Vector2(rect.size.x, 24)), 17, Color(0.78, 0.86, 1.0))
	else:
		_draw_text_fit("动物营地  攻%d  生命%d  射程%s" % [int(stats["attack"]), int(stats["max_hp"]), _attack_range_label(float(stats["attack_range"]))], Rect2(rect.position + Vector2(0, 34), Vector2(rect.size.x, 24)), 18, Color(0.84, 0.88, 1.0))
		_draw_text_fit(_card_skill_text(card), Rect2(rect.position + Vector2(0, 62), Vector2(rect.size.x, 24)), 17, Color(0.78, 0.86, 1.0))


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
	var panel = Rect2(60, 176, 600, 824)
	_box(panel, Color(1.0, 0.96, 0.78), COLOR_LINE, 5)
	var result_color = COLOR_YELLOW if result_text == "胜利" else (COLOR_BLUE if result_text == "平局" else COLOR_RED)
	if battle_mode == BATTLE_MODE_MULTIPLAYER and multiplayer_free_for_all:
		result_color = COLOR_YELLOW if multiplayer_placement == 1 else (COLOR_BLUE if multiplayer_placement <= 3 else COLOR_RED)
	_draw_text_center(result_text, Rect2(panel.position + Vector2(0, 24), Vector2(panel.size.x, 56)), 42, result_color)
	var reward_tickets = last_battle_reward_tickets if last_battle_reward_tickets > 0 else _battle_reward_tickets(result_text)
	if battle_mode == BATTLE_MODE_MULTIPLAYER:
		var star_text = ("+" if last_multiplayer_star_delta > 0 else "") + str(last_multiplayer_star_delta)
		_draw_text_center("奖励：%s星  %d抽卡券" % [star_text, reward_tickets], Rect2(panel.position + Vector2(0, 82), Vector2(panel.size.x, 32)), 21, COLOR_LINE)
	else:
		_draw_text_center("奖励：+%d 抽卡券" % reward_tickets, Rect2(panel.position + Vector2(0, 82), Vector2(panel.size.x, 32)), 21, COLOR_LINE)
	_draw_text_center("我的结算", Rect2(92, 302, 536, 28), 20, COLOR_PURPLE)
	var local_entry = {}
	for entry in result_player_entries:
		if bool(entry.get("is_local", false)):
			local_entry = entry
			break
	if not local_entry.is_empty():
		_draw_result_player_row(Rect2(92, 336, 536, 112), local_entry, true)
	_draw_text_fit("其他玩家（上下滑动查看）", Rect2(92, 486, 536, 30), 20, COLOR_LINE)
	var other_rect = _result_other_players_rect()
	draw_rect(other_rect, Color(0.20, 0.17, 0.28, 0.08))
	var others = _result_other_entries()
	result_players_scroll = clampf(result_players_scroll, 0.0, _result_players_max_scroll())
	for index in range(others.size()):
		var row = Rect2(other_rect.position + Vector2(0, float(index) * (RESULT_PLAYER_ROW_HEIGHT + RESULT_PLAYER_ROW_GAP) - result_players_scroll), Vector2(other_rect.size.x - (12.0 if _result_players_max_scroll() > 0.0 else 0.0), RESULT_PLAYER_ROW_HEIGHT))
		if row.position.y < other_rect.position.y or row.end.y > other_rect.end.y:
			continue
		_draw_result_player_row(row, others[index], false)
	if _result_players_max_scroll() > 0.0:
		var track = Rect2(other_rect.end.x - 7, other_rect.position.y + 4, 4, other_rect.size.y - 8)
		draw_rect(track, Color(0.18, 0.16, 0.25, 0.20))
		var thumb_height = maxf(42.0, track.size.y * other_rect.size.y / (other_rect.size.y + _result_players_max_scroll()))
		var thumb_y = track.position.y + (track.size.y - thumb_height) * result_players_scroll / _result_players_max_scroll()
		draw_rect(Rect2(track.position.x, thumb_y, track.size.x, thumb_height), COLOR_PURPLE)
	_cta(_result_return_rect(), "返回房间" if battle_mode == BATTLE_MODE_MULTIPLAYER and not multiplayer_free_for_all else "返回主界面", true)


func _draw_result_player_row(rect: Rect2, entry: Dictionary, is_local: bool) -> void:
	var fill = Color(1.0, 0.84, 0.30, 0.24) if is_local else Color(1.0, 1.0, 1.0, 0.72)
	var line = COLOR_GOLD if is_local else Color(0.20, 0.18, 0.28, 0.46)
	_box(rect, fill, line, 4 if is_local else 2)
	var placement = int(entry.get("placement", 0))
	draw_circle(rect.position + Vector2(32, rect.size.y * 0.5), 20.0, COLOR_GOLD if placement == 1 else COLOR_PURPLE)
	_draw_text_center(str(placement), Rect2(rect.position + Vector2(12, rect.size.y * 0.5 - 20), Vector2(40, 40)), 22, Color.WHITE)
	var badge = "  自己" if is_local else ""
	_draw_text_fit("第%d名  %s%s" % [placement, String(entry.get("name", "玩家")), badge], Rect2(rect.position + Vector2(66, 8), Vector2(rect.size.x - 82, 28)), 20, COLOR_LINE)
	var delta = int(entry.get("star_delta", 0))
	var delta_text = ("+" if delta > 0 else "") + str(delta)
	var delta_color = COLOR_GREEN if delta > 0 else (COLOR_RED if delta < 0 else COLOR_BLUE)
	_draw_text_fit("%s  →  %s" % [String(entry.get("old_rank_display", "")), String(entry.get("new_rank_display", ""))], Rect2(rect.position + Vector2(66, rect.size.y - 34), Vector2(rect.size.x - 150, 26)), 17, COLOR_PURPLE)
	_draw_text_right("%s星" % delta_text, Rect2(rect.end.x - 82, rect.position.y + rect.size.y * 0.5 - 13, 68, 26), 19, delta_color)


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
	var detail_motion_progress = -1.0
	if detail_upgrade_motion_timer > 0.0:
		detail_motion_progress = 1.0 - detail_upgrade_motion_timer / DETAIL_UPGRADE_MOTION_SECONDS
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
	if detail_motion_progress >= 0.0:
		_draw_animal_texture_at_foot(_card_texture(card), Vector2(art_rect.get_center().x, art_rect.end.y), art_rect.size, UnitMotionFeedback.power_up_pose(detail_motion_progress))
	else:
		draw_texture_rect(_card_texture(card), art_rect, false)
	_box(name_rect, rarity_fill.darkened(0.16), Color(1, 1, 1, 0.18), 1)
	_draw_text_center("Lv.%d  %s" % [_card_level(card_id), String(card.get("name", ""))], name_rect, 15, Color.WHITE)
	var kind = _card_kind(card)
	if kind == CARD_KIND_MINE:
		_draw_detail_stat_icon_value(rect.position + Vector2(142, 18), "hp", str(int(stats["max_hp"])), COLOR_RED)
		_draw_detail_stat_icon_value(rect.position + Vector2(242, 18), "gold", "+%d" % MINE_INCOME, COLOR_GOLD)
		_draw_text_center("%d秒" % int(INCOME_INTERVAL), Rect2(rect.position + Vector2(342, 20), Vector2(72, 28)), 18, COLOR_LINE)
	elif kind == CARD_KIND_DEFENSE:
		_draw_detail_stat_icon_value(rect.position + Vector2(142, 18), "attack", str(int(stats["attack"])), COLOR_RED)
		_draw_detail_stat_icon_value(rect.position + Vector2(232, 18), "hp", str(int(stats["max_hp"])), COLOR_RED)
		_draw_text_center(_attack_range_label(float(stats["attack_range"])), Rect2(rect.position + Vector2(330, 20), Vector2(72, 28)), 18, COLOR_LINE)
		_draw_text_center("%.1fs" % float(stats["summon_interval_sec"]), Rect2(rect.position + Vector2(424, 20), Vector2(72, 28)), 18, COLOR_LINE)
	else:
		_draw_detail_stat_icon_value(rect.position + Vector2(142, 18), "attack", str(int(stats["attack"])), COLOR_RED)
		_draw_detail_stat_icon_value(rect.position + Vector2(232, 18), "hp", str(int(stats["max_hp"])), COLOR_RED)
		_draw_text_center(_attack_range_label(float(stats["attack_range"])), Rect2(rect.position + Vector2(330, 20), Vector2(72, 28)), 18, COLOR_LINE)
	var has_guaranteed_hp_growth = CardRules.is_ranged_or_summon_animal(card)
	var skill_text = _card_detail_skill_text(card)
	if skill_text != "":
		_draw_text_center(skill_text, Rect2(rect.position + Vector2(138, 54), Vector2(370, 22 if has_guaranteed_hp_growth else 28)), 16, COLOR_PURPLE)
	if has_guaranteed_hp_growth:
		_draw_text_center("远程/召唤：每2级+1生命", Rect2(rect.position + Vector2(138, 76), Vector2(370, 16)), 13, COLOR_GREEN)
	var cost = _next_upgrade_cost(card_id)
	_draw_upgrade_progress(Rect2(rect.position + Vector2(138, 94 if has_guaranteed_hp_growth else 92), Vector2(352, 18)), card_id, true)
	if _can_show_equip_button(card_id):
		_cta(_equip_button_rect(), "选择中" if pending_equip_card_id == card_id else "上阵", true)
	_cta(_upgrade_button_rect(), "升级", cost >= 0 and _card_spare_count(card_id) >= cost)


func _card_detail_skill_text(card: Dictionary) -> String:
	return _card_display_skill_text(card, false)


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
		"gold":
			_draw_coin_icon(center, color)
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


func _draw_coin_icon(center: Vector2, color: Color) -> void:
	draw_circle(center, 11.0, color)
	draw_circle(center, 6.2, color.lightened(0.28))
	draw_arc(center, 11.4, 0.0, TAU, 20, COLOR_LINE, 2.0, true)


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
	if _uses_axial_battle_map():
		return MultiplayerRules.hex_center(key, Vector2.ZERO, HEX_SIZE)
	return BoardRules.hex_center(key, board_origin, HEX_SIZE)


func _multiplayer_camera_offset() -> Vector2:
	return _battle_view_rect().get_center() + board_pan


func _world_to_canvas(pos: Vector2) -> Vector2:
	if _uses_axial_battle_map():
		return pos + _multiplayer_camera_offset()
	return pos


func _canvas_to_world(pos: Vector2) -> Vector2:
	if _uses_axial_battle_map():
		return pos - _multiplayer_camera_offset()
	return pos


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
	if _uses_axial_battle_map():
		return MultiplayerRules.neighbors(tiles, key)
	return BoardRules.neighbors(key)


func _rebuild_ground_navigation() -> void:
	ground_navigation.clear()
	ground_navigation_ids.clear()
	var tile_keys = tiles.keys()
	tile_keys.sort_custom(Callable(self, "_is_tile_key_before"))
	for index in range(tile_keys.size()):
		var key: Vector2i = tile_keys[index]
		var point_id = index + 1
		ground_navigation_ids[key] = point_id
		ground_navigation.add_point(point_id, _hex_center(key))
	for key in tile_keys:
		var point_id = int(ground_navigation_ids[key])
		for neighbor in _neighbors(key):
			var neighbor_id = int(ground_navigation_ids.get(neighbor, 0))
			if neighbor_id > point_id:
				ground_navigation.connect_points(point_id, neighbor_id, true)


func _ground_path_between(start_key: Vector2i, target_key: Vector2i) -> PackedVector2Array:
	var start_id = int(ground_navigation_ids.get(start_key, 0))
	var target_id = int(ground_navigation_ids.get(target_key, 0))
	if start_id <= 0 or target_id <= 0:
		return PackedVector2Array()
	return ground_navigation.get_point_path(start_id, target_id)


func _is_tile_key_before(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


func _tile_at_world(pos: Vector2) -> Vector2i:
	if _uses_axial_battle_map():
		return MultiplayerRules.tile_at(tiles, pos, Vector2.ZERO, HEX_SIZE)
	return BoardRules.tile_at(tiles, pos, board_origin, HEX_SIZE)


func _tile_at_canvas(pos: Vector2) -> Vector2i:
	return _tile_at_world(_canvas_to_world(pos))


func _deck_slot_rect(index: int) -> Rect2:
	var col = index % 4
	var row = floori(float(index) / 4.0)
	return Rect2(64 + col * 150.0, 202 + row * 142.0, 124, 132)


func _start_rect() -> Rect2:
	return Rect2(190, 950, 340, 68)


func _multiplayer_start_rect() -> Rect2:
	return Rect2(190, 1030, 340, 68)


func _multiplayer_button_title_rect() -> Rect2:
	var button = _multiplayer_start_rect()
	return Rect2(button.position + Vector2(18.0, 0.0), Vector2(button.size.x - 36.0, button.size.y))


func _multiplayer_hot_badge_rect() -> Rect2:
	var button = _multiplayer_start_rect()
	return Rect2(button.end.x - 58.0, button.position.y - 12.0, 62.0, 30.0)


func _lobby_base_rect() -> Rect2:
	return Rect2(230, 228, 260, 286)


func _account_panel_rect() -> Rect2:
	return Rect2(62, 156, 596, 850)


func _account_title_rect() -> Rect2:
	return Rect2(96, 188, 420, 56)


func _account_close_rect() -> Rect2:
	return Rect2(532, 194, 96, 46)


func _account_agreement_rect() -> Rect2:
	return Rect2(104, 620, 512, 64)


func _account_music_rect() -> Rect2:
	return Rect2(104, 754, 246, 64)


func _account_sfx_rect() -> Rect2:
	return Rect2(370, 754, 246, 64)


func _account_name_input_rect() -> Rect2:
	return Rect2(190, 334, 426, 58)


func _account_password_input_rect() -> Rect2:
	return Rect2(190, 416, 426, 58)


func _account_login_rect() -> Rect2:
	return Rect2(104, 494, 246, 64)


func _account_register_rect() -> Rect2:
	return Rect2(370, 494, 246, 64)


func _account_logout_rect() -> Rect2:
	return Rect2(154, 856, 412, 68)


func _agreement_back_rect() -> Rect2:
	return Rect2(154, 846, 412, 68)


func _room_mode_rect(players_per_side: int) -> Rect2:
	return Rect2(72.0 + float(players_per_side - 1) * 200.0, 168, 176, 52)


func _room_code_copy_rect() -> Rect2:
	return Rect2(506, 246, 92, 48)


func _room_code_refresh_rect() -> Rect2:
	return Rect2(608, 246, 44, 48)


func _room_online_create_rect() -> Rect2:
	return Rect2(120, 326, 480, 72)


func _room_online_code_input_rect() -> Rect2:
	return Rect2(92, 466, 356, 64)


func _room_online_join_rect() -> Rect2:
	return Rect2(464, 466, 164, 64)


func _room_entry_ai_fill_rect() -> Rect2:
	return Rect2(92, 574, 536, 58)


func _room_online_retry_rect() -> Rect2:
	return Rect2(230, 690, 260, 60)


func _room_team_panel_rect(side_index: int) -> Rect2:
	return Rect2(48.0 + float(side_index) * 322.0, 334, 302, 470)


func _room_slot_rect(side_index: int, slot_index: int) -> Rect2:
	var panel = _room_team_panel_rect(side_index)
	return Rect2(panel.position + Vector2(16, 60 + float(slot_index) * 126.0), Vector2(panel.size.x - 32, 106))


func _room_ai_fill_rect() -> Rect2:
	return Rect2(48, 824, 624, 62)


func _room_ready_rect() -> Rect2:
	return Rect2(48, 900, 300, 54)


func _room_leave_rect() -> Rect2:
	return Rect2(372, 900, 300, 54)


func _room_start_rect() -> Rect2:
	return Rect2(150, 1000, 420, 72)


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


func _show_unlock_card_popup(key: Vector2i) -> void:
	if not tiles.has(key):
		return
	var card = _tile_display_card(tiles[key])
	if card.is_empty():
		return
	effects.append({
		"kind": "card_popup",
		"pos": _hex_center(key) + Vector2(0, -74),
		"card_id": String(card.get("id", "")),
		"time": UNLOCK_CARD_POPUP_SECONDS,
		"duration": UNLOCK_CARD_POPUP_SECONDS,
	})


func _projectile(start: Vector2, end: Vector2, team: int) -> void:
	var color = _team_color(team).lightened(0.18) if battle_mode == BATTLE_MODE_MULTIPLAYER else (COLOR_YELLOW if team == PLAYER else COLOR_ORANGE)
	effects.append({
		"kind": "projectile",
		"from": start,
		"to": end,
		"color": color,
		"time": PROJECTILE_TIME,
		"duration": PROJECTILE_TIME,
	})
