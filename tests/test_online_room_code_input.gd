extends Node

const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app: Node
var room_service_stub: Node


class OnlineRoomServiceStub extends Node:
	var join_calls = 0
	var joined_code = ""
	var joined_name = ""

	func is_connected_to_server() -> bool:
		return true

	func join_room(code: String, player_name: String) -> void:
		join_calls += 1
		joined_code = code
		joined_name = player_name


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	app.set("screen", "room")
	app.set("online_room_active", false)
	app.set("account_center_open", false)
	app.call("_layout", get_viewport().get_visible_rect().size)
	app.call("_update_online_room_code_field_layout")
	await get_tree().process_frame
	_test_real_line_edit_contract()
	await _test_mouse_click_focus()
	await _test_mobile_touch_focus()
	_test_numeric_sanitization()
	_test_submit_and_focus_lifecycle()
	_test_page_exit_hides_and_releases()
	if room_service_stub != null:
		room_service_stub.queue_free()
	app.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("Online room code input tests passed.")
	get_tree().quit(failures)


func _test_real_line_edit_contract() -> void:
	var field = _field()
	_expect_true(field != null, "room code field is a real LineEdit")
	if field == null:
		return
	_expect_true(field.visible, "room code field is visible on the room entry page")
	_expect_true(field.editable, "room code field accepts text")
	_expect_equal(field.max_length, 6, "room code field limits input to six characters")
	_expect_equal(field.focus_mode, Control.FOCUS_ALL, "room code field accepts pointer focus")
	_expect_equal(field.mouse_filter, Control.MOUSE_FILTER_STOP, "room code field owns pointer input")
	_expect_true(field.virtual_keyboard_enabled, "virtual keyboard is enabled")
	_expect_true(field.virtual_keyboard_show_on_focus, "focus requests the mobile virtual keyboard")
	_expect_equal(field.virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_NUMBER, "Android receives a numeric keyboard request")
	var expected_rect: Rect2 = app.call("_room_online_code_input_rect")
	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	_expect_vec2_close(field.position, offset + expected_rect.position * scale, "field position follows the portrait canvas")
	_expect_vec2_close(field.size, expected_rect.size * scale, "field size follows the portrait canvas")


func _test_mouse_click_focus() -> void:
	var field = _field()
	field.release_focus()
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = field.get_global_rect().get_center()
	app.call("_input", click)
	await get_tree().process_frame
	_expect_true(field.has_focus(), "desktop mouse click focuses the room code field")


func _test_mobile_touch_focus() -> void:
	var field = _field()
	field.release_focus()
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = field.get_global_rect().get_center()
	app.call("_input", touch)
	await get_tree().process_frame
	_expect_true(field.has_focus(), "mobile screen touch focuses the room code field")
	var release = InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = touch.position
	app.call("_input", release)
	await get_tree().process_frame


func _test_numeric_sanitization() -> void:
	var field = _field()
	app.call("_on_online_room_code_text_changed", "12a34 567")
	_expect_equal(String(app.get("online_room_join_code")), "123456", "pasted text keeps only the first six digits")
	_expect_equal(field.text, "123456", "sanitized room code is reflected in the real field")
	app.call("_on_online_room_code_text_changed", "9x")
	_expect_equal(String(app.get("online_room_join_code")), "9", "physical non-digit input is removed")
	_expect_equal(field.text, "9", "field text remains synchronized after filtering")


func _test_submit_and_focus_lifecycle() -> void:
	var field = _field()
	room_service_stub = OnlineRoomServiceStub.new()
	add_child(room_service_stub)
	app.set("online_room_service", room_service_stub)
	app.set("online_connection_state", "connected")
	app.call("_focus_online_room_code_input")
	app.call("_on_online_room_code_text_submitted", "123")
	_expect_equal(int(room_service_stub.get("join_calls")), 0, "short code never sends a room request")
	_expect_true(field.has_focus(), "invalid submit keeps focus for correction")
	app.call("_on_online_room_code_text_submitted", "654321")
	_expect_equal(int(room_service_stub.get("join_calls")), 1, "six-digit submit sends exactly one room request")
	_expect_equal(String(room_service_stub.get("joined_code")), "654321", "submitted code reaches the existing room service")
	_expect_false(field.has_focus(), "valid submit releases focus and closes the keyboard")


func _test_page_exit_hides_and_releases() -> void:
	var field = _field()
	app.set("online_room_active", false)
	app.set("screen", "room")
	app.call("_update_online_room_code_field_layout")
	app.call("_focus_online_room_code_input")
	_expect_true(field.has_focus(), "field can refocus before navigation")
	app.set("screen", "lobby")
	app.call("_update_online_room_code_field_layout")
	_expect_false(field.visible, "field is hidden outside the room entry page")
	_expect_false(field.has_focus(), "leaving the page releases text focus")


func _field() -> LineEdit:
	return app.get("online_room_code_field") as LineEdit


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


func _expect_vec2_close(actual: Vector2, expected: Vector2, label: String) -> void:
	if actual.is_equal_approx(expected):
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
