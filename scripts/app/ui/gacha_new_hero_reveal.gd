extends RefCounted
## Presentation only. The caller decides first ownership and grants the card.
signal hero_revealed(card: Dictionary)
const CardRules = preload("res://scripts/app/systems/card_rules.gd")
const UISkin = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")
const REVEAL_SECONDS = 2.0
const SIZE = Vector2(720, 1280)
const SKILL_LINES_PER_PAGE = 4
const QUALITY_NAMES = {"common": "普通", "rare": "稀有", "epic": "史诗", "legendary": "传说"}
var app
var current: Dictionary = {}
var pending: Array = []
var stage = ""
var elapsed = 0.0
var skill_page = 0
var completed_count = 0


func _init(owner) -> void:
	app = owner


func enqueue(card: Dictionary) -> bool:
	var id = String(card.get("id", ""))
	if id.is_empty() or not CardRules.is_animal_card(card):
		return false
	if String(current.get("id", "")) == id:
		return false
	for queued in pending:
		if String(queued.get("id", "")) == id:
			return false
	pending.append(card.duplicate(true))
	if not active():
		_begin_next()
	return true


func active() -> bool:
	return not current.is_empty()


func update(delta: float) -> void:
	if not active():
		return
	elapsed += maxf(0.0, delta)
	if stage == "rarity" and elapsed >= REVEAL_SECONDS:
		_show_hero()


func tap() -> bool:
	if not active():
		return false
	if stage == "rarity":
		_show_hero()
	elif skill_page + 1 < skill_page_count():
		skill_page += 1
	else:
		completed_count += 1
		_begin_next()
	return true


func _begin_next() -> void:
	current = pending.pop_front() if not pending.is_empty() else {}
	stage = "rarity" if not current.is_empty() else ""
	elapsed = 0.0
	skill_page = 0


func _show_hero() -> void:
	if not active() or stage != "rarity":
		return
	stage = "hero"
	elapsed = 0.0
	skill_page = 0
	hero_revealed.emit(current.duplicate(true))


func skill_lines() -> Array[String]:
	var content = String(current.get("skill_text", "")).strip_edges()
	if content.is_empty():
		content = "暂无专属技能"
	return _wrap(content, 548.0, 30)


func skill_page_count() -> int:
	return maxi(1, int(ceil(float(skill_lines().size()) / SKILL_LINES_PER_PAGE)))


func _wrap(content: String, width: float, font_size: int) -> Array[String]:
	var result: Array[String] = []
	var line = ""
	for character in content:
		if character == "\n":
			result.append(line)
			line = ""
			continue
		if not line.is_empty() and app.font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			result.append(line)
			line = ""
		line += character
	if not line.is_empty():
		result.append(line)
	return result


func draw() -> void:
	if not active():
		return
	var rarity = String(current.get("rarity", "common"))
	var color = UISkin.rarity(rarity)
	app.draw_rect(Rect2(Vector2.ZERO, SIZE), UISkin.PAPER)
	app.draw_circle(Vector2(360, 410), 326, color.lerp(UISkin.PAPER, 0.68))
	app.draw_circle(Vector2(360, 410), 254, color.lerp(UISkin.PAPER, 0.42))
	_draw_rays(Vector2(360, 440), color)
	if stage == "rarity":
		_draw_rarity(rarity, color)
	else:
		_draw_hero(rarity, color)


func _draw_rays(center: Vector2, color: Color) -> void:
	for i in range(12):
		var angle = float(i) * TAU / 12.0 + sin(elapsed * 0.4) * 0.035
		var direction = Vector2(cos(angle), sin(angle))
		var a = center + direction * 270
		var b = center + direction * (302 + 9 * sin(elapsed * 2 + i))
		app.draw_line(a, b, color.darkened(0.14), 5, true)


func _draw_rarity(rarity: String, color: Color) -> void:
	_text("新伙伴即将登场", Rect2(60, 124, 600, 78), 44)
	var lift = sin(clampf(elapsed / REVEAL_SECONDS, 0, 1) * PI) * 12
	var card_rect = Rect2(181, 287 - lift, 358, 468)
	app.draw_style_box(UISkin.panel(color.darkened(0.18), 32, true), card_rect.grow(8))
	app.draw_style_box(UISkin.panel(UISkin.RAISED, 26, false), card_rect)
	app.draw_style_box(UISkin.panel(color, 20, false), card_rect.grow(-18))
	var seal_center = Vector2(360, 461 - lift)
	var hex = PackedVector2Array()
	for i in range(6):
		hex.append(seal_center + Vector2.from_angle(TAU * float(i) / 6.0) * 105)
	app.draw_colored_polygon(hex, UISkin.RAISED)
	var outline = hex.duplicate()
	outline.append(hex[0])
	app.draw_polyline(outline, color.darkened(0.28), 4, true)
	_text(String(QUALITY_NAMES.get(rarity, "普通")), Rect2(258, 422 - lift, 204, 78), 50)
	_text(CardRules.rarity_label(rarity) + "品质", Rect2(217, 602 - lift, 286, 60), 36)
	_text("发现新的动物伙伴", Rect2(60, 839, 600, 54), 32)
	_text("点击揭晓", Rect2(60, 934, 600, 64), 36)
	app.draw_style_box(UISkin.panel(UISkin.SURFACE, 5, false), Rect2(220, 1038, 280, 10))
	var progress = clampf(elapsed / REVEAL_SECONDS, 0.01, 1.0)
	app.draw_style_box(UISkin.panel(color.darkened(0.18), 5, false), Rect2(220, 1038, 280 * progress, 10))
	_text("即将加入你的队伍", Rect2(60, 1091, 600, 48), 28)


