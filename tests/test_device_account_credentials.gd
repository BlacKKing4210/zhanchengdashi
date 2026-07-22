extends Node

const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")
const TEST_PATH = "user://tests/device_account_credentials_test.json"

var failures = 0


func _ready() -> void:
	_cleanup()
	var installation_id = "ab".repeat(32)
	var old_token = "cd".repeat(32)
	_write_credentials({
		"version": 1,
		"installation_id": installation_id,
		"refresh_token": old_token,
	})
	var transport = OnlineRoomTransport.new()
	transport.server_host = "old.example.com"
	transport.server_port = 24567
	transport._device_credential_path = TEST_PATH
	transport._load_or_create_device_credentials()
	_expect_equal(transport._installation_id, installation_id, "legacy credentials retain the installation id")
	_expect_equal(transport._refresh_token, "", "legacy credentials clear the unscoped refresh token")
	var migrated = _read_credentials()
	_expect_equal(int(migrated.get("version", 0)), 2, "legacy credentials are migrated to version two")
	_expect_equal(String(migrated.get("server_identity", "")), "old.example.com:24567", "migrated credentials record their server identity")

	_write_credentials({
		"version": 2,
		"installation_id": installation_id,
		"refresh_token": old_token,
		"server_identity": "old.example.com:24567",
	})
	transport.server_host = "cloud.example.com"
	transport.server_port = 24567
	transport._load_or_create_device_credentials()
	_expect_equal(transport._installation_id, installation_id, "endpoint changes retain the installation id")
	_expect_equal(transport._refresh_token, "", "endpoint changes clear the old refresh token")
	var changed_endpoint = _read_credentials()
	_expect_equal(String(changed_endpoint.get("server_identity", "")), "cloud.example.com:24567", "endpoint changes persist the new server identity")

	write_credentials_for_same_endpoint(installation_id, old_token)
	transport.server_host = "cloud.example.com"
	transport.server_port = 24567
	transport._load_or_create_device_credentials()
	_expect_equal(transport._refresh_token, old_token, "same endpoint keeps a valid refresh token")
	transport.free()
	_cleanup()
	if failures == 0:
		print("Device account credential scope tests passed.")
	get_tree().quit(failures)


func write_credentials_for_same_endpoint(installation_id: String, refresh_token: String) -> void:
	_write_credentials({
		"version": 2,
		"installation_id": installation_id,
		"refresh_token": refresh_token,
		"server_identity": "cloud.example.com:24567",
	})


func _write_credentials(value: Dictionary) -> void:
	var directory = TEST_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write test credentials")
		failures += 1
		return
	file.store_string(JSON.stringify(value))
	file.close()


func _read_credentials() -> Dictionary:
	var file = FileAccess.open(TEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary) if typeof(parsed) == TYPE_DICTIONARY else {}


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
