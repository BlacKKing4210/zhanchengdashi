extends Node

const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")
const TEST_PATH = "user://tests/remote_account_auth_failure_delivery.json"
const REMOTE_HOST = "106.15.61.103"
const REMOTE_PORT = 24567

var failures = 0
var transport: Node
var received_operation = ""
var received_error = ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	_write_stale_credentials()
	transport = get_node_or_null("/root/OnlineRoom")
	if transport == null:
		failures += 1
		push_error("shared OnlineRoom autoload is missing")
		get_tree().quit(failures)
		return
	transport.set("_device_credential_path", TEST_PATH)
	transport.operation_failed.connect(func(operation: String, error: String):
		received_operation = operation
		received_error = error
	)
	_expect_equal(
		int(transport.call("connect_to_server", REMOTE_HOST, REMOTE_PORT, "认证回包测试")),
		OK,
		"remote client begins connecting"
	)
	# Keep this probe read-only: it deliberately sends an invalid token and
	# disables the normal self-healing retry, so the public server must respond
	# with a failure and cannot create a test account.
	transport.set("_automatic_auth_retry_used", true)
	_expect_true(
		await _wait_until(func(): return bool(transport.call("is_connected_to_server"))),
		"remote ENet connection is established"
	)
	_expect_true(
		await _wait_until(func(): return received_operation == "authenticate_installation"),
		"public server returns the failed authentication result"
	)
	_expect_equal(received_error, "invalid_device_credentials", "public server rejects the unknown stale token safely")
	transport.call("stop_transport")
	_cleanup()
	if failures == 0:
		print("Remote account authentication failure-delivery test passed.")
	get_tree().quit(failures)


func _write_stale_credentials() -> void:
	var directory = TEST_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if file == null:
		failures += 1
		push_error("could not write remote authentication probe credentials")
		return
	file.store_string(JSON.stringify({
		"version": 2,
		"installation_id": Crypto.new().generate_random_bytes(32).hex_encode(),
		"refresh_token": Crypto.new().generate_random_bytes(32).hex_encode(),
		"server_identity": "%s:%d" % [REMOTE_HOST, REMOTE_PORT],
	}))
	file.close()


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


func _cleanup() -> void:
	for suffix in ["", ".tmp"]:
		var path = TEST_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