func _draw_hero(rarity: String, color: Color) -> void:
	_text("新伙伴加入", Rect2(60, 50, 600, 65), 42)
	app.draw_style_box(UISkin.panel(color, 20, false), Rect2(216, 127, 288, 52))
	_text(CardRules.rarity_label(rarity) + " · " + String(QUALITY_NAMES.get(rarity, "普通")), Rect2(216, 128, 288, 50), 30)
	var art_rect = Rect2(143, 215, 434, 348)
	_draw_portrait(art_rect)
	var name_lines = _wrap(String(current.get("name", current.get("id", ""))), 592, 44)
	for i in range(name_lines.size()):
		_text(name_lines[i], Rect2(64, 591 + i * 48, 592, 48), 44)
	app.draw_style_box(UISkin.panel(UISkin.RAISED, 18, false), Rect2(64, 674, 592, 165))
	var stats: Dictionary = app._card_stats(current)
	_stat("攻击", str(int(stats.get("attack", 0))), Rect2(78, 685, 276, 65))
	_stat("生命", str(int(stats.get("max_hp", 0))), Rect2(366, 685, 276, 65))
	var cells_per_second = float(current.get("base_move_speed", 0.0)) * float(app.UNIT_MOVE_SPEED_MULT)
	_stat("移速", "%s 格/秒" % _number(cells_per_second), Rect2(78, 765, 276, 65))
	var range_cells = float(stats.get("attack_range_cells", current.get("base_attack_range", 0.0)))
	_stat("射程", CardRules.attack_range_label(range_cells, 43.0), Rect2(366, 765, 276, 65))
	_text("专属能力", Rect2(80, 852, 560, 42), 28)
	var lines = skill_lines()
	var first = skill_page * SKILL_LINES_PER_PAGE
	for i in range(first, mini(first + SKILL_LINES_PER_PAGE, lines.size())):
		_text(lines[i], Rect2(86, 908 + (i - first) * 37, 548, 37), 30)
	var more_pages = skill_page + 1 < skill_page_count()
	var button_text = "继续阅读" if more_pages else ("下一位伙伴" if not pending.is_empty() else "继续")
	app.draw_style_box(UISkin.panel(UISkin.PRIMARY, 18, true), Rect2(138, 1112, 444, 76))
	_text(button_text, Rect2(138, 1112, 444, 76), 34)
	if skill_page_count() > 1:
		_text("能力 %d / %d" % [skill_page + 1, skill_page_count()], Rect2(60, 1202, 600, 40), 26)
	elif not pending.is_empty():
		_text("还有 %d 位新伙伴" % pending.size(), Rect2(60, 1202, 600, 40), 26)


func _draw_portrait(rect: Rect2) -> void:
	var texture: Texture2D = app._card_art_texture_or_null(current)
	if texture == null:
		_text("伙伴立绘加载中", rect, 30)
		return
	var normalized: Rect2 = app._animal_texture_visible_rect(texture)
	var source = Rect2(normalized.position * texture.get_size(), normalized.size * texture.get_size())
	if not source.has_area():
		return
	var entrance = 1.0 - pow(1.0 - clampf(elapsed / 0.42, 0, 1), 3)
	var art_scale = minf(rect.size.x / source.size.x, rect.size.y / source.size.y) * lerpf(0.92, 1.0, entrance)
	var size = source.size * art_scale
	var offset = Vector2(0, 14 * (1.0 - entrance) + sin(elapsed * 1.5) * 3)
	var target = Rect2(rect.get_center() - size * 0.5 + offset, size)
	app.draw_texture_rect_region(texture, target, source)


func _stat(label: String, value: String, rect: Rect2) -> void:
	_text(label, Rect2(rect.position, Vector2(rect.size.x, 28)), 24, UISkin.DISABLED_INK)
	_text(value, Rect2(rect.position + Vector2(0, 28), Vector2(rect.size.x, 36)), 30)


func _number(value: float) -> String:
	return str(snappedf(value, 0.01))


func _text(content: String, rect: Rect2, font_size: int, color: Color = UISkin.INK) -> void:
	# Width is preflighted/wrapped above: never invoke a shrinking/ellipsis helper.
	app._draw_text_native(content, rect, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
