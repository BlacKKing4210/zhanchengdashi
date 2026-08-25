extends CanvasLayer

signal avatar_selected(avatar_id: String)
signal locked_avatar_pressed(display_name: String, unlock_hint: String)
signal panel_closed

const AccountIdentityRules = preload("res://scripts/shared/account_identity_rules.gd")

const COLOR_BACKDROP = Color(0.03, 0.04, 0.06, 0.82)
const COLOR_PANEL = Color(0.96, 0.86, 0.66, 1.0)
const COLOR_INK = Color(0.09, 0.12, 0.18, 1.0)
const COLOR_MUTED = Color(0.32, 0.30, 0.28, 1.0)
const COLOR_SELECTED = Color(1.0, 0.51, 0.10, 1.0)
const COLOR_LOCKED = Color(0.34, 0.35, 0.39, 1.0)
const RARITY_COLORS = {
	"common": Color(0.34, 0.78, 0.38, 1.0),
	"rare": Color(0.22, 0.55, 0.91, 1.0),
	"epic": Color(0.56, 0.25, 0.84, 1.0),
	"legendary": Color(0.96, 0.55, 0.10, 1.0),
}
const RARITY_NAMES = {
	"common": "普通",
	"rare": "稀有",
	"epic": "史诗",
	"legendary": "传说",
}

var catalog: Array = []
var card_counts: Dictionary = {}
var selected_avatar_id = ""
var current_avatar_id = ""
var backdrop: ColorRect
var center: CenterContainer
var panel_container: PanelContainer
var scroll_container: ScrollContainer
var avatar_grid: GridContainer
var title_label: Label
var count_label: Label
var footer_label: Label
var tile_buttons: Array[Button] = []


func _ready() -> void:
	layer = 210
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	var viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_update_layout):
		viewport.size_changed.connect(_update_layout)
	_update_layout()
	hide_panel()


func show_picker(
	next_catalog: Array,
	next_card_counts: Dictionary,
	next_selected_avatar_id: String,
	next_current_avatar_id: String
) -> void:
	catalog = next_catalog.duplicate(true)
	card_counts = next_card_counts.duplicate(true)
	selected_avatar_id = next_selected_avatar_id.strip_edges().to_lower()
	current_avatar_id = next_current_avatar_id.strip_edges().to_lower()
	_rebuild_grid()
	footer_label.text = "未拥有的头像会显示“锁定”；点击可查看获得方式。"
	footer_label.add_theme_color_override("font_color", COLOR_MUTED)
	_update_layout()
	backdrop.show()
	if scroll_container != null:
		scroll_container.scroll_vertical = 0


func hide_panel() -> void:
	if backdrop == null:
		return
	var was_visible = backdrop.visible
	backdrop.hide()
	if was_visible:
		panel_closed.emit()


func is_panel_open() -> bool:
	return backdrop != null and backdrop.visible


func avatar_count() -> int:
	return catalog.size()


func unlocked_avatar_count() -> int:
	var count = 0
	for entry_value in catalog:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if AccountIdentityRules.avatar_is_unlocked(entry.get("id", ""), card_counts, current_avatar_id):
			count += 1
	return count


