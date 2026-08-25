extends Node

const AccountAvatarPicker = preload("res://scripts/app/ui/account_avatar_picker.gd")
const AccountIdentityRules = preload("res://scripts/shared/account_identity_rules.gd")

var failures = 0


func _ready() -> void:
	var cards_value = JSON.parse_string(FileAccess.get_file_as_string("res://runtime/config/cards.json"))
	var cards: Array = cards_value if typeof(cards_value) == TYPE_ARRAY else []
	var catalog = AccountIdentityRules.runtime_avatar_catalog(cards)
	var picker = AccountAvatarPicker.new()
	add_child(picker)
	await get_tree().process_frame

	var locked_result = {"name": "", "hint": ""}
	var selected_result = {"id": ""}
	picker.locked_avatar_pressed.connect(func(display_name: String, hint: String) -> void:
		locked_result["name"] = display_name
		locked_result["hint"] = hint
	)
	picker.avatar_selected.connect(func(avatar_id: String) -> void:
		selected_result["id"] = avatar_id
	)
	picker.show_picker(catalog, {"fox": 1}, "animal_cat", "animal_cat")
	await get_tree().process_frame

	_expect_true(picker.is_panel_open(), "picker opens as a modal")
	_expect_equal(picker.avatar_count(), 60, "picker displays all animal avatars")
	_expect_equal(picker.unlocked_avatar_count(), 2, "current legacy avatar and owned fox are unlocked")
	_expect_equal(picker.tile_buttons.size(), 60, "picker creates one interactive tile per animal")
	_expect_true(picker.backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "modal backdrop blocks underlying input")
	_expect_true(picker.scroll_container.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "avatar body supports vertical scrolling")
	_expect_true(picker.scroll_container.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "avatar body never requires horizontal scrolling")

	var locked_button = _button_for_avatar(picker.tile_buttons, "animal_tiger")
	_expect_true(locked_button != null and not bool(locked_button.get_meta("unlocked", true)), "unowned tiger is visibly represented by a locked interactive tile")
	if locked_button != null:
		locked_button.pressed.emit()
	_expect_true(String(locked_result["name"]) == "老虎", "locked click identifies the requested animal")
	_expect_true(String(locked_result["hint"]).contains("动物卡") and String(locked_result["hint"]).contains("抽卡"), "locked click explains how to obtain the avatar")
	_expect_true(picker.footer_label.text.contains("老虎") and picker.footer_label.text.contains("抽卡"), "locked obtain hint stays visible inside the modal")
	_expect_true(picker.is_panel_open(), "locked click keeps the picker open")

	var fox_button = _button_for_avatar(picker.tile_buttons, "animal_fox")
	_expect_true(fox_button != null and bool(fox_button.get_meta("unlocked", false)), "owned fox is selectable")
	if fox_button != null:
		fox_button.pressed.emit()
	_expect_true(String(selected_result["id"]) == "animal_fox", "unlocked click emits the selected avatar id")
	_expect_false(picker.is_panel_open(), "successful selection closes the picker")

	_expect_layout(Vector2(720, 1280), 4)
	_expect_layout(Vector2(540, 960), 3)
	_expect_layout(Vector2(1280, 720), 6)
	picker.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("ACCOUNT_AVATAR_PICKER_PASS")
	get_tree().quit(failures)


func _button_for_avatar(buttons: Array[Button], avatar_id: String) -> Button:
	for button in buttons:
		if String(button.get_meta("avatar_id", "")) == avatar_id:
			return button
	return null


func _expect_layout(viewport_size: Vector2, expected_columns: int) -> void:
	var metrics = AccountAvatarPicker.layout_metrics_for_viewport(viewport_size)
	var panel_size: Vector2 = metrics.get("panel_size", Vector2.ZERO)
	var safe_margin = float(metrics.get("safe_margin", 0.0))
	_expect_equal(int(metrics.get("columns", 0)), expected_columns, "%s uses the expected responsive column count" % viewport_size)
	_expect_true(panel_size.x <= viewport_size.x - safe_margin * 2.0 + 0.01, "%s panel width stays inside the viewport" % viewport_size)
	_expect_true(panel_size.y <= viewport_size.y - safe_margin * 2.0 + 0.01, "%s panel height stays inside the viewport" % viewport_size)


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
