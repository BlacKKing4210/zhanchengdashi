extends CanvasLayer

signal resource_change_requested(resource_id: String, operation_id: String, amount_text: String, card_id: String)
signal panel_closed

const GmResourceRules = preload("res://scripts/app/systems/gm_resource_rules.gd")
const UISkin = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")

const COLOR_BACKDROP = Color(0.025, 0.035, 0.06, 0.82)
const COLOR_PANEL = UISkin.RAISED
const COLOR_BORDER = Color(0.33, 0.70, 1.0, 1.0)
const COLOR_FIELD = UISkin.SURFACE
const COLOR_TEXT = UISkin.INK
const COLOR_MUTED = Color("675e51")
const COLOR_SUCCESS = Color("356345")
const COLOR_ERROR = Color("a12f27")

var context: Dictionary = {}
var backdrop: ColorRect
var center: CenterContainer
var panel_container: PanelContainer
var scroll_container: ScrollContainer
var resource_option: OptionButton
var operation_option: OptionButton
var card_row: HBoxContainer
var card_option: OptionButton
var amount_field: LineEdit
var current_value_label: Label
var restriction_label: Label
var feedback_label: Label
var apply_button: Button


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	var viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_update_layout):
		viewport.size_changed.connect(_update_layout)
	_update_layout()
	hide_panel()


func show_panel(next_context: Dictionary) -> void:
	context = next_context.duplicate(true)
	_populate_cards()
	_refresh_controls()
	_update_layout()
	backdrop.show()
	feedback_label.text = ""
	amount_field.text = "100"
	amount_field.grab_focus()


func hide_panel() -> void:
	if backdrop == null:
		return
	var was_visible = backdrop.visible
	backdrop.hide()
	if amount_field != null:
		amount_field.release_focus()
	if was_visible:
		panel_closed.emit()


func is_panel_open() -> bool:
	return backdrop != null and backdrop.visible


func set_context(next_context: Dictionary) -> void:
	context = next_context.duplicate(true)
	_populate_cards()
	_refresh_controls()


func show_result(message: String, success: bool) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", COLOR_SUCCESS if success else COLOR_ERROR)
	_refresh_controls()


func selected_resource_id() -> String:
	return _selected_metadata(resource_option)


func selected_operation_id() -> String:
	return _selected_metadata(operation_option)


func selected_card_id() -> String:
	return _selected_metadata(card_option)


