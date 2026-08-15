extends Node

const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")
const DedicatedShutdownControl = preload("res://scripts/server/dedicated_shutdown_control.gd")
const SHUTDOWN_POLL_SECONDS = 0.25
const EXIT_SHUTDOWN_IO_ERROR = 74
const EXIT_SHUTDOWN_CONFIG_ERROR = 78

var online_room: Node
var _shutdown_control: Variant
var _shutdown_control_enabled = false
var _shutdown_poll_elapsed = 0.0
var _shutdown_started = false
var _shutdown_exit_code = -1


func _ready() -> void:
	set_process(false)
	var control_result = _initialize_shutdown_control()
	if not bool(control_result.get("ok", false)):
		push_error("Dedicated shutdown control initialization failed: %s" % String(control_result.get("error", "unknown")))
		get_tree().quit(EXIT_SHUTDOWN_CONFIG_ERROR)
		return
	_shutdown_control_enabled = bool(control_result.get("enabled", false))
	set_process(_shutdown_control_enabled)
	call_deferred("_start_room_server")


func _process(delta: float) -> void:
	if not _shutdown_control_enabled or _shutdown_started:
		return
	_shutdown_poll_elapsed += delta
	if _shutdown_poll_elapsed < SHUTDOWN_POLL_SECONDS:
		return
	_shutdown_poll_elapsed = 0.0
	var request_result: Dictionary = _shutdown_control.call("poll_shutdown_request")
	if bool(request_result.get("accepted", false)):
		_perform_graceful_shutdown()


func _exit_tree() -> void:
	if _shutdown_started:
		return
	var transport_closed = _stop_online_room_and_confirm()
	var control_released = _release_shutdown_control()
	if not transport_closed or not control_released:
		push_error("Dedicated server tree exit could not confirm complete lifecycle cleanup.")


func _start_room_server() -> void:
	online_room = get_node_or_null("/root/OnlineRoom")
	if online_room == null:
		online_room = OnlineRoomTransport.new()
		online_room.name = "OnlineRoom"
		get_tree().root.add_child(online_room)
	elif bool(online_room.call("is_server_running")):
		_print_listening_status(_max_clients_from_environment_and_cli())
		_publish_shutdown_ready_or_abort()
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
	_publish_shutdown_ready_or_abort()


func _initialize_shutdown_control() -> Dictionary:
	_shutdown_control = DedicatedShutdownControl.new()
	return _shutdown_control.call("initialize")


func _publish_shutdown_ready_or_abort() -> bool:
	if not _shutdown_control_enabled:
		return true
	if bool(_shutdown_control.call("publish_ready")):
		print("Dedicated shutdown control is ready for the current server process.")
		return true
	push_error("Dedicated shutdown control could not publish its ready handshake.")
	var transport_closed = _stop_online_room_and_confirm()
	var control_released = _release_shutdown_control() if transport_closed else false
	var exit_code = EXIT_SHUTDOWN_CONFIG_ERROR if transport_closed and control_released else EXIT_SHUTDOWN_IO_ERROR
	_shutdown_started = true
	_shutdown_exit_code = exit_code
	get_tree().quit(exit_code)
	return false


func _perform_graceful_shutdown(quit_tree: bool = true) -> bool:
	if _shutdown_started:
		return _shutdown_exit_code == OK
	_shutdown_started = true
	var transport_closed = _stop_online_room_and_confirm()
	if not transport_closed:
		return _complete_shutdown_failure("transport_close_failed", quit_tree)
	if not bool(_shutdown_control.call(
		"write_result",
		false,
		EXIT_SHUTDOWN_IO_ERROR,
		"shutdown_completion_pending"
	)):
		return _complete_shutdown_failure("result_write_failed", quit_tree, false)
	if not _release_shutdown_control():
		return _complete_shutdown_failure("control_release_failed", quit_tree)
	if not bool(_shutdown_control.call(
		"write_result",
		true,
		OK,
		"graceful_shutdown_complete"
	)):
		return _complete_shutdown_failure("result_write_failed", quit_tree)
	_shutdown_exit_code = OK
	print("Dedicated shutdown completed: transport_close=true control_release=true exit_code=0.")
	if quit_tree and get_tree() != null:
		get_tree().quit(OK)
	return true


func _complete_shutdown_failure(reason: String, quit_tree: bool, write_result: bool = true) -> bool:
	_shutdown_exit_code = EXIT_SHUTDOWN_IO_ERROR
	var result_recorded = false
	if write_result and _shutdown_control != null:
		result_recorded = bool(_shutdown_control.call(
			"write_result",
			false,
			EXIT_SHUTDOWN_IO_ERROR,
			reason
		))
	push_error(
		"Dedicated shutdown failed: reason=%s result_recorded=%s exit_code=%d; residual state is retained fail-closed." % [
			reason,
			str(result_recorded),
			EXIT_SHUTDOWN_IO_ERROR,
		]
	)
	if quit_tree and get_tree() != null:
		get_tree().quit(EXIT_SHUTDOWN_IO_ERROR)
	return false


func _stop_online_room_and_confirm() -> bool:
	if not is_instance_valid(online_room):
		return true
	if not online_room.has_method("stop_transport_and_confirm"):
		push_error("OnlineRoom does not expose confirmed transport shutdown.")
		return false
	var close_result = online_room.call("stop_transport_and_confirm")
	if typeof(close_result) != TYPE_BOOL or not bool(close_result):
		push_error("OnlineRoom did not confirm PlayerAccountStore lifecycle lock release.")
		return false
	return true


func _release_shutdown_control() -> bool:
	if _shutdown_control == null or not bool(_shutdown_control.call("session_is_held")):
		return true
	return bool(_shutdown_control.call("release"))


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
