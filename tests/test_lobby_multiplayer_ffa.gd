extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_seeded_local_team_assignment()
	_test_lobby_button_starts_free_for_all()
	_test_explicit_free_for_all_entry()
	_test_live_tile_ranking()
	_test_free_for_all_placement_rewards()
	_test_room_entry_keeps_team_rules()
	if failures == 0:
		print("Lobby multiplayer free-for-all tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_lobby_button_starts_free_for_all() -> void:
	app.call("_layout", app.get_viewport().get_visible_rect().size)
	app.set("screen", "lobby")
	var button: Rect2 = app.call("_multiplayer_start_rect")
	var title: Rect2 = app.call("_multiplayer_button_title_rect")
	var badge: Rect2 = app.call("_multiplayer_hot_badge_rect")
	_expect_true(button.intersects(badge), "HOT badge remains attached to the multiplayer button")
	_expect_true(badge.get_center().x > button.get_center().x, "HOT badge stays on the button's right edge")
	_expect_true(badge.get_center().y < button.get_center().y, "HOT badge stays above the centered title")
	_expect_true(is_equal_approx(title.get_center().x, button.get_center().x), "multiplayer title is horizontally centered")
	_expect_true(is_equal_approx(title.get_center().y, button.get_center().y), "multiplayer title is vertically centered")

	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	app.call("_handle_tap", offset + badge.get_center() * scale)
	_expect_equal(String(app.get("screen")), "battle", "lobby multiplayer banner starts battle directly")
	_expect_true(bool(app.get("multiplayer_free_for_all")), "lobby multiplayer enables free-for-all rules")
	_expect_equal(app.get("room_active_team_ids"), MultiplayerRules.TEAM_IDS, "all six free-for-all teams are active")
	_expect_equal(String(app.get("room_map_id")), MultiplayerRules.FREE_FOR_ALL_MAP_ID, "lobby multiplayer uses the dedicated regular hex")
	_expect_equal((app.get("tiles") as Dictionary).size(), 331, "lobby multiplayer regular hex contains 331 cells")
	_expect_true(is_equal_approx(float(app.get("battle_timer")), MainApp.MULTIPLAYER_FREE_FOR_ALL_TIME), "lobby multiplayer starts with the six-minute timer")
	for first_team in MultiplayerRules.TEAM_IDS:
		for second_team in MultiplayerRules.TEAM_IDS:
			if first_team != second_team:
				_expect_false(bool(app.call("_are_allies", first_team, second_team)), "different free-for-all teams are enemies")
	app.call("_return_to_lobby")


func _test_seeded_local_team_assignment() -> void:
	var assigned_teams = []
	for seed in range(1, MultiplayerRules.TEAM_IDS.size() + 1):
		assigned_teams.append(MultiplayerRules.free_for_all_local_team(seed))
	_expect_equal(assigned_teams, MultiplayerRules.TEAM_IDS, "six consecutive match seeds cover all six triangular factions")
	_expect_equal(
		MultiplayerRules.free_for_all_local_team(17),
		MultiplayerRules.free_for_all_local_team(17),
		"same match seed keeps the local faction assignment reproducible"
	)


func _test_explicit_free_for_all_entry() -> void:
	app.set("room_players_per_side", 2)
	app.set("room_fill_with_ai", false)
	app.set("room_invite_code", "ABC123")
	app.set("room_human_teams", {BoardRules.PLAYER: "我", 2: "旧房间玩家"})
	app.set("room_pending_invites", {5: true})
	app.set("room_active_team_ids", [1, 2, 4, 5])
	app.call("_start_multiplayer_match", "", MultiplayerRules.MAX_PLAYERS_PER_SIDE, true)
	_expect_equal(String(app.get("screen")), "battle", "explicit free-for-all entry starts battle")
	_expect_true(bool(app.get("multiplayer_free_for_all")), "lobby multiplayer enables free-for-all rules")
	_expect_equal(int(app.get("room_players_per_side")), MultiplayerRules.MAX_PLAYERS_PER_SIDE, "lobby multiplayer activates all six slots")
	_expect_equal(app.get("room_active_team_ids"), MultiplayerRules.TEAM_IDS, "all six teams are active")
	_expect_equal(int(app.call("_multiplayer_alive_count")), MultiplayerRules.TEAM_IDS.size(), "all six players start alive")
	var local_team = int(app.call("_local_control_team"))
	_expect_true(local_team in MultiplayerRules.TEAM_IDS, "local player receives one of the six triangular factions")
	_expect_equal((app.get("room_human_teams") as Dictionary).keys(), [local_team], "only the assigned local faction remains human-controlled")
	var local_base: Vector2i = (app.get("room_base_keys") as Dictionary).get(local_team, MultiplayerRules.INVALID_KEY)
	_expect_true((app.get("tiles") as Dictionary).has(local_base), "the assigned local faction has a spawned base")
	var local_base_center: Vector2 = app.call("_world_to_canvas", app.call("_hex_center", local_base))
	_expect_true((app.call("_battle_view_rect") as Rect2).has_point(local_base_center), "initial camera follows the assigned local faction")
	for team in MultiplayerRules.TEAM_IDS:
		if int(team) != local_team:
			_expect_true((app.get("multiplayer_ai_timers") as Dictionary).has(team), "team %d is controlled by AI" % team)
	_expect_false(bool(app.call("_are_allies", 1, 2)), "different free-for-all teams are enemies")
	_expect_true(bool(app.call("_are_allies", 1, 1)), "a team remains allied with itself")
	var status_text = String(app.call("_match_status_text"))
	_expect_true(status_text.contains("06:00"), "battle status shows the six-minute countdown")
	_expect_true(status_text.contains("%d/6" % app.call("_multiplayer_team_rank", local_team)), "battle status shows the local live rank")
	app.call("_return_to_lobby")
	_expect_equal(String(app.get("screen")), "lobby", "free-for-all returns to the lobby")
	_expect_equal(int(app.get("room_players_per_side")), 2, "free-for-all preserves prepared room size")
	_expect_false(bool(app.get("room_fill_with_ai")), "free-for-all preserves room AI-fill preference")
	_expect_equal(String(app.get("room_invite_code")), "ABC123", "free-for-all preserves the room invite code")
	_expect_equal(String((app.get("room_human_teams") as Dictionary).get(2, "")), "旧房间玩家", "free-for-all restores invited room players")
	_expect_true((app.get("room_pending_invites") as Dictionary).has(5), "free-for-all restores pending room invites")


func _test_free_for_all_placement_rewards() -> void:
	app.call("_start_multiplayer_match", "", MultiplayerRules.MAX_PLAYERS_PER_SIDE, true)
	var local_team = int(app.call("_local_control_team"))
	var attacker = BoardRules.NEUTRAL
	for team in MultiplayerRules.TEAM_IDS:
		if int(team) != local_team:
			attacker = int(team)
			break
	var tiles_before: Dictionary = app.get("tiles")
	var transferred_count = 0
	for tile in tiles_before.values():
		if int(tile.get("team", BoardRules.NEUTRAL)) == local_team or BoardRules.visual_owner(tile) == local_team:
			transferred_count += 1
	var attacker_score_before = int(app.call("_multiplayer_tile_score", attacker))
	app.call("_eliminate_multiplayer_team", local_team, attacker)
	_expect_false(bool(app.get("game_over")), "local elimination keeps the free-for-all running for spectating")
	_expect_equal(int(app.call("_multiplayer_tile_score", local_team)), 0, "eliminated local player has zero tile score")
	_expect_false(bool(app.call("_can_unlock", MultiplayerRules.base_key(local_team), local_team)), "eliminated local player cannot buy tiles")
	var transferred_tiles = 0
	for tile in (app.get("tiles") as Dictionary).values():
		if BoardRules.visual_owner(tile) == attacker:
			transferred_tiles += 1
		_expect_false(int(tile.get("eliminated_team", BoardRules.NEUTRAL)) == local_team, "elimination leaves no defeated-player gray marker")
	_expect_true(transferred_tiles >= attacker_score_before + transferred_count, "eliminated player territory becomes attacker-owned")
	_expect_equal(int(app.call("_multiplayer_tile_score", attacker)), attacker_score_before + transferred_count, "attacker immediately gains the defeated territory score")
	app.call("_finish_multiplayer_free_for_all", app.call("_multiplayer_timeout_placement"))
	_expect_true(bool(app.get("game_over")), "timeout settlement ends the local free-for-all result")
	_expect_equal(int(app.get("multiplayer_placement")), 6, "first eliminated player places sixth")
	_expect_equal(int(app.get("last_multiplayer_star_delta")), -1, "sixth place loses one star")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 1, "sixth place receives one ticket")
	app.call("_return_to_lobby")

	app.call("_start_multiplayer_match", "", MultiplayerRules.MAX_PLAYERS_PER_SIDE, true)
	app.call("_finish_multiplayer_free_for_all", 3)
	_expect_equal(int(app.get("last_multiplayer_star_delta")), 2, "third place gains two stars")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 2, "third place receives two tickets")
	app.call("_return_to_lobby")

	app.call("_start_multiplayer_match", "", MultiplayerRules.MAX_PLAYERS_PER_SIDE, true)
	local_team = int(app.call("_local_control_team"))
	for team in MultiplayerRules.TEAM_IDS:
		if int(team) != local_team:
			app.call("_eliminate_multiplayer_team", team, local_team)
	_expect_true(bool(app.get("game_over")), "eliminating all five opponents ends the match")
	_expect_equal(int(app.get("multiplayer_placement")), 1, "last surviving player places first")
	_expect_equal(int(app.get("last_multiplayer_star_delta")), 3, "first place gains three stars")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 5, "first place receives five tickets")
	app.call("_return_to_lobby")


