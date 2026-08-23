extends Node

const MainApp = preload("res://scripts/app/main.gd")
const GmResourceRules = preload("res://scripts/app/systems/gm_resource_rules.gd")

var failures = 0


func _ready() -> void:
	var original_user_id = OnlineRoom.current_user_id
	var original_account_name = OnlineRoom.current_account_name
	var app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	app.set_process(false)
	OnlineRoom.current_user_id = ""
	OnlineRoom.current_account_name = ""
	app.set("screen", "battle")
	app.set("battle_mode", "classic")
	app.set("online_match_id", "")
	app.set("pause_open", false)
	app.set("gold", 60)

	var f2_event = InputEventKey.new()
	f2_event.pressed = true
	f2_event.keycode = KEY_F2
	app.call("_input", f2_event)
	_expect_true(bool(app.call("_is_gm_panel_open")), "F2 opens the runtime GM panel")
	_expect_true(bool(app.get("pause_open")), "opening the GM panel pauses a local battle")
	var panel = app.get("gm_panel")
	_expect_true(panel != null, "F2 creates exactly one GM panel")
	if panel != null:
		var amount_field: LineEdit = panel.get("amount_field")
		var backdrop: ColorRect = panel.get("backdrop")
		var apply_button: Button = panel.get("apply_button")
		_expect_true(amount_field.virtual_keyboard_enabled and amount_field.virtual_keyboard_show_on_focus, "GM amount input requests the mobile virtual keyboard")
		_expect_true(amount_field.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER, "GM amount input requests a numeric keyboard")
		_expect_true(amount_field.mouse_filter == Control.MOUSE_FILTER_STOP, "GM amount input consumes pointer and touch input")
		_expect_true(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "GM modal backdrop blocks gameplay pointer input")
		_expect_true(apply_button.mouse_filter == Control.MOUSE_FILTER_STOP, "GM apply button consumes pointer and touch input")

	if panel != null:
		(panel.get("amount_field") as LineEdit).text = "250"
		panel.call("_request_change")
	_expect_equal(int(app.get("gold")), 310, "GM adapter updates battle gold through validated rules")

	OnlineRoom.current_user_id = "U-GM-PROTECTED"
	app.set("gacha_tickets", 5)
	app.call(
		"_on_gm_resource_change_requested",
		GmResourceRules.RESOURCE_GACHA_TICKETS,
		GmResourceRules.OPERATION_ADD,
		"99",
		""
	)
	_expect_equal(int(app.get("gacha_tickets")), 5, "logged-in account resources are not changed by the client GM panel")

	var escape_event = InputEventKey.new()
	escape_event.pressed = true
	escape_event.keycode = KEY_ESCAPE
	app.call("_input", escape_event)
	_expect_false(bool(app.call("_is_gm_panel_open")), "Escape closes the GM panel")
	_expect_false(bool(app.get("pause_open")), "closing the GM panel restores the previous pause state")

	OnlineRoom.current_user_id = ""
	app.set("battle_mode", "multiplayer")
	app.set("online_match_id", "match-live")
	app.call("_input", f2_event)
	_expect_false(bool(app.call("_is_gm_panel_open")), "F2 cannot open the GM panel during an online match")
	_expect_true(String(app.get("toast_text")).contains("禁止"), "online-match denial is visible to the operator")

	app.set("online_match_id", "")
	app.set("battle_mode", "classic")
	app.call("_input", f2_event)
	var first_panel = app.get("gm_panel")
	app.call("_input", f2_event)
	app.call("_input", f2_event)
	_expect_true(app.get("gm_panel") == first_panel, "repeated F2 toggles reuse the single panel instance")
	app.call("_close_gm_panel")

	OnlineRoom.current_user_id = original_user_id
	OnlineRoom.current_account_name = original_account_name
	app.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("RUNTIME_GM_PANEL_PASS")
	get_tree().quit(failures)


func _expect_equal(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s: expected %d, got %d" % [label, expected, actual])


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	_fail("%s: expected true" % label)


func _expect_false(value: bool, label: String) -> void:
	if not value:
		return
	_fail("%s: expected false" % label)


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
