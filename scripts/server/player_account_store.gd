extends RefCounted

const ProfileAdapter = preload("res://scripts/server/player_account_profile_adapter.gd")
const LifecycleLock = preload("res://scripts/server/player_account_lifecycle_lock.gd")
const AccountCredentialRules = preload("res://scripts/shared/account_credential_rules.gd")
const AccountIdentityRules = preload("res://scripts/shared/account_identity_rules.gd")

const DEFAULT_PATH = "user://server/player_accounts.json"
const ADMIN_ACCOUNTS_SNAPSHOT_BASENAME = "admin_accounts_snapshot.json"
const DEFAULT_ADMIN_COMMAND_DIRECTORY_NAME = "admin_commands"
const AUTHORITY_LOCK_OWNER_BASENAME = "owner_token"
const PASSWORD_ROUNDS = 12000
const ACCOUNT_MIN_LENGTH = 3
const ACCOUNT_MAX_LENGTH = 32
const PASSWORD_MIN_LENGTH = 8
const PASSWORD_MAX_LENGTH = 72
const MAX_INSTALLATION_ACCOUNTS = 8
const RECOVERY_SECRET_HASH_PREFIX = "zhanchengdashi-recovery-v1:"
const PROFILE_REVISION_FIELD = "_profile_revision"
const MAX_AUTHORITY_BYTES = 64 * 1024 * 1024
const MAX_ADMIN_COMMAND_BYTES = 8 * 1024 * 1024
const MAX_ADMIN_COMMAND_GRANTS = 20
const MAX_ADMIN_GRANT_AMOUNT = 100000
const MAX_ADMIN_SELECTED_TARGETS = 500
const MAX_ADMIN_COMMANDS_PER_POLL = 20
const MAX_ADMIN_COMMAND_RECEIPTS = 5000

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
var admin_command_receipts: Dictionary = {}
var profile_adapter: RefCounted
var admin_accounts_snapshot_path = ""
var admin_card_catalog: Dictionary = {}
var admin_command_root = ""
var authority_storage_ready = true
var admin_snapshot_ready = false
var authority_extra_fields: Dictionary = {}
var last_atomic_write_cleanup_degraded = false
var authority_lifecycle_storage_path = ""
var authority_lifecycle_lock_path = ""
var authority_lifecycle_lock_owner_path = ""
var authority_lifecycle_lock_token = ""
var authority_lifecycle_lock_held = false


func _init(path_override: String = "", adapter: RefCounted = null) -> void:
	profile_adapter = adapter if adapter != null else ProfileAdapter.new()
	if not path_override.is_empty():
		storage_path = path_override
	var storage_directory = storage_path.get_base_dir()
	admin_accounts_snapshot_path = OS.get_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH").strip_edges()
	if admin_accounts_snapshot_path.is_empty():
		admin_accounts_snapshot_path = storage_directory.path_join(ADMIN_ACCOUNTS_SNAPSHOT_BASENAME)
	admin_command_root = OS.get_environment("ZHANCHENG_DASHBOARD_COMMAND_ROOT").strip_edges()
	if admin_command_root.is_empty():
		admin_command_root = storage_directory.path_join(DEFAULT_ADMIN_COMMAND_DIRECTORY_NAME)
	_load()
	if not authority_storage_ready:
		return
	_ensure_admin_command_directories()
	admin_snapshot_ready = _write_admin_accounts_snapshot() and not last_atomic_write_cleanup_degraded
	if not admin_snapshot_ready:
		push_error("PlayerAccountStore could not write the sanitized admin account snapshot.")


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or not authority_lifecycle_lock_held:
		return
	authority_lifecycle_lock_held = false
	LifecycleLock.release(
		authority_lifecycle_lock_path,
		authority_lifecycle_lock_owner_path,
		authority_lifecycle_lock_token,
		"object destruction"
	)


func is_authority_storage_ready() -> bool:
	return authority_storage_ready


func is_admin_snapshot_ready() -> bool:
	return admin_snapshot_ready


func close() -> bool:
	if not authority_lifecycle_lock_held:
		return true
	var released = LifecycleLock.release(
		authority_lifecycle_lock_path,
		authority_lifecycle_lock_owner_path,
		authority_lifecycle_lock_token,
		"explicit close"
	)
	if released:
		authority_lifecycle_lock_held = false
	return released


func register_account(account: String, password: String) -> Dictionary:
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
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
		"username": account.strip_edges().left(AccountIdentityRules.USERNAME_MAX_LENGTH),
		"avatar_id": AccountIdentityRules.DEFAULT_AVATAR_ID,
		"identity_revision": 1,
		"identity_complete": true,
		"auto_generated": false,
		"salt": salt,
		"password_hash": _password_hash(password, salt),
		"created_at_unix": now,
		"updated_at_unix": now,
		"profile_revision": 1,
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
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
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
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
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
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
	if not sessions.has(session_token):
		return _failure("invalid_session")
	var installation_hash = String(session_installations.get(session_token, ""))
	if installation_hash.is_empty() or not installations.has(installation_hash):
		return _failure("invalid_session")
	return _success({
		"user_id": String(sessions[session_token]),
		"accounts": _account_summaries(installation_hash, animal_card_ids),
	})


func set_auto_account_credentials_for_session(
	session_token: String,
	password: String,
	animal_card_ids: Array = []
) -> Dictionary:
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
	if not sessions.has(session_token):
		return _failure("invalid_session")
	var user_id = String(sessions[session_token])
	var old_key = _key_for_user_id(user_id)
	var normalized_password = password.strip_edges().to_lower()
	if (
		old_key.is_empty()
		or not AccountCredentialRules.is_valid_auto_account_id(user_id)
		or not _is_valid_auto_password(normalized_password)
	):
		return _failure("invalid_credentials")
	var previous_record: Dictionary = (accounts[old_key] as Dictionary).duplicate(true)
	var record: Dictionary = previous_record.duplicate(true)
	var account_name = String(record.get("account", "")).strip_edges()
	var has_password = not String(record.get("password_hash", "")).is_empty()
	var is_generated = bool(record.get("auto_generated", false))
	if account_name.is_empty() and not has_password and not is_generated:
		var new_key = _account_key(user_id)
		if accounts.has(new_key) and new_key != old_key:
			return _failure("account_exists")
		var salt = _random_hex(16)
		record["account"] = user_id
		record["auto_generated"] = true
		record["salt"] = salt
		record["password_hash"] = _password_hash(normalized_password, salt)
		record["updated_at_unix"] = int(Time.get_unix_time_from_system())
		accounts.erase(old_key)
		accounts[new_key] = record
		if not _save():
			accounts.erase(new_key)
			accounts[old_key] = previous_record
			return _failure("storage_error")
	elif (
		not AccountCredentialRules.is_auto_account(account_name, user_id, is_generated)
		or not has_password
		or _password_hash(normalized_password, String(record.get("salt", "")))
			!= String(record.get("password_hash", ""))
	):
		return _failure("invalid_credentials")
	var result = _session_result(session_token, true)
	var installation_hash = String(session_installations.get(session_token, ""))
	if not installation_hash.is_empty():
		result["accounts"] = _account_summaries(installation_hash, animal_card_ids)
	return result


