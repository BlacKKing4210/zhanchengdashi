extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_room_controls()
	await get_tree().process_frame
	app.call("_start_multiplayer_match", "2v2_crossroads", 2)
	await get_tree().process_frame
	_test_initial_state()
	_test_team_palette()
	_test_board_input_guards()
	_test_drag_threshold()
	_test_alliance_targeting_and_damage()
	_test_unit_cap()
	_test_runtime_smoke()
	_test_team_survival_and_loss_rewards()
	_test_win_rewards()
	_test_draw_rewards()
	if failures == 0:
		print("Room-mode integration tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_room_controls() -> void:
	app.call("_layout", app.get_viewport().get_visible_rect().size)
	app.set("screen", "lobby")
	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	var multiplayer_button: Rect2 = app.call("_multiplayer_start_rect")
	app.call("_handle_tap", offset + multiplayer_button.get_center() * scale)
	_expect_equal(String(app.get("screen")), "battle", "lobby multiplayer button starts a six-player battle")
	_expect_true(bool(app.get("multiplayer_free_for_all")), "lobby multiplayer button starts free-for-all rules")
	_expect_equal(app.get("room_active_team_ids"), MultiplayerRules.TEAM_IDS, "lobby multiplayer button activates all six teams")
	app.call("_return_to_lobby")

	app.set("screen", "lobby")
	app.call("_handle_nav", (app.call("_nav_rect", 4) as Rect2).get_center())
	_expect_equal(String(app.get("screen")), "room", "last navigation tab opens room mode")

	app.call("_set_room_size", 3)
	_expect_equal(app.get("room_active_team_ids"), [1, 2, 3, 4, 5, 6], "3v3 activates all fixed room slots")
	_expect_true(bool(app.call("room_accept_invite", "好友甲", "A", 1)), "side A invite fills team two")
	_expect_true(bool(app.call("room_accept_invite", "好友乙", "B", 0)), "side B invite fills team four")
	_expect_equal(String((app.get("room_human_teams") as Dictionary).get(2, "")), "好友甲", "accepted player name is stored in its slot")
	app.set("room_fill_with_ai", false)
	_expect_false(bool(app.call("_room_can_start")), "room cannot start with empty slots when AI fill is off")
	app.set("room_fill_with_ai", true)
	_expect_true(bool(app.call("_room_can_start")), "AI fill allows remaining slots to start")


func _test_initial_state() -> void:
	var tiles: Dictionary = app.get("tiles")
	var base_keys: Dictionary = app.get("room_base_keys")
	_expect_equal(String(app.get("battle_mode")), "multiplayer", "room match uses multiplayer battle mode")
	_expect_equal(String(app.get("room_map_id")), "2v2_crossroads", "explicit room map is selected")
	_expect_equal(app.get("room_active_team_ids"), [1, 2, 4, 5], "2v2 uses fixed side slot ids")
	_expect_true(tiles.size() > 144, "2v2 map keeps all four territories plus a connected neutral frontline")
	_expect_true(float(app.get("battle_timer")) <= 300.0 and float(app.get("battle_timer")) > 299.0, "room battle starts with a five-minute timer")
	_expect_equal(int(app.call("_multiplayer_alive_count")), 4, "all four active slots start alive")
	var local_base: Vector2i = base_keys.get(BoardRules.PLAYER, MultiplayerRules.INVALID_KEY)
	var local_base_center: Vector2 = app.call("_world_to_canvas", app.call("_hex_center", local_base))
	_expect_true((app.call("_battle_view_rect") as Rect2).has_point(local_base_center), "initial camera keeps local base in battle view")
	for team in [1, 2, 4, 5]:
		var base: Vector2i = base_keys.get(team, MultiplayerRules.INVALID_KEY)
		_expect_true(tiles.has(base), "team %d base key exists" % team)
		if not tiles.has(base):
			continue
		_expect_equal(String(tiles[base].get("building", "")), "base", "team %d base exists" % team)
		_expect_equal(int(tiles[base].get("team", BoardRules.NEUTRAL)), team, "team %d owns its base" % team)
		_expect_equal(_territory_count(tiles, team), 36, "team %d receives 36 starting cells" % team)


func _test_team_palette() -> void:
	for team in [1, 2, 3]:
		var color: Color = app.call("_team_color", team)
		_expect_true(color.r > color.b, "warm-side team %d stays visually warm" % team)
		_expect_true(_color_span(color) >= 0.65, "warm-side team %d uses high saturation" % team)
	for team in [4, 5, 6]:
		var color: Color = app.call("_team_color", team)
		_expect_true(color.b > color.r, "cool-side team %d stays visually cool" % team)
		_expect_true(_color_span(color) <= 0.36, "cool-side team %d uses restrained saturation" % team)


func _test_board_input_guards() -> void:
	var viewport_size = app.get_viewport().get_visible_rect().size
	app.call("_layout", viewport_size)
	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	app.call("_handle_tap", offset + Vector2(360, 40) * scale)
	_expect_equal(app.get("selected_tile"), MultiplayerRules.INVALID_KEY, "top status click does not select a hidden map tile")


func _test_drag_threshold() -> void:
	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	var start = offset + Vector2(360, 520) * scale
	app.call("_begin_board_pointer", start)
	app.call("_move_board_pointer", start + Vector2(10, 0) * scale, Vector2(10, 0) * scale)
	app.call("_move_board_pointer", start, Vector2(-10, 0) * scale)
	_expect_false(bool(app.get("board_pointer_dragged")), "small back-and-forth jitter remains a tap")
	app.set("board_pointer_down", false)
	app.call("_begin_board_pointer", start)
	app.call("_move_board_pointer", start + Vector2(13, 0) * scale, Vector2(13, 0) * scale)
	_expect_true(bool(app.get("board_pointer_dragged")), "net movement beyond twelve pixels starts drag")
	app.set("board_pointer_down", false)


func _test_alliance_targeting_and_damage() -> void:
	var tiles: Dictionary = app.get("tiles")
	var base_keys: Dictionary = app.get("room_base_keys")
	app.call("_refresh_combat_building_keys")
	var ally_base: Vector2i = base_keys.get(2, MultiplayerRules.INVALID_KEY)
	var target: Dictionary = app.call("_nearest_combat_target", app.call("_hex_center", ally_base), 2, -1)
	_expect_equal(String(target.get("kind", "")), "building", "automatic targeting still finds an opposing building")
	var target_key: Vector2i = target.get("key", MultiplayerRules.INVALID_KEY)
	var target_team = int(tiles.get(target_key, {}).get("team", BoardRules.NEUTRAL))
	_expect_false(bool(app.call("_are_allies", 2, target_team)), "automatic targeting skips allied bases")

	var player_base: Vector2i = base_keys.get(BoardRules.PLAYER, MultiplayerRules.INVALID_KEY)
	var hp_before = float(tiles[player_base].get("hp", 0.0))
	_expect_false(bool(app.call("_damage_tile", player_base, 2, 999.0)), "allied building damage is rejected")
	var tiles_after: Dictionary = app.get("tiles")
	_expect_equal(float(tiles_after[player_base].get("hp", 0.0)), hp_before, "allied building keeps its health")


func _test_unit_cap() -> void:
	var base: Vector2i = (app.get("room_base_keys") as Dictionary).get(BoardRules.PLAYER, MultiplayerRules.INVALID_KEY)
	for _index in range(20):
		app.call("_spawn_unit", BoardRules.PLAYER, base, "rabbit")
	var player_units = 0
	for unit in app.get("units"):
		if int(unit.get("team", BoardRules.NEUTRAL)) == BoardRules.PLAYER and float(unit.get("hp", 0.0)) > 0.0:
			player_units += 1
	_expect_equal(player_units, 12, "all spawn paths honor the twelve-unit slot cap")


func _test_runtime_smoke() -> void:
	for _step in range(120):
		app.call("_update_battle", 0.1)
	_expect_true(float(app.get("battle_timer")) <= 288.1, "room battle advances for twelve seconds")
	for team in app.get("room_active_team_ids"):
		var alive_units = 0
		for unit in app.get("units"):
			if int(unit.get("team", BoardRules.NEUTRAL)) == int(team) and float(unit.get("hp", 0.0)) > 0.0:
				alive_units += 1
		_expect_true(alive_units <= 12, "team %d remains within unit cap during runtime" % int(team))


func _test_team_survival_and_loss_rewards() -> void:
	app.call("_start_multiplayer_match", "2v2_crossroads", 2)
	app.call("_eliminate_multiplayer_team", BoardRules.PLAYER, 4)
	_expect_false(bool(app.get("game_over")), "local elimination does not end battle while an ally lives")
	app.call("_eliminate_multiplayer_team", 2, 4)
	_expect_true(bool(app.get("game_over")), "battle ends after every local-side base is eliminated")
	_expect_equal(String(app.get("room_result")), "loss", "local side receives a loss")
	_expect_equal(int(app.get("last_multiplayer_star_delta")), -1, "loss removes one star")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 1, "loss receives one ticket")


