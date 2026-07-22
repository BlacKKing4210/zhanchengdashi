extends SceneTree

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 24567
const DEFAULT_TIMEOUT_SECONDS := 8.0

var _peer := ENetMultiplayerPeer.new()


func _init() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var host := _command_line_value(["server-host", "host"])
	if host.is_empty():
		host = str(ProjectSettings.get_setting("network/server_host", DEFAULT_HOST)).strip_edges()
	if host.is_empty():
		host = DEFAULT_HOST
	var port := _command_line_value(["server-port", "port"]).to_int()
	if port <= 0:
		port = int(ProjectSettings.get_setting("network/server_port", DEFAULT_PORT))
	if port <= 0:
		port = DEFAULT_PORT

	var error := _peer.create_client(host, port, 3)
	if error != OK:
		push_error("REMOTE_ENET_CREATE_FAILED error=%d host=%s port=%d" % [error, host, port])
		_finish(error)
		return

	var deadline_msec := Time.get_ticks_msec() + int(DEFAULT_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() <= deadline_msec:
		_peer.poll()
		if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			print("REMOTE_ENET_CONNECTED host=%s port=%d" % [host, port])
			_finish(0)
			return
		await process_frame

	push_error("REMOTE_ENET_TIMEOUT host=%s port=%d" % [host, port])
	_finish(3)


func _finish(exit_code: int) -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	quit(exit_code)


func _command_line_value(keys: Array) -> String:
	var arguments := OS.get_cmdline_user_args()
	for argument_value in arguments:
		var argument := String(argument_value)
		for key_value in keys:
			var prefix := "--%s=" % String(key_value)
			if argument.begins_with(prefix):
				return argument.trim_prefix(prefix).strip_edges()
	return ""
