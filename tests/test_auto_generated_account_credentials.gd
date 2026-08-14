extends Node

const AccountCredentialRules = preload("res://scripts/shared/account_credential_rules.gd")
const PlayerAccountStore = preload("res://scripts/server/player_account_store.gd")

const TEST_ROOT = "user://tests/auto_generated_account_credentials"
const AUTHORITY_PATH = TEST_ROOT + "/player_accounts.json"
const SNAPSHOT_PATH = TEST_ROOT + "/admin_accounts_snapshot.json"
const COMMAND_ROOT = TEST_ROOT + "/admin_commands"
const INSTALLATION_A = "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"
const INSTALLATION_B = "b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2"
const RECOVERY_SECRET_A = "c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3"
const RECOVERY_SECRET_B = "d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4"
const WRONG_PASSWORD = "e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5"

const FORBIDDEN_RESPONSE_FIELDS = {
	"password": true,
	"salt": true,
	"password_hash": true,
	"recovery_secret": true,
	"recovery_secret_salt": true,
	"recovery_secret_hash": true,
	"token_salt": true,
	"refresh_token_hash": true,
}

var failures = 0


func _ready() -> void:
	var original_snapshot_path = OS.get_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH")
	var original_command_root = OS.get_environment("ZHANCHENG_DASHBOARD_COMMAND_ROOT")
	_remove_tree(TEST_ROOT)
	OS.set_environment(
		"ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH",
		ProjectSettings.globalize_path(SNAPSHOT_PATH)
	)
	OS.set_environment(
		"ZHANCHENG_DASHBOARD_COMMAND_ROOT",
		ProjectSettings.globalize_path(COMMAND_ROOT)
	)

	var store = PlayerAccountStore.new(AUTHORITY_PATH)
	print("AUTO_ACCOUNT_TEST_STAGE store_ready")
	if store.has_method("is_authority_storage_ready"):
		_expect(bool(store.call("is_authority_storage_ready")), "isolated account authority starts ready")
	var guest: Dictionary = store.authenticate_installation(
		INSTALLATION_A,
		"",
		{"gacha_tickets": 7},
		[],
		RECOVERY_SECRET_A
	)
	_expect(bool(guest.get("ok", false)), "first installation creates a guest account")
	_expect(String(guest.get("account", "")).is_empty(), "new installation starts as an unnamed guest")
	_expect(not bool(guest.get("has_password", true)), "guest starts without a configured password")
	_expect(not bool(guest.get("auto_generated", true)), "guest is not marked automatic before promotion")
	_expect_response_secret_free(guest, [], "guest authentication response")

	var user_id = String(guest.get("user_id", ""))
	var auto_password = AccountCredentialRules.derive_auto_password(user_id, RECOVERY_SECRET_A)
	_expect(not auto_password.is_empty(), "guest UserID and local recovery secret derive a password")
	var promoted: Dictionary = store.set_auto_account_credentials_for_session(
		String(guest.get("session_token", "")),
		auto_password
	)
	print("AUTO_ACCOUNT_TEST_STAGE promoted")
	_expect(bool(promoted.get("ok", false)), "guest is promoted to a password-backed automatic account")
	_expect(String(promoted.get("user_id", "")) == user_id, "promotion preserves the guest UserID")
	_expect(String(promoted.get("account", "")) == user_id, "automatic account ID equals its UserID")
	_expect(bool(promoted.get("has_password", false)), "promoted automatic account reports a configured password")
	_expect(bool(promoted.get("auto_generated", false)), "promoted account is marked automatically generated")
	_expect(bool(promoted.get("auto_password_local", false)), "promotion confirms the submitted password is locally available")
	_expect_response_secret_free(
		promoted,
		[auto_password, RECOVERY_SECRET_A],
		"automatic-account promotion response"
	)

	var rejected_verification: Dictionary = store.set_auto_account_credentials_for_session(
		String(promoted.get("session_token", "")),
		WRONG_PASSWORD
	)
	_expect(not bool(rejected_verification.get("ok", true)), "wrong automatic-account password is rejected")
	_expect(
		String(rejected_verification.get("error", "")) == "invalid_credentials",
		"wrong automatic-account password returns the generic credential error"
	)
	_expect_response_secret_free(
		rejected_verification,
		[WRONG_PASSWORD, RECOVERY_SECRET_A],
		"automatic-account verification failure"
	)

	var first_persisted_text = _read_text(AUTHORITY_PATH)
	_expect(not first_persisted_text.contains(auto_password), "authority JSON never stores the derived password")
	_expect(not first_persisted_text.contains(RECOVERY_SECRET_A), "authority JSON never stores the first recovery secret")
	if store.has_method("close"):
		_expect(bool(store.call("close")), "first account store releases its lifecycle lock before restart")
	store = null

	var restarted = PlayerAccountStore.new(AUTHORITY_PATH)
	print("AUTO_ACCOUNT_TEST_STAGE restarted")
	if restarted.has_method("is_authority_storage_ready"):
		_expect(bool(restarted.call("is_authority_storage_ready")), "account authority restarts from the promoted record")
	var wrong_login: Dictionary = restarted.login(user_id, WRONG_PASSWORD, INSTALLATION_B)
	_expect(not bool(wrong_login.get("ok", true)), "copied UserID rejects a wrong password on another installation")
	_expect(
		String(wrong_login.get("error", "")) == "invalid_credentials",
		"wrong cross-installation login keeps a generic credential error"
	)
	_expect_response_secret_free(wrong_login, [WRONG_PASSWORD], "wrong cross-installation login response")

	var copied_login: Dictionary = restarted.login(
		user_id,
		auto_password,
		INSTALLATION_B,
		"",
		[],
		RECOVERY_SECRET_B
	)
	print("AUTO_ACCOUNT_TEST_STAGE copied_login")
	_expect(bool(copied_login.get("ok", false)), "copied UserID and password log in on a distinct installation")
	_expect(String(copied_login.get("user_id", "")) == user_id, "second installation opens the same UserID")
	_expect(String(copied_login.get("account", "")) == user_id, "second installation returns the automatic account ID")
	_expect(bool(copied_login.get("auto_generated", false)), "second installation recognizes the automatic account")
	_expect(String(copied_login.get("refresh_token", "")).length() == 64, "second installation receives its own refresh token")
	_expect_response_secret_free(
		copied_login,
		[auto_password, RECOVERY_SECRET_A, RECOVERY_SECRET_B],
		"successful cross-installation login response"
	)

	var final_persisted_text = _read_text(AUTHORITY_PATH)
	_expect(not final_persisted_text.contains(auto_password), "final authority JSON excludes the derived password")
	_expect(not final_persisted_text.contains(RECOVERY_SECRET_A), "final authority JSON excludes the first recovery secret")
	_expect(not final_persisted_text.contains(RECOVERY_SECRET_B), "final authority JSON excludes the second recovery secret")
	if restarted.has_method("close"):
		_expect(bool(restarted.call("close")), "restarted account store releases its lifecycle lock")
	restarted = null

	OS.set_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH", original_snapshot_path)
	OS.set_environment("ZHANCHENG_DASHBOARD_COMMAND_ROOT", original_command_root)
	_remove_tree(TEST_ROOT)
	if failures == 0:
		print("AUTO_GENERATED_ACCOUNT_CREDENTIALS_TEST_PASS")
	else:
		push_error("AUTO_GENERATED_ACCOUNT_CREDENTIALS_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _expect_response_secret_free(response: Dictionary, secret_values: Array, label: String) -> void:
	_expect(not _contains_forbidden_response_field(response), "%s excludes secret-bearing fields" % label)
	var serialized = JSON.stringify(response)
	for secret_value in secret_values:
		var secret = String(secret_value)
		if not secret.is_empty():
			_expect(not serialized.contains(secret), "%s excludes submitted secret values" % label)


func _contains_forbidden_response_field(value: Variant) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in value:
			var key = String(key_value).strip_edges().to_lower()
			if FORBIDDEN_RESPONSE_FIELDS.has(key):
				return true
			if _contains_forbidden_response_field((value as Dictionary)[key_value]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for item in value:
			if _contains_forbidden_response_field(item):
				return true
	return false


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content = file.get_as_text()
	file.close()
	return content


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
