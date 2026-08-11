extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")
const RoomRegistry = preload("res://scripts/network/room_registry.gd")

var failures = 0
var server_scope: Node
var host_scope: Node
var guest_scope: Node
var server: Node
var host_transport: Node
var guest_transport: Node
var host_game: Node
var guest_game: Node


func _ready() -> void:
	call_deferred("_run_gameplay_loopback")


func _run_gameplay_loopback() -> void:
	server_scope = _create_endpoint_scope("GameplayServer")
	host_scope = _create_endpoint_scope("GameplayHost")
	guest_scope = _create_endpoint_scope("GameplayGuest")
	server = _add_online_room(server_scope)
	host_transport = _add_online_room(host_scope)
	guest_transport = _add_online_room(guest_scope)
	host_game = _add_game(host_scope, host_transport, "HostGame")
	guest_game = _add_game(guest_scope, guest_transport, "GuestGame")
	await get_tree().process_frame

	var port = 29000 + posmod(OS.get_process_id(), 1500)
	_expect_equal(int(server.call("start_server", "127.0.0.1", port, RoomRegistry.new(54321), 8)), OK, "gameplay loopback server starts")
	_expect_equal(int(host_transport.call("connect_to_server", "127.0.0.1", port, "房主")), OK, "host connects")
	_expect_equal(int(guest_transport.call("connect_to_server", "127.0.0.1", port, "访客")), OK, "guest connects")
	_expect_true(await _wait_until(func(): return bool(host_transport.call("is_connected_to_server")) and bool(guest_transport.call("is_connected_to_server"))), "both gameplay clients connect")

	host_game.set("room_players_per_side", 1)
	host_game.set("room_fill_with_ai", false)
	host_game.call("_request_online_create_room")
	_expect_true(await _wait_until(func(): return bool(host_game.get("online_room_active"))), "host game receives its created room")
	var room_code = String(host_game.get("room_invite_code"))
	guest_game.set("online_room_join_code", room_code)
	guest_game.call("_request_online_join")
	_expect_true(await _wait_until(func(): return bool(guest_game.get("online_room_active")) and (host_game.get("room_human_teams") as Dictionary).size() == 2), "guest joins through the main-game adapter")

	host_transport.call("set_ready", true)
	guest_transport.call("set_ready", true)
	_expect_true(await _wait_until(func(): return bool(host_game.get("online_room_can_start"))), "ready snapshots enable the host start gate")
	host_transport.call("start_room")
	_expect_true(await _wait_until(func(): return String(host_game.get("online_match_id")) != "" and String(host_game.get("online_match_id")) == String(guest_game.get("online_match_id"))), "both games enter the same internet match")
	_expect_true(bool(host_game.get("online_match_authority")), "host game advances the battle")
	_expect_false(bool(guest_game.get("online_match_authority")), "guest game waits for host snapshots")
	var host_team = int(host_game.get("local_team_id"))
	var guest_team = int(guest_game.get("local_team_id"))
	_expect_true(host_team in [1, 4] and guest_team in [1, 4] and host_team != guest_team, "games receive distinct randomized spawn slots")

	var guest_unlock = _first_affordable_unlock(guest_game, guest_team)
	_expect_true(guest_unlock != Vector2i(-99, -99), "guest has an affordable server-assigned tile")
	guest_game.call("_try_unlock", guest_unlock)
	_expect_true(await _wait_until(func(): return int((host_game.get("tiles") as Dictionary)[guest_unlock].get("team", BoardRules.NEUTRAL)) == guest_team), "guest command reaches and mutates the host authority")
	_expect_true(await _wait_until(func(): return int((guest_game.get("tiles") as Dictionary)[guest_unlock].get("team", BoardRules.NEUTRAL)) == guest_team), "authority snapshot returns the guest's result to the guest client")
	_expect_true(absf(float(host_game.get("battle_timer")) - float(guest_game.get("battle_timer"))) < 1.0, "battle timer remains synchronized")

	host_transport.call("leave_room")
	_expect_true(await _wait_until(func(): return bool(guest_game.get("online_match_authority"))), "remaining guest takes over authority after host leaves")
	var takeover_timer = float(guest_game.get("battle_timer"))
	_expect_true(await _wait_until(func(): return float(guest_game.get("battle_timer")) < takeover_timer - 0.05), "migrated authority continues the battle simulation")

	server.call("stop_transport")
	host_transport.call("stop_transport")
	guest_transport.call("stop_transport")
	server_scope.queue_free()
	host_scope.queue_free()
	guest_scope.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("Online room gameplay loopback tests passed.")
	get_tree().quit(failures)


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


func _add_game(scope: Node, transport: Node, node_name: String) -> Node:
	var game = MainApp.new()
	game.name = node_name
	scope.add_child(game)
	game.set("online_room_service", transport)
	for binding in [
		["server_connected", "_on_online_server_connected"],
		["server_connection_failed", "_on_online_server_connection_failed"],
		["server_disconnected", "_on_online_server_disconnected"],
		["operation_completed", "_on_online_operation_completed"],
		["operation_failed", "_on_online_operation_failed"],
		["room_snapshot_changed", "_on_online_room_snapshot"],
		["room_left", "_on_online_room_left"],
		["match_started", "_on_online_match_started"],
		["authority_changed", "_on_online_authority_changed"],
		["battle_command_received", "_on_online_battle_command"],
		["authority_snapshot_received", "_on_online_authority_snapshot"],
	]:
		game.call("_connect_online_signal", binding[0], binding[1])
	return game


func _first_affordable_unlock(game: Node, team: int) -> Vector2i:
	for key in (game.get("tiles") as Dictionary).keys():
		if not bool(game.call("_can_unlock", key, team)):
			continue
		if int(game.call("_unlock_cost", key, team)) <= int(game.call("_gold_for_team", team)):
			return key
	return Vector2i(-99, -99)


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
