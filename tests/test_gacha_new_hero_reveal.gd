extends Node

const Reveal = preload("res://scripts/app/ui/gacha_new_hero_reveal.gd")
const CardRules = preload("res://scripts/app/systems/card_rules.gd")
const UISkin = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")

class DrawProbe extends RefCounted:
	const UNIT_MOVE_SPEED_MULT = 0.5
	var canvas_offset = Vector2.ZERO
	var canvas_scale = 1.0
	var font: Font = ThemeDB.fallback_font
	var texts: Array = []
	var colors: Array = []
	var portraits: Array = []
	var wallet_gold = 987
	var gacha_tickets = 23
	var card_counts = {"mouse": 1}
	func _draw_text_native(text: String, rect: Rect2, font_size: int, color: Color, _alignment: int) -> void:
		texts.append({"text": text, "rect": rect, "font_size": font_size, "color": color})
	func _card_stats(card: Dictionary) -> Dictionary:
		var stats = CardRules.card_stats(card, {})
		stats.attack_range_cells = stats.attack_range
		stats.attack_range = maxf(0.65, float(stats.attack_range)) * sqrt(3.0) * 43.0
		stats.move_speed *= sqrt(3.0) * 43.0 * UNIT_MOVE_SPEED_MULT
		return stats
	func _card_art_texture_or_null(card: Dictionary) -> Texture2D:
		return load(String(card.art_path)) as Texture2D
	func _animal_texture_visible_rect(_texture: Texture2D) -> Rect2:
		return Rect2(0, 0, 1, 1)
	func _set_tracked_draw_transform(_origin: Vector2, _rotation: float, _scale: Vector2) -> void: pass
	func draw_rect(_rect: Rect2, color: Color) -> void: colors.append(color)
	func draw_circle(_center: Vector2, _radius: float, color: Color) -> void: colors.append(color)
	func draw_line(_a: Vector2, _b: Vector2, _color: Color, _width: float, _antialias: bool) -> void: pass
	func draw_style_box(style: StyleBoxFlat, _rect: Rect2) -> void: colors.append(style.bg_color)
	func draw_colored_polygon(_polygon: PackedVector2Array, color: Color) -> void: colors.append(color)
	func draw_polyline(_polygon: PackedVector2Array, _color: Color, _width: float, _antialias: bool) -> void: pass
	func draw_texture_rect_region(texture: Texture2D, target: Rect2, source: Rect2) -> void:
		portraits.append({"texture": texture.resource_path, "target": target, "source": source})
	func reset() -> void:
		texts.clear()
		colors.clear()
		portraits.clear()

var checks = 0
var failures = 0
var cards: Array = []
var probe: DrawProbe


