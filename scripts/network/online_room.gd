extends Node

## Internet room transport shared by the game client and the dedicated server.
##
## Add this script as the `OnlineRoom` autoload so every RPC has the same
## `/root/OnlineRoom` path on clients and on the dedicated server. Room rules
## remain in RoomRegistry; this node only owns ENet, sender authentication and
## delivery guarantees.

signal server_started(bind_host: String, port: int)
signal server_stopped
signal server_connected(host: String, port: int, peer_id: int)
signal server_connection_failed(message: String)
signal server_disconnected
signal operation_completed(operation: String, result: Dictionary)
signal operation_failed(operation: String, error: String)
signal room_snapshot_changed(snapshot: Dictionary)
signal room_left
signal match_started(match_data: Dictionary)
signal authority_changed(match_data: Dictionary)
signal battle_command_received(envelope: Dictionary)
signal authority_snapshot_received(envelope: Dictionary)
signal account_state_changed(state: Dictionary)

const DEFAULT_HOST = "127.0.0.1"
const DEFAULT_BIND_HOST = "0.0.0.0"
const DEFAULT_PORT = 24567
const DEFAULT_MAX_CLIENTS = 64
const PROJECT_SERVER_HOST_SETTING = "network/server_host"
const PROJECT_SERVER_PORT_SETTING = "network/server_port"
const CHANNEL_COUNT = 3
const REGISTRY_PATH = "res://scripts/network/room_registry.gd"
const ACCOUNT_STORE_PATH = "res://scripts/server/player_account_store.gd"
const MATCH_ANALYTICS_STORE_PATH = "res://scripts/server/match_analytics_store.gd"
const DEVICE_CREDENTIAL_PATH = "user://client/device_account.json"
const MAX_PLAYER_NAME_LENGTH = 24
const MAX_COMMAND_BYTES = 64 * 1024
const MAX_SNAPSHOT_BYTES = 1024 * 1024
const SERVER_PEER_ID = 1
const MAP_SUFFIXES = ["plateau", "diamond", "hourglass", "crossroads", "ripple"]

enum TransportMode {
	OFFLINE,
	SERVER,
	CLIENT,
}

var mode = TransportMode.OFFLINE
var server_host = DEFAULT_HOST
var server_port = DEFAULT_PORT
var bind_host = DEFAULT_BIND_HOST
var local_player_name = "玩家"
var current_room_snapshot: Dictionary = {}
var current_match: Dictionary = {}
var last_operation_error = ""
var current_user_id = ""
var current_profile: Dictionary = {}
var current_account_summaries: Array = []

var _enet_peer: ENetMultiplayerPeer
var _client_connected = false
var _stopping = false
var _registry: Variant
var _server_peer_rooms: Dictionary = {}
var _server_room_options: Dictionary = {}
var _server_room_matches: Dictionary = {}
var _server_authority_sequences: Dictionary = {}
var _server_match_serial = 0
var _server_boot_nonce = ""
var _account_store: Variant
var _match_analytics_store: Variant
var _server_peer_sessions: Dictionary = {}
var _client_session_token = ""
var _device_credential_path = DEVICE_CREDENTIAL_PATH
var _installation_id = ""
var _refresh_token = ""


func _ready() -> void:
	_wire_multiplayer_signals()
	_load_or_create_device_credentials()
	server_host = default_server_host()
	server_port = default_server_port()
	bind_host = default_bind_host()
	if OS.has_feature("dedicated_server"):
		call_deferred("_start_feature_dedicated_server")


func start_server(
	requested_bind_host: String = "",
	requested_port: int = -1,
	registry_override: Variant = null,
	max_clients: int = DEFAULT_MAX_CLIENTS
) -> Error:
	stop_transport()
	_wire_multiplayer_signals()
	bind_host = requested_bind_host.strip_edges()
	if bind_host.is_empty():
		bind_host = default_bind_host()
	server_port = requested_port if requested_port > 0 else default_server_port()
	_registry = registry_override if registry_override != null else _create_registry()
	_account_store = _create_account_store()
	_match_analytics_store = _create_match_analytics_store()
	_server_boot_nonce = Crypto.new().generate_random_bytes(6).hex_encode()
	if _registry == null:
		return _server_start_failed(ERR_CANT_CREATE, "RoomRegistry 无法加载")

	if _account_store == null:
		return _server_start_failed(ERR_CANT_CREATE, "PlayerAccountStore could not load")
	if _match_analytics_store == null:
		return _server_start_failed(ERR_CANT_CREATE, "MatchAnalyticsStore could not load")
	var catalog_result = _match_analytics_store.call("register_animal_catalog", _server_animal_catalog())
	if typeof(catalog_result) != TYPE_DICTIONARY or not bool((catalog_result as Dictionary).get("ok", false)):
		return _server_start_failed(ERR_CANT_CREATE, "MatchAnalyticsStore could not write the animal catalog")

	_enet_peer = ENetMultiplayerPeer.new()
	_enet_peer.set_bind_ip(bind_host)
	var error = _enet_peer.create_server(
		server_port,
		maxi(1, max_clients),
		CHANNEL_COUNT
	)
	if error != OK:
		return _server_start_failed(error, "无法监听 UDP %s:%d" % [bind_host, server_port])

	mode = TransportMode.SERVER
	multiplayer.multiplayer_peer = _enet_peer
	server_started.emit(bind_host, server_port)
	return OK


func connect_to_server(
	requested_host: String = "",
	requested_port: int = -1,
	player_name: String = "玩家"
) -> Error:
	stop_transport()
	_wire_multiplayer_signals()
	server_host = requested_host.strip_edges()
	if server_host.is_empty():
		server_host = default_server_host()
	server_port = requested_port if requested_port > 0 else default_server_port()
	local_player_name = _sanitize_player_name(player_name, 0)
	_enet_peer = ENetMultiplayerPeer.new()
	var error = _enet_peer.create_client(server_host, server_port, CHANNEL_COUNT)
	if error != OK:
		_enet_peer = null
		mode = TransportMode.OFFLINE
		var message = "无法连接 %s:%d" % [server_host, server_port]
		server_connection_failed.emit(message)
		return error
	mode = TransportMode.CLIENT
	multiplayer.multiplayer_peer = _enet_peer
	return OK


