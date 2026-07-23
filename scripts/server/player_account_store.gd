extends RefCounted

const RankMirrorRules = preload("res://scripts/app/systems/rank_mirror_rules.gd")

const DEFAULT_PATH = "user://server/player_accounts.json"
const PASSWORD_ROUNDS = 12000
const ACCOUNT_MIN_LENGTH = 3
const ACCOUNT_MAX_LENGTH = 32
const PASSWORD_MIN_LENGTH = 8
const PASSWORD_MAX_LENGTH = 72
const RECOVERY_SECRET_HASH_PREFIX = "zhanchengdashi-recovery-v1:"
const MAX_INSTALLATION_ACCOUNTS = 8

const RANK_NAMES = {
	"bronze": "青铜",
	"silver": "白银",
	"gold": "黄金",
	"platinum": "铂金",
	"diamond": "钻石",
	"star": "星耀",
	"king": "王者",
}

var storage_path = DEFAULT_PATH
var accounts: Dictionary = {}
var sessions: Dictionary = {}
var session_installations: Dictionary = {}
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


func login(
	account: String,
	password: String,
	installation_id: String = "",
	refresh_token: String = "",
	animal_card_ids: Array = [],
	recovery_secret: String = ""
) -> Dictionary:
	var key = _account_key(account)
	if not accounts.has(key):
		return _failure("invalid_credentials")
	var record: Dictionary = accounts[key]
	var expected = String(record.get("password_hash", ""))
	var actual = _password_hash(password, String(record.get("salt", "")))
	if expected.is_empty() or actual != expected:
		return _failure("invalid_credentials")
	var user_id = String(record["user_id"])
	var installation_hash = _installation_hash(installation_id)
	var issued_refresh_token = ""
	if not installation_id.is_empty():
		if installation_hash.is_empty():
			return _failure("invalid_installation_id")
		var binding_result = _bind_installation_to_user(installation_hash, user_id, refresh_token, recovery_secret)
		if not bool(binding_result.get("ok", false)):
			return binding_result
		issued_refresh_token = String(binding_result.get("refresh_token", ""))
	var result = _create_session(user_id, installation_hash)
	if not installation_hash.is_empty():
		result["accounts"] = _account_summaries(installation_hash, animal_card_ids)
	if not issued_refresh_token.is_empty():
		result["refresh_token"] = issued_refresh_token
	return result


func authenticate_installation(
	installation_id: String,
	refresh_token: String,
	starter_profile: Dictionary = {},
	animal_card_ids: Array = [],
	recovery_secret: String = ""
) -> Dictionary:
	var installation_hash = _installation_hash(installation_id)
	if installation_hash.is_empty():
		return _failure("invalid_installation_id")
	if installations.has(installation_hash):
		return _login_installation(installation_hash, refresh_token, animal_card_ids, recovery_secret)
	if not refresh_token.is_empty():
		return _failure("invalid_device_credentials")
	return _register_installation(installation_hash, starter_profile, animal_card_ids, recovery_secret)


func logout(session_token: String) -> Dictionary:
	if session_token.is_empty() or not sessions.has(session_token):
		return _failure("invalid_session")
	sessions.erase(session_token)
	session_installations.erase(session_token)
	return _success()


func account_summaries_for_session(session_token: String, animal_card_ids: Array = []) -> Dictionary:
	if not sessions.has(session_token):
		return _failure("invalid_session")
	var installation_hash = String(session_installations.get(session_token, ""))
	if installation_hash.is_empty() or not installations.has(installation_hash):
		return _failure("invalid_session")
	return _success({
		"user_id": String(sessions[session_token]),
		"accounts": _account_summaries(installation_hash, animal_card_ids),
	})