func create_account_for_session(
	session_token: String,
	starter_profile: Dictionary,
	animal_card_ids: Array = []
) -> Dictionary:
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
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
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
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
			"account": String(current_record.get("account", "")),
			"username": String(current_record.get("username", "")),
			"avatar_id": String(current_record.get("avatar_id", AccountIdentityRules.DEFAULT_AVATAR_ID)),
			"identity_revision": maxi(1, int(current_record.get("identity_revision", 1))),
			"identity_complete": bool(current_record.get("identity_complete", true)),
			"has_password": not String(current_record.get("password_hash", "")).is_empty(),
			"auto_generated": bool(current_record.get("auto_generated", false)),
			"auto_password_local": false,
			"session_token": session_token,
			"profile": (current_record.get("profile", {}) as Dictionary).duplicate(true),
			"profile_revision": maxi(1, int(current_record.get("profile_revision", 1))),
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
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
	var user_id = String(sessions.get(session_token, ""))
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_session")
	var previous_record: Dictionary = (accounts[key] as Dictionary).duplicate(true)
	var record: Dictionary = previous_record.duplicate(true)
	var profile_value = record.get("profile", {})
	var existing_profile = (profile_value as Dictionary).duplicate(true) if typeof(profile_value) == TYPE_DICTIONARY else {}
	var normalized_profile = _normalize_profile(existing_profile)
	if JSON.stringify(existing_profile) != JSON.stringify(normalized_profile):
		record["profile"] = normalized_profile
		record["profile_revision"] = maxi(1, int(record.get("profile_revision", 1))) + 1
		record["updated_at_unix"] = int(Time.get_unix_time_from_system())
		accounts[key] = record
		if not _save():
			accounts[key] = previous_record
			return _failure("storage_error")
	return _success({
		"user_id": record["user_id"],
		"account": String(record.get("account", "")),
		"username": String(record.get("username", "")),
		"avatar_id": String(record.get("avatar_id", AccountIdentityRules.DEFAULT_AVATAR_ID)),
		"identity_revision": maxi(1, int(record.get("identity_revision", 1))),
		"identity_complete": bool(record.get("identity_complete", true)),
		"has_password": not String(record.get("password_hash", "")).is_empty(),
		"auto_generated": bool(record.get("auto_generated", false)),
		"profile": normalized_profile.duplicate(true),
		"profile_revision": maxi(1, int(record.get("profile_revision", 1))),
		"conflict": false,
	})


func update_identity(
	session_token: String,
	username: String,
	avatar_id: String,
	expected_revision: int,
	animal_card_ids: Array = []
) -> Dictionary:
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
	var user_id = String(sessions.get(session_token, ""))
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_session")
	var normalized_username = AccountIdentityRules.normalize_username(username)
	var username_error = AccountIdentityRules.username_error(normalized_username)
	if not username_error.is_empty():
		return _failure(username_error)
	var normalized_avatar_id = avatar_id.strip_edges().to_lower()
	if not AccountIdentityRules.is_runtime_avatar_id(normalized_avatar_id, animal_card_ids):
		return _failure("invalid_avatar")
	var previous_record: Dictionary = (accounts[key] as Dictionary).duplicate(true)
	var previous_avatar_id = String(previous_record.get("avatar_id", AccountIdentityRules.DEFAULT_AVATAR_ID)).strip_edges().to_lower()
	var profile_value = previous_record.get("profile", {})
	var profile: Dictionary = profile_value if typeof(profile_value) == TYPE_DICTIONARY else {}
	var counts_value = profile.get("card_counts", {})
	var owned_card_counts: Dictionary = counts_value if typeof(counts_value) == TYPE_DICTIONARY else {}
	if not AccountIdentityRules.avatar_is_unlocked(normalized_avatar_id, owned_card_counts, previous_avatar_id):
		return _failure("avatar_locked")
	var current_revision = maxi(1, int(previous_record.get("identity_revision", 1)))
	if expected_revision != current_revision:
		return _identity_result(previous_record, true)
	var record = previous_record.duplicate(true)
	record["username"] = normalized_username
	record["avatar_id"] = normalized_avatar_id
	record["identity_revision"] = current_revision + 1
	record["identity_complete"] = true
	record["updated_at_unix"] = int(Time.get_unix_time_from_system())
	accounts[key] = record
	if not _save():
		accounts[key] = previous_record
		return _failure("storage_error")
	return _identity_result(record, false)


func save_profile(session_token: String, profile: Dictionary) -> Dictionary:
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
	var user_id = String(sessions.get(session_token, ""))
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_session")
	var previous_record: Dictionary = (accounts[key] as Dictionary).duplicate(true)
	var record: Dictionary = previous_record.duplicate(true)
	var current_revision = maxi(1, int(record.get("profile_revision", 1)))
	var supplied_revision = int(profile.get(PROFILE_REVISION_FIELD, profile.get("profile_revision", -1)))
	if supplied_revision < 0 and current_revision == 1:
		# One compatibility write lets pre-CAS local tests and clients migrate.
		supplied_revision = current_revision
	if supplied_revision != current_revision:
		return _profile_result(record, true)
	var profile_source = profile.duplicate(true)
	profile_source.erase(PROFILE_REVISION_FIELD)
	profile_source.erase("profile_revision")
	record["profile"] = _normalize_profile(profile_source)
	record["profile_revision"] = current_revision + 1
	record["updated_at_unix"] = int(Time.get_unix_time_from_system())
	accounts[key] = record
	if not _save():
		accounts[key] = previous_record
		return _failure("storage_error")
	return _profile_result(record, false)


func _profile_result(record: Dictionary, conflict: bool) -> Dictionary:
	return _success({
		"user_id": String(record.get("user_id", "")),
		"account": String(record.get("account", "")),
		"username": String(record.get("username", "")),
		"avatar_id": String(record.get("avatar_id", AccountIdentityRules.DEFAULT_AVATAR_ID)),
		"identity_revision": maxi(1, int(record.get("identity_revision", 1))),
		"identity_complete": bool(record.get("identity_complete", true)),
		"has_password": not String(record.get("password_hash", "")).is_empty(),
		"auto_generated": bool(record.get("auto_generated", false)),
		"profile": (record.get("profile", {}) as Dictionary).duplicate(true),
		"profile_revision": maxi(1, int(record.get("profile_revision", 1))),
		"conflict": conflict,
	})


func _identity_result(record: Dictionary, conflict: bool) -> Dictionary:
	return _success({
		"user_id": String(record.get("user_id", "")),
		"account": String(record.get("account", "")),
		"username": String(record.get("username", "")),
		"avatar_id": String(record.get("avatar_id", AccountIdentityRules.DEFAULT_AVATAR_ID)),
		"identity_revision": maxi(1, int(record.get("identity_revision", 1))),
		"identity_complete": bool(record.get("identity_complete", true)),
		"conflict": conflict,
	})


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


func _create_session(
	user_id: String,
	installation_hash: String = "",
	auto_password_local: bool = false
) -> Dictionary:
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_device_credentials")
	var token = _random_hex(32)
	sessions[token] = user_id
	if not installation_hash.is_empty():
		session_installations[token] = installation_hash
	return _session_result(token, auto_password_local)


