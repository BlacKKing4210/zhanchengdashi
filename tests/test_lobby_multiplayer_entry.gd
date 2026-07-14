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
	var title: Rect2 = app.call("_multiplayer_button_title_rect")
	var badge: Rect2 = app.call("_multiplayer_hot_badge_rect")
	_expect_true(button.encloses(title), "multiplayer title stays inside the button")
	_expect_true(button.intersects(badge), "HOT badge remains attached to the multiplayer button")
	_expect_true(badge.get_center().x > button.get_center().x, "HOT badge sits on the button's right side")
	_expect_true(badge.get_center().y < button.get_center().y, "HOT badge sits on the button's upper edge")

	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	var badge_click = button.intersection(badge).get_center()
	app.call("_handle_tap", offset + badge_click * scale)
	_expect_equal(String(app.get("screen")), "battle", "lobby multiplayer button starts a battle directly")
	_expect_equal(String(app.get("battle_mode")), "multiplayer", "lobby multiplayer button uses multiplayer battle rules")
	_expect_true(bool(app.get("multiplayer_free_for_all")), "lobby multiplayer button enables six-player free-for-all rules")
	_expect_equal(app.get("room_active_team_ids"), MultiplayerRules.TEAM_IDS, "lobby multiplayer battle activates all six teams")
	for first_team in MultiplayerRules.TEAM_IDS:
		for second_team in MultiplayerRules.TEAM_IDS:
			if first_team == second_team:
				continue
			_expect_true(not bool(app.call("_are_allies", first_team, second_team)), "free-for-all teams %d and %d are enemies" % [first_team, second_team])

	app.call("_return_to_lobby")
	_expect_equal(String(app.get("screen")), "lobby", "free-for-all returns to the lobby")
	app.call("_handle_nav", (app.call("_nav_rect", 4) as Rect2).get_center())
	_expect_equal(String(app.get("screen")), "room", "bottom room tab remains the internet room entry")
	_expect_true(app.get("online_room_service") != null, "internet room transport remains available through the room tab")
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