static func layout_metrics_for_viewport(viewport_size: Vector2) -> Dictionary:
	var safe_margin = 16.0 if minf(viewport_size.x, viewport_size.y) < 700.0 else 22.0
	var available = Vector2(
		maxf(320.0, viewport_size.x - safe_margin * 2.0),
		maxf(480.0, viewport_size.y - safe_margin * 2.0)
	)
	var target_width = minf(1000.0 if viewport_size.x >= 1000.0 else 680.0, available.x)
	var target_height = minf(900.0 if viewport_size.y < 1000.0 else 1160.0, available.y)
	var columns = 6 if viewport_size.x >= 1000.0 else (4 if viewport_size.x >= 640.0 else 3)
	var inner_width = maxf(240.0, target_width - 72.0)
	var tile_width = floorf((inner_width - float(columns - 1) * 12.0) / float(columns))
	return {
		"safe_margin": safe_margin,
		"panel_size": Vector2(target_width, target_height),
		"columns": columns,
		"tile_size": Vector2(maxf(104.0, tile_width), 190.0),
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
	panel_container.add_theme_stylebox_override("panel", _style_box(COLOR_PANEL, COLOR_INK, 4, 18))
	center.add_child(panel_container)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel_container.add_child(margin)

	var shell = VBoxContainer.new()
	shell.name = "Shell"
	shell.add_theme_constant_override("separation", 12)
	margin.add_child(shell)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	shell.add_child(header)
	title_label = _label("选择动物头像", 32, COLOR_INK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button = _button("关闭")
	close_button.name = "CloseButton"
	close_button.custom_minimum_size = Vector2(104.0, 56.0)
	close_button.pressed.connect(hide_panel)
	header.add_child(close_button)

	var divider = HSeparator.new()
	divider.modulate = Color(0.40, 0.30, 0.18, 0.55)
	shell.add_child(divider)

	count_label = _label("全部动物", 19, COLOR_MUTED)
	shell.add_child(count_label)

	scroll_container = ScrollContainer.new()
	scroll_container.name = "AvatarScroll"
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.follow_focus = true
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(scroll_container)

	avatar_grid = GridContainer.new()
	avatar_grid.name = "AvatarGrid"
	avatar_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avatar_grid.add_theme_constant_override("h_separation", 12)
	avatar_grid.add_theme_constant_override("v_separation", 12)
	scroll_container.add_child(avatar_grid)

	footer_label = _label("未拥有的头像会显示“锁定”；点击可查看获得方式。", 18, COLOR_MUTED)
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.custom_minimum_size = Vector2(0.0, 42.0)
	shell.add_child(footer_label)


func _rebuild_grid() -> void:
	for child in avatar_grid.get_children():
		child.queue_free()
	tile_buttons.clear()
	var unlocked_count = unlocked_avatar_count()
	count_label.text = "全部动物 %d · 已解锁 %d · 锁定 %d" % [catalog.size(), unlocked_count, catalog.size() - unlocked_count]
	var metrics = layout_metrics_for_viewport(get_viewport().get_visible_rect().size)
	avatar_grid.columns = int(metrics.get("columns", 4))
	var tile_size: Vector2 = metrics.get("tile_size", Vector2(136.0, 190.0))
	for entry_value in catalog:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var button = _create_avatar_button(entry, tile_size)
		avatar_grid.add_child(button)
		tile_buttons.append(button)


func _create_avatar_button(entry: Dictionary, tile_size: Vector2) -> Button:
	var avatar_id = String(entry.get("id", "")).strip_edges().to_lower()
	var rarity = String(entry.get("rarity", "common")).strip_edges().to_lower()
	var rarity_color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
	var unlocked = AccountIdentityRules.avatar_is_unlocked(avatar_id, card_counts, current_avatar_id)
	var selected = avatar_id == selected_avatar_id
	var border_color = COLOR_SELECTED if selected else (rarity_color if unlocked else COLOR_LOCKED)
	var fill_color = Color(1.0, 0.97, 0.86, 1.0) if unlocked else Color(0.52, 0.51, 0.48, 1.0)
	var button = Button.new()
	button.name = "Avatar_%s" % String(entry.get("card_id", avatar_id))
	button.text = ""
	button.custom_minimum_size = tile_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = "选择%s头像" % String(entry.get("name", "")) if unlocked else AccountIdentityRules.avatar_unlock_hint(entry)
	button.set_meta("avatar_id", avatar_id)
	button.set_meta("unlocked", unlocked)
	button.add_theme_stylebox_override("normal", _style_box(fill_color, border_color, 5 if selected else 3, 12))
	button.add_theme_stylebox_override("hover", _style_box(fill_color.lightened(0.06), COLOR_SELECTED if unlocked else Color(0.75, 0.75, 0.75), 5, 12))
	button.add_theme_stylebox_override("pressed", _style_box(fill_color.darkened(0.06), border_color, 4, 12))
	button.pressed.connect(_on_avatar_pressed.bind(entry.duplicate(true), unlocked))

	var content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8.0
	content.offset_top = 8.0
	content.offset_right = -8.0
	content.offset_bottom = -8.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	button.add_child(content)

	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(0.0, 84.0)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path = String(entry.get("path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		portrait.texture = load(path) as Texture2D
	portrait.modulate = Color(1.0, 1.0, 1.0, 1.0 if unlocked else 0.32)
	content.add_child(portrait)

	var name_label = _label(String(entry.get("name", entry.get("card_id", "动物"))), 18, COLOR_INK if unlocked else Color(0.22, 0.22, 0.22))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(name_label)
	var rarity_label = _label(String(RARITY_NAMES.get(rarity, "普通")), 16, rarity_color if unlocked else COLOR_LOCKED)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(rarity_label)
	var state_label = _label("已选" if selected else ("可用" if unlocked else "锁定"), 16, COLOR_SELECTED if selected else (Color(0.18, 0.46, 0.23) if unlocked else Color(0.25, 0.25, 0.25)))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(state_label)
	return button


func _on_avatar_pressed(entry: Dictionary, unlocked: bool) -> void:
	if not unlocked:
		var unlock_hint = AccountIdentityRules.avatar_unlock_hint(entry)
		footer_label.text = "获取方式：%s" % unlock_hint
		footer_label.add_theme_color_override("font_color", Color(0.72, 0.34, 0.04))
		locked_avatar_pressed.emit(String(entry.get("name", "该动物")), unlock_hint)
		return
	selected_avatar_id = String(entry.get("id", "")).strip_edges().to_lower()
	avatar_selected.emit(selected_avatar_id)
	hide_panel()


func _update_layout() -> void:
	if center == null or panel_container == null:
		return
	var metrics = layout_metrics_for_viewport(get_viewport().get_visible_rect().size)
	var safe_margin = float(metrics.get("safe_margin", 18.0))
	center.offset_left = safe_margin
	center.offset_top = safe_margin
	center.offset_right = -safe_margin
	center.offset_bottom = -safe_margin
	panel_container.custom_minimum_size = metrics.get("panel_size", Vector2(680.0, 1160.0))
	if avatar_grid != null:
		avatar_grid.columns = int(metrics.get("columns", 4))
		var tile_size: Vector2 = metrics.get("tile_size", Vector2(136.0, 190.0))
		for button in tile_buttons:
			button.custom_minimum_size = tile_size


func _button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style_box(Color(0.47, 0.50, 0.63), COLOR_INK, 3, 8))
	button.add_theme_stylebox_override("hover", _style_box(Color(0.55, 0.59, 0.74), COLOR_SELECTED, 3, 8))
	button.add_theme_stylebox_override("pressed", _style_box(Color(0.39, 0.42, 0.56), COLOR_INK, 3, 8))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style
