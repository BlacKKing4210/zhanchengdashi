extends Node

const MainApp = preload("res://scripts/app/main.gd")

var failures = 0


func _ready() -> void:
	var original_user_id = OnlineRoom.current_user_id
	var original_account_name = OnlineRoom.current_account_name
	var original_has_password = OnlineRoom.current_account_has_password
	OnlineRoom.current_user_id = "U-account-entry-test"
	OnlineRoom.current_account_name = "FieldMouse"
	OnlineRoom.current_account_has_password = true
	var app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	app.set("account_center_open", true)
	app.set("account_manual_login_open", false)
	app.call("_set_account_fields_visible", true)
	var name_field: LineEdit = app.get("account_name_field")
	var password_field: LineEdit = app.get("account_password_field")
	_expect_false(name_field.visible, "generated device account keeps manual fields hidden by default")
	_expect_false(password_field.visible, "generated device account keeps the password field hidden by default")
	var switch_rect: Rect2 = app.call("_account_switch_rect")
	var bind_rect: Rect2 = app.call("_account_bind_rect")
	_expect_false(switch_rect.intersects(bind_rect), "switch and bind account controls do not overlap")
	app.call("_handle_account_center_tap", bind_rect.get_center())
	_expect_true(bool(app.get("account_manual_login_open")), "bind account control opens the manual login form")
	_expect_true(name_field.visible, "bind account control shows the account field")
	_expect_true(password_field.visible, "bind account control shows the password field")
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
	app.call("_handle_account_center_tap", (app.call("_account_password_view_rect") as Rect2).get_center())
	_expect_true(bool(app.get("account_manual_login_open")), "password view without current-session credentials requires re-verification")
	_expect_true(name_field.visible and password_field.visible, "re-verification exposes native account inputs")
	_expect_true(name_field.text == "FieldMouse", "re-verification pre-fills the known account name")
	OnlineRoom.current_user_id = original_user_id
	OnlineRoom.current_account_name = original_account_name
	OnlineRoom.current_account_has_password = original_has_password
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
