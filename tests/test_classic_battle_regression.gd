extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_all_classic_maps()
	_test_random_classic_selection()
	_test_classic_camera_drag()
	_test_tower_price_progression()
	_test_classic_base_results()
	if failures == 0:
		print("Classic battle regression tests passed for five random-map variants.")
	app.queue_free()
	get_tree().quit(failures)


func _test_all_classic_maps() -> void:
	for map_id in MultiplayerRules.map_ids_for_size(1):
		app.call("_start_match", map_id)
		var tiles: Dictionary = app.get("tiles")
		var base_keys: Dictionary = app.get("classic_base_keys")
		_expect_equal(String(app.get("classic_map_id")), String(map_id), "%s is selected for classic play" % map_id)
		_expect_equal(tiles.size(), 75, "%s keeps the full 1v1 board" % map_id)
		_expect_equal(_territory_count(tiles, BoardRules.PLAYER), 36, "%s gives the player 36 cells" % map_id)
		_expect_equal(_territory_count(tiles, BoardRules.ENEMY), 36, "%s gives the enemy 36 cells" % map_id)
		_expect_equal(int(app.get("gold")), 60, "%s keeps player starting gold" % map_id)
		_expect_equal(int(app.get("enemy_gold")), 60, "%s keeps enemy starting gold" % map_id)
		_expect_equal(float(app.get("battle_timer")), 180.0, "%s keeps the classic timer" % map_id)
		_expect_base(tiles, base_keys.get(BoardRules.PLAYER, MultiplayerRules.INVALID_KEY), BoardRules.PLAYER, "%s player" % map_id)
		_expect_base(tiles, base_keys.get(BoardRules.ENEMY, MultiplayerRules.INVALID_KEY), BoardRules.ENEMY, "%s enemy" % map_id)
		var player_base: Vector2i = base_keys.get(BoardRules.PLAYER, MultiplayerRules.INVALID_KEY)
		var player_base_canvas: Vector2 = app.call("_world_to_canvas", app.call("_hex_center", player_base))
		_expect_true((app.call("_battle_view_rect") as Rect2).has_point(player_base_canvas), "%s opens with the player base visible" % map_id)


func _test_random_classic_selection() -> void:
	app.call("_start_match")
	_expect_true(String(app.get("classic_map_id")) in MultiplayerRules.map_ids_for_size(1), "normal classic start only selects from the five 1v1 maps")


func _test_classic_camera_drag() -> void:
	app.call("_start_match", "1v1_crossroads")
	app.call("_layout", app.get_viewport().get_visible_rect().size)
	var pan_before: Vector2 = app.get("board_pan")
	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	var start = offset + Vector2(360, 520) * scale
	var delta = Vector2(-40, 0) * scale
	app.call("_begin_board_pointer", start)
	app.call("_move_board_pointer", start + delta, delta)
	app.call("_end_board_pointer", start + delta)
	_expect_true(Vector2(app.get("board_pan")).distance_to(pan_before) > 0.1, "classic 1v1 map can be dragged inside the battle viewport")


func _test_tower_price_progression() -> void:
	app.call("_start_match", "1v1_plateau")
	app.set("gold", 1000)
	var tiles: Dictionary = app.get("tiles")
	var base: Vector2i = (app.get("classic_base_keys") as Dictionary).get(BoardRules.PLAYER, MultiplayerRules.INVALID_KEY)
	var first = _force_connected_tower_site(tiles, base, [])
	app.set("tiles", tiles)
	_expect_equal(int(app.call("_unlock_cost", first, BoardRules.PLAYER)), 50, "first player tower costs 50")
	_expect_true(bool(app.call("_try_unlock", first)), "first tower purchase is handled")
	_expect_equal(String((app.get("tiles") as Dictionary)[first].get("building", "")), "tower", "first purchase creates a tower")
	_expect_equal(int(app.get("gold")), 950, "first tower deducts 50 gold")

	tiles = app.get("tiles")
	var second = _force_connected_tower_site(tiles, first, [base])
	app.set("tiles", tiles)
	_expect_equal(int(app.call("_unlock_cost", second, BoardRules.PLAYER)), 100, "second player tower costs 100")
	_expect_true(bool(app.call("_try_unlock", second)), "second tower purchase is handled")
	_expect_equal(int(app.get("gold")), 850, "second tower deducts 100 gold")

	tiles = app.get("tiles")
	var third = _force_connected_tower_site(tiles, second, [base, first])
	app.set("tiles", tiles)
	_expect_equal(int(app.call("_unlock_cost", third, BoardRules.PLAYER)), 150, "third player tower is priced at 150")
	_expect_equal(int(app.call("_unlock_cost", third, BoardRules.ENEMY)), 50, "enemy tower progression remains independent")


func _test_classic_base_results() -> void:
	app.call("_start_match", "1v1_diamond")
	var base_keys: Dictionary = app.get("classic_base_keys")
	app.call("_damage_tile", base_keys.get(BoardRules.ENEMY, MultiplayerRules.INVALID_KEY), BoardRules.PLAYER, 999999.0)
	_expect_true(bool(app.get("game_over")), "destroying enemy base ends classic battle")
	_expect_equal(String(app.get("result_text")), "胜利", "destroying enemy base remains a win")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 3, "classic win keeps three-ticket reward")
	_expect_equal((app.get("result_player_entries") as Array).size(), 2, "classic settlement lists both players")
	_expect_equal((app.call("_result_other_entries") as Array).size(), 1, "classic opponent appears below the fixed local row")

	app.call("_start_match", "1v1_diamond")
	base_keys = app.get("classic_base_keys")
	app.call("_damage_tile", base_keys.get(BoardRules.PLAYER, MultiplayerRules.INVALID_KEY), BoardRules.ENEMY, 999999.0)
	_expect_true(bool(app.get("game_over")), "destroying player base ends classic battle")
	_expect_equal(String(app.get("result_text")), "失败", "destroying player base remains a loss")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 1, "classic loss keeps one-ticket reward")


func _force_connected_tower_site(tiles: Dictionary, connected_key: Vector2i, excluded: Array) -> Vector2i:
	for key in MultiplayerRules.neighbors(tiles, connected_key):
		if key in excluded or int(tiles[key].get("territory_team", BoardRules.NEUTRAL)) != BoardRules.PLAYER:
			continue
		if String(tiles[key].get("building", "")) != "":
			continue
		var tile = BoardRules.empty_locked_tile()
		tile["territory_team"] = BoardRules.PLAYER
		tile["site"] = "tower"
		tile["site_cost"] = 50
		tiles[key] = tile
		return key
	push_error("tower test could not find a connected player tile")
	return MultiplayerRules.INVALID_KEY


func _territory_count(tiles: Dictionary, team: int) -> int:
	var count = 0
	for tile in tiles.values():
		if int(tile.get("territory_team", BoardRules.NEUTRAL)) == team:
			count += 1
	return count


func _expect_base(tiles: Dictionary, key: Vector2i, team: int, label: String) -> void:
	_expect_true(tiles.has(key), "%s base tile exists" % label)
	if not tiles.has(key):
		return
	var tile = tiles[key]
	_expect_equal(int(tile.get("team", BoardRules.NEUTRAL)), team, "%s base keeps its team" % label)
	_expect_equal(String(tile.get("building", "")), "base", "%s base keeps base building" % label)
	_expect_true(float(tile.get("hp", 0.0)) > 0.0, "%s base starts alive" % label)


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