func _session_result(session_token: String, auto_password_local: bool = false) -> Dictionary:
	var user_id = String(sessions.get(session_token, ""))
	var key = _key_for_user_id(user_id)
	if key.is_empty():
		return _failure("invalid_session")
	var record: Dictionary = accounts[key]
	return _success({
		"user_id": user_id,
		"account": String(record.get("account", "")),
		"username": String(record.get("username", "")),
		"avatar_id": String(record.get("avatar_id", AccountIdentityRules.DEFAULT_AVATAR_ID)),
		"identity_revision": maxi(1, int(record.get("identity_revision", 1))),
		"identity_complete": bool(record.get("identity_complete", true)),
		"has_password": not String(record.get("password_hash", "")).is_empty(),
		"auto_generated": bool(record.get("auto_generated", false)),
		"auto_password_local": auto_password_local,
		"session_token": session_token,
		"profile": (record["profile"] as Dictionary).duplicate(true),
		"profile_revision": maxi(1, int(record.get("profile_revision", 1))),
	})


func _device_account_record(
	user_id: String,
	now: int,
	starter_profile: Dictionary
) -> Dictionary:
	return {
		"user_id": user_id,
		"account": "",
		"username": AccountIdentityRules.default_username(user_id),
		"avatar_id": AccountIdentityRules.DEFAULT_AVATAR_ID,
		"identity_revision": 1,
		"identity_complete": false,
		"auto_generated": false,
		"salt": "",
		"password_hash": "",
		"created_at_unix": now,
		"updated_at_unix": now,
		"profile_revision": 1,
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
	return AccountCredentialRules.is_valid_recovery_secret(recovery_secret)


func _is_valid_auto_password(password: String) -> bool:
	return (
		password.length() == AccountCredentialRules.AUTO_PASSWORD_HEX_LENGTH
		and password.is_valid_hex_number(false)
		and password == password.to_lower()
	)


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
		var summary = profile_adapter.summary_for_profile(profile, animal_card_ids)
		summary["user_id"] = user_id
		summary["account"] = String(record.get("account", ""))
		summary["username"] = String(record.get("username", ""))
		summary["avatar_id"] = String(record.get("avatar_id", AccountIdentityRules.DEFAULT_AVATAR_ID))
		summary["identity_revision"] = maxi(1, int(record.get("identity_revision", 1)))
		summary["identity_complete"] = bool(record.get("identity_complete", true))
		summary["has_password"] = not String(record.get("password_hash", "")).is_empty()
		summary["auto_generated"] = bool(record.get("auto_generated", false))
		summary["is_active"] = user_id == active_user_id
		summary["profile_revision"] = maxi(1, int(record.get("profile_revision", 1)))
		result.append(summary)
		continue
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


func admin_accounts_snapshot() -> Dictionary:
	var rows = []
	for account_key_value in accounts:
		if typeof(accounts[account_key_value]) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = accounts[account_key_value]
		var user_id = _safe_admin_text(record.get("user_id", ""), 80)
		if user_id.is_empty():
			continue
		var profile_value = record.get("profile", {})
		var profile: Dictionary = _normalize_profile(profile_value if typeof(profile_value) == TYPE_DICTIONARY else {})
		rows.append({
			"user_id": user_id,
			"masked_account": _masked_account(record.get("account", "")),
			"username": _safe_admin_text(record.get("username", ""), AccountIdentityRules.USERNAME_MAX_LENGTH),
			"avatar_id": _safe_admin_text(record.get("avatar_id", AccountIdentityRules.DEFAULT_AVATAR_ID), 48),
			"identity_revision": maxi(1, int(record.get("identity_revision", 1))),
			"created_at_unix": maxi(0, int(record.get("created_at_unix", 0))),
			"updated_at_unix": maxi(0, int(record.get("updated_at_unix", 0))),
			"profile_revision": maxi(1, int(record.get("profile_revision", 1))),
			"deck": _admin_card_array(profile.get("deck", []), 8),
			"card_levels": _admin_card_dictionary(profile.get("card_levels", {}), 1, 99),
			"rank": {
				"rank_key": _safe_admin_text(profile.get("rank_key", "bronze"), 24).to_lower(),
				"rank_stars": maxi(0, int(profile.get("rank_stars", 1))),
				"elo": maxi(0, int(profile.get("elo", 1000))),
			},
			"rank_mirrors": _normalize_rank_mirrors(profile.get("rank_mirrors", {})),
			"resources": {
				"gacha_tickets": maxi(0, int(profile.get("gacha_tickets", 0))),
				"card_copies": _admin_card_dictionary(profile.get("card_counts", {}), 0, 1000000000),
			},
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("user_id", "")) < String(b.get("user_id", ""))
	)
	return {
		"version": 2,
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"card_names": admin_card_catalog.duplicate(true),
		"accounts": rows,
	}


func register_admin_card_catalog(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("invalid_card_catalog")
	var normalized: Dictionary = {}
	for raw_card_id in value:
		var card_id = _safe_admin_card_id(raw_card_id)
		var card_name = _safe_admin_text((value as Dictionary).get(raw_card_id, ""), 48)
		if not card_id.is_empty() and not card_name.is_empty():
			normalized[card_id] = card_name
	admin_card_catalog = normalized
	if not _write_admin_accounts_snapshot():
		return _failure("snapshot_write_failed")
	return _success({"card_count": admin_card_catalog.size()})


func process_admin_commands(allowed_card_ids: Array = [], max_commands: int = MAX_ADMIN_COMMANDS_PER_POLL) -> Dictionary:
	if not authority_storage_ready:
		return _failure("authority_storage_unavailable")
	_ensure_admin_command_directories()
	var allowed_cards = {}
	for raw_card_id in allowed_card_ids:
		var card_id = _safe_admin_card_id(raw_card_id)
		if not card_id.is_empty():
			allowed_cards[card_id] = true
	var pending_directory_path = _admin_command_bucket_path("pending")
	var directory = DirAccess.open(pending_directory_path)
	if directory == null:
		return _failure("command_directory_unavailable")
	var files = []
	directory.list_dir_begin()
	var file_name = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.to_lower().ends_with(".json"):
			files.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	files.sort()
	var processed = 0
	var failed = 0
	var idempotent = 0
	var attempted = 0
	for pending_file_name in files:
		if attempted >= clampi(max_commands, 1, MAX_ADMIN_COMMANDS_PER_POLL):
			break
		attempted += 1
		var result = _process_admin_command_file(String(pending_file_name), allowed_cards)
		match String(result.get("status", "")):
			"processed":
				processed += 1
			"idempotent":
				idempotent += 1
			"failed":
				failed += 1
	return _success({
		"processed": processed,
		"failed": failed,
		"idempotent": idempotent,
		"remaining_observed": maxi(0, files.size() - attempted),
	})


func _process_admin_command_file(file_name: String, allowed_cards: Dictionary) -> Dictionary:
	var pending_path = _admin_command_bucket_path("pending").path_join(file_name)
	var command_id_from_file = file_name.trim_suffix(".json").to_lower()
	var failure_id = command_id_from_file if _is_valid_admin_command_id(command_id_from_file) else "invalid-%s" % file_name.sha256_text().left(32)
	var file = FileAccess.open(pending_path, FileAccess.READ)
	if file == null:
		return {"status": "skipped"}
	if file.get_length() <= 0 or file.get_length() > MAX_ADMIN_COMMAND_BYTES:
		file.close()
		return _complete_failed_admin_command(pending_path, failure_id, "invalid_command_size")
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return _complete_failed_admin_command(pending_path, failure_id, "invalid_command_json")
	var source: Dictionary = parsed
	var command_id = String(source.get("command_id", "")).strip_edges().to_lower()
	if not _is_valid_admin_command_id(command_id) or command_id != command_id_from_file:
		return _complete_failed_admin_command(pending_path, failure_id, "invalid_command_id", source)
	if admin_command_receipts.has(command_id) and typeof(admin_command_receipts[command_id]) == TYPE_DICTIONARY:
		var existing_receipt: Dictionary = (admin_command_receipts[command_id] as Dictionary).duplicate(true)
		if _write_admin_command_receipt("processed", command_id, existing_receipt):
			_remove_data_file(pending_path)
			return {"status": "idempotent", "command_id": command_id}
		return {"status": "skipped", "command_id": command_id}
	var processed_receipt = _read_admin_command_receipt("processed", command_id)
	if not processed_receipt.is_empty():
		_remove_data_file(pending_path)
		return {"status": "idempotent", "command_id": command_id}
	var failed_receipt = _read_admin_command_receipt("failed", command_id)
	if not failed_receipt.is_empty():
		_remove_data_file(pending_path)
		return {"status": "failed", "command_id": command_id, "error": String(failed_receipt.get("error", "previously_failed"))}

	var validation = _validate_admin_command(source, command_id, allowed_cards)
	if not bool(validation.get("ok", false)):
		return _complete_failed_admin_command(pending_path, command_id, String(validation.get("error", "invalid_command")), source)
	var command: Dictionary = validation["command"]
	var previous_accounts = accounts.duplicate(true)
	var previous_receipts = admin_command_receipts.duplicate(true)
	var now = int(Time.get_unix_time_from_system())
	var applied_accounts = []
	for target_user_id_value in command["target_user_ids"]:
		var target_user_id = String(target_user_id_value)
		var account_key = _key_for_user_id(target_user_id)
		var record: Dictionary = (accounts[account_key] as Dictionary).duplicate(true)
		var profile: Dictionary = _normalize_profile(record.get("profile", {}))
		for grant_value in command["grants"]:
			var grant: Dictionary = grant_value
			var amount = int(grant.get("amount", 0))
			if String(grant.get("resource", "")) == "gacha_tickets":
				profile["gacha_tickets"] = clampi(maxi(0, int(profile.get("gacha_tickets", 0))) + amount, 0, 1000000000)
			else:
				var card_id = String(grant.get("card_id", ""))
				var card_counts: Dictionary = profile.get("card_counts", {}).duplicate(true)
				card_counts[card_id] = clampi(maxi(0, int(card_counts.get(card_id, 0))) + amount, 0, 1000000000)
				profile["card_counts"] = card_counts
		record["profile"] = _normalize_profile(profile)
		record["profile_revision"] = maxi(1, int(record.get("profile_revision", 1))) + 1
		record["updated_at_unix"] = now
		accounts[account_key] = record
		applied_accounts.append({
			"user_id": target_user_id,
			"profile_revision": int(record["profile_revision"]),
		})
	var receipt = {
		"version": 1,
		"command_id": command_id,
		"idempotency_key": String(command.get("idempotency_key", command_id)),
		"status": "processed",
		"scope": String(command.get("scope", "target")),
		"actor": String(command.get("actor", "")),
		"reason": String(command.get("reason", "")),
		"target_user_ids": (command.get("target_user_ids", []) as Array).duplicate(),
		"target_count": (command.get("target_user_ids", []) as Array).size(),
		"grants": (command.get("grants", []) as Array).duplicate(true),
		"created_at_unix": maxi(0, int(command.get("created_at_unix", 0))),
		"processed_at_unix": now,
		"accounts": applied_accounts,
	}
	admin_command_receipts[command_id] = receipt.duplicate(true)
	_trim_admin_command_receipts()
	if not _save():
		accounts = previous_accounts
		admin_command_receipts = previous_receipts
		return {"status": "skipped", "command_id": command_id, "error": "storage_error"}
	if not _write_admin_command_receipt("processed", command_id, receipt):
		# The durable ledger prevents a retry from crediting the same command twice.
		return {"status": "skipped", "command_id": command_id, "error": "receipt_write_error"}
	_remove_data_file(pending_path)
	return {"status": "processed", "command_id": command_id}


func _validate_admin_command(source: Dictionary, expected_command_id: String, allowed_cards: Dictionary) -> Dictionary:
	if int(source.get("version", 0)) != 1:
		return _failure("unsupported_command_version")
	var command_id = String(source.get("command_id", "")).strip_edges().to_lower()
	var idempotency_key = String(source.get("idempotency_key", "")).strip_edges().to_lower()
	if command_id != expected_command_id or idempotency_key != command_id:
		return _failure("idempotency_mismatch")
	var actor = _safe_admin_text(source.get("actor", ""), 40)
	if actor.is_empty():
		return _failure("invalid_actor")
	var reason = _safe_admin_text(source.get("reason", ""), 200)
	if reason.is_empty():
		return _failure("invalid_reason")
	var scope = String(source.get("scope", "")).strip_edges().to_lower()
	if scope not in ["target", "selected", "all"]:
		return _failure("invalid_scope")
	if scope == "all" and String(source.get("all_confirmation", "")) != "SEND TO ALL":
		return _failure("all_confirmation_required")
	if scope != "all" and not String(source.get("all_confirmation", "")).is_empty():
		return _failure("unexpected_all_confirmation")
	var raw_target_user_ids = source.get("target_user_ids", [])
	if typeof(raw_target_user_ids) != TYPE_ARRAY:
		return _failure("invalid_targets")
	var target_user_ids = []
	for raw_user_id in raw_target_user_ids:
		var user_id = _safe_admin_text(raw_user_id, 80)
		if user_id.is_empty() or target_user_ids.has(user_id) or _key_for_user_id(user_id).is_empty():
			return _failure("invalid_target")
		target_user_ids.append(user_id)
	if target_user_ids.is_empty() or (scope == "target" and target_user_ids.size() != 1):
		return _failure("invalid_targets")
	if scope == "selected" and (target_user_ids.size() < 2 or target_user_ids.size() > MAX_ADMIN_SELECTED_TARGETS):
		return _failure("invalid_selected_targets")
	if int(source.get("target_count", -1)) != target_user_ids.size():
		return _failure("invalid_target_count")
	var sorted_target_user_ids = target_user_ids.duplicate()
	sorted_target_user_ids.sort()
	if sorted_target_user_ids != target_user_ids:
		return _failure("invalid_target_order")
	if scope == "selected" and target_user_ids.size() == accounts.size():
		return _failure("all_scope_required")
	if scope == "all":
		if target_user_ids.size() != accounts.size():
			return _failure("invalid_targets")
		for record_value in accounts.values():
			if typeof(record_value) != TYPE_DICTIONARY:
				return _failure("invalid_targets")
			var current_user_id = _safe_admin_text((record_value as Dictionary).get("user_id", ""), 80)
			if current_user_id.is_empty() or not target_user_ids.has(current_user_id):
				return _failure("invalid_targets")
	var raw_grants = source.get("grants", [])
	if typeof(raw_grants) != TYPE_ARRAY or raw_grants.is_empty() or raw_grants.size() > MAX_ADMIN_COMMAND_GRANTS:
		return _failure("invalid_grants")
	var grants = []
	var grant_keys = {}
	for raw_grant in raw_grants:
		if typeof(raw_grant) != TYPE_DICTIONARY:
			return _failure("invalid_grant")
		var resource = String((raw_grant as Dictionary).get("resource", "")).strip_edges().to_lower()
		var amount = int((raw_grant as Dictionary).get("amount", 0))
		if amount < 1 or amount > MAX_ADMIN_GRANT_AMOUNT:
			return _failure("invalid_grant_amount")
		if resource == "gacha_tickets":
			if grant_keys.has(resource):
				return _failure("duplicate_grant")
			grant_keys[resource] = true
			grants.append({"resource": resource, "amount": amount})
		elif resource == "card_copies":
			var card_id = _safe_admin_card_id((raw_grant as Dictionary).get("card_id", ""))
			if card_id.is_empty() or allowed_cards.is_empty() or not allowed_cards.has(card_id):
				return _failure("invalid_card_id")
			var grant_key = "%s:%s" % [resource, card_id]
			if grant_keys.has(grant_key):
				return _failure("duplicate_grant")
			grant_keys[grant_key] = true
			grants.append({"resource": resource, "card_id": card_id, "amount": amount})
		else:
			return _failure("unsupported_resource")
	return _success({
		"command": {
			"version": 1,
			"command_id": command_id,
			"idempotency_key": idempotency_key,
			"actor": actor,
			"reason": reason,
			"scope": scope,
			"all_confirmation": "SEND TO ALL" if scope == "all" else "",
			"target_user_ids": target_user_ids,
			"grants": grants,
			"created_at_unix": maxi(0, int(source.get("created_at_unix", 0))),
		},
	})


func _complete_failed_admin_command(pending_path: String, command_id: String, error: String, source: Dictionary = {}) -> Dictionary:
	var failed_targets = _safe_failed_command_targets(source.get("target_user_ids", []))
	var receipt = {
		"version": 1,
		"command_id": command_id,
		"idempotency_key": _safe_admin_text(source.get("idempotency_key", ""), 80),
		"status": "failed",
		"scope": _safe_admin_text(source.get("scope", ""), 16),
		"actor": _safe_admin_text(source.get("actor", ""), 40),
		"reason": _safe_admin_text(source.get("reason", ""), 200),
		"target_user_ids": failed_targets,
		"target_count": failed_targets.size(),
		"grants": _safe_failed_command_grants(source.get("grants", [])),
		"created_at_unix": maxi(0, int(source.get("created_at_unix", 0))),
		"processed_at_unix": int(Time.get_unix_time_from_system()),
		"error": _safe_admin_text(error, 64),
	}
	if _write_admin_command_receipt("failed", command_id, receipt):
		_remove_data_file(pending_path)
		return {"status": "failed", "command_id": command_id, "error": error}
	return {"status": "skipped", "command_id": command_id, "error": "receipt_write_error"}


func _safe_failed_command_targets(value: Variant) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_user_id in value:
		var user_id = _safe_admin_text(raw_user_id, 80)
		if not user_id.is_empty() and not result.has(user_id):
			result.append(user_id)
		if result.size() >= 100000:
			break
	return result


func _safe_failed_command_grants(value: Variant) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_grant in value:
		if typeof(raw_grant) != TYPE_DICTIONARY:
			continue
		var resource = String((raw_grant as Dictionary).get("resource", "")).strip_edges().to_lower()
		var amount = clampi(int((raw_grant as Dictionary).get("amount", 0)), 0, MAX_ADMIN_GRANT_AMOUNT)
		if resource == "gacha_tickets" and amount > 0:
			result.append({"resource": resource, "amount": amount})
		elif resource == "card_copies" and amount > 0:
			var card_id = _safe_admin_card_id((raw_grant as Dictionary).get("card_id", ""))
			if not card_id.is_empty():
				result.append({"resource": resource, "card_id": card_id, "amount": amount})
		if result.size() >= MAX_ADMIN_COMMAND_GRANTS:
			break
	return result


func _write_admin_command_receipt(bucket: String, command_id: String, receipt: Dictionary) -> bool:
	return _atomic_write_json(_admin_command_bucket_path(bucket).path_join("%s.json" % command_id), receipt)


func _read_admin_command_receipt(bucket: String, command_id: String) -> Dictionary:
	var path = _admin_command_bucket_path(bucket).path_join("%s.json" % command_id)
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_ADMIN_COMMAND_BYTES:
		if file != null:
			file.close()
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var receipt: Dictionary = parsed
	if String(receipt.get("command_id", "")).to_lower() != command_id or String(receipt.get("status", "")) != bucket:
		return {}
	return receipt.duplicate(true)


func _trim_admin_command_receipts() -> void:
	while admin_command_receipts.size() > MAX_ADMIN_COMMAND_RECEIPTS:
		var oldest_id = ""
		var oldest_time = 9223372036854775807
		for command_id_value in admin_command_receipts:
			var receipt_value = admin_command_receipts[command_id_value]
			var processed_at = int((receipt_value as Dictionary).get("processed_at_unix", 0)) if typeof(receipt_value) == TYPE_DICTIONARY else 0
			if processed_at < oldest_time:
				oldest_time = processed_at
				oldest_id = String(command_id_value)
		if oldest_id.is_empty():
			break
		admin_command_receipts.erase(oldest_id)


func _ensure_admin_command_directories() -> void:
	for bucket in ["pending", "processed", "failed"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_admin_command_bucket_path(bucket)))


func _admin_command_bucket_path(bucket: String) -> String:
	return admin_command_root.path_join(bucket)


func _remove_data_file(path: String) -> bool:
	var state = _path_entry_state(path)
	if state == "missing":
		return true
	if state != "file":
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _is_valid_admin_command_id(value: String) -> bool:
	var pattern = RegEx.new()
	if pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$") != OK:
		return false
	return pattern.search(value.to_lower()) != null


func _safe_admin_card_id(value: Variant) -> String:
	var card_id = _safe_admin_text(value, 64)
	var pattern = RegEx.new()
	if pattern.compile("^[A-Za-z0-9_.:-]{1,64}$") != OK:
		return ""
	return card_id if pattern.search(card_id) != null else ""


func _safe_admin_text(value: Variant, max_length: int) -> String:
	return String(value).replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(max_length)


func _masked_account(value: Variant) -> String:
	var account = _safe_admin_text(value, ACCOUNT_MAX_LENGTH)
	if account.is_empty():
		return "device-account"
	if account.length() == 1:
		return "*"
	if account.length() == 2:
		return "%s*" % account.left(1)
	return "%s***%s" % [account.left(1), account.right(1)]


func _admin_card_array(value: Variant, limit: int) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_card_id in value:
		var card_id = _safe_admin_card_id(raw_card_id)
		if not card_id.is_empty() and not result.has(card_id):
			result.append(card_id)
		if result.size() >= limit:
			break
	return result


func _admin_card_dictionary(value: Variant, minimum: int, maximum: int) -> Dictionary:
	var result = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_card_id in value:
		var card_id = _safe_admin_card_id(raw_card_id)
		if not card_id.is_empty():
			result[card_id] = clampi(int(value[raw_card_id]), minimum, maximum)
	return result


func _key_for_user_id(user_id: String) -> String:
	if user_id.is_empty():
		return ""
	for key in accounts:
		if String((accounts[key] as Dictionary).get("user_id", "")) == user_id:
			return String(key)
	return ""


func _normalize_profile(source: Dictionary) -> Dictionary:
	return profile_adapter.normalize_profile(source)


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
	return (profile_adapter.installation_token_prefix() + normalized).sha256_text()


func _refresh_token_hash(refresh_token: String, salt: String) -> String:
	return (profile_adapter.refresh_token_prefix() + salt + ":" + refresh_token).sha256_text()


func _recovery_secret_hash(recovery_secret: String, salt: String) -> String:
	return (RECOVERY_SECRET_HASH_PREFIX + salt + ":" + recovery_secret).sha256_text()


func _new_user_id() -> String:
	return "U-%d-%s" % [int(Time.get_unix_time_from_system()), _random_hex(5).to_upper()]


func _random_hex(byte_count: int) -> String:
	var crypto = Crypto.new()
	return crypto.generate_random_bytes(byte_count).hex_encode()


func _prepare_authority_storage_path() -> String:
	if storage_path.get_file().strip_edges().is_empty():
		return "authority_path_invalid"
	var directory = storage_path.get_base_dir()
	if directory.is_empty():
		return "authority_directory_invalid"
	var directory_error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return "authority_directory_unavailable"
	var primary_state = _path_entry_state(storage_path)
	if primary_state == "unknown":
		return "authority_directory_unreadable"
	if primary_state == "directory":
		return "authority_path_is_directory"
	return _probe_directory_writable(directory)


func _probe_directory_writable(directory: String) -> String:
	var probe_path = directory.path_join(".player_account_store_probe_%d_%s.tmp" % [Time.get_ticks_usec(), _random_hex(4)])
	var probe = FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		return "authority_directory_unwritable"
	probe.store_string("authority-storage-ready")
	probe.flush()
	var write_error = probe.get_error()
	probe.close()
	if write_error != OK:
		_remove_data_file(probe_path)
		return "authority_directory_unwritable"
	var verification = FileAccess.open(probe_path, FileAccess.READ)
	if verification == null:
		_remove_data_file(probe_path)
		return "authority_directory_unreadable"
	var verified_text = verification.get_as_text()
	var read_error = verification.get_error()
	verification.close()
	if read_error != OK or verified_text != "authority-storage-ready":
		_remove_data_file(probe_path)
		return "authority_directory_unreadable"
	if not _remove_data_file(probe_path):
		return "authority_directory_cleanup_failed"
	return ""


func _path_entry_state(path: String) -> String:
	var directory_path = path.get_base_dir()
	if directory_path.is_empty():
		return "unknown"
	var directory = DirAccess.open(directory_path)
	if directory == null:
		return "unknown"
	var listing_error = directory.list_dir_begin()
	if listing_error != OK:
		return "unknown"
	var expected_name = path.get_file()
	var entry_name = directory.get_next()
	while not entry_name.is_empty():
		var matches = entry_name == expected_name
		if OS.get_name() == "Windows":
			matches = entry_name.to_lower() == expected_name.to_lower()
		if matches:
			var state = "directory" if directory.current_is_dir() else "file"
			directory.list_dir_end()
			return state
		entry_name = directory.get_next()
	directory.list_dir_end()
	return "missing"


func _load() -> void:
	authority_storage_ready = true
	admin_snapshot_ready = false
	accounts.clear()
	sessions.clear()
	session_installations.clear()
	installations.clear()
	admin_command_receipts.clear()
	authority_extra_fields.clear()
	var path_error = _prepare_authority_storage_path()
	if not path_error.is_empty():
		_mark_authority_unavailable(path_error)
		return
	var lock_error = _acquire_authority_lifecycle_lock()
	if not lock_error.is_empty():
		_mark_authority_unavailable(lock_error)
		return
	var read_result: Dictionary
	var primary_state = _path_entry_state(storage_path)
	if primary_state == "file":
		read_result = _read_authority_payload(storage_path)
		if not bool(read_result.get("ok", false)):
			_mark_authority_unavailable(String(read_result.get("error", "authority_read_failed")))
			return
	elif primary_state == "missing":
		var previous_path = "%s.previous" % storage_path
		var previous_state = _path_entry_state(previous_path)
		if previous_state == "missing":
			return
		if previous_state != "file":
			_mark_authority_unavailable("authority_previous_unavailable")
			return
		read_result = _read_authority_payload(previous_path)
		if not bool(read_result.get("ok", false)):
			_mark_authority_unavailable("authority_previous_invalid")
			return
		var recovery_payload: Dictionary = (read_result.get("payload", {}) as Dictionary).duplicate(true)
		if not _atomic_write_json(storage_path, recovery_payload):
			_mark_authority_unavailable("authority_previous_restore_failed")
			return
		if last_atomic_write_cleanup_degraded:
			_mark_authority_unavailable("authority_previous_restore_degraded")
			return
		push_warning("PlayerAccountStore restored a missing authority file from its validated previous generation.")
	else:
		_mark_authority_unavailable("authority_path_unavailable")
		return
	var parsed: Dictionary = (read_result.get("payload", {}) as Dictionary).duplicate(true)
	var version = int(parsed.get("version", 0))
	accounts = (parsed.get("accounts", {}) as Dictionary).duplicate(true)
	installations = (parsed.get("installations", {}) as Dictionary).duplicate(true)
	if version >= 3:
		admin_command_receipts = (parsed.get("admin_command_receipts", {}) as Dictionary).duplicate(true)
	else:
		var legacy_receipts = parsed.get("admin_command_receipts", {})
		admin_command_receipts = (legacy_receipts as Dictionary).duplicate(true) if typeof(legacy_receipts) == TYPE_DICTIONARY else {}
	for field_name_value in parsed:
		var field_name = String(field_name_value)
		if field_name not in ["version", "accounts", "installations", "admin_command_receipts"]:
			authority_extra_fields[field_name] = parsed[field_name_value]
	var migration_required = version < 3
	if _add_missing_profile_revisions():
		migration_required = true
	if _add_missing_identity_fields():
		migration_required = true
	if migration_required and not _save():
		_mark_authority_unavailable("authority_migration_persist_failed")


func _read_authority_payload(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("authority_unreadable")
	var length = file.get_length()
	if length <= 0 or length > MAX_AUTHORITY_BYTES:
		file.close()
		return _failure("authority_size_invalid")
	var stored_text = file.get_as_text()
	var read_error = file.get_error()
	file.close()
	if read_error != OK:
		return _failure("authority_unreadable")
	var parsed = JSON.parse_string(stored_text)
	var schema_error = _authority_payload_error(parsed)
	if not schema_error.is_empty():
		return _failure(schema_error)
	return _success({"payload": (parsed as Dictionary).duplicate(true)})


func _authority_payload_error(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return "authority_json_invalid"
	var payload: Dictionary = value
	var raw_version = payload.get("version", 0)
	if typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT:
		return "authority_version_invalid"
	var version_number = float(raw_version)
	if version_number != floor(version_number):
		return "authority_version_invalid"
	var version = int(raw_version)
	if version < 2 or version > 3:
		return "authority_version_unsupported"
	var loaded_accounts = payload.get("accounts", null)
	if typeof(loaded_accounts) != TYPE_DICTIONARY:
		return "authority_accounts_invalid"
	var seen_user_ids = {}
	for raw_account_key in loaded_accounts:
		if String(raw_account_key).strip_edges().is_empty() or typeof(loaded_accounts[raw_account_key]) != TYPE_DICTIONARY:
			return "authority_account_record_invalid"
		var record: Dictionary = loaded_accounts[raw_account_key]
		var user_id = String(record.get("user_id", "")).strip_edges()
		if user_id.is_empty() or seen_user_ids.has(user_id):
			return "authority_user_id_invalid"
		seen_user_ids[user_id] = true
		if typeof(record.get("profile", null)) != TYPE_DICTIONARY:
			return "authority_profile_invalid"
		if version >= 3 and int(record.get("profile_revision", 0)) < 1:
			return "authority_profile_revision_invalid"
	var loaded_installations = payload.get("installations", {})
	if typeof(loaded_installations) != TYPE_DICTIONARY:
		return "authority_installations_invalid"
	for installation_key in loaded_installations:
		if typeof(loaded_installations[installation_key]) != TYPE_DICTIONARY:
			return "authority_installation_record_invalid"
	var loaded_receipts = payload.get("admin_command_receipts", null if version >= 3 else {})
	if typeof(loaded_receipts) != TYPE_DICTIONARY:
		return "authority_receipts_invalid"
	for receipt_key in loaded_receipts:
		if typeof(loaded_receipts[receipt_key]) != TYPE_DICTIONARY:
			return "authority_receipt_record_invalid"
	return ""


func _add_missing_profile_revisions() -> bool:
	var changed = false
	for raw_account_key in accounts:
		var record: Dictionary = (accounts[raw_account_key] as Dictionary).duplicate(true)
		if int(record.get("profile_revision", 0)) >= 1:
			continue
		record["profile_revision"] = 1
		accounts[raw_account_key] = record
		changed = true
	return changed


func _add_missing_identity_fields() -> bool:
	var changed = false
	for raw_account_key in accounts:
		var record: Dictionary = (accounts[raw_account_key] as Dictionary).duplicate(true)
		var record_changed = false
		var username = AccountIdentityRules.normalize_username(record.get("username", ""))
		if not AccountIdentityRules.is_valid_username(username):
			username = AccountIdentityRules.default_username(
				record.get("user_id", ""),
				record.get("account", ""),
				bool(record.get("auto_generated", false))
			)
			record_changed = true
		if String(record.get("username", "")) != username:
			record["username"] = username
			record_changed = true
		var avatar_id = String(record.get("avatar_id", "")).strip_edges().to_lower()
		if not AccountIdentityRules.is_runtime_avatar_id(avatar_id):
			avatar_id = AccountIdentityRules.DEFAULT_AVATAR_ID
			record_changed = true
		if String(record.get("avatar_id", "")) != avatar_id:
			record["avatar_id"] = avatar_id
			record_changed = true
		if int(record.get("identity_revision", 0)) < 1:
			record["identity_revision"] = 1
			record_changed = true
		if not record.has("identity_complete"):
			# Existing records are migrated without forcing a blocking setup flow.
			record["identity_complete"] = true
			record_changed = true
		if record_changed:
			accounts[raw_account_key] = record
			changed = true
	return changed


func _mark_authority_unavailable(error_code: String) -> void:
	authority_storage_ready = false
	admin_snapshot_ready = false
	push_error("PlayerAccountStore authority storage is unavailable: %s" % error_code)


func _acquire_authority_lifecycle_lock() -> String:
	authority_lifecycle_storage_path = storage_path
	authority_lifecycle_lock_path = "%s.write_lock" % storage_path
	authority_lifecycle_lock_owner_path = authority_lifecycle_lock_path.path_join(AUTHORITY_LOCK_OWNER_BASENAME)
	authority_lifecycle_lock_token = "%d:%d:%s" % [OS.get_process_id(), Time.get_ticks_usec(), _random_hex(16)]
	authority_lifecycle_lock_held = false
	var lock_error = DirAccess.make_dir_absolute(ProjectSettings.globalize_path(authority_lifecycle_lock_path))
	if lock_error != OK:
		push_error("PlayerAccountStore lifecycle lock acquisition failed for %s (error %d); an existing or residual lock is never guessed safe." % [storage_path.get_file(), lock_error])
		return "authority_lifecycle_lock_unavailable"
	var owner_file = FileAccess.open(authority_lifecycle_lock_owner_path, FileAccess.WRITE)
	if owner_file == null:
		var owner_open_error = FileAccess.get_open_error()
		push_error("PlayerAccountStore lifecycle lock owner write failed for %s (error %d)." % [storage_path.get_file(), owner_open_error])
		_cleanup_unclaimed_authority_lock()
		return "authority_lifecycle_lock_owner_unwritable"
	owner_file.store_string(authority_lifecycle_lock_token)
	owner_file.flush()
	var owner_write_error = owner_file.get_error()
	owner_file.close()
	if owner_write_error != OK or _read_lock_owner_token() != authority_lifecycle_lock_token:
		push_error("PlayerAccountStore lifecycle lock owner verification failed for %s (error %d)." % [storage_path.get_file(), owner_write_error])
		_cleanup_unclaimed_authority_lock()
		return "authority_lifecycle_lock_owner_invalid"
	authority_lifecycle_lock_held = true
	return ""


func _cleanup_unclaimed_authority_lock() -> void:
	if _path_entry_state(authority_lifecycle_lock_owner_path) == "file":
		var owner_cleanup_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(authority_lifecycle_lock_owner_path))
		if owner_cleanup_error != OK:
			push_error("PlayerAccountStore could not clean an unclaimed lifecycle lock owner file (error %d)." % owner_cleanup_error)
			return
	var lock_cleanup_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(authority_lifecycle_lock_path))
	if lock_cleanup_error != OK:
		push_error("PlayerAccountStore could not clean an unclaimed lifecycle lock directory (error %d)." % lock_cleanup_error)


func _read_lock_owner_token() -> String:
	var owner_file = FileAccess.open(authority_lifecycle_lock_owner_path, FileAccess.READ)
	if owner_file == null:
		return ""
	var token = owner_file.get_as_text()
	var read_error = owner_file.get_error()
	owner_file.close()
	return token if read_error == OK else ""


func _authority_lifecycle_lock_is_owned() -> bool:
	return (
		authority_lifecycle_lock_held
		and not authority_lifecycle_lock_token.is_empty()
		and _path_entry_state(authority_lifecycle_lock_path) == "directory"
		and _read_lock_owner_token() == authority_lifecycle_lock_token
	)


func _save() -> bool:
	if not authority_storage_ready:
		return false
	var payload = authority_extra_fields.duplicate(true)
	payload.merge({
		"version": 3,
		"accounts": accounts,
		"installations": installations,
		"admin_command_receipts": admin_command_receipts,
	}, true)
	var schema_error = _authority_payload_error(payload)
	if not schema_error.is_empty():
		_mark_authority_unavailable(schema_error)
		return false
	if not _atomic_write_json(storage_path, payload):
		_mark_authority_unavailable("authority_write_failed")
		return false
	var authority_cleanup_degraded = last_atomic_write_cleanup_degraded
	var snapshot_written = _write_admin_accounts_snapshot()
	admin_snapshot_ready = snapshot_written and not last_atomic_write_cleanup_degraded
	if authority_cleanup_degraded:
		_mark_authority_unavailable("authority_postcommit_cleanup_degraded")
	if not admin_snapshot_ready:
		push_error("PlayerAccountStore saved authority data but could not refresh the sanitized admin account snapshot.")
	return true


func _write_admin_accounts_snapshot() -> bool:
	if admin_accounts_snapshot_path.get_file().to_lower() != ADMIN_ACCOUNTS_SNAPSHOT_BASENAME:
		return false
	return _atomic_write_json(admin_accounts_snapshot_path, admin_accounts_snapshot())


func _atomic_write_json(path: String, payload: Dictionary) -> bool:
	last_atomic_write_cleanup_degraded = false
	var directory = path.get_base_dir()
	if directory.is_empty():
		_report_atomic_write_error(path, "directory_invalid", ERR_INVALID_PARAMETER)
		return false
	var directory_error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_report_atomic_write_error(path, "directory_create", directory_error)
		return false
	if path == storage_path:
		if path != authority_lifecycle_storage_path or not _authority_lifecycle_lock_is_owned():
			_report_atomic_write_error(path, "lifecycle_lock_not_owned", ERR_LOCKED)
			return false
		return _atomic_write_json_locked(path, payload)
	var lock_path = "%s.write_lock" % path
	var lock_error = DirAccess.make_dir_absolute(ProjectSettings.globalize_path(lock_path))
	if lock_error != OK:
		_report_atomic_write_error(path, "lock_acquire", lock_error)
		return false
	var result = _atomic_write_json_locked(path, payload)
	var unlock_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(lock_path))
	if unlock_error != OK:
		last_atomic_write_cleanup_degraded = true
		var unlock_stage = "postcommit_lock_release" if result else "lock_release"
		_report_atomic_write_error(path, unlock_stage, unlock_error)
	return result


