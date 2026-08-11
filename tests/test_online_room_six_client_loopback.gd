extends Node

const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")
const RoomRegistry = preload("res://scripts/network/room_registry.gd")

var failures = 0
var server_scope: Node
var server: Node
var client_scopes: Array = []
var clients: Array = []
var received_command_teams: Dictionary = {}
var received_snapshot_peers: Dictionary = {}


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	server_scope = _create_endpoint_scope("SixClientServer")
	server = _add_online_room(server_scope)
	var port = 29000 + posmod(OS.get_process_id(), 2000)
	_expect_equal(
		int(server.call("start_server", "127.0.0.1", port, RoomRegistry.new(67890), 8)),
		OK,
		"six-client server starts"
	)

	for index in range(6):
		var scope = _create_endpoint_scope("SixClient%d" % (index + 1))
		var client = _add_online_room(scope)
		client_scopes.append(scope)
		clients.append(client)
		_expect_equal(
			int(client.call("connect_to_server", "127.0.0.1", port, "Player%d" % (index + 1))),
			OK,
			"client %d begins connecting" % (index + 1)
		)
	_expect_true(
		await _wait_until(func(): return _all_clients_connected()),
		"all six human clients connect through ENet"
	)

	var host: Node = clients[0]
	_expect_true(
		bool(host.call("create_room", "Player1", 3, {"fill_with_ai": false, "map_id": "3v3_crossroads"})),
		"host requests a human-only 3V3 room"
	)
	_expect_true(
		await _wait_until(func(): return int((host.get("current_room_snapshot") as Dictionary).get("capacity", 0)) == 6),
		"server creates a six-slot 3V3 room"
	)
	var room_code = String((host.get("current_room_snapshot") as Dictionary).get("room_code", ""))
	_expect_equal(room_code.length(), 6, "3V3 room uses a six-digit code")

	for index in range(1, clients.size()):
		_expect_true(
			bool(clients[index].call("join_room", room_code, "Player%d" % (index + 1))),
			"client %d sends a join request" % (index + 1)
		)
	_expect_true(
		await _wait_until(func(): return _all_clients_have_human_count(6)),
		"all six human players join the same internet room"
	)

	var assigned_teams: Dictionary = {}
	for client in clients:
		assigned_teams[int((client.get("current_room_snapshot") as Dictionary).get("local_team_id", 0))] = true
	_expect_equal(assigned_teams.size(), 6, "server gives every human a distinct team slot")
	for team_id in [1, 2, 3, 4, 5, 6]:
		_expect_true(assigned_teams.has(team_id), "3V3 assigns team slot %d" % team_id)

	for client in clients:
		client.call("set_ready", true)
	_expect_true(
		await _wait_until(func(): return bool((host.get("current_room_snapshot") as Dictionary).get("can_start", false))),
		"six ready humans make the room startable"
	)
	host.call("start_room")
	_expect_true(
		await _wait_until(func(): return _all_clients_have_match()),
		"all six clients receive the 3V3 match start"
	)
	var match_id = String((host.get("current_match") as Dictionary).get("match_id", ""))
	var match_seed = int((host.get("current_match") as Dictionary).get("match_seed", 0))
	_expect_true(match_seed != 0, "3V3 server publishes a nonzero match seed")
	for client in clients:
		var match_data: Dictionary = client.get("current_match")
		_expect_equal(String(match_data.get("match_id", "")), match_id, "3V3 match id stays consistent")
		_expect_equal(String(match_data.get("map_id", "")), "3v3_crossroads", "3V3 map stays consistent")
		_expect_equal(int(match_data.get("match_seed", -1)), match_seed, "3V3 match seed stays consistent")
	_expect_true(bool((host.get("current_match") as Dictionary).get("is_authority", false)), "room creator is battle authority")

	host.battle_command_received.connect(_on_host_battle_command)
	for index in range(1, clients.size()):
		clients[index].call("send_battle_command", {"action": "probe", "sequence": index})
	_expect_true(
		await _wait_until(func(): return received_command_teams.size() == 5),
		"commands from all five guests reach the authority"
	)
	for team_id in [2, 3, 4, 5, 6]:
		_expect_true(received_command_teams.has(team_id), "server authenticates command team %d" % team_id)

	for index in range(1, clients.size()):
		clients[index].authority_snapshot_received.connect(_on_guest_snapshot.bind(clients[index]))
	host.call("send_authority_snapshot", {"sequence": 1, "match_id": match_id, "probe": true})
	_expect_true(
		await _wait_until(func(): return received_snapshot_peers.size() == 5),
		"one reliable authority snapshot reaches all five guests"
	)

	for index in range(clients.size() - 1, 0, -1):
		clients[index].call("leave_room")
		_expect_true(
			await _wait_until(func(): return (clients[index].get("current_room_snapshot") as Dictionary).is_empty()),
			"client %d leaves the running room cleanly" % (index + 1)
		)
	host.call("leave_room")
	_expect_true(
		await _wait_until(func(): return (host.get("current_room_snapshot") as Dictionary).is_empty()),
		"last player closes the 3V3 room"
	)

	for client in clients:
		client.call("stop_transport")
	server.call("stop_transport")
	for scope in client_scopes:
		scope.queue_free()
	server_scope.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("Online six-human 3V3 ENet loopback tests passed.")
	get_tree().quit(failures)


func _on_host_battle_command(envelope: Dictionary) -> void:
	received_command_teams[int(envelope.get("sender_team_id", 0))] = true


func _on_guest_snapshot(_envelope: Dictionary, client: Node) -> void:
	received_snapshot_peers[int(client.call("local_peer_id"))] = true


func _all_clients_connected() -> bool:
	for client in clients:
		if not bool(client.call("is_connected_to_server")):
			return false
	return true


func _all_clients_have_human_count(expected_count: int) -> bool:
	for client in clients:
		if int((client.get("current_room_snapshot") as Dictionary).get("human_count", 0)) != expected_count:
			return false
	return true


func _all_clients_have_match() -> bool:
	for client in clients:
		if int((client.get("current_match") as Dictionary).get("players_per_side", 0)) != 3:
			return false
	return true


func _create_endpoint_scope(scope_name: String) -> Node:
	var scope = Node.new()
	scope.name = scope_name
	add_child(scope)
	get_tree().set_multiplayer(SceneMultiplayer.new(), scope.get_path())
	return scope


func _add_online_room(scope: Node) -> Node:
	var endpoint = OnlineRoomTransport.new()
	endpoint.name = "OnlineRoom"
	scope.add_child(endpoint)
	return endpoint


func _wait_until(condition: Callable, max_frames: int = 600) -> bool:
	for _index in range(max_frames):
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return false


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
