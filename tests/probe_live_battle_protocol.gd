extends Node
const Transport = preload("res://scripts/network/online_room.gd")
class ReadOnlyClient extends Transport:
	func _ready() -> void: pass
	func _exit_tree() -> void: pass

func _ready() -> void:
	if not "--read-only-cloud-probe" in OS.get_cmdline_user_args():
		get_tree().quit(0)
		return
	var scope = Node.new()
	add_child(scope)
	get_tree().set_multiplayer(SceneMultiplayer.new(), scope.get_path())
	var endpoint = ReadOnlyClient.new()
	endpoint.name = "OnlineRoom"
	scope.add_child(endpoint)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(endpoint.default_server_host(), endpoint.default_server_port(), 3)
	if error != OK:
		get_tree().quit(1)
		return
	endpoint.multiplayer.multiplayer_peer = peer
	var deadline = Time.get_ticks_msec() + 8000
	while peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		print("READ_ONLY_CLOUD_PROBE connection_failed")
		peer.close()
		get_tree().quit(1)
		return
	var replies: Array = []
	endpoint.operation_failed.connect(func(operation, message): replies.append({"operation": operation, "message": message}))
	# No login, account creation, room creation, active match, or user-data mutation.
	# The deployed service must route this to battle_command and reject no-match.
	endpoint.rpc_id(1, "_rpc_submit_battle_command", {"action": "unlock_tile", "sequence": 1, "q": 0, "r": 0})
	while replies.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	var valid = replies.size() == 1 and replies[0].operation == "battle_command" and replies[0].message == "比赛尚未开始"
	print("READ_ONLY_CLOUD_BUILD_ROUTE_PASS" if valid else "READ_ONLY_CLOUD_BUILD_ROUTE_FAIL", " replies=", JSON.stringify(replies))
	peer.close()
	scope.queue_free()
	get_tree().quit(0 if valid else 1)
