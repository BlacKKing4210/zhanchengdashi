extends RefCounted

const ENV_CONTROL_ROOT = "ZHANCHENG_SHUTDOWN_CONTROL_ROOT"
const SESSION_DIRECTORY_NAME = "junglelaw-server.shutdown"
const OWNER_TOKEN_BASENAME = "owner_token"
const READY_BASENAME = "ready.json"
const REQUEST_BASENAME = "request.json"
const RESULT_BASENAME = "junglelaw-server.shutdown-result.json"
const CONTROL_VERSION = 1
const MAX_CONTROL_FILE_BYTES = 4096

var control_root = ""
var session_path = ""
var owner_path = ""
var ready_path = ""
var request_path = ""
var result_path = ""

var _owner_token = ""
var _process_id = 0
var _initialized = false
var _session_held = false
var _clean_release_completed = false
var _post_release_result_available = false
var _ready_published = false
var _last_rejected_request_reason = ""
var _test_fail_result_previous_cleanup_on_success = false


func initialize(root_override: String = "") -> Dictionary:
	if _session_held:
		return _failure("already_initialized")
	var requested_root = root_override.strip_edges()
	if requested_root.is_empty():
		requested_root = OS.get_environment(ENV_CONTROL_ROOT).strip_edges()
	if requested_root.is_empty():
		return {"ok": true, "enabled": false}
	if requested_root.begins_with("res://") or requested_root.begins_with("user://") or not requested_root.is_absolute_path():
		return _failure("control_root_must_be_native_absolute")
	control_root = requested_root.simplify_path()
	if not DirAccess.dir_exists_absolute(control_root):
		return _failure("control_root_unavailable")
	if not _control_root_permissions_are_private():
		return _failure("control_root_permissions_not_private")

	session_path = control_root.path_join(SESSION_DIRECTORY_NAME)
	owner_path = session_path.path_join(OWNER_TOKEN_BASENAME)
	ready_path = session_path.path_join(READY_BASENAME)
	request_path = session_path.path_join(REQUEST_BASENAME)
	result_path = control_root.path_join(RESULT_BASENAME)
	_owner_token = Crypto.new().generate_random_bytes(32).hex_encode()
	_process_id = OS.get_process_id()
	var session_error = DirAccess.make_dir_absolute(session_path)
	if session_error != OK:
		return _failure("control_session_unavailable")
	if not _write_text_new(owner_path, _owner_token) or _read_text(owner_path) != _owner_token:
		_cleanup_unclaimed_session()
		return _failure("control_owner_token_unwritable")
	_initialized = true
	_session_held = true
	_clean_release_completed = false
	_post_release_result_available = false
	return {"ok": true, "enabled": true}


func publish_ready() -> bool:
	if not _session_is_owned() or _ready_published:
		return false
	if _path_entry_state(ready_path) != "missing" or _path_entry_state(request_path) != "missing":
		return false
	var ready_payload = {
		"version": CONTROL_VERSION,
		"state": "ready",
		"pid": _process_id,
		"token": _owner_token,
		"started_at_unix": int(Time.get_unix_time_from_system()),
	}
	if not _write_json_new(ready_path, ready_payload):
		return false
	_ready_published = true
	return true


func poll_shutdown_request() -> Dictionary:
	if not _session_held or not _ready_published:
		return {"accepted": false}
	var request_state = _path_entry_state(request_path)
	if request_state == "missing":
		return {"accepted": false}
	if request_state != "file":
		return _reject_request("request_not_regular_file")
	var read_result = _read_json_dictionary(request_path)
	if not bool(read_result.get("ok", false)):
		return _reject_request(String(read_result.get("error", "request_unreadable")))
	var payload: Dictionary = read_result.get("payload", {})
	if not _integer_field_matches(payload, "version", CONTROL_VERSION):
		return _reject_request("request_version_mismatch")
	if String(payload.get("action", "")) != "shutdown":
		return _reject_request("request_action_mismatch")
	if not _integer_field_matches(payload, "pid", _process_id):
		return _reject_request("request_pid_mismatch")
	var token = String(payload.get("token", ""))
	if token.length() != 64 or token != _owner_token:
		return _reject_request("request_token_mismatch")
	_last_rejected_request_reason = ""
	return {"accepted": true}


