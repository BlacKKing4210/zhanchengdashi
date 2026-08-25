extends Node

const MainApp = preload("res://scripts/app/main.gd")
const AccountCredentialRules = preload("res://scripts/shared/account_credential_rules.gd")

var failures = 0


func _ready() -> void:
	var original_user_id = OnlineRoom.current_user_id
	var original_account_name = OnlineRoom.current_account_name
	var original_username = OnlineRoom.current_username
	var original_avatar_id = OnlineRoom.current_avatar_id
	var original_identity_revision = OnlineRoom.current_identity_revision
	var original_identity_complete = OnlineRoom.current_identity_complete
	var original_has_password = OnlineRoom.current_account_has_password
	var original_is_generated = OnlineRoom.current_account_is_generated
	var original_auto_password_local = OnlineRoom.current_auto_password_local
	var original_recovery_secret = String(OnlineRoom.get("_device_recovery_secret"))
	OnlineRoom.current_user_id = "U-account-entry-test"
	OnlineRoom.current_account_name = "FieldMouse"
	OnlineRoom.current_username = "田野仓鼠"
	OnlineRoom.current_avatar_id = "animal_hamster"
	OnlineRoom.current_identity_revision = 3
	OnlineRoom.current_identity_complete = true
	OnlineRoom.current_account_has_password = true
	var app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	app.set("account_center_open", true)
	app.set("account_manual_login_open", false)
	app.call("_sync_account_identity_editor", true)
	app.call("_set_account_fields_visible", true)
	var username_field: LineEdit = app.get("account_username_field")
	var name_field: LineEdit = app.get("account_name_field")
	var password_field: LineEdit = app.get("account_password_field")
	_expect_true(username_field.visible, "authenticated account shows the independent username field")
	_expect_true(username_field.text == "田野仓鼠", "username editor uses the display username instead of the account id")
	_expect_false(name_field.visible, "generated device account keeps manual fields hidden by default")
	_expect_false(password_field.visible, "generated device account keeps the password field hidden by default")
	var switch_rect: Rect2 = app.call("_account_switch_rect")
	var bind_rect: Rect2 = app.call("_account_bind_rect")
	var password_view_rect: Rect2 = app.call("_account_password_view_rect")
	var credentials_copy_rect: Rect2 = app.call("_account_credentials_copy_rect")
	var avatar_entry_rect: Rect2 = app.call("_account_avatar_entry_rect")
	_expect_false(switch_rect.intersects(bind_rect), "switch and bind account controls do not overlap")
	_expect_false(password_view_rect.intersects(credentials_copy_rect), "password view and the single credential copy control do not overlap")
	_expect_true(credentials_copy_rect.size.x >= 48.0 and credentials_copy_rect.size.y >= 48.0, "single credential copy control has a mobile touch target")
	_expect_false(app.has_method("_account_id_copy_rect") or app.has_method("_account_password_copy_rect") or app.has_method("_account_copy_all_rect"), "legacy three-copy hit targets are removed")
	app.call("_handle_account_center_tap", avatar_entry_rect.get_center())
	await get_tree().process_frame
	_expect_true(bool(app.call("_is_account_avatar_picker_open")), "tapping the current avatar opens the all-animal picker")
	app.call("_close_account_avatar_picker")
	app.call("_handle_account_center_tap", bind_rect.get_center())
	_expect_true(bool(app.get("account_manual_login_open")), "bind account control opens the manual login form")
	_expect_true(name_field.visible, "bind account control shows the account field")
	_expect_true(password_field.visible, "bind account control shows the password field")
	_expect_false(username_field.visible, "manual login temporarily hides the display-name editor")
	_expect_true(name_field.virtual_keyboard_enabled and name_field.virtual_keyboard_show_on_focus, "account input requests the mobile virtual keyboard")
	_expect_true(password_field.virtual_keyboard_enabled and password_field.virtual_keyboard_show_on_focus, "password input requests the mobile virtual keyboard")
	_expect_true(password_field.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_PASSWORD, "password input requests a password keyboard on mobile")
	_expect_true(name_field.mouse_filter == Control.MOUSE_FILTER_STOP and password_field.mouse_filter == Control.MOUSE_FILTER_STOP, "account controls consume pointer and touch input")
	var touch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = name_field.get_global_rect().get_center()
	app.call("_input", touch)
	_expect_true(name_field.has_focus(), "screen touch focuses the account input")
	name_field.text_submitted.emit(name_field.text)
	_expect_true(password_field.has_focus(), "account submit advances focus to the password input")
	app.call("_handle_account_center_tap", (app.call("_account_close_rect") as Rect2).get_center())
	_expect_false(bool(app.get("account_manual_login_open")), "closing the account panel exits manual login mode")
	_expect_false(name_field.visible, "closing the account panel hides the account field")
	app.set("account_center_open", true)
	app.call("_handle_account_center_tap", credentials_copy_rect.get_center())
	_expect_true(bool(app.get("account_manual_login_open")), "copy without current-session credentials requires re-login")
	_expect_true(String(app.get("account_clipboard_payload")).is_empty(), "copy without current-session credentials writes no tracked payload")
	app.set("account_manual_login_open", false)
	app.call("_set_account_fields_visible", false)
	app.call("_remember_account_password", "FieldMouse", "copy-password-demo")
	var expected_payload = "账号ID：FieldMouse\n密码：copy-password-demo"
	_expect_true(String(app.call("_account_credential_clipboard_text")) == expected_payload, "the single copy payload includes account id and manual-session password")
	app.set("account_clipboard_payload", expected_payload)
	app.set("account_clipboard_clear_timer", 60.0)
	_expect_true(bool(app.call("_clipboard_payload_matches_tracked", expected_payload)), "clipboard ownership recognizes the unchanged credential payload")
	_expect_false(bool(app.call("_clipboard_payload_matches_tracked", "newer-player-clipboard")), "clipboard ownership rejects newer player clipboard content")
	app.call("_update_account_clipboard_expiry", 61.0)
	_expect_true(String(app.get("account_clipboard_payload")).is_empty(), "clipboard expiry forgets the tracked payload")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set("")
		app.call("_handle_account_center_tap", credentials_copy_rect.get_center())
		_expect_true(String(app.get("account_clipboard_payload")) == expected_payload, "copy tracks the operating-system clipboard payload")
		_expect_true(bool(app.call("_clipboard_payload_matches_tracked", DisplayServer.clipboard_get())), "copy writes the credential payload to the operating-system clipboard")
		DisplayServer.clipboard_set("newer-player-clipboard")
		app.call("_update_account_clipboard_expiry", 61.0)
		_expect_true(DisplayServer.clipboard_get() == "newer-player-clipboard", "clipboard expiry preserves newer player clipboard content")
		app.call("_handle_account_center_tap", credentials_copy_rect.get_center())
		app.call("_update_account_clipboard_expiry", 61.0)
		_expect_true(DisplayServer.clipboard_get().is_empty(), "clipboard expiry clears the unchanged credential payload")
	app.call("_clear_session_account_password")
	app.call("_handle_account_center_tap", password_view_rect.get_center())
	_expect_true(bool(app.get("account_manual_login_open")), "password view without current-session credentials requires re-login")
	_expect_true(name_field.visible and password_field.visible, "re-login exposes native account inputs")
	_expect_true(name_field.text == "FieldMouse", "re-login pre-fills the known account name")
	var auto_user_id = "U-1786700000-ABCDEF1234"
	var auto_recovery_secret = "a1".repeat(32)
	var auto_password = AccountCredentialRules.derive_auto_password(auto_user_id, auto_recovery_secret)
	OnlineRoom.current_user_id = auto_user_id
	OnlineRoom.current_account_name = auto_user_id
	OnlineRoom.current_account_has_password = true
	OnlineRoom.current_account_is_generated = true
	OnlineRoom.current_auto_password_local = true
	OnlineRoom.set("_device_recovery_secret", auto_recovery_secret)
	app.call("_clear_session_account_password")
	app.set("account_manual_login_open", false)
	app.call("_set_account_fields_visible", false)
	var expected_auto_payload = "账号ID：%s\n密码：%s" % [auto_user_id, auto_password]
	_expect_true(bool(app.call("_account_password_available_for_view")), "origin device can view its generated account password")
	_expect_true(String(app.call("_account_credential_clipboard_text")) == expected_auto_payload, "generated account copy payload contains its account id and derived password")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set("")
		app.call("_handle_account_center_tap", credentials_copy_rect.get_center())
		_expect_true(String(app.get("account_clipboard_payload")) == expected_auto_payload, "generated account copy button works without reopening login")
	OnlineRoom.current_user_id = original_user_id
	OnlineRoom.current_account_name = original_account_name
	OnlineRoom.current_username = original_username
	OnlineRoom.current_avatar_id = original_avatar_id
	OnlineRoom.current_identity_revision = original_identity_revision
	OnlineRoom.current_identity_complete = original_identity_complete
	OnlineRoom.current_account_has_password = original_has_password
	OnlineRoom.current_account_is_generated = original_is_generated
	OnlineRoom.current_auto_password_local = original_auto_password_local
	OnlineRoom.set("_device_recovery_secret", original_recovery_secret)
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set("")
	app.queue_free()
	if failures == 0:
		print("Account manual login entry tests passed.")
	get_tree().quit(failures)


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
