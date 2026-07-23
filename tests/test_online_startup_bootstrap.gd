extends Node

const MainApp = preload("res://scripts/app/main.gd")


class FakeOnlineRoom:
	extends Node

	var connection_attempts = 0


	func is_connected_to_server() -> bool:
		return false


	func connect_to_server(_host: String, _port: int, _player_name: String) -> Error:
		connection_attempts += 1
		return OK


var failures = 0


func _ready() -> void:
	var app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	var original_room = app.get("online_room_service")
	var fake_room = FakeOnlineRoom.new()
	app.set("online_room_service", fake_room)
	app.set("online_connection_state", "offline")
	app.set("startup_auto_connect_test_enabled", true)
	app.call("_auto_login_saved_account_on_startup")
	_expect(fake_room.connection_attempts == 1, "startup connects without depending on current_scene identity")
	_expect(bool(app.get("online_auto_connect_enabled")), "startup enables bounded reconnect behavior")
	app.set("online_auto_connect_enabled", false)
	app.set("online_room_service", original_room)
	app.queue_free()
	if failures == 0:
		print("ONLINE_STARTUP_BOOTSTRAP_TEST_PASS")
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
