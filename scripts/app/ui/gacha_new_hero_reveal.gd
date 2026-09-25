extends RefCounted
## Presentation only. The caller decides first ownership and grants the card.
signal hero_revealed(card: Dictionary)
const CardRules = preload("res://scripts/app/systems/card_rules.gd")
const UISkin = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")
const REVEAL_SECONDS = 2.0
const FLIP_SECONDS = 0.56
const SIZE = Vector2(720, 1280)
var app
var current: Dictionary = {}
var pending: Array = []
var stage = ""
var elapsed = 0.0
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
		_begin_flip()
	elif stage == "flip" and elapsed >= FLIP_SECONDS:
		_show_hero()


func tap() -> bool:
	if not active():
		return false
	if stage == "rarity":
		_begin_flip()
	elif stage == "hero":
		completed_count += 1
		_begin_next()
	# Flip input is consumed without dismissing or restarting the animation.
	return true


func _begin_next() -> void:
	current = pending.pop_front() if not pending.is_empty() else {}
	stage = "rarity" if not current.is_empty() else ""
	elapsed = 0.0


func _begin_flip() -> void:
	if not active() or stage != "rarity":
		return
	stage = "flip"
	elapsed = 0.0


func _show_hero() -> void:
	if not active() or stage != "flip":
		return
	stage = "hero"
	elapsed = 0.0
	hero_revealed.emit(current.duplicate(true))


func draw() -> void:
	if not active():
		return
	var color = UISkin.rarity(String(current.get("rarity", "common")))
	app.draw_rect(Rect2(Vector2.ZERO, SIZE), UISkin.PAPER)
	app.draw_circle(Vector2(360, 525), 326, color.lerp(UISkin.PAPER, 0.68))
	app.draw_circle(Vector2(360, 525), 254, color.lerp(UISkin.PAPER, 0.42))
	_draw_rays(Vector2(360, 525), color)
	if stage == "hero":
		_draw_hero()
	else:
		_text("新伙伴即将登场", Rect2(60, 124, 600, 78), 44)
		_draw_reveal_card(color)


func _draw_rays(center: Vector2, color: Color) -> void:
	for i in range(12):
		var angle = float(i) * TAU / 12.0 + sin(elapsed * 0.4) * 0.035
		var direction = Vector2(cos(angle), sin(angle))
		var a = center + direction * 270
		var b = center + direction * (302 + 9 * sin(elapsed * 2 + i))
		app.draw_line(a, b, color.darkened(0.14), 5, true)


func _draw_reveal_card(color: Color) -> void:
	var rect = Rect2(181, 310, 358, 358 * 158.0 / 132.0)
	var progress = clampf(elapsed / FLIP_SECONDS, 0, 1) if stage == "flip" else 0.0
	var width_scale = maxf(0.04, absf(cos(progress * PI))) if stage == "flip" else 1.0
	# Transform the whole card around its center so art cannot reflow or stretch at rest.
	app._set_tracked_draw_transform(app.canvas_offset + Vector2(rect.get_center().x * (1.0 - width_scale), 0) * app.canvas_scale, 0.0, Vector2(width_scale, 1.0) * app.canvas_scale)
	app.draw_style_box(UISkin.panel(color.darkened(0.18), 32, true), rect.grow(8))
	app.draw_style_box(UISkin.panel(UISkin.RAISED, 26, false), rect)
	app.draw_style_box(UISkin.panel(color, 20, false), rect.grow(-18))
	if stage == "flip" and progress >= 0.5:
		_draw_portrait(rect.grow(-36), false)
	else:
		_draw_paw(rect.get_center(), color)
	app._set_tracked_draw_transform(app.canvas_offset, 0.0, Vector2.ONE * app.canvas_scale)


func _draw_paw(center: Vector2, color: Color) -> void:
	# A simple motif keeps the card back free of quality words and instructions.
	app.draw_circle(center + Vector2(0, 24), 47, UISkin.RAISED)
	for offset in [Vector2(-61, -24), Vector2(-25, -67), Vector2(25, -67), Vector2(61, -24)]:
		app.draw_circle(center + offset, 22, UISkin.RAISED)
	app.draw_circle(center + Vector2(0, 32), 18, color.lerp(UISkin.RAISED, 0.55))


func _draw_hero() -> void:
	_draw_portrait(Rect2(96, 260, 528, 528))
	_text(String(current.get("name", current.get("id", ""))), Rect2(64, 840, 592, 64), 46)
	app.draw_style_box(UISkin.panel(UISkin.PRIMARY, 18, true), Rect2(138, 1112, 444, 76))
	_text("继续", Rect2(138, 1112, 444, 76), 34)


func _draw_portrait(rect: Rect2, entrance_motion: bool = true) -> void:
	var texture: Texture2D = app._card_art_texture_or_null(current)
	if texture == null:
		return
	var normalized: Rect2 = app._animal_texture_visible_rect(texture)
	var source = Rect2(normalized.position * texture.get_size(), normalized.size * texture.get_size())
	if not source.has_area():
		return
	var entrance = 1.0 - pow(1.0 - clampf(elapsed / 0.42, 0, 1), 3) if entrance_motion else 1.0
	var art_scale = minf(rect.size.x / source.size.x, rect.size.y / source.size.y) * lerpf(0.92, 1.0, entrance)
	var size = source.size * art_scale
	var offset = Vector2(0, 14 * (1.0 - entrance) + sin(elapsed * 1.5) * 3) if entrance_motion else Vector2.ZERO
	var target = Rect2(rect.get_center() - size * 0.5 + offset, size)
	app.draw_texture_rect_region(texture, target, source)


func _text(content: String, rect: Rect2, font_size: int, color: Color = UISkin.INK) -> void:
	app._draw_text_native(content, rect, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
