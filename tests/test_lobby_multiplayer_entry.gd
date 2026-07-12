extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	app.call("_layout", app.get_viewport().get_visible_rect().size)
	app.set("screen", "lobby")
	var button: Rect2 = app.call("_multiplayer_start_rect")
	var badge: Rect2 = app.call("_multiplayer_reward_badge_rect")
	_expect_true(button.encloses(badge), "reward badge stays inside the multiplayer button")
	_expect_true(badge.get_center().x > button.get_center().x and badge.get_center().y < button.get_center().y, "reward badge anchors to the upper-right corner")

	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	app.call("_handle_tap", offset + badge.get_center() * scale)
	_expect_equal(String(app.get("screen")), "battle", "lobby multiplayer button starts battle directly")
	_expect_equal(String(app.get("battle_mode")), "multiplayer", "lobby multiplayer button uses multiplayer battle mode")
	_expect_equal(int(app.call("_multiplayer_alive_count")), MultiplayerRules.TEAM_IDS.size(), "all six players start alive")

	var player_base = MultiplayerRules.base_key(BoardRules.PLAYER)
	var tiles: Dictionary = app.get("tiles")
	_expect_true(tiles.has(player_base), "local player base exists")
	if tiles.has(player_base):
		var hp_before = float(tiles[player_base].get("hp", 0.0))
		app.call("_damage_tile", player_base, 2, 1.0)
		var hp_after = float((app.get("tiles") as Dictionary)[player_base].get("hp", 0.0))
		_expect_true(hp_after < hp_before, "different players are enemies in the lobby multiplayer match")

	app.call("_return_to_lobby")
	_expect_equal(String(app.get("screen")), "lobby", "lobby multiplayer result returns to the lobby")
	if failures == 0:
		print("Lobby multiplayer entry tests passed.")
	app.queue_free()
	get_tree().quit(failures)


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