func create_account_for_session(
	session_token: String,
	starter_profile: Dictionary,
	animal_card_ids: Array = []
) -> Dictionary:
	if not sessions.has(session_token):
		return _failure("invalid_session")
	var installation_hash = String(session_installations.get(session_token, ""))
	if installation_hash.is_empty() or not installations.has(installation_hash):
		return _failure("invalid_session")
	var previous_binding: Dictionary = (installations[installation_hash] as Dictionary).duplicate(true)
	var user_ids = _installation_user_ids(previous_binding)
	if user_ids.size() >= MAX_INSTALLATION_ACCOUNTS:
		return _failure("account_limit")
	var now = int(Time.get_unix_time_from_system())
	var user_id = _new_user_id()
	var account_key = "device:%s" % user_id.to_lower()
	accounts[account_key] = _device_account_record(user_id, now, starter_profile)
	user_ids.append(user_id)
	var binding = previous_binding.duplicate(true)
	binding["user_ids"] = user_ids
	binding["user_id"] = user_id
	binding["updated_at_unix"] = now
	installations[installation_hash] = binding
	if not _save():
		accounts.erase(account_key)
		installations[installation_hash] = previous_binding
		return _failure("storage_error")
	logout(session_token)
	var result = _create_session(user_id, installation_hash)
	result["new_account"] = true
	result["accounts"] = _account_summaries(installation_hash, animal_card_ids)
	return result


func switch_account(
	session_token: String,
	target_user_id: String,
	animal_card_ids: Array = []
) -> Dictionary:
	if not sessions.has(session_token):
		return _failure("invalid_session")
	var installation_hash = String(session_installations.get(session_token, ""))
	if installation_hash.is_empty() or not installations.has(installation_hash):
		return _failure("invalid_session")
	var previous_binding: Dictionary = (installations[installation_hash] as Dictionary).duplicate(true)
	var user_ids = _installation_user_ids(previous_binding)
	if not user_ids.has(target_user_id) or _key_for_user_id(target_user_id).is_empty():
		return _failure("account_not_owned")
	if String(sessions[session_token]) == target_user_id:
		var current_record = _record_for_session(session_token)
		return _success({
			"user_id": target_user_id,
			"session_token": session_token,
			"profile": (current_record.get("profile", {}) as Dictionary).duplicate(true),
			"accounts": _account_summaries(installation_hash, animal_card_ids),
		})
	var binding = previous_binding.duplicate(true)
	binding["user_ids"] = user_ids
	binding["user_id"] = target_user_id
	binding["updated_at_unix"] = int(Time.get_unix_time_from_system())
	installations[installation_hash] = binding
	if not _save():
		installations[installation_hash] = previous_binding
		return _failure("storage_error")
	logout(session_token)
	var result = _create_session(target_user_id, installation_hash)
	result["accounts"] = _account_summaries(installation_hash, animal_card_ids)
	return result


