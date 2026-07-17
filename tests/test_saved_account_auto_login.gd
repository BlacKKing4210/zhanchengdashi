extends Node

const MainApp = preload("res://scripts/app/main.gd")
const RankingRules = preload("res://scripts/app/systems/ranking_rules.gd")

var failures = 0


class FakeOnlineRoom:
	extends Node
	var saved_login = false
	var connect_calls = 0

	func has_saved_login() -> bool:
		return saved_login

	func is_connected_to_server() -> bool:
		return false

	func connect_to_server(_host: String, _port: int, _display_name: String) -> int:
		connect_calls += 1
		return OK


func _ready() -> void:
	var app = MainApp.new()
	app.set("rank_db", {"player": RankingRules.default_profile(), "mirrors": {}})
	var fake_online_room = FakeOnlineRoom.new()
	app.set("online_room_service", fake_online_room)
	app.set("online_connection_state", "offline")
	app.call("_auto_login_saved_account")
	_expect_equal(fake_online_room.connect_calls, 0, "startup stays offline when no saved login exists")
	fake_online_room.saved_login = true
	app.call("_auto_login_saved_account")
	_expect_equal(fake_online_room.connect_calls, 1, "startup connects automatically when saved login exists")
	_expect_equal(String(app.get("online_connection_state")), "connecting", "automatic login reports the connection state")
	app.free()
	fake_online_room.free()
	if failures == 0:
		print("Saved account auto-login tests passed.")
	get_tree().quit(failures)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