func stop_transport() -> void:
	if _stopping:
		return
	_stopping = true
	var previous_mode = mode
	if _enet_peer != null:
		_enet_peer.close()
	if multiplayer != null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_enet_peer = null
	mode = TransportMode.OFFLINE
	_client_connected = false
	_registry = null
	_server_peer_rooms.clear()
	_server_room_options.clear()
	_server_room_matches.clear()
	_server_authority_sequences.clear()
	_server_boot_nonce = ""
	_server_peer_sessions.clear()
	_account_store = null
	_match_analytics_store = null
	_clear_account_state()
	_clear_client_room_state(false)
	_stopping = false
	if previous_mode == TransportMode.SERVER:
		server_stopped.emit()


func disconnect_from_server() -> void:
	stop_transport()


func is_server_running() -> bool:
	return mode == TransportMode.SERVER and multiplayer.is_server()


func is_connected_to_server() -> bool:
	return mode == TransportMode.CLIENT and _client_connected


func local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()


func create_room(
	player_name: String = "玩家",
	players_per_side: int = 1,
	options: Dictionary = {}
) -> bool:
	if not _require_client_connection("create_room"):
		return false
	local_player_name = _sanitize_player_name(player_name, local_peer_id())
	rpc_id(
		SERVER_PEER_ID,
		"_rpc_request_create_room",
		local_player_name,
		clampi(players_per_side, 1, 3),
		options.duplicate(true)
	)
	return true


func join_room(room_code: String, player_name: String = "玩家") -> bool:
	if not _require_client_connection("join_room"):
		return false
	local_player_name = _sanitize_player_name(player_name, local_peer_id())
	rpc_id(
		SERVER_PEER_ID,
		"_rpc_request_join_room",
		_sanitize_room_code(room_code),
		local_player_name
	)
	return true


