extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	app.set("battle_mode", "classic")
	app.call("_reset_battle")
	_test_classic_initial_state()
	_test_classic_base_results()
	if failures == 0:
		print("Classic battle regression tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_classic_initial_state() -> void:
	var tiles: Dictionary = app.get("tiles")
	_expect_equal(tiles.size(), BoardRules.GRID_COLS * BoardRules.GRID_ROWS, "classic board keeps original dimensions")
	_expect_equal(int(app.get("gold")), 60, "classic player starts with 60 gold")
	_expect_equal(int(app.get("enemy_gold")), 60, "classic enemy starts with 60 gold")
	_expect_equal(float(app.get("battle_timer")), 180.0, "classic battle keeps 180 second timer")
	_expect_base(tiles, BoardRules.PLAYER_BASE, BoardRules.PLAYER, "player")
	_expect_base(tiles, BoardRules.ENEMY_BASE, BoardRules.ENEMY, "enemy")


func _test_classic_base_results() -> void:
	app.call("_damage_tile", BoardRules.ENEMY_BASE, BoardRules.PLAYER, 999999.0)
	_expect_true(bool(app.get("game_over")), "destroying enemy base ends classic battle")
	_expect_equal(String(app.get("result_text")), "胜利", "destroying enemy base remains a win")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 3, "classic win keeps three-ticket reward")

	app.set("battle_mode", "classic")
	app.call("_reset_battle")
	app.call("_damage_tile", BoardRules.PLAYER_BASE, BoardRules.ENEMY, 999999.0)
	_expect_true(bool(app.get("game_over")), "destroying player base ends classic battle")
	_expect_equal(String(app.get("result_text")), "失败", "destroying player base remains a loss")
	_expect_equal(int(app.get("last_battle_reward_tickets")), 1, "classic loss keeps one-ticket reward")


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
