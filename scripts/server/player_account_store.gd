extends RefCounted

const DEFAULT_PATH = "user://server/player_accounts.json"
const PASSWORD_ROUNDS = 12000
const ACCOUNT_MIN_LENGTH = 3
const ACCOUNT_MAX_LENGTH = 32
const PASSWORD_MIN_LENGTH = 8
const PASSWORD_MAX_LENGTH = 72

var storage_path = DEFAULT_PATH
var accounts: Dictionary = {}
var sessions: Dictionary = {}
var installations: Dictionary = {}


func _init(path_override: String = "") -> void:
	if not path_override.is_empty():
		storage_path = path_override
	_load()


func register_account(account: String, password: String) -> Dictionary:
	var key = _account_key(account)
	var error = _credential_error(key, password)
	if not error.is_empty():
		return _failure(error)
	if accounts.has(key):
		return _failure("account_exists")
	var salt = _random_hex(16)
	var now = int(Time.get_unix_time_from_system())
	var record = {
		"user_id": _new_user_id(),
		"account": account.strip_edges(),
		"salt": salt,
		"password_hash": _password_hash(password, salt),
		"created_at_unix": now,
		"updated_at_unix": now,
		"profile": _normalize_profile({}),
	}
	accounts[key] = record
	if not _save():
		accounts.erase(key)
		return _failure("storage_error")
	return _success({"user_id": record["user_id"]})


func login(account: String, password: String) -> Dictionary:
	var key = _account_key(account)
	if not accounts.has(key):
		return _failure("invalid_credentials")
	var record: Dictionary = accounts[key]
	var expected = String(record.get("password_hash", ""))
	var actual = _password_hash(password, String(record.get("salt", "")))
	if expected.is_empty() or actual != expected:
		return _failure("invalid_credentials")
	var token = _random_hex(32)
	sessions[token] = String(record["user_id"])
	return _success({
		"user_id": record["user_id"],
		"session_token": token,
		"profile": (record["profile"] as Dictionary).duplicate(true),
	})


func authenticate_installation(installation_id: String, refresh_token: String) -> Dictionary:
	var installation_hash = _installation_hash(installation_id)
	if installation_hash.is_empty():
		return _failure("invalid_installation_id")
	if installations.has(installation_hash):
		return _login_installation(installation_hash, refresh_token)
	if not refresh_token.is_empty():
		return _failure("invalid_device_credentials")
	return _register_installation(installation_hash)


func logout(session_token: String) -> Dictionary:
	if session_token.is_empty() or not sessions.has(session_token):
		return _failure("invalid_session")
	sessions.erase(session_token)
	return _success()


func profile_for_session(session_token: String) -> Dictionary:
	var record = _record_for_session(session_token)
	if record.is_empty():
		return _failure("invalid_session")
	return _success({
		"user_id": record["user_id"],
		"profile": (record["profile"] as Dictionary).duplicate(true),
	})


func save_profile(session_token: String, profile: Dictionary) -> Dictionary:
	var user_id = String(sessions.get(session_token, ""))
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_session")
	var record: Dictionary = accounts[key]
	record["profile"] = _normalize_profile(profile)
	record["updated_at_unix"] = int(Time.get_unix_time_from_system())
	accounts[key] = record
	if not _save():
		return _failure("storage_error")
	return profile_for_session(session_token)


func _record_for_session(session_token: String) -> Dictionary:
	var key = _key_for_user_id(String(sessions.get(session_token, "")))
	return (accounts[key] as Dictionary) if not key.is_empty() else {}


func _register_installation(installation_hash: String) -> Dictionary:
	var refresh_token = _random_hex(32)
	var token_salt = _random_hex(16)
	var now = int(Time.get_unix_time_from_system())
	var user_id = _new_user_id()
	var account_key = "device:%s" % user_id.to_lower()
	accounts[account_key] = {
		"user_id": user_id,
		"account": "",
		"salt": "",
		"password_hash": "",
		"created_at_unix": now,
		"updated_at_unix": now,
		"profile": _normalize_profile({}),
	}
	installations[installation_hash] = {
		"user_id": user_id,
		"token_salt": token_salt,
		"refresh_token_hash": _refresh_token_hash(refresh_token, token_salt),
		"created_at_unix": now,
		"updated_at_unix": now,
	}
	if not _save():
		accounts.erase(account_key)
		installations.erase(installation_hash)
		return _failure("storage_error")
	var result = _create_session(user_id)
	result["refresh_token"] = refresh_token
	result["new_account"] = true
	return result


