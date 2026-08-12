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
	var restarted = PlayerAccountStore.new(TEST_PATH)
	var resumed: Dictionary = restarted.authenticate_installation(installation_id, refresh_token)
	_expect_true(bool(resumed.get("ok", false)), "saved installation credentials restore the named account after restart")
	_expect_equal(String(resumed.get("user_id", "")), String(registered.get("user_id", "")), "automatic restore returns the same user id")
	_expect_equal(int((resumed.get("profile", {}) as Dictionary).get("gacha_tickets", 0)), 12, "automatic restore returns the saved profile")

	var app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	var password_field: LineEdit = app.get("account_password_field")
	_expect_true(password_field.secret, "password input masks user text")
	_expect_equal(password_field.max_length, 72, "password input enforces the server maximum length")
	password_field.text = PASSWORD
	app.set("account_manual_login_open", true)
	app.call("_on_online_operation_completed", "login_account", {})
	_expect_equal(password_field.text, "", "successful login clears the in-memory password field")
	_expect_false(bool(app.get("account_manual_login_open")), "successful login closes manual login mode")
	_expect_equal(
		String(app.call("_online_error_message", "login_account", "invalid_credentials")),
		"账号或密码错误",
		"failed login uses a generic non-enumerating message"
	)
	app.queue_free()

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
	for suffix in ["", ".tmp"]:
		var path = TEST_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