func profile_for_session(session_token: String) -> Dictionary:
	var user_id = String(sessions.get(session_token, ""))
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_session")
	var record: Dictionary = accounts[key]
	var profile_value = record.get("profile", {})
	var existing_profile = (profile_value as Dictionary).duplicate(true) if typeof(profile_value) == TYPE_DICTIONARY else {}
	var normalized_profile = _normalize_profile(existing_profile)
	if JSON.stringify(existing_profile) != JSON.stringify(normalized_profile):
		record["profile"] = normalized_profile
		record["updated_at_unix"] = int(Time.get_unix_time_from_system())
		accounts[key] = record
		if not _save():
			return _failure("storage_error")
	return _success({
		"user_id": record["user_id"],
		"profile": normalized_profile.duplicate(true),
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


func _register_installation(
	installation_hash: String,
	starter_profile: Dictionary,
	animal_card_ids: Array,
	recovery_secret: String = ""
) -> Dictionary:
	var refresh_token = _random_hex(32)
	var token_salt = _random_hex(16)
	var now = int(Time.get_unix_time_from_system())
	var user_id = _new_user_id()
	var account_key = "device:%s" % user_id.to_lower()
	accounts[account_key] = _device_account_record(user_id, now, starter_profile)
	var binding = {
		"user_id": user_id,
		"user_ids": [user_id],
		"token_salt": token_salt,
		"refresh_token_hash": _refresh_token_hash(refresh_token, token_salt),
		"created_at_unix": now,
		"updated_at_unix": now,
	}
	if _is_valid_recovery_secret(recovery_secret):
		binding = _binding_with_recovery_secret(binding, recovery_secret)
	installations[installation_hash] = binding
	if not _save():
		accounts.erase(account_key)
		installations.erase(installation_hash)
		return _failure("storage_error")
	var result = _create_session(user_id, installation_hash)
	result["refresh_token"] = refresh_token
	result["new_account"] = true
	result["accounts"] = _account_summaries(installation_hash, animal_card_ids)
	return result


func _bind_installation_to_user(
	installation_hash: String,
	user_id: String,
	refresh_token: String,
	recovery_secret: String = ""
) -> Dictionary:
	if _key_for_user_id(user_id).is_empty():
		return _failure("invalid_credentials")
	var now = int(Time.get_unix_time_from_system())
	var had_previous_binding = installations.has(installation_hash)
	var previous_binding: Dictionary = (installations[installation_hash] as Dictionary).duplicate(true) if had_previous_binding else {}
	var issued_refresh_token = ""
	var token_salt = ""
	var binding: Dictionary = {}
	if had_previous_binding:
		var user_ids = _installation_user_ids(previous_binding)
		if not user_ids.has(user_id):
			if user_ids.size() >= MAX_INSTALLATION_ACCOUNTS:
				return _failure("account_limit")
			user_ids.append(user_id)
		binding = previous_binding.duplicate(true)
		binding["user_id"] = user_id
		binding["user_ids"] = user_ids
		binding["updated_at_unix"] = now
		if not _installation_token_is_valid(installation_hash, refresh_token):
			issued_refresh_token = _random_hex(32)
			token_salt = _random_hex(16)
			binding["token_salt"] = token_salt
			binding["refresh_token_hash"] = _refresh_token_hash(issued_refresh_token, token_salt)
	else:
		issued_refresh_token = _random_hex(32)
		token_salt = _random_hex(16)
		binding = {
			"user_id": user_id,
			"user_ids": [user_id],
			"token_salt": token_salt,
			"refresh_token_hash": _refresh_token_hash(issued_refresh_token, token_salt),
			"created_at_unix": now,
			"updated_at_unix": now,
		}
	if _is_valid_recovery_secret(recovery_secret):
		binding = _binding_with_recovery_secret(binding, recovery_secret)
	installations[installation_hash] = binding
	if not _save():
		if had_previous_binding:
			installations[installation_hash] = previous_binding
		else:
			installations.erase(installation_hash)
		return _failure("storage_error")
	var result = _success()
	if not issued_refresh_token.is_empty():
		result["refresh_token"] = issued_refresh_token
	return result


func _login_installation(
	installation_hash: String,
	refresh_token: String,
	animal_card_ids: Array,
	recovery_secret: String = ""
) -> Dictionary:
	if not _installation_token_is_valid(installation_hash, refresh_token):
		if not _installation_recovery_secret_is_valid(installation_hash, recovery_secret):
			return _failure("invalid_device_credentials")
		return _recover_installation_with_recovery_secret(installation_hash, recovery_secret, animal_card_ids)
	var binding: Dictionary = (installations[installation_hash] as Dictionary).duplicate(true)
	var user_id = String(binding.get("user_id", ""))
	if _key_for_user_id(user_id).is_empty() or not _installation_user_ids(binding).has(user_id):
		return _failure("invalid_device_credentials")
	if _is_valid_recovery_secret(recovery_secret) and not _installation_recovery_secret_is_valid(installation_hash, recovery_secret):
		var previous_binding = binding.duplicate(true)
		binding = _binding_with_recovery_secret(binding, recovery_secret)
		binding["updated_at_unix"] = int(Time.get_unix_time_from_system())
		installations[installation_hash] = binding
		if not _save():
			installations[installation_hash] = previous_binding
			return _failure("storage_error")
	var result = _create_session(user_id, installation_hash)
	result["accounts"] = _account_summaries(installation_hash, animal_card_ids)
	return result


func _recover_installation_with_recovery_secret(
	installation_hash: String,
	recovery_secret: String,
	animal_card_ids: Array
) -> Dictionary:
	if not _installation_recovery_secret_is_valid(installation_hash, recovery_secret):
		return _failure("invalid_device_credentials")
	var previous_binding: Dictionary = (installations[installation_hash] as Dictionary).duplicate(true)
	var binding = previous_binding.duplicate(true)
	var user_id = String(binding.get("user_id", ""))
	if _key_for_user_id(user_id).is_empty() or not _installation_user_ids(binding).has(user_id):
		return _failure("invalid_device_credentials")
	var issued_refresh_token = _random_hex(32)
	var token_salt = _random_hex(16)
	binding["token_salt"] = token_salt
	binding["refresh_token_hash"] = _refresh_token_hash(issued_refresh_token, token_salt)
	binding["updated_at_unix"] = int(Time.get_unix_time_from_system())
	installations[installation_hash] = binding
	if not _save():
		installations[installation_hash] = previous_binding
		return _failure("storage_error")
	var result = _create_session(user_id, installation_hash)
	result["refresh_token"] = issued_refresh_token
	result["accounts"] = _account_summaries(installation_hash, animal_card_ids)
	return result


func _create_session(user_id: String, installation_hash: String = "") -> Dictionary:
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_device_credentials")
	var token = _random_hex(32)
	sessions[token] = user_id
	if not installation_hash.is_empty():
		session_installations[token] = installation_hash
	var record: Dictionary = accounts[key]
	return _success({
		"user_id": user_id,
		"session_token": token,
		"profile": (record["profile"] as Dictionary).duplicate(true),
	})


func _device_account_record(user_id: String, now: int, starter_profile: Dictionary) -> Dictionary:
	return {
		"user_id": user_id,
		"account": "",
		"salt": "",
		"password_hash": "",
		"created_at_unix": now,
		"updated_at_unix": now,
		"profile": _normalize_profile(starter_profile),
	}


func _installation_token_is_valid(installation_hash: String, refresh_token: String) -> bool:
	if installation_hash.is_empty() or not installations.has(installation_hash):
		return false
	if refresh_token.length() != 64 or not refresh_token.is_valid_hex_number(false):
		return false
	var binding: Dictionary = installations[installation_hash]
	var expected = String(binding.get("refresh_token_hash", ""))
	var actual = _refresh_token_hash(refresh_token, String(binding.get("token_salt", "")))
	return not expected.is_empty() and actual == expected

func _is_valid_recovery_secret(recovery_secret: String) -> bool:
	return recovery_secret.length() == 64 and recovery_secret.is_valid_hex_number(false)


func _installation_recovery_secret_is_valid(installation_hash: String, recovery_secret: String) -> bool:
	if installation_hash.is_empty() or not installations.has(installation_hash) or not _is_valid_recovery_secret(recovery_secret):
		return false
	var binding: Dictionary = installations[installation_hash]
	var salt = String(binding.get("recovery_secret_salt", ""))
	var expected = String(binding.get("recovery_secret_hash", ""))
	if salt.is_empty() or expected.is_empty():
		return false
	return _recovery_secret_hash(recovery_secret, salt) == expected


func _binding_with_recovery_secret(binding: Dictionary, recovery_secret: String) -> Dictionary:
	var result = binding.duplicate(true)
	var salt = _random_hex(16)
	result["recovery_secret_salt"] = salt
	result["recovery_secret_hash"] = _recovery_secret_hash(recovery_secret, salt)
	return result



func _installation_user_ids(binding: Dictionary) -> Array:
	var result = []
	var raw_user_ids = binding.get("user_ids", [])
	if typeof(raw_user_ids) == TYPE_ARRAY:
		for raw_user_id in raw_user_ids:
			var user_id = String(raw_user_id).strip_edges()
			if not user_id.is_empty() and not result.has(user_id) and not _key_for_user_id(user_id).is_empty():
				result.append(user_id)
			if result.size() >= MAX_INSTALLATION_ACCOUNTS:
				break
	var active_user_id = String(binding.get("user_id", "")).strip_edges()
	if not active_user_id.is_empty() and not result.has(active_user_id) and not _key_for_user_id(active_user_id).is_empty():
		result.push_front(active_user_id)
	return result


func _account_summaries(installation_hash: String, animal_card_ids: Array) -> Array:
	if installation_hash.is_empty() or not installations.has(installation_hash):
		return []
	var binding: Dictionary = installations[installation_hash]
	var active_user_id = String(binding.get("user_id", ""))
	var result = []
	for user_id in _installation_user_ids(binding):
		var key = _key_for_user_id(user_id)
		if key.is_empty():
			continue
		var record: Dictionary = accounts[key]
		var profile: Dictionary = record.get("profile", {})
		var rank_key = String(profile.get("rank_key", "bronze")).strip_edges().to_lower()
		var rank_stars = maxi(1, int(profile.get("rank_stars", 1)))
		result.append({
			"user_id": user_id,
			"rank_key": rank_key,
			"rank_stars": rank_stars,
			"rank_display": "%s %d星" % [String(RANK_NAMES.get(rank_key, RANK_NAMES["bronze"])), rank_stars],
			"animal_count": _animal_count(profile, animal_card_ids),
			"is_active": user_id == active_user_id,
		})
	return result


func _animal_count(profile: Dictionary, animal_card_ids: Array) -> int:
	var allowed_ids = {}
	for raw_card_id in animal_card_ids:
		var card_id = String(raw_card_id).strip_edges()
		if not card_id.is_empty():
			allowed_ids[card_id] = true
	var count = 0
	var card_counts = profile.get("card_counts", {})
	if typeof(card_counts) != TYPE_DICTIONARY:
		return 0
	for raw_card_id in card_counts:
		var card_id = String(raw_card_id)
		if allowed_ids.is_empty() or allowed_ids.has(card_id):
			count += maxi(0, int(card_counts[raw_card_id]))
	return count


func _key_for_user_id(user_id: String) -> String:
	if user_id.is_empty():
		return ""
	for key in accounts:
		if String((accounts[key] as Dictionary).get("user_id", "")) == user_id:
			return String(key)
	return ""


func _normalize_profile(source: Dictionary) -> Dictionary:
	var mirror_policy_version = maxi(0, int(source.get("rank_mirror_policy_version", 0)))
	var rank_mirrors = _normalize_rank_mirrors(source.get("rank_mirrors", {}))
	rank_mirrors = RankMirrorRules.migrate_legacy_mirrors(rank_mirrors, mirror_policy_version)
	return {
		"card_counts": _positive_int_dictionary(source.get("card_counts", {}), 0),
		"card_levels": _positive_int_dictionary(source.get("card_levels", {}), 1),
		"deck": _string_array(source.get("deck", []), 8),
		"gacha_tickets": maxi(0, int(source.get("gacha_tickets", 10))),
		"rank_stars": maxi(0, int(source.get("rank_stars", 1))),
		"rank_key": String(source.get("rank_key", "bronze")).strip_edges(),
		"elo": maxi(0, int(source.get("elo", 1000))),
		"rank_mirrors": rank_mirrors,
		"rank_mirror_policy_version": RankMirrorRules.POLICY_VERSION,
	}


func _normalize_rank_mirrors(value: Variant) -> Dictionary:
	var result = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_rank_key in value:
		var rank_key = String(raw_rank_key).strip_edges().to_lower()
		if rank_key.is_empty() or rank_key.length() > 24 or typeof(value[raw_rank_key]) != TYPE_ARRAY:
			continue
		var records = []
		for raw_record in value[raw_rank_key]:
			if typeof(raw_record) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = raw_record
			var record_deck = _string_array(record.get("deck", []), 8)
			if record_deck.is_empty():
				continue
			var levels = _positive_int_dictionary(record.get("card_levels", {}), 1)
			var deck_levels = {}
			for card_id in record_deck:
				deck_levels[card_id] = maxi(1, int(levels.get(card_id, 1)))
			records.append({
				"mirror_id": String(record.get("mirror_id", "")).strip_edges().left(80),
				"player_id": String(record.get("player_id", "")).strip_edges().left(80),
				"name": String(record.get("name", "")).strip_edges().left(40),
				"rank_key": rank_key,
				"rank_display": String(record.get("rank_display", "")).strip_edges().left(40),
				"stars": maxi(0, int(record.get("stars", 0))),
				"elo": maxi(0, int(record.get("elo", 0))),
				"deck": record_deck,
				"card_levels": deck_levels,
				"created_at_unix": maxi(0, int(record.get("created_at_unix", 0))),
			})
			if records.size() >= 15:
				break
		if not records.is_empty():
			result[rank_key] = records
	return result


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

func _recovery_secret_hash(recovery_secret: String, salt: String) -> String:
	return (RECOVERY_SECRET_HASH_PREFIX + salt + ":" + recovery_secret).sha256_text()



func _new_user_id() -> String:
	return "U-%d-%s" % [int(Time.get_unix_time_from_system()), _random_hex(5).to_upper()]


func _random_hex(byte_count: int) -> String:
	var crypto = Crypto.new()
	return crypto.generate_random_bytes(byte_count).hex_encode()


func _load() -> void:
	accounts.clear()
	sessions.clear()
	session_installations.clear()
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
