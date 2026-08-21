extends Node

const DedicatedShutdownControl = preload("res://scripts/server/dedicated_shutdown_control.gd")
const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")
const PlayerAccountStore = preload("res://scripts/server/player_account_store.gd")
const ServerMain = preload("res://scripts/server/server_main.gd")

const TEST_ROOT = "user://tests/dedicated_shutdown_control"
const CONTROL_ROOT = TEST_ROOT + "/runtime"
const ACCOUNT_PATH = TEST_ROOT + "/authority/player_accounts.json"
const FAILURE_ACCOUNT_PATH = TEST_ROOT + "/failure_authority/player_accounts.json"
const RESULT_FAILURE_ACCOUNT_PATH = TEST_ROOT + "/result_failure_authority/player_accounts.json"

var failures = 0


func _ready() -> void:
	_remove_tree(TEST_ROOT)
	_expect(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTROL_ROOT)) == OK,
		"isolated shutdown control root is created"
	)
	_test_environment_control_root_contract()
	_test_token_bound_request_and_confirmed_close()
	_test_release_is_idempotent_and_foreign_owner_is_preserved()
	_test_residual_control_session_fails_closed()
	_test_close_failure_is_visible_and_retained()
	_test_result_previous_cleanup_failure_never_exposes_fixed_success()
	_remove_tree(TEST_ROOT)
	if failures == 0:
		print("DEDICATED_SHUTDOWN_CONTROL_TEST_PASS")
	else:
		push_error("DEDICATED_SHUTDOWN_CONTROL_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _test_environment_control_root_contract() -> void:
	var original_root = OS.get_environment(DedicatedShutdownControl.ENV_CONTROL_ROOT)
	OS.set_environment(DedicatedShutdownControl.ENV_CONTROL_ROOT, ProjectSettings.globalize_path(CONTROL_ROOT))
	var control = DedicatedShutdownControl.new()
	var initialized: Dictionary = control.initialize()
	_expect(bool(initialized.get("ok", false)) and bool(initialized.get("enabled", false)), "explicit shutdown control environment enables the bridge")
	_expect(control.release(), "environment-configured control session releases explicitly")
	OS.set_environment(DedicatedShutdownControl.ENV_CONTROL_ROOT, original_root)
	var disabled_control = DedicatedShutdownControl.new()
	if original_root.is_empty():
		var disabled_result: Dictionary = disabled_control.initialize()
		_expect(bool(disabled_result.get("ok", false)) and not bool(disabled_result.get("enabled", true)), "unset shutdown control environment leaves the bridge disabled")


func _test_token_bound_request_and_confirmed_close() -> void:
	var control = DedicatedShutdownControl.new()
	var control_root = ProjectSettings.globalize_path(CONTROL_ROOT)
	var initialized: Dictionary = control.initialize(control_root)
	_expect(bool(initialized.get("ok", false)) and bool(initialized.get("enabled", false)), "explicit native control root enables the shutdown bridge")
	_expect(control.publish_ready(), "ready handshake is published after initialization")
	var ready = _read_json(control.ready_path)
	var token = String(ready.get("token", ""))
	_expect(token.length() == 64 and token.is_valid_hex_number(false), "ready handshake carries a fresh 32-byte token")
	_expect(int(ready.get("pid", 0)) == OS.get_process_id(), "ready handshake is bound to the current process")

	_expect(_write_json(control.request_path, {
		"version": 1,
		"action": "shutdown",
		"pid": OS.get_process_id(),
		"token": "00".repeat(32),
		"requested_at_unix": int(Time.get_unix_time_from_system()),
	}), "foreign-token shutdown request fixture is written")
	var rejected: Dictionary = control.poll_shutdown_request()
	_expect(not bool(rejected.get("accepted", false)), "foreign-token shutdown request is rejected")
	_expect(_path_is_directory(control.session_path), "rejected request does not release the control session")
	_remove_file(control.request_path)
	_expect(_write_json(control.request_path, {
		"version": 1,
		"action": "shutdown",
		"pid": OS.get_process_id(),
		"token": token,
		"requested_at_unix": int(Time.get_unix_time_from_system()),
	}), "matching shutdown request fixture is written")
	_expect(bool(control.poll_shutdown_request().get("accepted", false)), "matching token and pid request is accepted")

	var store = PlayerAccountStore.new(ACCOUNT_PATH)
	_expect(store.is_authority_storage_ready(), "shutdown test authority owns its isolated lifecycle lock")
	var authority_lock_path = "%s.write_lock" % ACCOUNT_PATH
	_expect(_path_is_directory(authority_lock_path), "authority lifecycle lock exists before shutdown")
	var transport = OnlineRoomTransport.new()
	transport.set("_account_store", store)
	var server_main = ServerMain.new()
	server_main.online_room = transport
	server_main.set("_shutdown_control", control)
	server_main.set("_shutdown_control_enabled", true)
	_expect(bool(server_main.call("_perform_graceful_shutdown", false)), "main-thread shutdown confirms transport and store close")
	_expect(bool(server_main.call("_perform_graceful_shutdown", false)), "repeated main-thread shutdown is idempotently successful")
	_expect(not _path_is_directory(authority_lock_path), "confirmed shutdown releases the authority lifecycle lock")
	_expect(not _path_is_directory(control.session_path), "confirmed shutdown releases its owned control session")
	var result = _read_json(control.result_path)
	_expect(bool(result.get("ok", false)) and int(result.get("exit_code", -1)) == 0, "confirmed shutdown records an exit-zero result")
	_expect(String(result.get("token", "")) == token, "shutdown result is bound to the accepted startup token")
	_expect(not FileAccess.file_exists("%s.previous" % control.result_path), "confirmed shutdown leaves no previous-result rejection guard")
	_expect(not control.write_result(false, 74, "must_not_overwrite_success"), "clean-release result slot is consumed exactly once")
	_expect(bool(_read_json(control.result_path).get("ok", false)), "a consumed clean-release result cannot be overwritten")
	server_main.free()
	transport.free()
	store = null

	var restarted_control = DedicatedShutdownControl.new()
	_expect(bool(restarted_control.initialize(control_root).get("ok", false)), "a new server session starts after confirmed shutdown cleanup")
	_expect(restarted_control.release(), "restarted control session explicitly releases before ready publication")
	_expect(restarted_control.release(), "repeated control release is idempotently safe")


func _test_release_is_idempotent_and_foreign_owner_is_preserved() -> void:
	var control = DedicatedShutdownControl.new()
	_expect(bool(control.initialize(ProjectSettings.globalize_path(CONTROL_ROOT)).get("ok", false)), "foreign-owner test acquires the control session")
	_expect(control.publish_ready(), "foreign-owner test publishes ready")
	var ready = _read_json(control.ready_path)
	var owned_token = String(ready.get("token", ""))
	_expect(_write_text(control.owner_path, "different-owner-token"), "foreign owner token replaces the recorded control owner")
	_expect(not control.release(), "control release refuses another owner token")
	_expect(_path_is_directory(control.session_path), "foreign owner control session is not deleted")
	_expect(_read_text(control.owner_path) == "different-owner-token", "foreign owner token remains unchanged")
	_expect(_write_text(control.owner_path, owned_token), "exact original control owner token is restored for bounded cleanup")
	_expect(control.release(), "restored exact control owner permits cleanup")
	_expect(control.release(), "cleanup remains idempotent after ownership release")


func _test_residual_control_session_fails_closed() -> void:
	var session_path = ProjectSettings.globalize_path(CONTROL_ROOT).path_join(DedicatedShutdownControl.SESSION_DIRECTORY_NAME)
	_expect(DirAccess.make_dir_absolute(session_path) == OK, "crash-simulation control session is created")
	_expect(_write_text(session_path.path_join(DedicatedShutdownControl.OWNER_TOKEN_BASENAME), "dead-process-token"), "crash-simulation owner token is written")
	var restart = DedicatedShutdownControl.new()
	var restart_result: Dictionary = restart.initialize(ProjectSettings.globalize_path(CONTROL_ROOT))
	_expect(not bool(restart_result.get("ok", true)), "residual shutdown control session makes restart fail closed")
	_expect(_path_is_directory(session_path), "residual control session is never guessed safe or deleted")
	_expect(_read_text(session_path.path_join(DedicatedShutdownControl.OWNER_TOKEN_BASENAME)) == "dead-process-token", "residual owner token remains byte-for-byte unchanged")
	_remove_tree(session_path)


func _test_close_failure_is_visible_and_retained() -> void:
	var control = DedicatedShutdownControl.new()
	_expect(bool(control.initialize(ProjectSettings.globalize_path(CONTROL_ROOT)).get("ok", false)), "close-failure test acquires the control session")
	_expect(control.publish_ready(), "close-failure test publishes ready")
	var ready = _read_json(control.ready_path)
	var request_payload = {
		"version": 1,
		"action": "shutdown",
		"pid": int(ready.get("pid", 0)),
		"token": String(ready.get("token", "")),
		"requested_at_unix": int(Time.get_unix_time_from_system()),
	}
	_expect(_write_json(control.request_path, request_payload), "close-failure matching request is written")
	_expect(bool(control.poll_shutdown_request().get("accepted", false)), "close-failure matching request is accepted")

	var store = PlayerAccountStore.new(FAILURE_ACCOUNT_PATH)
	var authority_lock_path = "%s.write_lock" % FAILURE_ACCOUNT_PATH
	var authority_owner_path = authority_lock_path.path_join("owner_token")
	var authority_owner_token = String(store.authority_lifecycle_lock_token)
	_expect(_write_text(authority_owner_path, "different-authority-owner"), "authority owner mismatch fault is injected")
	var transport = OnlineRoomTransport.new()
	transport.set("_account_store", store)
	var server_main = ServerMain.new()
	server_main.online_room = transport
	server_main.set("_shutdown_control", control)
	server_main.set("_shutdown_control_enabled", true)
	_expect(not bool(server_main.call("_perform_graceful_shutdown", false)), "authority close failure returns a non-success shutdown result")
	_expect(int(server_main.get("_shutdown_exit_code")) == ServerMain.EXIT_SHUTDOWN_IO_ERROR, "authority close failure selects exit code 74")
	_expect(_path_is_directory(authority_lock_path), "failed authority close retains the lifecycle lock fail closed")
	_expect(_path_is_directory(control.session_path), "failed authority close retains the control session fail closed")
	var result = _read_json(control.result_path)
	_expect(not bool(result.get("ok", true)) and String(result.get("reason", "")) == "transport_close_failed", "failed authority close records a diagnostic result")

	_expect(_write_text(authority_owner_path, authority_owner_token), "exact authority owner token is restored for bounded test cleanup")
	_expect(transport.stop_transport_and_confirm(), "restored authority owner permits explicit cleanup")
	_expect(control.release(), "failed-shutdown control session is explicitly cleaned after restoring its exact owner")
	server_main.free()
	transport.free()
	store = null


func _test_result_previous_cleanup_failure_never_exposes_fixed_success() -> void:
	var control = DedicatedShutdownControl.new()
	_expect(bool(control.initialize(ProjectSettings.globalize_path(CONTROL_ROOT)).get("ok", false)), "result-cleanup failure test acquires the control session")
	_expect(control.publish_ready(), "result-cleanup failure test publishes ready")
	var store = PlayerAccountStore.new(RESULT_FAILURE_ACCOUNT_PATH)
	var authority_lock_path = "%s.write_lock" % RESULT_FAILURE_ACCOUNT_PATH
	_expect(store.is_authority_storage_ready() and _path_is_directory(authority_lock_path), "result-cleanup failure test owns its authority lifecycle lock")
	var transport = OnlineRoomTransport.new()
	transport.set("_account_store", store)
	var server_main = ServerMain.new()
	server_main.online_room = transport
	server_main.set("_shutdown_control", control)
	server_main.set("_shutdown_control_enabled", true)
	control.set("_test_fail_result_previous_cleanup_on_success", true)
	_expect(not bool(server_main.call("_perform_graceful_shutdown", false)), "post-commit previous cleanup fault makes shutdown non-success")
	_expect(int(server_main.get("_shutdown_exit_code")) == ServerMain.EXIT_SHUTDOWN_IO_ERROR, "post-commit previous cleanup fault selects exit code 74")
	_expect(not _path_is_directory(authority_lock_path), "post-commit result fault occurs only after authority lock release")
	_expect(not _path_is_directory(control.session_path), "post-commit result fault occurs only after strict control release")
	var fixed_result = _read_json(control.result_path)
	_expect(not bool(fixed_result.get("ok", true)), "fixed result main is never success after process exit 74")
	_expect(int(fixed_result.get("exit_code", 0)) == ServerMain.EXIT_SHUTDOWN_IO_ERROR, "fixed result main records exit code 74")
	_expect(String(fixed_result.get("reason", "")) == "result_write_failed", "fixed result main records the post-release result failure")
	_expect(
		not bool(fixed_result.get("ok", false)) or FileAccess.file_exists("%s.previous" % control.result_path),
		"any fixed success left by an unrecoverable rollback remains accompanied by .previous for helper rejection"
	)
	var failed_commit_results = _result_failed_commit_payloads(control.control_root)
	_expect(failed_commit_results.size() == 1, "the unconfirmed success is isolated in one uniquely named failure slot")
	if failed_commit_results.size() == 1:
		var isolated_result: Dictionary = failed_commit_results[0]
		_expect(bool(isolated_result.get("ok", false)) and int(isolated_result.get("exit_code", -1)) == 0, "isolated failure slot preserves the unconfirmed success for diagnosis only")
	_expect(not control.write_result(true, 0, "must_not_recover_after_failure"), "post-release result slot is consumed by the explicit failure result")
	server_main.free()
	transport.free()
	store = null


func _write_json(path: String, payload: Dictionary) -> bool:
	return _write_text(path, JSON.stringify(payload, "\t"))


func _write_text(path: String, text: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var write_error = file.get_error()
	file.close()
	return write_error == OK


func _read_json(path: String) -> Dictionary:
	var value = JSON.parse_string(_read_text(path))
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text = file.get_as_text()
	file.close()
	return text


func _result_failed_commit_payloads(control_root: String) -> Array:
	var directory = DirAccess.open(control_root)
	if directory == null:
		return []
	var result: Array = []
	var prefix = "%s.failed_commit_" % DedicatedShutdownControl.RESULT_BASENAME
	directory.list_dir_begin()
	var entry = directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and entry.begins_with(prefix):
			result.append(_read_json(control_root.path_join(entry)))
		entry = directory.get_next()
	directory.list_dir_end()
	return result


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _path_is_directory(path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


func _remove_tree(path: String) -> void:
	var absolute_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
		return
	var directory = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry = directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."]:
			var child = path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
