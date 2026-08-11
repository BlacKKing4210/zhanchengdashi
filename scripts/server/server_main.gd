extends Node

const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")

var online_room: Node


func _ready() -> void:
	call_deferred("_start_room_server")


func _exit_tree() -> void:
	if is_instance_valid(online_room) and online_room.has_method("stop_transport"):
		online_room.call("stop_transport")


func _start_room_server() -> void:
	online_room = get_node_or_null("/root/OnlineRoom")
	if online_room == null:
		online_room = OnlineRoomTransport.new()
		online_room.name = "OnlineRoom"
		get_tree().root.add_child(online_room)
	elif bool(online_room.call("is_server_running")):
		_print_listening_status(_max_clients_from_environment_and_cli())
		return

	var max_clients = _max_clients_from_environment_and_cli()
	var error = int(online_room.call(
		"start_server",
		online_room.call("default_bind_host"),
		online_room.call("default_server_port"),
		null,
		max_clients
	))
	if error != OK:
		push_error("Internet room server failed to start (error %d)." % error)
		get_tree().quit(error)
		return
	_print_listening_status(max_clients)


func _print_listening_status(max_clients: int) -> void:
	print(
		"Internet room server listening on UDP %s:%d (max clients: %d)." % [
			online_room.get("bind_host"),
			int(online_room.get("server_port")),
			max_clients,
		]
	)


func _max_clients_from_environment_and_cli() -> int:
	if is_instance_valid(online_room) and online_room.has_method("default_max_clients"):
		return int(online_room.call("default_max_clients"))
	return OnlineRoomTransport.DEFAULT_MAX_CLIENTS