func _test_live_tile_ranking() -> void:
	app.call("_start_multiplayer_match", "", MultiplayerRules.MAX_PLAYERS_PER_SIDE, true)
	var local_team = int(app.call("_local_control_team"))
	var leader_team = BoardRules.NEUTRAL
	for team in MultiplayerRules.TEAM_IDS:
		if int(team) != local_team:
			leader_team = int(team)
			break
	var tiles: Dictionary = app.get("tiles")
	var bonus_key = Vector2i.ZERO
	_expect_true(tiles.has(bonus_key), "FFA has a neutral center cell for ranking setup")
	if tiles.has(bonus_key):
		tiles[bonus_key] = BoardRules.with_soft_occupation(tiles[bonus_key], leader_team)
		app.set("tiles", tiles)
	var ranking: Array = app.call("_multiplayer_live_ranking")
	_expect_equal(int(ranking[0].get("team", BoardRules.NEUTRAL)), leader_team, "live ranking puts the largest territory first")
	_expect_equal(int(ranking[0].get("tiles", 0)), 56, "live ranking publishes the current visible territory score")
	var expected_placement = int(app.call("_multiplayer_team_rank", local_team))
	_expect_true(expected_placement > 1, "local live rank updates when another player leads")
	app.set("battle_timer", 0.01)
	app.call("_update_battle", 0.02)
	_expect_true(bool(app.get("game_over")), "six-minute timeout settles the free-for-all")
	_expect_equal(int(app.get("multiplayer_placement")), expected_placement, "timeout uses the local faction's live territory ranking")
	app.call("_return_to_lobby")


func _test_room_entry_keeps_team_rules() -> void:
	app.set("screen", "lobby")
	app.call("_handle_nav", (app.call("_nav_rect", 4) as Rect2).get_center())
	_expect_equal(String(app.get("screen")), "room", "bottom navigation still opens the room page")
	app.set("room_fill_with_ai", true)
	app.call("_start_multiplayer_match", "2v2_crossroads", 2)
	_expect_false(bool(app.get("multiplayer_free_for_all")), "room match keeps team mode")
	_expect_true(bool(app.call("_are_allies", 1, 2)), "room teammates remain allies")
	app.call("_return_to_lobby")
	_expect_equal(String(app.get("screen")), "room", "room match returns to the room page")


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
