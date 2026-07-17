extends Node

const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")
const RoomRegistry = preload("res://scripts/network/room_registry.gd")

var failures = 0
var server_scope: Node
var host_scope: Node
var guest_scope: Node
var server: Node
var host: Node
var guest: Node
var host_command: Dictionary = {}
var guest_authority_snapshot: Dictionary = {}
var guest_host_only_failure = false
const DEVICE_TEST_DIR = "user://tests/device_auth_transport"


func _ready() -> void:
	call_deferred("_run_loopback_test")


func _run_loopback_test() -> void:
	_cleanup_device_credentials()
	server_scope = _create_endpoint_scope("ServerEndpoint")
	host_scope = _create_endpoint_scope("HostEndpoint")
	guest_scope = _create_endpoint_scope("GuestEndpoint")
	server = _add_online_room(server_scope)
	host = _add_online_room(host_scope, "host")
	guest = _add_online_room(guest_scope, "guest")

	var port = 26000 + posmod(OS.get_process_id(), 3000)
	_expect_equal(
		int(server.call("start_server", "127.0.0.1", port, RoomRegistry.new(12345), 8)),
		OK,
		"loopback server starts"
	)
	_expect_equal(
		int(host.call("connect_to_server", "127.0.0.1", port, "房主")),
		OK,
		"host begins connecting"
	)
	_expect_equal(
		int(guest.call("connect_to_server", "127.0.0.1", port, "访客")),
		OK,
		"guest begins connecting"
	)
	_expect_true(
		await _wait_until(func(): return bool(host.call("is_connected_to_server")) and bool(guest.call("is_connected_to_server"))),
		"both clients connect through ENet loopback"
	)
	_expect_true(
		await _wait_until(func(): return not String(host.get("current_user_id")).is_empty() and not String(guest.get("current_user_id")).is_empty()),
		"first connection automatically creates and logs in both device accounts"
	)
	_expect_true(
		FileAccess.file_exists(DEVICE_TEST_DIR + "/host.json") and FileAccess.file_exists(DEVICE_TEST_DIR + "/guest.json"),
		"clients persist installation ids and refresh tokens"
	)
	_expect_true(bool(host.call("has_saved_login")) and bool(guest.call("has_saved_login")), "persisted client credentials are eligible for startup auto-login")
	_expect_true(String(host.get("current_user_id")) != String(guest.get("current_user_id")), "different installations receive different user ids")
	var host_original_user_id = String(host.get("current_user_id"))
	host.call("request_account_summaries")
	_expect_true(
		await _wait_until(func(): return (host.get("current_account_summaries") as Array).size() == 1),
		"host receives the full account list for its installation"
	)
	host.call("create_new_account")
	_expect_true(
		await _wait_until(func(): return String(host.get("current_user_id")) != host_original_user_id),
		"host switches to the newly created account"
	)
	_expect_true(
		(host.get("current_account_summaries") as Array).size() == 2,
		"new account remains available in the transport account list"
	)
	host.call("switch_account", host_original_user_id)
	_expect_true(
		await _wait_until(func(): return String(host.get("current_user_id")) == host_original_user_id),
		"host can switch back to the original account through ENet"
	)

	_expect_true(bool(host.call("create_room", "房主", 1, {"fill_with_ai": false})), "host sends create request")
	_expect_true(
		await _wait_until(func(): return not (host.get("current_room_snapshot") as Dictionary).is_empty()),
		"host receives reliable full room snapshot"
	)
	var room_code = String((host.get("current_room_snapshot") as Dictionary).get("room_code", ""))
	_expect_true(room_code.length() == 6, "server creates a six-digit room code")

	_expect_true(bool(guest.call("join_room", room_code, "访客")), "guest sends join request")
	_expect_true(
		await _wait_until(func(): return int((host.get("current_room_snapshot") as Dictionary).get("human_count", 0)) == 2 and int((guest.get("current_room_snapshot") as Dictionary).get("human_count", 0)) == 2),
		"join broadcasts a complete snapshot to every room member"
	)
	_expect_equal(
		String((guest.get("current_room_snapshot") as Dictionary).get("room_code", "")),
		room_code,
		"guest joins the requested internet room"
	)
	_expect_true(
		int((host.get("current_room_snapshot") as Dictionary).get("local_team_id", 0)) != int((guest.get("current_room_snapshot") as Dictionary).get("local_team_id", 0)),
		"server assigns distinct player slots"
	)
	for slot_value in (host.get("current_room_snapshot") as Dictionary).get("slots", []):
		if typeof(slot_value) == TYPE_DICTIONARY and String((slot_value as Dictionary).get("kind", "")) == "human":
			_expect_true(String((slot_value as Dictionary).get("rank_key", "")).length() > 0, "room snapshot includes each human player's rank tier")
			_expect_true(int((slot_value as Dictionary).get("rank_stars", 0)) > 0, "room snapshot includes each human player's rank stars")
			_expect_true(typeof((slot_value as Dictionary).get("deck", null)) == TYPE_ARRAY, "room snapshot includes each human player's deck")
			_expect_true(typeof((slot_value as Dictionary).get("card_levels", null)) == TYPE_DICTIONARY, "room snapshot includes each human player's card levels")

	guest.operation_failed.connect(func(operation: String, _error: String):
		if operation == "update_room_options":
			guest_host_only_failure = true
	)
	guest.call("update_room_options", {"players_per_side": 2})
	_expect_true(
		await _wait_until(func(): return guest_host_only_failure),
		"server derives remote sender id and rejects guest host operations"
	)

	host.call("set_ready", true)
	guest.call("set_ready", true)
	_expect_true(
		await _wait_until(func(): return bool((host.get("current_room_snapshot") as Dictionary).get("can_start", false))),
		"ready changes are reliably synchronized"
	)
	host.call("start_room")
	_expect_true(
		await _wait_until(func(): return not (host.get("current_match") as Dictionary).is_empty() and not (guest.get("current_match") as Dictionary).is_empty()),
		"host starts one synchronized match for the room"
	)
	var host_match: Dictionary = host.get("current_match")
	var guest_match: Dictionary = guest.get("current_match")
	_expect_equal(String(host_match.get("match_id", "")), String(guest_match.get("match_id", "")), "all clients receive the same match id")
	_expect_equal(String(host_match.get("map_id", "")), String(guest_match.get("map_id", "")), "all clients receive the same map id")
	_expect_true(int(host_match.get("match_seed", 0)) != 0, "server publishes a nonzero match seed")
	_expect_equal(int(host_match.get("match_seed", 0)), int(guest_match.get("match_seed", -1)), "all clients receive the same match seed")
	_expect_true(bool(host_match.get("is_authority", false)), "room host is the battle authority")
	_expect_false(bool(guest_match.get("is_authority", true)), "guest is not the battle authority")
	var host_team = int(host_match.get("local_team_id", 0))
	var guest_team = int(guest_match.get("local_team_id", 0))
	_expect_true(host_team in [1, 4] and guest_team in [1, 4] and host_team != guest_team, "server randomizes distinct active spawn slots")

	host.battle_command_received.connect(func(envelope: Dictionary): host_command = envelope)
	guest.call("send_battle_command", {"type": "unlock", "cell": Vector2i(2, 3)})
	_expect_true(
		await _wait_until(func(): return not host_command.is_empty()),
		"reliable battle command reaches the host authority"
	)
	_expect_equal(int(host_command.get("sender_peer_id", 0)), int(guest.call("local_peer_id")), "server stamps the authenticated sender peer")
	_expect_equal(int(host_command.get("sender_team_id", 0)), guest_team, "server stamps the randomized sender team from registry assignment")

	guest.authority_snapshot_received.connect(func(envelope: Dictionary): guest_authority_snapshot = envelope)
	host.call("send_authority_snapshot", {"sequence": 1, "tick": 12, "units": []})
	_expect_true(
		await _wait_until(func(): return not guest_authority_snapshot.is_empty()),
		"reliable authority snapshot reaches the guest"
	)
	_expect_equal(int(guest_authority_snapshot.get("sequence", 0)), 1, "authority snapshot preserves sequence")

	var accepted_snapshot_sequence = int(guest_authority_snapshot.get("sequence", 0))
	guest.rpc_id(1, "_rpc_submit_authority_snapshot", {"sequence": 99, "forged": true})
	await _wait_frames(12)
	_expect_equal(
		int(guest_authority_snapshot.get("sequence", 0)),
		accepted_snapshot_sequence,
		"server rejects a forged non-authority snapshot"
	)

	host.call("leave_room")
	_expect_true(
		await _wait_until(func(): return (host.get("current_room_snapshot") as Dictionary).is_empty() and int((guest.get("current_room_snapshot") as Dictionary).get("human_count", 0)) == 1 and bool((guest.get("current_match") as Dictionary).get("is_authority", false))),
		"host departure promotes the remaining client to battle authority"
	)
	guest.call("leave_room")
	_expect_true(
		await _wait_until(func(): return (guest.get("current_room_snapshot") as Dictionary).is_empty()),
		"last player can close the first room"
	)
	await _test_ai_filled_room_size(2)
	await _test_ai_filled_room_size(3)

	server.call("stop_transport")
	host.call("stop_transport")
	guest.call("stop_transport")
	server_scope.queue_free()
	host_scope.queue_free()
	guest_scope.queue_free()
	await get_tree().process_frame
	_cleanup_device_credentials()
	if failures == 0:
		print("Online room ENet loopback tests passed.")
	get_tree().quit(failures)