static func layout_metrics_for_viewport(viewport_size: Vector2) -> Dictionary:
	var safe_margin = 14.0 if minf(viewport_size.x, viewport_size.y) < 700.0 else 22.0
	var available = Vector2(
		maxf(360.0, viewport_size.x - safe_margin * 2.0),
		maxf(520.0, viewport_size.y - safe_margin * 2.0)
	)
	var target_width = minf(760.0, available.x)
	var target_height = minf(1040.0 if viewport_size.y >= 900.0 else 760.0, available.y)
	return {
		"safe_margin": safe_margin,
		"panel_size": Vector2(target_width, target_height),
	}


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	center = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	panel_container = PanelContainer.new()
	panel_container.name = "Panel"
	panel_container.add_theme_stylebox_override("panel", _style_box(COLOR_PANEL, COLOR_BORDER, 4, 20))
	center.add_child(panel_container)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel_container.add_child(margin)

	var shell = VBoxContainer.new()
	shell.name = "Shell"
	shell.add_theme_constant_override("separation", 16)
	margin.add_child(shell)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	shell.add_child(header)
	var title = _label("运行时 GM", 38, COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var shortcut = _label("F2 开关", 24, COLOR_MUTED)
	shortcut.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(shortcut)
	var close_button = _button("关闭", 118.0)
	close_button.name = "CloseButton"
	close_button.pressed.connect(hide_panel)
	header.add_child(close_button)

	var divider = HSeparator.new()
	divider.modulate = COLOR_BORDER
	shell.add_child(divider)

	scroll_container = ScrollContainer.new()
	scroll_container.name = "BodyScroll"
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.follow_focus = true
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(scroll_container)

	var body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	scroll_container.add_child(body)

	var warning = _label("仅限调试构建 · 互联网对战禁用 · 不写入已登录账号", 23, Color("876017"))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(warning)

	resource_option = _option_button("ResourceOption")
	for option in GmResourceRules.resource_options():
		_add_option(resource_option, String(option.get("label", "")), String(option.get("id", "")))
	resource_option.item_selected.connect(_on_selection_changed)
	body.add_child(_field_row("资源", resource_option))

	card_option = _option_button("CardOption")
	card_option.item_selected.connect(_on_selection_changed)
	card_row = _field_row("卡牌", card_option)
	body.add_child(card_row)

	operation_option = _option_button("OperationOption")
	for option in GmResourceRules.operation_options():
		_add_option(operation_option, String(option.get("label", "")), String(option.get("id", "")))
	operation_option.item_selected.connect(_on_selection_changed)
	body.add_child(_field_row("操作", operation_option))

	amount_field = LineEdit.new()
	amount_field.name = "AmountField"
	amount_field.text = "100"
	amount_field.placeholder_text = "请输入非负整数"
	amount_field.custom_minimum_size = Vector2(0.0, 68.0)
	amount_field.virtual_keyboard_enabled = true
	amount_field.virtual_keyboard_show_on_focus = true
	amount_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	amount_field.mouse_filter = Control.MOUSE_FILTER_STOP
	amount_field.add_theme_font_size_override("font_size", 28)
	amount_field.add_theme_color_override("font_color", COLOR_TEXT)
	amount_field.add_theme_color_override("font_placeholder_color", COLOR_MUTED)
	amount_field.add_theme_stylebox_override("normal", _style_box(COLOR_FIELD, Color(0.27, 0.35, 0.49), 2, 12))
	amount_field.add_theme_stylebox_override("focus", _style_box(COLOR_FIELD, COLOR_BORDER, 3, 12))
	amount_field.text_submitted.connect(_on_amount_submitted)
	body.add_child(_field_row("数值", amount_field))

	current_value_label = _label("当前值：—", 27, COLOR_TEXT)
	body.add_child(current_value_label)
	restriction_label = _label("", 23, COLOR_MUTED)
	restriction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	restriction_label.custom_minimum_size = Vector2(0.0, 58.0)
	body.add_child(restriction_label)
	feedback_label = _label("", 24, COLOR_SUCCESS)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(0.0, 58.0)
	body.add_child(feedback_label)

	apply_button = _button("执行资源修改", 0.0)
	apply_button.name = "ApplyButton"
	apply_button.custom_minimum_size = Vector2(0.0, 78.0)
	apply_button.add_theme_font_size_override("font_size", 30)
	apply_button.pressed.connect(_request_change)
	body.add_child(apply_button)

	var footnote = _label("测试数据仅保留在当前运行会话；关闭游戏后不会自动保存。", 21, COLOR_MUTED)
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(footnote)


func _update_layout() -> void:
	if center == null or panel_container == null:
		return
	var metrics = layout_metrics_for_viewport(get_viewport().get_visible_rect().size)
	var safe_margin = float(metrics.get("safe_margin", 18.0))
	center.offset_left = safe_margin
	center.offset_top = safe_margin
	center.offset_right = -safe_margin
	center.offset_bottom = -safe_margin
	panel_container.custom_minimum_size = metrics.get("panel_size", Vector2(676.0, 1040.0))


func _populate_cards() -> void:
	if card_option == null:
		return
	var previous_card_id = selected_card_id()
	card_option.clear()
	var card_entries = context.get("cards", [])
	if typeof(card_entries) != TYPE_ARRAY:
		return
	for card_value in card_entries:
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = card_value
		var card_id = String(card.get("id", ""))
		if card_id.is_empty():
			continue
		var card_name = String(card.get("name", card_id))
		_add_option(card_option, "%s（%s）" % [card_name, card_id], card_id)
		if card_id == previous_card_id:
			card_option.select(card_option.item_count - 1)


func _refresh_controls() -> void:
	if resource_option == null:
		return
	var resource_id = selected_resource_id()
	var requires_card = GmResourceRules.uses_card(resource_id)
	card_row.visible = requires_card
	card_option.disabled = card_option.item_count == 0
	var current_value = _context_current_value(resource_id, selected_card_id())
	current_value_label.text = "当前值：%d" % current_value
	var availability = GmResourceRules.availability(resource_id, context)
	var allowed = bool(availability.get("ok", false)) and (not requires_card or card_option.item_count > 0)
	apply_button.disabled = not allowed
	amount_field.editable = allowed
	if allowed:
		if resource_id == GmResourceRules.RESOURCE_CARD_LEVEL:
			restriction_label.text = "允许范围：1–%d" % GmResourceRules.MAX_CARD_LEVEL
		else:
			restriction_label.text = "允许范围：0–%d" % GmResourceRules.MAX_RESOURCE_VALUE
		restriction_label.add_theme_color_override("font_color", COLOR_MUTED)
	else:
		var denial_message = String(availability.get("message", ""))
		if denial_message.is_empty():
			denial_message = "没有可操作的卡牌"
		restriction_label.text = denial_message
		restriction_label.add_theme_color_override("font_color", COLOR_ERROR)


func _context_current_value(resource_id: String, card_id: String) -> int:
	var resources_value = context.get("resources", {})
	var resources: Dictionary = resources_value if typeof(resources_value) == TYPE_DICTIONARY else {}
	if resource_id == GmResourceRules.RESOURCE_BATTLE_GOLD:
		return int(resources.get(GmResourceRules.RESOURCE_BATTLE_GOLD, 0))
	if resource_id == GmResourceRules.RESOURCE_GACHA_TICKETS:
		return int(resources.get(GmResourceRules.RESOURCE_GACHA_TICKETS, 0))
	if resource_id == GmResourceRules.RESOURCE_CARD_COUNT:
		var counts_value = context.get("card_counts", {})
		var counts: Dictionary = counts_value if typeof(counts_value) == TYPE_DICTIONARY else {}
		return int(counts.get(card_id, 0))
	if resource_id == GmResourceRules.RESOURCE_CARD_LEVEL:
		var levels_value = context.get("card_levels", {})
		var levels: Dictionary = levels_value if typeof(levels_value) == TYPE_DICTIONARY else {}
		return maxi(GmResourceRules.MIN_CARD_LEVEL, int(levels.get(card_id, GmResourceRules.MIN_CARD_LEVEL)))
	return 0


func _on_selection_changed(_index: int) -> void:
	feedback_label.text = ""
	_refresh_controls()


func _on_amount_submitted(_value: String) -> void:
	_request_change()


func _request_change() -> void:
	if apply_button.disabled:
		return
	resource_change_requested.emit(
		selected_resource_id(),
		selected_operation_id(),
		amount_field.text,
		selected_card_id()
	)


func _selected_metadata(option: OptionButton) -> String:
	if option == null or option.item_count == 0 or option.selected < 0:
		return ""
	return String(option.get_item_metadata(option.selected))


func _add_option(option: OptionButton, label: String, metadata: String) -> void:
	option.add_item(label)
	option.set_item_metadata(option.item_count - 1, metadata)


func _field_row(label_text: String, field: Control) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var label = _label(label_text, 27, COLOR_TEXT)
	label.custom_minimum_size = Vector2(138.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row


func _option_button(control_name: String) -> OptionButton:
	var option = OptionButton.new()
	option.name = control_name
	option.custom_minimum_size = Vector2(0.0, 68.0)
	option.mouse_filter = Control.MOUSE_FILTER_STOP
	option.add_theme_font_size_override("font_size", 27)
	option.add_theme_color_override("font_color", COLOR_TEXT)
	option.add_theme_color_override("font_hover_color", COLOR_TEXT)
	option.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	option.add_theme_color_override("icon_normal_color", COLOR_MUTED)
	var popup = option.get_popup()
	popup.add_theme_stylebox_override("panel", _style_box(UISkin.RAISED, Color.TRANSPARENT, 0, 12))
	popup.add_theme_stylebox_override("hover", _style_box(UISkin.PRIMARY, Color.TRANSPARENT, 0, 8))
	popup.add_theme_color_override("font_color", COLOR_TEXT)
	popup.add_theme_color_override("font_hover_color", COLOR_TEXT)
	popup.add_theme_font_size_override("font_size", 24)
	option.add_theme_stylebox_override("normal", _style_box(COLOR_FIELD, Color(0.27, 0.35, 0.49), 2, 12))
	option.add_theme_stylebox_override("hover", _style_box(Color(0.16, 0.22, 0.34), COLOR_BORDER, 2, 12))
	return option


func _button(text: String, minimum_width: float) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(minimum_width, 62.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	button.add_theme_stylebox_override("normal", _style_box(Color(0.16, 0.40, 0.68), COLOR_BORDER, 2, 12))
	button.add_theme_stylebox_override("hover", _style_box(Color(0.21, 0.50, 0.82), Color(0.57, 0.85, 1.0), 3, 12))
	button.add_theme_stylebox_override("pressed", _style_box(Color(0.11, 0.30, 0.54), COLOR_BORDER, 2, 12))
	button.add_theme_stylebox_override("disabled", _style_box(Color(0.15, 0.17, 0.22), Color(0.31, 0.34, 0.40), 2, 12))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_box(fill: Color, _border: Color, _border_width: int, radius: int) -> StyleBoxFlat:
	var style = UISkin.panel(UISkin.surface_color(fill), radius).duplicate()
	style.content_margin_left = 18.0
	style.content_margin_top = 12.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 12.0
	return style