func write_result(ok: bool, exit_code: int, reason: String) -> bool:
	if not _initialized or _owner_token.is_empty() or result_path.is_empty():
		return false
	if _clean_release_completed and not _post_release_result_available:
		return false
	if not _clean_release_completed and not _session_is_owned():
		return false
	var written = _replace_json(result_path, {
		"version": CONTROL_VERSION,
		"pid": _process_id,
		"token": _owner_token,
		"ok": ok,
		"exit_code": exit_code,
		"reason": reason,
		"completed_at_unix": int(Time.get_unix_time_from_system()),
	})
	if written and _clean_release_completed:
		_post_release_result_available = false
	return written


func release() -> bool:
	if not _session_held:
		return true
	if not _session_is_owned():
		push_error("Dedicated shutdown control ownership does not match; the session was not removed.")
		return false
	if _path_entry_state(request_path) == "file":
		var request_result = _read_json_dictionary(request_path)
		var request_payload: Dictionary = request_result.get("payload", {})
		if (
			not bool(request_result.get("ok", false))
			or String(request_payload.get("token", "")) != _owner_token
			or int(request_payload.get("pid", 0)) != _process_id
		):
			push_error("Dedicated shutdown control request ownership does not match; the session was not removed.")
			return false
		if not _remove_file(request_path, "request"):
			return false
	elif _path_entry_state(request_path) != "missing":
		push_error("Dedicated shutdown control request path is not a regular file; the session was not removed.")
		return false
	if _path_entry_state(ready_path) == "file":
		var ready_result = _read_json_dictionary(ready_path)
		var ready_payload: Dictionary = ready_result.get("payload", {})
		if (
			not bool(ready_result.get("ok", false))
			or String(ready_payload.get("token", "")) != _owner_token
			or int(ready_payload.get("pid", 0)) != _process_id
		):
			push_error("Dedicated shutdown control ready ownership does not match; the session was not removed.")
			return false
		if not _remove_file(ready_path, "ready"):
			return false
	elif _ready_published or _path_entry_state(ready_path) != "missing":
		push_error("Dedicated shutdown control ready file disappeared or changed type; the session was not removed.")
		return false
	if not _remove_file(owner_path, "owner token"):
		return false
	var session_remove_error = DirAccess.remove_absolute(session_path)
	if session_remove_error != OK:
		push_error("Dedicated shutdown control session release failed (error %d)." % session_remove_error)
		return false
	_session_held = false
	_clean_release_completed = true
	_post_release_result_available = true
	_ready_published = false
	return true


func is_enabled() -> bool:
	return _session_held


func session_is_held() -> bool:
	return _session_held


func _control_root_permissions_are_private() -> bool:
	if OS.get_name() == "Windows":
		return true
	var permissions = FileAccess.get_unix_permissions(control_root)
	return permissions >= 0 and (permissions & 63) == 0 and (permissions & 448) == 448


func _session_is_owned() -> bool:
	return (
		_session_held
		and not _owner_token.is_empty()
		and _path_entry_state(session_path) == "directory"
		and _read_text(owner_path) == _owner_token
	)


func _reject_request(reason: String) -> Dictionary:
	if reason != _last_rejected_request_reason:
		push_warning("Dedicated shutdown request rejected (%s); it was left untouched." % reason)
		_last_rejected_request_reason = reason
	return {"accepted": false, "error": reason}


func _integer_field_matches(payload: Dictionary, field_name: String, expected: int) -> bool:
	var value = payload.get(field_name, null)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number = float(value)
	return number == floor(number) and int(number) == expected


func _write_json_new(path: String, payload: Dictionary) -> bool:
	# The runtime uses this only for owner/ready files inside the atomically
	# acquired, private session directory. The external stop helper owns the
	# request path and must create it with a real no-replace operation.
	var temporary_path = "%s.%d.%s.tmp" % [path, Time.get_ticks_usec(), Crypto.new().generate_random_bytes(4).hex_encode()]
	if not _write_text_new(temporary_path, JSON.stringify(payload, "\t")):
		return false
	if _path_entry_state(path) != "missing":
		_remove_file_if_present(temporary_path)
		return false
	var commit_error = DirAccess.rename_absolute(temporary_path, path)
	if commit_error == OK:
		return true
	_remove_file_if_present(temporary_path)
	return false


func _write_text_new(path: String, text: String) -> bool:
	if _path_entry_state(path) != "missing":
		return false
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var write_error = file.get_error()
	file.close()
	return write_error == OK and _read_text(path) == text


