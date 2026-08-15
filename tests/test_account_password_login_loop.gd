extends Node

const MainApp = preload("res://scripts/app/main.gd")
const PlayerAccountStore = preload("res://scripts/server/player_account_store.gd")

const TEST_PATH = "user://tests/account_password_login_loop.json"
const ACCOUNT = "ProducerAccount"
const PASSWORD = "safe-password-1936"

var failures = 0


func _ready() -> void:
	_cleanup()
	var store = PlayerAccountStore.new(TEST_PATH)
	var registered: Dictionary = store.register_account(ACCOUNT, PASSWORD)
	_expect_true(bool(registered.get("ok", false)), "username and password registration succeeds")
	_expect_false(bool(store.login(ACCOUNT, "wrong-password").get("ok", true)), "wrong password is rejected")
	var installation_id = "a1".repeat(32)
	var login: Dictionary = store.login(ACCOUNT.to_lower(), PASSWORD, installation_id)
	_expect_true(bool(login.get("ok", false)), "username login is case insensitive and binds the installation")
	_expect_equal(String(login.get("account", "")), ACCOUNT, "login returns the canonical account name")
	_expect_true(bool(login.get("has_password", false)), "login reports the password-configured state")
	_expect_false(login.has("password") or login.has("salt") or login.has("password_hash"), "login response excludes password material")
	var refresh_token = String(login.get("refresh_token", ""))
	_expect_equal(refresh_token.length(), 64, "password login issues a scoped refresh token")
	var session_token = String(login.get("session_token", ""))
	var saved: Dictionary = store.save_profile(session_token, {
		"card_counts": {"rabbit": 3},
		"card_levels": {"rabbit": 2},
		"deck": ["rabbit"],
		"gacha_tickets": 12,
		"rank_key": "silver",
		"rank_stars": 2,
		"elo": 1100,
	})
	_expect_true(bool(saved.get("ok", false)), "authenticated account saves its server-authoritative profile")
	var persisted_text = _read_text(TEST_PATH)
	_expect_false(persisted_text.contains(PASSWORD), "persisted account data never contains the plaintext password")
	_expect_true(bool(store.close()), "first account store explicitly releases its lifecycle lock")
	store = null
	var restarted = PlayerAccountStore.new(TEST_PATH)
	var resumed: Dictionary = restarted.authenticate_installation(installation_id, refresh_token)
	_expect_true(bool(resumed.get("ok", false)), "saved installation credentials restore the named account after restart")
	_expect_equal(String(resumed.get("user_id", "")), String(registered.get("user_id", "")), "automatic restore returns the same user id")
	_expect_equal(String(resumed.get("account", "")), ACCOUNT, "automatic restore returns the account name")
	_expect_false(JSON.stringify(resumed).contains(PASSWORD), "automatic restore never returns the plaintext password")
	_expect_equal(int((resumed.get("profile", {}) as Dictionary).get("gacha_tickets", 0)), 12, "automatic restore returns the saved profile")

	var original_user_id = OnlineRoom.current_user_id
	var original_account_name = OnlineRoom.current_account_name
	var original_has_password = OnlineRoom.current_account_has_password
	var original_profile = OnlineRoom.current_profile.duplicate(true)
	var original_summaries = OnlineRoom.current_account_summaries.duplicate(true)
	var original_session_token = String(OnlineRoom.get("_client_session_token"))
	OnlineRoom.call("_apply_account_operation", "authenticate_installation", resumed)
	_expect_equal(OnlineRoom.current_user_id, String(registered.get("user_id", "")), "network adapter applies the restored user id")
	_expect_equal(OnlineRoom.current_account_name, ACCOUNT, "network adapter exposes the restored account name")
	_expect_true(OnlineRoom.current_account_has_password, "network adapter exposes password-configured state without password material")
	var app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	var password_field: LineEdit = app.get("account_password_field")
	_expect_true(password_field.secret, "password input masks user text")
	_expect_equal(password_field.max_length, 72, "password input enforces the server maximum length")
	password_field.text = PASSWORD
	app.set("account_pending_auth_name", ACCOUNT)
	app.set("account_pending_auth_password", PASSWORD)
	app.set("account_manual_login_open", true)
	app.call("_on_online_operation_completed", "login_account", {"account": ACCOUNT})
	_expect_equal(password_field.text, "", "successful login clears the in-memory password field")
	_expect_false(bool(app.get("account_manual_login_open")), "successful login closes manual login mode")
	_expect_equal(String(app.get("account_session_password")), PASSWORD, "successful manual login retains the password only for the foreground process session")
	_expect_true(bool(app.call("_account_password_available_for_view")), "current-session password can be viewed after manual login")
	app.set("account_center_open", true)
	app.call("_handle_account_center_tap", (app.call("_account_password_view_rect") as Rect2).get_center())
	_expect_true(bool(app.get("account_password_revealed")), "credential button reveals the current-session password")
	app.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect_equal(String(app.get("account_session_password")), "", "application focus loss clears the current-session password")
	_expect_false(bool(app.get("account_password_revealed")), "application focus loss closes password reveal state")
	_expect_equal(
		String(app.call("_online_error_message", "login_account", "invalid_credentials")),
		"账号或密码错误",
		"failed login uses a generic non-enumerating message"
	)
	app.queue_free()
	OnlineRoom.current_user_id = original_user_id
	OnlineRoom.current_account_name = original_account_name
	OnlineRoom.current_account_has_password = original_has_password
	OnlineRoom.current_profile = original_profile
	OnlineRoom.current_account_summaries = original_summaries
	OnlineRoom.set("_client_session_token", original_session_token)

	_expect_true(bool(restarted.close()), "restarted account store explicitly releases its lifecycle lock")
	_expect_true(bool(restarted.close()), "repeated account store close is idempotently safe")
	restarted = null
	_cleanup()
	if failures == 0:
		print("ACCOUNT_PASSWORD_LOGIN_LOOP_TEST_PASS")
	else:
		push_error("ACCOUNT_PASSWORD_LOGIN_LOOP_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_false(value: bool, label: String) -> void:
	if not value:
		return
	failures += 1
	push_error("%s: expected false" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _cleanup() -> void:
	for suffix in ["", ".previous", ".tmp"]:
		var path = TEST_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var lock_path = TEST_PATH + ".write_lock"
	var owner_path = lock_path.path_join("owner_token")
	if FileAccess.file_exists(owner_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(owner_path))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(lock_path)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lock_path))
