extends Node

const PlayerAccountStore = preload("res://scripts/server/player_account_store.gd")
const TEST_PATH = "user://tests/player_accounts_test.json"

var failures = 0


func _ready() -> void:
	_cleanup()
	var store = PlayerAccountStore.new(TEST_PATH)
	var registered: Dictionary = store.register_account("FieldMouse", "safe-pass-1936")
	_expect(bool(registered.get("ok", false)), "registers an account")
	_expect(String(registered.get("user_id", "")).begins_with("U-"), "server generates a user id")
	_expect(not bool(store.register_account("fieldmouse", "safe-pass-1936").get("ok", true)), "account names are unique case-insensitively")
	_expect(not bool(store.login("FieldMouse", "wrong-password").get("ok", true)), "wrong password is rejected")
	var installation_id = "ab".repeat(32)
	var device_login: Dictionary = store.authenticate_installation(installation_id, "")
	_expect(bool(device_login.get("ok", false)), "first installation authentication creates an account")
	_expect(String(device_login.get("user_id", "")).begins_with("U-"), "device account receives a server user id")
	var refresh_token = String(device_login.get("refresh_token", ""))
	_expect(refresh_token.length() == 64, "device account receives a long-term refresh token once")
	_expect(not bool(store.authenticate_installation(installation_id, "wrong-token").get("ok", true)), "wrong device token is rejected")

	var login: Dictionary = store.login("fieldmouse", "safe-pass-1936")
	_expect(bool(login.get("ok", false)), "correct password logs in")
	var token = String(login.get("session_token", ""))
	var saved: Dictionary = store.save_profile(token, {
		"card_counts": {"rabbit": 7, "wolf": 2},
		"card_levels": {"rabbit": 3, "wolf": 2},
		"deck": ["rabbit", "wolf"],
		"gacha_tickets": 19,
		"rank_stars": 8,
		"rank_key": "gold",
		"elo": 1234,
	})
	_expect(bool(saved.get("ok", false)), "saves the authenticated player's profile")
	_expect(not bool(store.save_profile("invalid", {}).get("ok", true)), "rejects unauthenticated profile writes")

	var reloaded = PlayerAccountStore.new(TEST_PATH)
	var resumed_device: Dictionary = reloaded.authenticate_installation(installation_id, refresh_token)
	_expect(bool(resumed_device.get("ok", false)), "saved device credentials log in after server restart")
	_expect(String(resumed_device.get("user_id", "")) == String(device_login.get("user_id", "")), "device login keeps the same user id")
	_expect(String(resumed_device.get("refresh_token", "")).is_empty(), "existing device login does not re-expose the refresh token")
	var relogin: Dictionary = reloaded.login("FieldMouse", "safe-pass-1936")
	var profile: Dictionary = relogin.get("profile", {})
	_expect(int(profile.get("gacha_tickets", 0)) == 19, "tickets survive server restart")
	_expect(int((profile.get("card_levels", {}) as Dictionary).get("rabbit", 0)) == 3, "card stars survive server restart")
	_expect((profile.get("deck", []) as Array) == ["rabbit", "wolf"], "deck survives server restart")
	_expect(String(profile.get("rank_key", "")) == "gold", "rank tier survives server restart")
	_expect(bool(reloaded.logout(String(relogin.get("session_token", ""))).get("ok", false)), "logout invalidates the session")

	_cleanup()
	if failures == 0:
		print("PLAYER_ACCOUNT_STORE_TEST_PASS")
	else:
		push_error("PLAYER_ACCOUNT_STORE_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _cleanup() -> void:
	for suffix in ["", ".tmp"]:
		var path = TEST_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