func update_room_options(options: Dictionary) -> bool:
	if not _require_client_connection("update_room_options"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_update_room_options", options.duplicate(true))
	return true


func move_to_slot(team_id: int) -> bool:
	if not _require_client_connection("move_to_slot"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_move_to_slot", team_id)
	return true


func set_ready(ready: bool) -> bool:
	if not _require_client_connection("set_ready"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_set_ready", ready)
	return true


func start_room() -> bool:
	if not _require_client_connection("start_room"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_start_room")
	return true


func request_start_match() -> bool:
	return start_room()


func leave_room() -> bool:
	if not _require_client_connection("leave_room"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_leave_room")
	return true


func send_battle_command(command: Dictionary) -> bool:
	if not _require_client_connection("battle_command"):
		return false
	if current_match.is_empty():
		_emit_local_failure("battle_command", "比赛尚未开始")
		return false
	if not _payload_fits(command, MAX_COMMAND_BYTES):
		_emit_local_failure("battle_command", "战斗命令过大")
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_submit_battle_command", command.duplicate(true))
	return true


func send_authority_snapshot(snapshot: Dictionary) -> bool:
	if not _require_client_connection("authority_snapshot"):
		return false
	if current_match.is_empty() or not bool(current_match.get("is_authority", false)):
		_emit_local_failure("authority_snapshot", "只有房主权威端可以发送战斗快照")
		return false
	if not _payload_fits(snapshot, MAX_SNAPSHOT_BYTES):
		_emit_local_failure("authority_snapshot", "战斗快照过大")
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_submit_authority_snapshot", snapshot.duplicate(true))
	return true


func register_account(account: String, password: String) -> bool:
	if not _require_client_connection("register_account"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_register_account", account, password)
	return true


func login_account(account: String, password: String) -> bool:
	if not _require_client_connection("login_account"):
		return false
	if _installation_id.is_empty():
		_load_or_create_device_credentials()
	rpc_id(SERVER_PEER_ID, "_rpc_request_login_account", account, password, _installation_id, _refresh_token)
	return true


func authenticate_default_account() -> bool:
	if not _require_client_connection("authenticate_installation"):
		return false
	if _installation_id.is_empty():
		_load_or_create_device_credentials()
	rpc_id(SERVER_PEER_ID, "_rpc_request_authenticate_installation", _installation_id, _refresh_token)
	return true


func has_saved_login() -> bool:
	return (
		_installation_id.length() == 64
		and _installation_id.is_valid_hex_number(false)
		and _refresh_token.length() == 64
		and _refresh_token.is_valid_hex_number(false)
	)


func logout_account() -> bool:
	if not _require_client_connection("logout_account"):
		_clear_account_state()
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_logout_account", _client_session_token)
	return true


func request_account_summaries() -> bool:
	if not _require_client_connection("list_accounts"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_account_summaries", _client_session_token)
	return true


func switch_account(user_id: String) -> bool:
	if not _require_client_connection("switch_account"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_switch_account", _client_session_token, user_id)
	return true


func create_new_account() -> bool:
	if not _require_client_connection("create_new_account"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_create_new_account", _client_session_token)
	return true


func request_player_profile() -> bool:
	if not _require_client_connection("load_player_profile"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_player_profile", _client_session_token)
	return true


func save_player_profile(profile: Dictionary) -> bool:
	if not _require_client_connection("save_player_profile"):
		return false
	rpc_id(SERVER_PEER_ID, "_rpc_request_save_player_profile", _client_session_token, profile.duplicate(true))
	return true


func default_server_host() -> String:
	var cli_value = _command_line_value(["server-host", "host"])
	if not cli_value.is_empty():
		return cli_value
	var environment_value = OS.get_environment("ZHANCHENG_SERVER_HOST").strip_edges()
	if not environment_value.is_empty():
		return environment_value
	var project_value = str(ProjectSettings.get_setting(PROJECT_SERVER_HOST_SETTING, "")).strip_edges()
	return project_value if not project_value.is_empty() else DEFAULT_HOST


func default_bind_host() -> String:
	var cli_value = _command_line_value(["bind-host"])
	if not cli_value.is_empty():
		return cli_value
	var environment_value = OS.get_environment("ZHANCHENG_BIND_HOST").strip_edges()
	return environment_value if not environment_value.is_empty() else DEFAULT_BIND_HOST


func default_server_port() -> int:
	var cli_value = _command_line_value(["server-port", "port"])
	if cli_value.is_valid_int():
		return clampi(cli_value.to_int(), 1, 65535)
	var environment_value = OS.get_environment("ZHANCHENG_SERVER_PORT").strip_edges()
	if environment_value.is_valid_int():
		return clampi(environment_value.to_int(), 1, 65535)
	var project_value = str(ProjectSettings.get_setting(PROJECT_SERVER_PORT_SETTING, "")).strip_edges()
	if project_value.is_valid_int():
		return clampi(project_value.to_int(), 1, 65535)
	return DEFAULT_PORT


func default_max_clients() -> int:
	var cli_value = _command_line_value(["max-clients"])
	if cli_value.is_valid_int():
		return clampi(cli_value.to_int(), 2, 512)
	var environment_value = OS.get_environment("ZHANCHENG_MAX_CLIENTS").strip_edges()
	if environment_value.is_valid_int():
		return clampi(environment_value.to_int(), 2, 512)
	return DEFAULT_MAX_CLIENTS


func _start_feature_dedicated_server() -> void:
	if mode != TransportMode.OFFLINE:
		return
	var error = start_server(default_bind_host(), default_server_port(), null, default_max_clients())
	if error != OK:
		push_error("Dedicated internet room server failed to start (error %d)." % error)
		return
	print("Dedicated internet room server listening on UDP %s:%d." % [bind_host, server_port])


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_register_account(account: String, password: String) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	_send_operation_result(sender, "register_account", _account_store.call("register_account", account, password))


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_login_account(
	account: String,
	password: String,
	installation_id: String = "",
	refresh_token: String = ""
) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	var result: Dictionary = _account_store.call(
		"login",
		account,
		password,
		installation_id,
		refresh_token,
		_server_animal_card_ids()
	)
	if bool(result.get("ok", false)):
		_invalidate_server_peer_session(sender)
		_server_peer_sessions[sender] = String(result.get("session_token", ""))
	_send_operation_result(sender, "login_account", result)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_authenticate_installation(installation_id: String, refresh_token: String) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	var result: Dictionary = _account_store.call(
		"authenticate_installation",
		installation_id,
		refresh_token,
		_server_starter_profile(),
		_server_animal_card_ids()
	)
	if bool(result.get("ok", false)):
		_invalidate_server_peer_session(sender)
		_server_peer_sessions[sender] = String(result.get("session_token", ""))
	_send_operation_result(sender, "authenticate_installation", result)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_logout_account(session_token: String) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	if session_token != String(_server_peer_sessions.get(sender, "")):
		_send_operation_result(sender, "logout_account", _failure("invalid_session"))
		return
	var result: Dictionary = _account_store.call("logout", session_token)
	_server_peer_sessions.erase(sender)
	_send_operation_result(sender, "logout_account", result)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_account_summaries(session_token: String) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	if session_token != String(_server_peer_sessions.get(sender, "")):
		_send_operation_result(sender, "list_accounts", _failure("invalid_session"))
		return
	_send_operation_result(sender, "list_accounts", _account_store.call(
		"account_summaries_for_session",
		session_token,
		_server_animal_card_ids()
	))


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_switch_account(session_token: String, user_id: String) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	if session_token != String(_server_peer_sessions.get(sender, "")):
		_send_operation_result(sender, "switch_account", _failure("invalid_session"))
		return
	var result: Dictionary = _account_store.call("switch_account", session_token, user_id, _server_animal_card_ids())
	if bool(result.get("ok", false)) and result.has("session_token"):
		_server_peer_sessions[sender] = String(result.get("session_token", ""))
	_send_operation_result(sender, "switch_account", result)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_create_new_account(session_token: String) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	if session_token != String(_server_peer_sessions.get(sender, "")):
		_send_operation_result(sender, "create_new_account", _failure("invalid_session"))
		return
	var result: Dictionary = _account_store.call(
		"create_account_for_session",
		session_token,
		_server_starter_profile(),
		_server_animal_card_ids()
	)
	if bool(result.get("ok", false)) and result.has("session_token"):
		_server_peer_sessions[sender] = String(result.get("session_token", ""))
	_send_operation_result(sender, "create_new_account", result)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_player_profile(session_token: String) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	if session_token != String(_server_peer_sessions.get(sender, "")):
		_send_operation_result(sender, "load_player_profile", _failure("invalid_session"))
		return
	_send_operation_result(sender, "load_player_profile", _account_store.call("profile_for_session", session_token))


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_save_player_profile(session_token: String, profile: Dictionary) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	if session_token != String(_server_peer_sessions.get(sender, "")):
		_send_operation_result(sender, "save_player_profile", _failure("invalid_session"))
		return
	_send_operation_result(sender, "save_player_profile", _account_store.call("save_profile", session_token, profile))


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_create_room(
	player_name: String,
	players_per_side: int,
	options: Dictionary
) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	var safe_options = _sanitize_room_options(options, clampi(players_per_side, 1, 3))
	var result = _registry_call("create_room", [
		sender,
		_sanitize_player_name(player_name, sender),
		int(safe_options["players_per_side"]),
		bool(safe_options["fill_with_ai"]),
		_server_rank_profile(sender),
	])
	if not bool(result.get("ok", false)):
		_send_operation_result(sender, "create_room", result)
		return
	var room_code = _registry_room_code(sender, result)
	if room_code.is_empty():
		_send_operation_result(sender, "create_room", _failure("房间创建后没有房间码"))
		return
	_server_peer_rooms[sender] = room_code
	_server_room_options[room_code] = safe_options
	_send_operation_result(sender, "create_room", result)
	_broadcast_room_snapshots(room_code, result)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_join_room(room_code: String, player_name: String) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	var result = _registry_call("join_room", [
		sender,
		_sanitize_room_code(room_code),
		_sanitize_player_name(player_name, sender),
		_server_rank_profile(sender),
	])
	if not bool(result.get("ok", false)):
		_send_operation_result(sender, "join_room", result)
		return
	var joined_room_code = _registry_room_code(sender, result)
	if joined_room_code.is_empty():
		_send_operation_result(sender, "join_room", _failure("加入后没有房间码"))
		return
	_server_peer_rooms[sender] = joined_room_code
	if not _server_room_options.has(joined_room_code):
		var snapshot = _registry_snapshot(sender)
		_server_room_options[joined_room_code] = _sanitize_room_options(snapshot, int(snapshot.get("players_per_side", 1)))
	_send_operation_result(sender, "join_room", result)
	_broadcast_room_snapshots(joined_room_code, result)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_update_room_options(options: Dictionary) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	var room_code = _server_room_code(sender)
	if room_code.is_empty():
		_send_operation_result(sender, "update_room_options", _failure("尚未加入房间"))
		return
	var current_snapshot = _registry_snapshot(sender)
	var merged = _server_room_options.get(room_code, {}).duplicate(true)
	merged.merge(options, true)
	var safe_options = _sanitize_room_options(
		merged,
		int(current_snapshot.get("players_per_side", 1))
	)
	var result = _registry_call("update_room_settings", [
		sender,
		int(safe_options["players_per_side"]),
		bool(safe_options["fill_with_ai"]),
	])
	if bool(result.get("ok", false)):
		_server_room_options[room_code] = safe_options
	_send_operation_result(sender, "update_room_options", result)
	if bool(result.get("ok", false)):
		_broadcast_room_snapshots(room_code, result)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_move_to_slot(team_id: int) -> void:
	_handle_room_mutation("move_to_slot", "move_to_slot", [team_id])


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_ready(ready: bool) -> void:
	_handle_room_mutation("set_ready", "set_ready", [ready])


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_leave_room() -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	var room_code = _server_room_code(sender)
	var result = _registry_call("leave_room", [sender])
	_send_operation_result(sender, "leave_room", result)
	if not bool(result.get("ok", false)):
		return
	_server_peer_rooms.erase(sender)
	_migrate_match_authority(room_code, sender, result)
	rpc_id(sender, "_rpc_receive_room_left")
	_broadcast_room_snapshots(room_code, result)
	_cleanup_empty_room(room_code)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_start_room() -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	var room_code = _server_room_code(sender)
	if room_code.is_empty():
		_send_operation_result(sender, "start_room", _failure("尚未加入房间"))
		return
	var result = _registry_call("start_room", [sender])
	_send_operation_result(sender, "start_room", result)
	if not bool(result.get("ok", false)):
		return
	_broadcast_room_snapshots(room_code, result)
	_start_network_match(room_code, result)


@rpc("any_peer", "call_remote", "reliable", 2)
func _rpc_submit_battle_command(command: Dictionary) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not _payload_fits(command, MAX_COMMAND_BYTES):
		_send_operation_result(sender, "battle_command", _failure("战斗命令过大"))
		return
	var room_code = _server_room_code(sender)
	var server_match = _server_room_matches.get(room_code, {})
	if room_code.is_empty() or server_match.is_empty():
		_send_operation_result(sender, "battle_command", _failure("比赛尚未开始"))
		return
	var authority_peer_id = int(server_match.get("authority_peer_id", 0))
	if authority_peer_id <= SERVER_PEER_ID or not _server_peer_rooms.has(authority_peer_id):
		_send_operation_result(sender, "battle_command", _failure("房主权威端已离线"))
		return
	var assignment = _registry_call("assignment_for_peer", [sender])
	var envelope = {
		"match_id": String(server_match.get("match_id", "")),
		"sender_peer_id": sender,
		"sender_team_id": int(assignment.get("team_id", 0)),
		"command": command.duplicate(true),
	}
	rpc_id(authority_peer_id, "_rpc_receive_battle_command", envelope)


@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_submit_authority_snapshot(snapshot: Dictionary) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not _payload_fits(snapshot, MAX_SNAPSHOT_BYTES):
		return
	var room_code = _server_room_code(sender)
	var server_match = _server_room_matches.get(room_code, {})
	if room_code.is_empty() or server_match.is_empty():
		return
	if sender != int(server_match.get("authority_peer_id", 0)):
		return
	var previous_sequence = int(_server_authority_sequences.get(room_code, -1))
	var sequence = int(snapshot.get("sequence", previous_sequence + 1))
	if sequence <= previous_sequence:
		return
	_server_authority_sequences[room_code] = sequence
	_try_finalize_server_match_analytics(room_code, server_match, snapshot)
	var envelope = {
		"match_id": String(server_match.get("match_id", "")),
		"authority_peer_id": sender,
		"sequence": sequence,
		"snapshot": snapshot.duplicate(true),
	}
	for peer_id in _room_peer_ids(room_code):
		if int(peer_id) != sender:
			rpc_id(int(peer_id), "_rpc_receive_authority_snapshot", envelope)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_operation_result(operation: String, result: Dictionary) -> void:
	last_operation_error = String(result.get("error", ""))
	if bool(result.get("ok", false)):
		_apply_account_operation(operation, result)
		operation_completed.emit(operation, result.duplicate(true))
	else:
		operation_failed.emit(operation, last_operation_error)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_room_snapshot(snapshot: Dictionary) -> void:
	current_room_snapshot = snapshot.duplicate(true)
	room_snapshot_changed.emit(current_room_snapshot.duplicate(true))


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_room_left() -> void:
	_clear_client_room_state(true)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_match_started(match_data: Dictionary) -> void:
	current_match = match_data.duplicate(true)
	match_started.emit(current_match.duplicate(true))


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_receive_authority_changed(change: Dictionary) -> void:
	if String(change.get("match_id", "")) != String(current_match.get("match_id", "")):
		return
	current_match["authority_peer_id"] = int(change.get("authority_peer_id", 0))
	current_match["is_authority"] = bool(change.get("is_authority", false))
	authority_changed.emit(current_match.duplicate(true))


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_receive_battle_command(envelope: Dictionary) -> void:
	if String(envelope.get("match_id", "")) != String(current_match.get("match_id", "")):
		return
	battle_command_received.emit(envelope.duplicate(true))


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_receive_authority_snapshot(envelope: Dictionary) -> void:
	if String(envelope.get("match_id", "")) != String(current_match.get("match_id", "")):
		return
	authority_snapshot_received.emit(envelope.duplicate(true))


func _handle_room_mutation(operation: String, registry_method: String, arguments: Array) -> void:
	if not _accept_server_request():
		return
	var sender = multiplayer.get_remote_sender_id()
	var room_code = _server_room_code(sender)
	var call_arguments = [sender]
	call_arguments.append_array(arguments)
	var result = _registry_call(registry_method, call_arguments)
	_send_operation_result(sender, operation, result)
	if bool(result.get("ok", false)):
		_broadcast_room_snapshots(room_code, result)


func _start_network_match(room_code: String, start_result: Dictionary) -> void:
	var peer_ids = _affected_peer_ids(start_result, room_code)
	if peer_ids.is_empty():
		return
	var host_snapshot = _registry_snapshot(int(peer_ids[0]))
	var players_per_side = int(host_snapshot.get("players_per_side", 1))
	var options: Dictionary = _server_room_options.get(room_code, {}).duplicate(true)
	var map_id = _select_map_id(room_code, players_per_side, String(options.get("map_id", "")))
	_server_match_serial += 1
	var authority_peer_id = int(start_result.get(
		"authority_peer_id",
		host_snapshot.get("authority_peer_id", host_snapshot.get("host_peer_id", 0))
	))
	var match_id = "%s-%d-%s-%d" % [
		room_code,
		int(Time.get_unix_time_from_system()),
		_server_boot_nonce,
		_server_match_serial,
	]
	var match_seed = posmod(hash("%s:%s" % [match_id, map_id]), 2147483646) + 1
	var match_data = {
		"room_code": room_code,
		"match_id": match_id,
		"map_id": map_id,
		"players_per_side": players_per_side,
		"match_seed": match_seed,
		"authority_peer_id": authority_peer_id,
	}
	var analytics_roster = _server_match_roster(room_code)
	var expected_human_count = players_per_side * 2
	var analytics_result = _failure("incomplete_human_roster")
	if _server_roster_is_valid_for_analytics(analytics_roster, expected_human_count):
		analytics_result = _start_server_match_analytics(match_data, analytics_roster)
	match_data["analytics_tracked"] = bool(analytics_result.get("ok", false))
	match_data["analytics_catalog_available"] = bool(analytics_result.get("animal_catalog_available", false))
	_server_room_matches[room_code] = match_data
	_server_authority_sequences[room_code] = -1
	for peer_id_value in peer_ids:
		var peer_id = int(peer_id_value)
		var snapshot = _snapshot_with_transport_fields(peer_id)
		var payload = match_data.duplicate(true)
		payload["local_team_id"] = int(snapshot.get("local_team_id", 0))
		payload["is_authority"] = peer_id == authority_peer_id
		payload["room_snapshot"] = snapshot
		rpc_id(peer_id, "_rpc_receive_match_started", payload)


func _start_server_match_analytics(match_data: Dictionary, roster: Array) -> Dictionary:
	if _match_analytics_store == null:
		return _failure("analytics_unavailable")
	if roster.is_empty():
		return _failure("no_authenticated_players")
	var result = _match_analytics_store.call("begin_match", {
		"match_id": String(match_data.get("match_id", "")),
		"room_code": String(match_data.get("room_code", "")),
		"map_id": String(match_data.get("map_id", "")),
		"started_at_unix": int(Time.get_unix_time_from_system()),
	}, roster, _server_animal_catalog())
	return (result as Dictionary).duplicate(true) if typeof(result) == TYPE_DICTIONARY else _failure("analytics_invalid_result")


func _try_finalize_server_match_analytics(room_code: String, match_data: Dictionary, snapshot: Dictionary) -> void:
	if _match_analytics_store == null or not bool(match_data.get("analytics_tracked", false)):
		return
	if not bool(snapshot.get("game_over", false)):
		return
	var match_id = String(match_data.get("match_id", ""))
	if match_id.is_empty():
		return
	var snapshot_match_id = String(snapshot.get("match_id", ""))
	if snapshot_match_id != match_id:
		return
	var terminal_result = _server_terminal_result_from_snapshot(snapshot)
	var team_outcomes = terminal_result.get("team_outcomes", {})
	if typeof(team_outcomes) != TYPE_DICTIONARY or (team_outcomes as Dictionary).is_empty():
		return
	_match_analytics_store.call(
		"finalize_match",
		match_id,
		terminal_result
	)


func _server_terminal_result_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var team_outcomes: Dictionary = {}
	var placements_by_team: Dictionary = {}
	var side_a_outcome = String(snapshot.get("side_a_outcome", snapshot.get("authority_room_result", snapshot.get("room_result", "")))).strip_edges().to_lower()
	if side_a_outcome in ["win", "loss", "draw"]:
		for team_id in range(1, 7):
			if side_a_outcome == "draw":
				team_outcomes[team_id] = "draw"
			else:
				var is_side_a = _server_team_side(team_id) == "a"
				team_outcomes[team_id] = side_a_outcome if is_side_a else ("loss" if side_a_outcome == "win" else "win")

	var raw_placements = snapshot.get("multiplayer_placements", {})
	if typeof(raw_placements) == TYPE_DICTIONARY:
		for raw_team_id in raw_placements:
			var team_id = int(raw_team_id)
			var placement = int(raw_placements[raw_team_id])
			if team_id >= 1 and team_id <= 6 and placement > 0:
				placements_by_team[team_id] = placement
	if team_outcomes.is_empty() and not placements_by_team.is_empty():
		var best_placement = 999
		for placement_value in placements_by_team.values():
			best_placement = mini(best_placement, int(placement_value))
		for team_id_value in placements_by_team:
			var team_id = int(team_id_value)
			team_outcomes[team_id] = "win" if int(placements_by_team[team_id]) == best_placement else "loss"

	return {
		"team_outcomes": team_outcomes,
		"placements_by_team": placements_by_team,
	}


func _server_team_side(team_id: int) -> String:
	if team_id >= 1 and team_id <= 3:
		return "a"
	if team_id >= 4 and team_id <= 6:
		return "b"
	return ""


func _server_match_roster(room_code: String) -> Array:
	if _registry == null or not _registry.has_method("match_roster"):
		return []
	var value = _registry.call("match_roster", room_code)
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _server_roster_is_valid_for_analytics(roster: Array, expected_human_count: int) -> bool:
	if roster.size() != expected_human_count:
		return false
	var seen_user_ids = {}
	for raw_player in roster:
		if typeof(raw_player) != TYPE_DICTIONARY:
			return false
		var user_id = String((raw_player as Dictionary).get("user_id", "")).strip_edges()
		if user_id.is_empty() or seen_user_ids.has(user_id):
			return false
		seen_user_ids[user_id] = true
	return true


func _server_animal_card_ids() -> Array:
	var catalog = _server_animal_catalog()
	var result = []
	for card_id_value in catalog:
		result.append(String(card_id_value))
	return result


func _server_animal_catalog() -> Dictionary:
	var config_db = get_node_or_null("/root/ConfigDB")
	if config_db == null or not config_db.has_method("get_table"):
		return {}
	var card_rows = config_db.call("get_table", "cards")
	if typeof(card_rows) != TYPE_ARRAY:
		return {}
	var result = {}
	for raw_card in card_rows:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = raw_card
		var card_id = String(card.get("id", "")).strip_edges()
		if card_id.is_empty() or not _server_card_is_animal(card):
			continue
		var card_name = String(card.get("name", card_id)).strip_edges()
		result[card_id] = card_name if not card_name.is_empty() else card_id
	return result


func _server_starter_profile() -> Dictionary:
	var profile = {
		"card_counts": {},
		"card_levels": {},
		"deck": [],
		"gacha_tickets": 10,
		"rank_stars": 1,
		"rank_key": "bronze",
		"elo": 1000,
		"rank_mirrors": {},
	}
	var config_db = get_node_or_null("/root/ConfigDB")
	if config_db == null or not config_db.has_method("get_table"):
		return profile
	var card_rows = config_db.call("get_table", "cards")
	if typeof(card_rows) != TYPE_ARRAY:
		return profile
	var starter_animals = []
	var available_cards = {}
	for raw_card in card_rows:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = raw_card
		var card_id = String(card.get("id", "")).strip_edges()
		if card_id.is_empty():
			continue
		available_cards[card_id] = true
		if not _server_card_is_animal(card):
			continue
		if String(card.get("rarity", "")).strip_edges().to_lower() == "common" and starter_animals.size() < 8:
			starter_animals.append(card_id)
	for card_id in starter_animals:
		profile["card_counts"][card_id] = 1
		profile["card_levels"][card_id] = 1
	for required_id in ["gold_mine_card", "defense_watch_tower"]:
		if available_cards.has(required_id):
			profile["card_counts"][required_id] = 1
			profile["card_levels"][required_id] = 1
			profile["deck"].append(required_id)
	for card_id in starter_animals:
		if profile["deck"].size() >= 8:
			break
		profile["deck"].append(card_id)
	var index = 0
	while profile["deck"].size() < 8 and not starter_animals.is_empty():
		profile["deck"].append(starter_animals[index % starter_animals.size()])
		index += 1
	return profile


func _server_card_has_building_tag(card: Dictionary) -> bool:
	var tags = card.get("tags", "")
	if typeof(tags) == TYPE_ARRAY:
		for raw_tag in tags:
			if String(raw_tag).strip_edges().to_lower() == "building":
				return true
		return false
	for raw_tag in String(tags).split("|", false):
		if raw_tag.strip_edges().to_lower() == "building":
			return true
	return false


func _server_card_is_animal(card: Dictionary) -> bool:
	var art_path = String(card.get("art_path", "")).strip_edges().to_lower()
	if art_path.contains("/animals/"):
		return true
	if art_path.contains("/buildings/"):
		return false
	return not _server_card_has_building_tag(card)


func _invalidate_server_peer_session(peer_id: int) -> void:
	var existing_token = String(_server_peer_sessions.get(peer_id, ""))
	if not existing_token.is_empty() and _account_store != null:
		_account_store.call("logout", existing_token)
	_server_peer_sessions.erase(peer_id)


func _broadcast_room_snapshots(room_code: String, mutation_result: Dictionary = {}) -> void:
	if room_code.is_empty():
		return
	for peer_id_value in _affected_peer_ids(mutation_result, room_code):
		var peer_id = int(peer_id_value)
		var snapshot = _snapshot_with_transport_fields(peer_id)
		if not snapshot.is_empty():
			rpc_id(peer_id, "_rpc_receive_room_snapshot", snapshot)


func _snapshot_with_transport_fields(peer_id: int) -> Dictionary:
	var snapshot = _registry_snapshot(peer_id)
	if snapshot.is_empty():
		return snapshot
	var room_code = String(snapshot.get("room_code", _server_room_code(peer_id)))
	var options: Dictionary = _server_room_options.get(room_code, {}).duplicate(true)
	snapshot["options"] = options
	snapshot["map_id"] = String(options.get("map_id", ""))
	return snapshot


func _send_operation_result(peer_id: int, operation: String, result: Dictionary) -> void:
	rpc_id(peer_id, "_rpc_receive_operation_result", operation, result.duplicate(true))


func _affected_peer_ids(result: Dictionary, room_code: String) -> Array:
	var affected = result.get("affected_peer_ids", [])
	if affected is Array and not affected.is_empty():
		return affected.duplicate()
	return _room_peer_ids(room_code)


func _room_peer_ids(room_code: String) -> Array:
	var result = []
	for peer_id in _server_peer_rooms:
		if String(_server_peer_rooms[peer_id]) == room_code:
			result.append(int(peer_id))
	result.sort()
	return result


func _server_room_code(peer_id: int) -> String:
	if _server_peer_rooms.has(peer_id):
		return String(_server_peer_rooms[peer_id])
	return _registry_room_code(peer_id)


func _registry_room_code(peer_id: int, fallback: Dictionary = {}) -> String:
	if _registry != null and _registry.has_method("room_code_for_peer"):
		var value = _registry.call("room_code_for_peer", peer_id)
		if typeof(value) == TYPE_STRING:
			var room_code = String(value)
			if not room_code.is_empty():
				return room_code
	return String(fallback.get("room_code", ""))


func _registry_snapshot(peer_id: int) -> Dictionary:
	var result = _registry_call("snapshot_for_peer", [peer_id])
	if bool(result.get("ok", false)) and result.has("snapshot"):
		return (result["snapshot"] as Dictionary).duplicate(true)
	if bool(result.get("ok", false)):
		return result.duplicate(true)
	return {}


func _server_rank_profile(peer_id: int) -> Dictionary:
	if _account_store == null:
		return {}
	var session_token = String(_server_peer_sessions.get(peer_id, ""))
	if session_token.is_empty():
		return {}
	var result = _account_store.call("profile_for_session", session_token)
	if typeof(result) != TYPE_DICTIONARY or not bool((result as Dictionary).get("ok", false)):
		return {}
	var profile = (result as Dictionary).get("profile", {})
	if typeof(profile) != TYPE_DICTIONARY:
		return {}
	return {
		"user_id": String((result as Dictionary).get("user_id", "")),
		"rank_key": String((profile as Dictionary).get("rank_key", "bronze")),
		"rank_stars": maxi(1, int((profile as Dictionary).get("rank_stars", 1))),
		"elo": maxi(0, int((profile as Dictionary).get("elo", 1000))),
		"deck": ((profile as Dictionary).get("deck", []) as Array).duplicate() if typeof((profile as Dictionary).get("deck", [])) == TYPE_ARRAY else [],
		"card_levels": ((profile as Dictionary).get("card_levels", {}) as Dictionary).duplicate(true) if typeof((profile as Dictionary).get("card_levels", {})) == TYPE_DICTIONARY else {},
	}


func _registry_call(method: String, arguments: Array) -> Dictionary:
	if _registry == null or not _registry.has_method(method):
		return _failure("RoomRegistry 缺少 %s" % method)
	var value = _registry.callv(method, arguments)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return _failure("RoomRegistry.%s 返回格式无效" % method)


func _create_registry() -> Variant:
	var script = load(REGISTRY_PATH)
	if script == null:
		return null
	return script.new()


func _create_account_store() -> Variant:
	var script = load(ACCOUNT_STORE_PATH)
	return script.new() if script != null else null


func _create_match_analytics_store() -> Variant:
	var script = load(MATCH_ANALYTICS_STORE_PATH)
	return script.new() if script != null else null


func _apply_account_operation(operation: String, result: Dictionary) -> void:
	if operation in ["login_account", "authenticate_installation", "switch_account", "create_new_account"]:
		_client_session_token = String(result.get("session_token", ""))
		current_user_id = String(result.get("user_id", ""))
		current_profile = (result.get("profile", {}) as Dictionary).duplicate(true)
		var issued_refresh_token = String(result.get("refresh_token", ""))
		if not issued_refresh_token.is_empty():
			_refresh_token = issued_refresh_token
			_save_device_credentials()
	elif operation in ["load_player_profile", "save_player_profile"]:
		current_user_id = String(result.get("user_id", current_user_id))
		current_profile = (result.get("profile", {}) as Dictionary).duplicate(true)
	elif operation == "logout_account":
		_clear_account_state()
	if result.has("accounts") and typeof(result.get("accounts")) == TYPE_ARRAY:
		current_account_summaries = (result.get("accounts") as Array).duplicate(true)
	account_state_changed.emit({
		"user_id": current_user_id,
		"profile": current_profile.duplicate(true),
		"accounts": current_account_summaries.duplicate(true),
		"logged_in": not current_user_id.is_empty(),
	})


func _clear_account_state() -> void:
	_client_session_token = ""
	current_user_id = ""
	current_profile.clear()
	current_account_summaries.clear()


func _accept_server_request() -> bool:
	return (
		mode == TransportMode.SERVER
		and multiplayer.is_server()
		and multiplayer.get_remote_sender_id() > SERVER_PEER_ID
	)


func _wire_multiplayer_signals() -> void:
	_connect_once(multiplayer.peer_connected, _on_peer_connected)
	_connect_once(multiplayer.peer_disconnected, _on_peer_disconnected)
	_connect_once(multiplayer.connected_to_server, _on_connected_to_server)
	_connect_once(multiplayer.connection_failed, _on_connection_failed)
	_connect_once(multiplayer.server_disconnected, _on_server_disconnected)


func _connect_once(source: Signal, callable: Callable) -> void:
	if not source.is_connected(callable):
		source.connect(callable)


func _on_peer_connected(_peer_id: int) -> void:
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if mode != TransportMode.SERVER:
		return
	var room_code = _server_room_code(peer_id)
	var session_token = String(_server_peer_sessions.get(peer_id, ""))
	if not session_token.is_empty() and _account_store != null:
		_account_store.call("logout", session_token)
	_server_peer_sessions.erase(peer_id)
	var result = _registry_call("peer_disconnected", [peer_id])
	_server_peer_rooms.erase(peer_id)
	if not room_code.is_empty():
		_migrate_match_authority(room_code, peer_id, result)
		_broadcast_room_snapshots(room_code, result)
		_cleanup_empty_room(room_code)


func _on_connected_to_server() -> void:
	if mode != TransportMode.CLIENT:
		return
	_client_connected = true
	server_connected.emit(server_host, server_port, multiplayer.get_unique_id())
	authenticate_default_account()


func _load_or_create_device_credentials() -> void:
	_installation_id = ""
	_refresh_token = ""
	if FileAccess.file_exists(_device_credential_path):
		var file = FileAccess.open(_device_credential_path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_installation_id = String(parsed.get("installation_id", "")).strip_edges().to_lower()
				_refresh_token = String(parsed.get("refresh_token", "")).strip_edges().to_lower()
	if _installation_id.length() != 64 or not _installation_id.is_valid_hex_number(false):
		_installation_id = Crypto.new().generate_random_bytes(32).hex_encode()
		_refresh_token = ""
		_save_device_credentials()


func _save_device_credentials() -> bool:
	var directory = _device_credential_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file = FileAccess.open(_device_credential_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"version": 1,
		"installation_id": _installation_id,
		"refresh_token": _refresh_token,
	}, "\t"))
	return true


func _on_connection_failed() -> void:
	if mode != TransportMode.CLIENT:
		return
	_client_connected = false
	server_connection_failed.emit("无法连接 %s:%d" % [server_host, server_port])


func _on_server_disconnected() -> void:
	if mode != TransportMode.CLIENT:
		return
	_client_connected = false
	_clear_client_room_state(false)
	server_disconnected.emit()


func _cleanup_empty_room(room_code: String) -> void:
	if room_code.is_empty() or not _room_peer_ids(room_code).is_empty():
		return
	_server_room_options.erase(room_code)
	_server_room_matches.erase(room_code)
	_server_authority_sequences.erase(room_code)


func _migrate_match_authority(
	room_code: String,
	departed_peer_id: int,
	leave_result: Dictionary
) -> void:
	if room_code.is_empty() or not _server_room_matches.has(room_code):
		return
	var match_data: Dictionary = _server_room_matches[room_code]
	if int(match_data.get("authority_peer_id", 0)) != departed_peer_id:
		return
	var peer_ids = _room_peer_ids(room_code)
	if peer_ids.is_empty():
		return
	var new_authority = int(leave_result.get("new_host_peer_id", 0))
	if not peer_ids.has(new_authority):
		var first_snapshot = _registry_snapshot(int(peer_ids[0]))
		new_authority = int(first_snapshot.get("authority_peer_id", peer_ids[0]))
	match_data["authority_peer_id"] = new_authority
	_server_room_matches[room_code] = match_data
	_server_authority_sequences[room_code] = -1
	for peer_id_value in peer_ids:
		var peer_id = int(peer_id_value)
		rpc_id(peer_id, "_rpc_receive_authority_changed", {
			"match_id": String(match_data.get("match_id", "")),
			"authority_peer_id": new_authority,
			"is_authority": peer_id == new_authority,
		})


func _clear_client_room_state(emit_left_signal: bool) -> void:
	current_room_snapshot.clear()
	current_match.clear()
	if emit_left_signal:
		room_left.emit()


func _require_client_connection(operation: String) -> bool:
	if is_connected_to_server():
		return true
	_emit_local_failure(operation, "尚未连接互联网房间服务器")
	return false


func _emit_local_failure(operation: String, message: String) -> void:
	last_operation_error = message
	operation_failed.emit(operation, message)


func _server_start_failed(error: Error, message: String) -> Error:
	_enet_peer = null
	_registry = null
	mode = TransportMode.OFFLINE
	server_connection_failed.emit(message)
	return error


func _sanitize_player_name(value: String, peer_id: int) -> String:
	var result = value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	result = result.left(MAX_PLAYER_NAME_LENGTH)
	return result if not result.is_empty() else "玩家%d" % maxi(1, peer_id)


func _sanitize_room_code(value: String) -> String:
	return value.strip_edges().to_upper().replace(" ", "").left(12)


func _sanitize_room_options(options: Dictionary, fallback_size: int) -> Dictionary:
	var players_per_side = clampi(int(options.get("players_per_side", fallback_size)), 1, 3)
	var requested_map_id = String(options.get("map_id", "")).strip_edges().to_lower()
	return {
		"players_per_side": players_per_side,
		"fill_with_ai": bool(options.get("fill_with_ai", false)),
		"map_id": _validated_map_id(players_per_side, requested_map_id),
	}


func _validated_map_id(players_per_side: int, requested_map_id: String) -> String:
	if requested_map_id.is_empty():
		return ""
	var prefix = "%dv%d_" % [players_per_side, players_per_side]
	if not requested_map_id.begins_with(prefix):
		return ""
	var suffix = requested_map_id.trim_prefix(prefix)
	return requested_map_id if suffix in MAP_SUFFIXES else ""


func _select_map_id(room_code: String, players_per_side: int, requested_map_id: String) -> String:
	var validated = _validated_map_id(players_per_side, requested_map_id)
	if not validated.is_empty():
		return validated
	var index = posmod(hash(room_code + ":" + str(_server_match_serial + 1)), MAP_SUFFIXES.size())
	return "%dv%d_%s" % [players_per_side, players_per_side, MAP_SUFFIXES[index]]


func _payload_fits(payload: Dictionary, byte_limit: int) -> bool:
	return var_to_bytes(payload).size() <= byte_limit


func _command_line_value(keys: Array) -> String:
	var arguments = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for argument_value in arguments:
		var argument = String(argument_value)
		for key_value in keys:
			var prefix = "--%s=" % String(key_value)
			if argument.begins_with(prefix):
				return argument.trim_prefix(prefix).strip_edges()
	return ""


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
