extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	app.call("_start_multiplayer_match")
	_test_initial_state()
	_test_board_input_guards()
	_test_drag_threshold()
	_test_attack_orders()
	_test_unit_cap()
	_test_runtime_smoke()
	_test_first_place_rewards()
	_test_sixth_place_rewards()
	if failures == 0:
		print("Multiplayer integration tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_initial_state() -> void:
	var tiles: Dictionary = app.get("tiles")
	_expect_equal(String(app.get("battle_mode")), "multiplayer", "multiplayer mode starts")
	_expect_equal(tiles.size(), 1141, "multiplayer integration creates full board")
	_expect_equal(float(app.get("battle_timer")), 300.0, "multiplayer integration uses five-minute timer")
	_expect_equal(int(app.call("_multiplayer_alive_count")), 6, "all six players start alive")
	var local_base_center: Vector2 = app.call("_hex_center", MultiplayerRules.base_key(BoardRules.PLAYER))
	_expect_true((app.call("_battle_view_rect") as Rect2).has_point(local_base_center), "initial camera keeps local base in battle view")
	for team in MultiplayerRules.TEAM_IDS:
		var base = MultiplayerRules.base_key(team)
		_expect_equal(String(tiles[base].get("building", "")), "base", "team %d base exists" % team)
		_expect_equal(int(tiles[base].get("team", BoardRules.NEUTRAL)), team, "team %d owns its base" % team)


func _test_board_input_guards() -> void:
	var viewport_size = app.get_viewport().get_visible_rect().size
	app.call("_layout", viewport_size)
	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	app.call("_handle_tap", offset + Vector2(360, 40) * scale)
	_expect_false((app.get("multiplayer_attack_orders") as Dictionary).has(BoardRules.PLAYER), "top status click does not issue map order")
	_expect_equal(app.get("selected_tile"), MultiplayerRules.INVALID_KEY, "top status click does not select hidden map tile")


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


func _test_attack_orders() -> void:
	var first_target = MultiplayerRules.base_key(2)
	_expect_true(bool(app.call("_try_issue_attack_order", BoardRules.PLAYER, first_target)), "player can order an enemy base attack")
	var orders: Dictionary = app.get("multiplayer_attack_orders")
	_expect_equal(orders.get(BoardRules.PLAYER), first_target, "enemy base becomes active attack order")
	_expect_equal(float((app.get("multiplayer_attack_cooldowns") as Dictionary).get(BoardRules.PLAYER, 0.0)), 3.0, "attack order starts three-second cooldown")
	var blocked_target = MultiplayerRules.base_key(3)
	_expect_true(bool(app.call("_try_issue_attack_order", BoardRules.PLAYER, blocked_target)), "cooldown consumes repeated target click")
	_expect_equal(orders.get(BoardRules.PLAYER), first_target, "cooldown preserves previous target")

	app.call("_update_attack_order_cooldowns", 1.25)
	_expect_equal(float((app.get("multiplayer_attack_cooldowns") as Dictionary).get(BoardRules.PLAYER, 0.0)), 1.75, "attack cooldown counts down")
	app.call("_update_attack_order_cooldowns", 1.75)
	_expect_equal(float((app.get("multiplayer_attack_cooldowns") as Dictionary).get(BoardRules.PLAYER, 0.0)), 0.0, "attack cooldown reaches zero")
	_expect_true(bool(app.call("_try_issue_attack_order", BoardRules.PLAYER, Vector2i.ZERO)), "player can order a neutral region advance")
	var player_base_pos = MultiplayerRules.hex_center(MultiplayerRules.base_key(BoardRules.PLAYER), app.get("board_origin"), 43.0)
	var target: Dictionary = app.call("_ordered_combat_target", player_base_pos, BoardRules.PLAYER, -1)
	_expect_equal(String(target.get("kind", "")), "waypoint", "empty region order becomes a march waypoint")
	_expect_equal(target.get("key", MultiplayerRules.INVALID_KEY), Vector2i.ZERO, "waypoint keeps clicked region")


func _test_unit_cap() -> void:
	var base = MultiplayerRules.base_key(BoardRules.PLAYER)
	for _index in range(20):
		app.call("_spawn_unit", BoardRules.PLAYER, base, "rabbit")
	var player_units = 0
	for unit in app.get("units"):
		if int(unit.get("team", BoardRules.NEUTRAL)) == BoardRules.PLAYER and float(unit.get("hp", 0.0)) > 0.0:
			player_units += 1
	_expect_equal(player_units, 12, "all spawn paths honor twelve-unit team cap")


func _test_runtime_smoke() -> void:
	for _step in range(120):
		app.call("_update_battle", 0.1)
	_expect_true(float(app.get("battle_timer")) <= 288.1, "multiplayer battle advances for twelve seconds")
	for team in MultiplayerRules.TEAM_IDS:
		var alive_units = 0
		for unit in app.get("units"):
			if int(unit.get("team", BoardRules.NEUTRAL)) == team and float(unit.get("hp", 0.0)) > 0.0:
				alive_units += 1
		_expect_true(alive_units <= 12, "team %d remains within unit cap during runtime" % team)


func _test_first_place_rewards() -> void:
	for team in [2, 3, 4, 5, 6]:
		app.call("_eliminate_multiplayer_team", team, BoardRules.PLAYER)
	_expect_true(bool(app.get("game_over")), "last rival elimination ends battle")
	_expect_equal(int(app.get("multiplayer_placement")), 1, "last survivor receives first place")
	_expect_equal(int(app.get("last_multiplayer_star_delta")), 3, "first place receives three stars")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 5, "first place receives five tickets")


func _test_sixth_place_rewards() -> void:
	app.set("battle_mode", "multiplayer")
	app.call("_reset_battle")
	app.call("_eliminate_multiplayer_team", BoardRules.PLAYER, 2)
	_expect_true(bool(app.get("game_over")), "local base elimination ends local battle")
	_expect_equal(int(app.get("multiplayer_placement")), 6, "first player eliminated receives sixth place")
	_expect_equal(int(app.get("last_multiplayer_star_delta")), -1, "sixth place loses one star")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 1, "sixth place receives one ticket")


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