func _login_installation(installation_hash: String, refresh_token: String) -> Dictionary:
	if refresh_token.length() != 64 or not refresh_token.is_valid_hex_number(false):
		return _failure("invalid_device_credentials")
	var binding: Dictionary = installations[installation_hash]
	var expected = String(binding.get("refresh_token_hash", ""))
	var actual = _refresh_token_hash(refresh_token, String(binding.get("token_salt", "")))
	if expected.is_empty() or actual != expected:
		return _failure("invalid_device_credentials")
	var user_id = String(binding.get("user_id", ""))
	if _key_for_user_id(user_id).is_empty():
		return _failure("invalid_device_credentials")
	return _create_session(user_id)


func _create_session(user_id: String) -> Dictionary:
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_device_credentials")
	var token = _random_hex(32)
	sessions[token] = user_id
	var record: Dictionary = accounts[key]
	return _success({
		"user_id": user_id,
		"session_token": token,
		"profile": (record["profile"] as Dictionary).duplicate(true),
	})


func _key_for_user_id(user_id: String) -> String:
	if user_id.is_empty():
		return ""
	for key in accounts:
		if String((accounts[key] as Dictionary).get("user_id", "")) == user_id:
			return String(key)
	return ""


func _normalize_profile(source: Dictionary) -> Dictionary:
	return {
		"card_counts": _positive_int_dictionary(source.get("card_counts", {}), 0),
		"card_levels": _positive_int_dictionary(source.get("card_levels", {}), 1),
		"deck": _string_array(source.get("deck", []), 8),
		"gacha_tickets": maxi(0, int(source.get("gacha_tickets", 10))),
		"rank_stars": maxi(0, int(source.get("rank_stars", 1))),
		"rank_key": String(source.get("rank_key", "bronze")).strip_edges(),
		"elo": maxi(0, int(source.get("elo", 1000))),
	}


func _positive_int_dictionary(value: Variant, minimum: int) -> Dictionary:
	var result = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value:
		var id = String(key).strip_edges()
		if not id.is_empty():
			result[id] = maxi(minimum, int(value[key]))
	return result


func _string_array(value: Variant, limit: int) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var id = String(item).strip_edges()
		if not id.is_empty() and not result.has(id):
			result.append(id)
		if result.size() >= limit:
			break
	return result


func _credential_error(account_key: String, password: String) -> String:
	if account_key.length() < ACCOUNT_MIN_LENGTH or account_key.length() > ACCOUNT_MAX_LENGTH:
		return "invalid_account"
	if password.length() < PASSWORD_MIN_LENGTH or password.length() > PASSWORD_MAX_LENGTH:
		return "invalid_password"
	return ""


func _account_key(account: String) -> String:
	return account.strip_edges().to_lower()


func _password_hash(password: String, salt: String) -> String:
	var value = (salt + ":" + password).sha256_text()
	for _round in range(PASSWORD_ROUNDS - 1):
		value = (value + ":" + salt).sha256_text()
	return value


func _installation_hash(installation_id: String) -> String:
	var normalized = installation_id.strip_edges().to_lower()
	if normalized.length() != 64 or not normalized.is_valid_hex_number(false):
		return ""
	return ("zhanchengdashi-installation-v1:" + normalized).sha256_text()


func _refresh_token_hash(refresh_token: String, salt: String) -> String:
	return ("zhanchengdashi-refresh-v1:" + salt + ":" + refresh_token).sha256_text()


func _new_user_id() -> String:
	return "U-%d-%s" % [int(Time.get_unix_time_from_system()), _random_hex(5).to_upper()]


func _random_hex(byte_count: int) -> String:
	var crypto = Crypto.new()
	return crypto.generate_random_bytes(byte_count).hex_encode()


func _load() -> void:
	accounts.clear()
	installations.clear()
	if not FileAccess.file_exists(storage_path):
		return
	var file = FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("accounts", {})) == TYPE_DICTIONARY:
		accounts = (parsed["accounts"] as Dictionary).duplicate(true)
		if typeof(parsed.get("installations", {})) == TYPE_DICTIONARY:
			installations = (parsed["installations"] as Dictionary).duplicate(true)


func _save() -> bool:
	var directory = storage_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var temporary_path = storage_path + ".tmp"
	var file = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"version": 2,
		"accounts": accounts,
		"installations": installations,
	}, "\t"))
	file.close()
	var absolute_target = ProjectSettings.globalize_path(storage_path)
	var absolute_temporary = ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(storage_path):
		DirAccess.remove_absolute(absolute_target)
	return DirAccess.rename_absolute(absolute_temporary, absolute_target) == OK


func _success(extra: Dictionary = {}) -> Dictionary:
	var result = {"ok": true}
	result.merge(extra, true)
	return result


func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
