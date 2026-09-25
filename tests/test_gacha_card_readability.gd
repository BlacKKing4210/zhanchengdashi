extends Node
const Base = preload("res://tests/test_online_rewards_release.gd")
class Probe extends Base.TestApp:
	var card_probe = false
	var labels: Array = []
	var probe_cards: Array = []
	func _draw_gacha_screen() -> void:
		super._draw_gacha_screen()
		card_probe = true
		for card in probe_cards:
			_draw_gacha_showcase_card(_gacha_reward_card_rect(0, 10), card)
		card_probe = false
	func _draw_text_center(text: String, rect: Rect2, size: int, color: Color) -> void:
		if card_probe:
			labels.append({"text": text, "width": font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, "rect": rect, "size": size})
		super._draw_text_center(text, rect, size, color)

var checks = 0
var failures = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	GameAudio.set_music_enabled(false)
	GameAudio.set_sfx_enabled(false)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(360, 640)
	add_child(viewport)
	var app = Probe.new()
	viewport.add_child(app)
	app.set_process(false)
	app.screen = "gacha"
	app.probe_cards = app.cards.duplicate(true)
	app.queue_redraw()
	await get_tree().process_frame
	for label in app.labels:
		check(label.width <= label.rect.size.x, "No ellipsis or clipping: " + label.text)
		check(label.size >= 23, "Readable reward label: " + label.text)
	check(app.labels.size() == app.cards.size() * 2, "Every card name and explicit quality measured")
	for count in range(1, 11):
		var rects: Array = []
		for i in range(count):
			var rect = app._gacha_reward_card_rect(i, count)
			check(Rect2(46, 298, 628, 482).encloses(rect), "Reward stays inside content panel")
			for previous in rects: check(not rect.intersects(previous), "Reward cards do not overlap")
			rects.append(rect)
	print("GACHA_CARD_READABILITY checks=", checks, " failures=", failures, " cards=", app.cards.size())
	app.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