func _test_win_rewards() -> void:
	app.call("_start_multiplayer_match", "2v2_crossroads", 2)
	app.call("_eliminate_multiplayer_team", 4, BoardRules.PLAYER)
	_expect_false(bool(app.get("game_over")), "one defeated rival does not end a 2v2 battle")
	app.call("_eliminate_multiplayer_team", 5, BoardRules.PLAYER)
	_expect_true(bool(app.get("game_over")), "battle ends after every opposing base is eliminated")
	_expect_equal(String(app.get("room_result")), "win", "local side receives a win")
	_expect_equal(int(app.get("last_multiplayer_star_delta")), 3, "win receives three stars")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 5, "win receives five tickets")


func _test_draw_rewards() -> void:
	app.call("_start_multiplayer_match", "2v2_crossroads", 2)
	app.call("_finish_multiplayer_battle", "draw")
	_expect_equal(String(app.get("room_result")), "draw", "tied room result is recorded")
	_expect_equal(int(app.get("last_multiplayer_star_delta")), 0, "draw keeps star count unchanged")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 2, "draw receives two tickets")


func _territory_count(tiles: Dictionary, team: int) -> int:
	var count = 0
	for tile in tiles.values():
		if int(tile.get("territory_team", BoardRules.NEUTRAL)) == team:
			count += 1
	return count


func _color_span(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))


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
