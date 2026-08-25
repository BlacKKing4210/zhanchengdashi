extends Node

const MainApp = preload("res://scripts/app/main.gd")
const GmResourceRules = preload("res://scripts/app/systems/gm_resource_rules.gd")
const RuntimeGmPanel = preload("res://scripts/app/ui/runtime_gm_panel.gd")

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
		var panel_container: PanelContainer = panel.get("panel_container")
		var scroll_container: ScrollContainer = panel.get("scroll_container")
		_expect_true(amount_field.virtual_keyboard_enabled and amount_field.virtual_keyboard_show_on_focus, "GM amount input requests the mobile virtual keyboard")
		_expect_true(amount_field.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER, "GM amount input requests a numeric keyboard")
		_expect_true(amount_field.mouse_filter == Control.MOUSE_FILTER_STOP, "GM amount input consumes pointer and touch input")
		_expect_true(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "GM modal backdrop blocks gameplay pointer input")
		_expect_true(apply_button.mouse_filter == Control.MOUSE_FILTER_STOP, "GM apply button consumes pointer and touch input")
		_expect_true(scroll_container != null and scroll_container.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "GM form body is vertically scrollable when needed")
		var viewport_size = get_viewport().get_visible_rect().size
		var panel_rect = panel_container.get_global_rect()
		_expect_true(panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0, "GM panel starts inside the default viewport")
		_expect_true(panel_rect.end.x <= viewport_size.x + 0.01 and panel_rect.end.y <= viewport_size.y + 0.01, "GM panel stays fully inside the default viewport")

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
	_expect_layout(Vector2(720, 1280))
	_expect_layout(Vector2(540, 960))
	_expect_layout(Vector2(1280, 720))

	var landscape_viewport = SubViewport.new()
	landscape_viewport.size = Vector2i(1280, 720)
	landscape_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(landscape_viewport)
	var landscape_panel = RuntimeGmPanel.new()
	landscape_viewport.add_child(landscape_panel)
	await get_tree().process_frame
	landscape_panel.show_panel(app.call("_gm_context"))
	await get_tree().process_frame
	await get_tree().process_frame
	var landscape_rect = landscape_panel.panel_container.get_global_rect()
	_expect_true(landscape_rect.position.x >= 0.0 and landscape_rect.position.y >= 0.0, "landscape GM panel starts inside the viewport")
	_expect_true(landscape_rect.end.x <= 1280.01 and landscape_rect.end.y <= 720.01, "landscape GM panel stays inside 1280x720")
	var landscape_scrollbar = landscape_panel.scroll_container.get_v_scroll_bar()
	_expect_true(landscape_scrollbar.max_value > landscape_scrollbar.page, "landscape GM body exposes scrolling instead of clipping controls")
	landscape_panel.queue_free()
	landscape_viewport.queue_free()

	var narrow_viewport = SubViewport.new()
	narrow_viewport.size = Vector2i(540, 960)
	narrow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(narrow_viewport)
	var narrow_panel = RuntimeGmPanel.new()
	narrow_viewport.add_child(narrow_panel)
	await get_tree().process_frame
	narrow_panel.show_panel(app.call("_gm_context"))
	await get_tree().process_frame
	await get_tree().process_frame
	var narrow_rect = narrow_panel.panel_container.get_global_rect()
	_expect_true(narrow_rect.position.x >= 0.0 and narrow_rect.position.y >= 0.0, "narrow GM panel starts inside the viewport")
	_expect_true(narrow_rect.end.x <= 540.01 and narrow_rect.end.y <= 960.01, "narrow GM panel stays inside 540x960")
	_expect_true(narrow_panel.scroll_container.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "narrow GM body keeps automatic scrolling available if content grows")
	narrow_panel.queue_free()
	narrow_viewport.queue_free()

	OnlineRoom.current_user_id = original_user_id
	OnlineRoom.current_account_name = original_account_name
	app.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("RUNTIME_GM_PANEL_PASS")
	get_tree().quit(failures)


func _expect_layout(viewport_size: Vector2) -> void:
	var metrics = RuntimeGmPanel.layout_metrics_for_viewport(viewport_size)
	var panel_size: Vector2 = metrics.get("panel_size", Vector2.ZERO)
	var safe_margin = float(metrics.get("safe_margin", 0.0))
	_expect_true(panel_size.x <= viewport_size.x - safe_margin * 2.0 + 0.01, "%s GM width fits its viewport" % viewport_size)
	_expect_true(panel_size.y <= viewport_size.y - safe_margin * 2.0 + 0.01, "%s GM height fits its viewport" % viewport_size)


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