func _replace_json(path: String, payload: Dictionary) -> bool:
	var serialized = JSON.stringify(payload, "\t")
	var temporary_path = "%s.%d.%s.tmp" % [path, Time.get_ticks_usec(), Crypto.new().generate_random_bytes(4).hex_encode()]
	if not _write_text_new(temporary_path, serialized):
		return false
	var previous_path = "%s.previous" % path
	var previous_state = _path_entry_state(previous_path)
	var target_state = _path_entry_state(path)
	if target_state == "missing":
		if path == result_path and previous_state != "missing":
			_remove_file_if_present(temporary_path)
			return false
		var create_error = DirAccess.rename_absolute(temporary_path, path)
		if create_error == OK:
			return true
		_remove_file_if_present(temporary_path)
		return false
	if target_state != "file":
		_remove_file_if_present(temporary_path)
		return false
	if previous_state == "file":
		if path == result_path:
			_remove_file_if_present(temporary_path)
			return false
		if DirAccess.remove_absolute(previous_path) != OK:
			_remove_file_if_present(temporary_path)
			return false
	elif previous_state != "missing":
		_remove_file_if_present(temporary_path)
		return false
	if DirAccess.rename_absolute(path, previous_path) != OK:
		_remove_file_if_present(temporary_path)
		return false
	var commit_error = DirAccess.rename_absolute(temporary_path, path)
	if commit_error != OK:
		if path != result_path:
			DirAccess.rename_absolute(previous_path, path)
		_remove_file_if_present(temporary_path)
		return false
	var previous_cleanup_error = OK
	if path == result_path and bool(payload.get("ok", false)) and _test_fail_result_previous_cleanup_on_success:
		_test_fail_result_previous_cleanup_on_success = false
		previous_cleanup_error = ERR_CANT_CREATE
	else:
		previous_cleanup_error = DirAccess.remove_absolute(previous_path)
	if previous_cleanup_error != OK:
		_rollback_committed_result(path, previous_path, previous_cleanup_error)
		return false
	return true


func _rollback_committed_result(path: String, previous_path: String, cleanup_error: Error) -> void:
	var failed_commit_path = "%s.failed_commit_%d_%s" % [
		path,
		Time.get_ticks_usec(),
		Crypto.new().generate_random_bytes(4).hex_encode(),
	]
	var isolate_error = DirAccess.rename_absolute(path, failed_commit_path)
	if isolate_error != OK:
		push_error(
			"Dedicated shutdown result previous cleanup failed (error %d) and committed-result isolation failed (error %d); fixed success remains accompanied by .previous and must be rejected." % [
				cleanup_error,
				isolate_error,
			]
		)
		return
	var restore_error = DirAccess.rename_absolute(previous_path, path)
	if restore_error != OK:
		push_error(
			"Dedicated shutdown result previous cleanup failed (error %d); committed success was isolated but previous-result restoration failed (error %d)." % [
				cleanup_error,
				restore_error,
			]
		)
		return
	push_error(
		"Dedicated shutdown result previous cleanup failed (error %d); committed success was isolated and the previous non-success result was restored." % cleanup_error
	)


func _read_json_dictionary(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("request_unreadable")
	var length = file.get_length()
	if length <= 0 or length > MAX_CONTROL_FILE_BYTES:
		file.close()
		return _failure("request_size_invalid")
	var text = file.get_as_text()
	var read_error = file.get_error()
	file.close()
	if read_error != OK:
		return _failure("request_unreadable")
	var value = JSON.parse_string(text)
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("request_json_invalid")
	return {"ok": true, "payload": value}


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text = file.get_as_text()
	var read_error = file.get_error()
	file.close()
	return text if read_error == OK else ""


func _remove_file(path: String, label: String) -> bool:
	var remove_error = DirAccess.remove_absolute(path)
	if remove_error == OK:
		return true
	push_error("Dedicated shutdown control %s release failed (error %d)." % [label, remove_error])
	return false


func _remove_file_if_present(path: String) -> void:
	if _path_entry_state(path) == "file":
		DirAccess.remove_absolute(path)


func _cleanup_unclaimed_session() -> void:
	_remove_file_if_present(owner_path)
	DirAccess.remove_absolute(session_path)


func _path_entry_state(path: String) -> String:
	if path.is_empty():
		return "missing"
	var parent = DirAccess.open(path.get_base_dir())
	if parent == null:
		return "missing"
	var expected_name = path.get_file()
	parent.list_dir_begin()
	var entry_name = parent.get_next()
	while not entry_name.is_empty():
		var matches = entry_name == expected_name
		if OS.get_name() == "Windows":
			matches = entry_name.to_lower() == expected_name.to_lower()
		if matches:
			var state = "directory" if parent.current_is_dir() else "file"
			parent.list_dir_end()
			return state
		entry_name = parent.get_next()
	parent.list_dir_end()
	return "missing"


func _failure(error: String) -> Dictionary:
	return {"ok": false, "enabled": false, "error": error}
