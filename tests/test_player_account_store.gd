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
		"rank_mirrors": {
			"gold": [{
				"mirror_id": "winner-1",
				"player_id": "winner-user",
				"rank_display": "黄金 3星",
				"stars": 3,
				"elo": 1300,
				"deck": ["rabbit", "wolf"],
				"card_levels": {"rabbit": 3, "wolf": 2, "unused": 99},
				"created_at_unix": 123456,
			}],
		},
	})
	_expect(bool(saved.get("ok", false)), "saves the authenticated player's profile")
	_expect(not bool(store.save_profile("invalid", {}).get("ok", true)), "rejects unauthenticated profile writes")

	var reloaded = PlayerAccountStore.new(TEST_PATH)
	var resumed_device: Dictionary = reloaded.authenticate_installation(installation_id, refresh_token)
	_expect(bool(resumed_device.get("ok", false)), "saved device credentials log in after server restart")
	_expect(String(resumed_device.get("user_id", "")) == String(device_login.get("user_id", "")), "device login keeps the same user id")
	_expect(String(resumed_device.get("refresh_token", "")).is_empty(), "existing device login does not re-expose the refresh token")
	var device_session = String(resumed_device.get("session_token", ""))
	var first_accounts: Dictionary = reloaded.account_summaries_for_session(device_session, ["rabbit", "wolf"])
	_expect(bool(first_accounts.get("ok", false)), "device session lists its owned accounts")
	_expect((first_accounts.get("accounts", []) as Array).size() == 1, "new installation starts with one owned account")
	var created_account: Dictionary = reloaded.create_account_for_session(device_session, {
		"card_counts": {"rabbit": 4, "wolf": 2},
		"card_levels": {"rabbit": 1, "wolf": 1},
		"deck": ["rabbit", "wolf"],
		"gacha_tickets": 10,
		"rank_stars": 1,
		"rank_key": "bronze",
		"elo": 1000,
	}, ["rabbit", "wolf"])
	_expect(bool(created_account.get("ok", false)), "device can create a fresh account")
	_expect(bool(created_account.get("new_account", false)), "fresh account is marked as a new game")
	_expect(String(created_account.get("user_id", "")) != String(device_login.get("user_id", "")), "fresh account receives a distinct user id")
	var created_accounts: Array = created_account.get("accounts", [])
	_expect(created_accounts.size() == 2, "new account remains in the device account list")
	if created_accounts.size() >= 2:
		_expect(int((created_accounts[1] as Dictionary).get("animal_count", 0)) == 6, "account list reports total owned animals")
	var switched_account: Dictionary = reloaded.switch_account(
		String(created_account.get("session_token", "")),
		String(device_login.get("user_id", "")),
		["rabbit", "wolf"]
	)
	_expect(bool(switched_account.get("ok", false)), "device can switch back to an owned account")
	_expect(String(switched_account.get("user_id", "")) == String(device_login.get("user_id", "")), "switch restores the selected user id")
	var relogin: Dictionary = reloaded.login("FieldMouse", "safe-pass-1936")
	var profile: Dictionary = relogin.get("profile", {})
	_expect(int(profile.get("gacha_tickets", 0)) == 19, "tickets survive server restart")
	_expect(int((profile.get("card_levels", {}) as Dictionary).get("rabbit", 0)) == 3, "card stars survive server restart")
	_expect((profile.get("deck", []) as Array) == ["rabbit", "wolf"], "deck survives server restart")
	_expect(String(profile.get("rank_key", "")) == "gold", "rank tier survives server restart")
	var rank_mirrors: Dictionary = profile.get("rank_mirrors", {})
	_expect((rank_mirrors.get("gold", []) as Array).size() == 1, "rank winner lineup survives server restart")
	var winner: Dictionary = (rank_mirrors["gold"] as Array)[0]
	_expect((winner.get("deck", []) as Array) == ["rabbit", "wolf"], "winner lineup preserves its deck")
	_expect(not (winner.get("card_levels", {}) as Dictionary).has("unused"), "winner lineup stores levels only for deck cards")
	var named_installation_id = "cd".repeat(32)
	var named_device: Dictionary = reloaded.authenticate_installation(named_installation_id, "")
	var named_refresh_token = String(named_device.get("refresh_token", ""))
	var bound_login: Dictionary = reloaded.login(
		"FieldMouse",
		"safe-pass-1936",
		named_installation_id,
		named_refresh_token,
		["rabbit", "wolf"]
	)
	_expect(bool(bound_login.get("ok", false)), "manual account login binds the current installation securely")
	_expect(String(bound_login.get("user_id", "")) == String(registered.get("user_id", "")), "manual login selects the named account")
	var restarted_after_binding = PlayerAccountStore.new(TEST_PATH)
	var auto_login: Dictionary = restarted_after_binding.authenticate_installation(named_installation_id, named_refresh_token)
	_expect(bool(auto_login.get("ok", false)), "bound installation credentials survive a server restart")
	_expect(String(auto_login.get("user_id", "")) == String(registered.get("user_id", "")), "saved device credentials automatically restore the named account")
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