func _atomic_write_json_locked(path: String, payload: Dictionary) -> bool:
	var temporary_path = "%s.%d.%s.tmp" % [path, Time.get_ticks_usec(), _random_hex(4)]
	var file = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_report_atomic_write_error(path, "temporary_open", FileAccess.get_open_error())
		return false
	var serialized = JSON.stringify(payload, "\t")
	file.store_string(serialized)
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		_report_atomic_write_error(path, "temporary_flush", write_error)
		_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_flush")
		return false
	var verification_file = FileAccess.open(temporary_path, FileAccess.READ)
	if verification_file == null:
		_report_atomic_write_error(path, "temporary_reopen", FileAccess.get_open_error())
		_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_reopen")
		return false
	var verified_text = verification_file.get_as_text()
	var verification_error = verification_file.get_error()
	verification_file.close()
	var verified_payload = JSON.parse_string(verified_text)
	if verification_error != OK:
		_report_atomic_write_error(path, "temporary_readback", verification_error)
		_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_readback")
		return false
	if verified_text != serialized or typeof(verified_payload) != TYPE_DICTIONARY:
		_report_atomic_write_error(path, "temporary_verify", ERR_FILE_CORRUPT)
		_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_verify")
		return false
	var absolute_path = ProjectSettings.globalize_path(path)
	var absolute_temporary_path = ProjectSettings.globalize_path(temporary_path)
	var target_state = _path_entry_state(path)
	if target_state == "missing":
		var create_error = DirAccess.rename_absolute(absolute_temporary_path, absolute_path)
		if create_error == OK:
			return true
		_report_atomic_write_error(path, "target_create", create_error)
		_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_create")
		return false
	if target_state != "file":
		_report_atomic_write_error(path, "target_state_%s" % target_state, ERR_CANT_OPEN)
		_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_target_state")
		return false
	var backup_path = "%s.previous" % path
	var absolute_backup_path = ProjectSettings.globalize_path(backup_path)
	var rollback_path = "%s.transaction_%d_%s" % [backup_path, Time.get_ticks_usec(), _random_hex(4)]
	var absolute_rollback_path = ProjectSettings.globalize_path(rollback_path)
	var previous_state = _path_entry_state(backup_path)
	if previous_state not in ["missing", "file"]:
		_report_atomic_write_error(path, "previous_state_%s" % previous_state, ERR_CANT_OPEN)
		_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_previous_state")
		return false
	var previous_staged = false
	if previous_state == "file":
		var stage_error = DirAccess.rename_absolute(absolute_backup_path, absolute_rollback_path)
		if stage_error != OK:
			_report_atomic_write_error(path, "previous_stage", stage_error)
			_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_previous_stage")
			return false
		previous_staged = true
	var primary_backup_error = DirAccess.rename_absolute(absolute_path, absolute_backup_path)
	if primary_backup_error != OK:
		_report_atomic_write_error(path, "primary_to_previous", primary_backup_error)
		if previous_staged:
			var previous_restore_error = DirAccess.rename_absolute(absolute_rollback_path, absolute_backup_path)
			if previous_restore_error != OK:
				_report_atomic_write_error(path, "previous_restore_after_primary_failure", previous_restore_error)
		_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_primary_backup")
		return false
	var commit_error = DirAccess.rename_absolute(absolute_temporary_path, absolute_path)
	if commit_error == OK:
		if previous_staged:
			var stale_cleanup_error = DirAccess.remove_absolute(absolute_rollback_path)
			if stale_cleanup_error != OK:
				last_atomic_write_cleanup_degraded = true
				_report_atomic_write_error(path, "postcommit_previous_cleanup", stale_cleanup_error)
		return true
	_report_atomic_write_error(path, "temporary_to_primary", commit_error)
	var primary_restore_error = DirAccess.rename_absolute(absolute_backup_path, absolute_path)
	if primary_restore_error != OK:
		_report_atomic_write_error(path, "primary_restore", primary_restore_error)
	elif previous_staged:
		var previous_restore_error = DirAccess.rename_absolute(absolute_rollback_path, absolute_backup_path)
		if previous_restore_error != OK:
			_report_atomic_write_error(path, "previous_restore", previous_restore_error)
	_cleanup_atomic_file(path, temporary_path, "temporary_cleanup_after_commit_failure")
	return false


func _cleanup_atomic_file(target_path: String, cleanup_path: String, stage: String) -> void:
	var state = _path_entry_state(cleanup_path)
	if state == "missing":
		return
	if state != "file":
		_report_atomic_write_error(target_path, stage, ERR_CANT_OPEN)
		return
	var cleanup_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))
	if cleanup_error != OK:
		_report_atomic_write_error(target_path, stage, cleanup_error)


func _report_atomic_write_error(path: String, stage: String, error: int) -> void:
	push_error("PlayerAccountStore atomic write failed for %s at %s (error %d)." % [path.get_file(), stage, error])


func _success(extra: Dictionary = {}) -> Dictionary:
	var result = {"ok": true}
	result.merge(extra, true)
	return result


func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