func _ready() -> void:
	GameAudio.set_music_enabled(false)
	GameAudio.set_sfx_enabled(false)
	for row in ConfigDB.get_table("cards"):
		var card = CardRules.card_from_row(row)
		if CardRules.is_animal_card(card):
			cards.append(card)
	probe = DrawProbe.new()
	_test_sequence()
	_test_all_cards()
	_test_long_skill()
	print("GACHA_NEW_HERO_REVEAL_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "animal_cards": cards.size(), "scope": "presentation logic and measured design-canvas text; root owns real gacha input and GPU"}))
	probe = null
	await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GACHA_REVEAL: " + label)


func _test_sequence() -> void:
	var reveal = Reveal.new(probe)
	var original_inventory = probe.card_counts.duplicate(true)
	check(not reveal.active() and not reveal.tap(), "idle presenter ignores input")
	check(not reveal.enqueue({}), "empty card rejected")
	check(not reveal.enqueue({"id": "defense_test", "tags": ["tower"]}), "non-animal cannot enter new-hero scene")
	var first: Dictionary = cards[0].duplicate(true)
	check(reveal.enqueue(first), "first card queued")
	check(reveal.stage == "rarity" and reveal.active(), "first card starts at quality page")
	first.name = "mutated outside presenter"
	check(reveal.current.name != first.name, "presentation snapshots card input")
	check(not reveal.enqueue(cards[0]), "same pending first-ownership event not shown twice")
	check(reveal.enqueue(cards[1]) and reveal.pending.size() == 1, "multiple first-time heroes queued")
	reveal.update(-10)
	check(reveal.elapsed == 0, "negative delta cannot reverse timer")
	reveal.update(1.99)
	check(reveal.stage == "rarity", "quality page remains before two seconds")
	reveal.update(0.01)
	check(reveal.stage == "flip", "two seconds starts automatic card flip")
	reveal.tap()
	check(reveal.stage == "flip", "tap during flip cannot skip the reveal")
	reveal.update(Reveal.FLIP_SECONDS)
	check(reveal.stage == "hero", "flip completion reveals the hero")
	reveal.update(100)
	check(reveal.stage == "hero" and reveal.current.id == cards[0].id, "hero details never auto-dismiss")
	check(reveal.tap() and reveal.current.id == cards[1].id and reveal.stage == "rarity", "hero tap advances to next quality reveal")
	check(reveal.tap() and reveal.stage == "flip", "card tap starts reveal flip")
	reveal.update(Reveal.FLIP_SECONDS)
	reveal.tap()
	check(not reveal.active() and reveal.pending.is_empty() and reveal.completed_count == 2, "last hero tap returns to caller")
	check(probe.wallet_gold == 987 and probe.gacha_tickets == 23 and probe.card_counts == original_inventory, "presentation does not grant or spend resources")
	check(reveal.enqueue(cards[0]), "a new independent ownership event can replay after queue completion")
	reveal = null


func _test_all_cards() -> void:
	for card in cards:
		var reveal = Reveal.new(probe)
		reveal.enqueue(card)
		probe.reset()
		reveal.draw()
		check(probe.colors.has(UISkin.rarity(card.rarity)), "official quality color " + card.id)
		check(probe.texts.size() == 1 and probe.texts[0].text == "新伙伴即将登场", "no quality labels or below-card instructions " + card.id)
		check(probe.portraits.is_empty(), "portrait remains hidden on quality page " + card.id)
		_check_text_bounds(card.id + " quality")
		reveal.tap()
		reveal.update(Reveal.FLIP_SECONDS)
		reveal.update(0.5)
		probe.reset()
		reveal.draw()
		check(probe.portraits.size() == 1 and probe.portraits[0].texture == card.art_path, "existing formal portrait " + card.id)
		check(probe.texts.any(func(item): return item.text == card.name), "full Chinese name " + card.id)
		check(probe.texts.size() == 2 and probe.texts[1].text == "继续", "hero only shows name and continue " + card.id)
		_check_text_bounds(card.id + " hero")
		for portrait in probe.portraits:
			check(Rect2(90, 254, 540, 548).encloses(portrait.target), "hero illustration stays above name " + card.id)
		reveal = null


func _test_long_skill() -> void:
	var reveal = Reveal.new(probe)
	var stress: Dictionary = cards[0].duplicate(true)
	stress.skill_text = "攻击敌人后，为所有友方动物恢复生命并提高移动速度。".repeat(12)
	reveal.enqueue(stress)
	reveal.tap()
	reveal.update(Reveal.FLIP_SECONDS)
	probe.reset()
	reveal.draw()
	check(probe.texts.size() == 2, "long ability cannot leak into the clean celebration")
	check(reveal.current.skill_text == stress.skill_text, "ability data remains intact for collection")
	reveal.tap()
	check(not reveal.active(), "continue exits in one tap regardless of ability length")
	reveal = null


func _check_text_bounds(label: String) -> void:
	for text in probe.texts:
		var size = probe.font.get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(text.font_size))
		check(size.x <= text.rect.size.x + 0.01, "no horizontal text clipping " + label + ": " + text.text)
		check(Rect2(Vector2.ZERO, Reveal.SIZE).encloses(text.rect), "text stays on design canvas " + label)
		check(int(text.font_size) >= 24, "minimum logical font 24 " + label)
	for a in range(probe.texts.size()):
		for b in range(a + 1, probe.texts.size()):
			check(not probe.texts[a].rect.intersects(probe.texts[b].rect), "critical text boxes never overlap " + label)