func _test_ai_filled_room_size(players_per_side: int) -> void:
	var requested_map_id = "%dv%d_crossroads" % [players_per_side, players_per_side]
	host.call("create_room", "房主", players_per_side, {
		"fill_with_ai": true,
		"map_id": requested_map_id,
	})
	_expect_true(
		await _wait_until(func(): return int((host.get("current_room_snapshot") as Dictionary).get("capacity", 0)) == players_per_side * 2),
		"%dV%d room is created through the transport" % [players_per_side, players_per_side]
	)
	host.call("set_ready", true)
	_expect_true(
		await _wait_until(func(): return bool((host.get("current_room_snapshot") as Dictionary).get("can_start", false))),
		"%dV%d AI-filled room becomes startable" % [players_per_side, players_per_side]
	)
	host.call("start_room")
	_expect_true(
		await _wait_until(func(): return int((host.get("current_match") as Dictionary).get("players_per_side", 0)) == players_per_side),
		"%dV%d room receives a match payload" % [players_per_side, players_per_side]
	)
	_expect_equal(
		String((host.get("current_match") as Dictionary).get("map_id", "")),
		requested_map_id,
		"%dV%d room keeps the host-selected map" % [players_per_side, players_per_side]
	)
	host.call("leave_room")
	_expect_true(
		await _wait_until(func(): return (host.get("current_room_snapshot") as Dictionary).is_empty()),
		"%dV%d room closes cleanly" % [players_per_side, players_per_side]
	)


func _create_endpoint_scope(scope_name: String) -> Node:
	var scope = Node.new()
	scope.name = scope_name
	add_child(scope)
	get_tree().set_multiplayer(SceneMultiplayer.new(), scope.get_path())
	return scope


func _add_online_room(scope: Node, credential_name: String = "") -> Node:
	var endpoint = OnlineRoomTransport.new()
	endpoint.name = "OnlineRoom"
	if not credential_name.is_empty():
		endpoint.set("_device_credential_path", DEVICE_TEST_DIR + "/%s.json" % credential_name)
	scope.add_child(endpoint)
	return endpoint


func _cleanup_device_credentials() -> void:
	for credential_name in ["host", "guest"]:
		var path = DEVICE_TEST_DIR + "/%s.json" % credential_name
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _wait_until(condition: Callable, max_frames: int = 360) -> bool:
	for _index in range(max_frames):
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return false


func _wait_frames(frame_count: int) -> void:
	for _index in range(frame_count):
		await get_tree().process_frame


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
