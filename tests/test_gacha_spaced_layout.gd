extends Node
## Frozen evaluator: native input and actual draw interception; no roll/grant overrides.
const Base = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/gacha-spaced-20260925/"
const MIX = ["defense_longshot_tower", "mouse", "sparrow", "frog", "goat", "chicken", "snail", "sparrow", "mouse", "duck"]

class TestApp extends Base.TestApp:
	var labels: Array = []
	var art: Array = []
	var faces: Array = []
	var backs: Array = []
	var current_card: Rect2
	var scanning = false
	var panel: Rect2
	func _init() -> void: home_preview = false
	func _draw() -> void:
		labels.clear()
		art.clear()
		faces.clear()
		backs.clear()
		super._draw()
	func _draw_gacha_showcase_card(rect: Rect2, card: Dictionary) -> void:
		scanning = true
		current_card = rect
		faces.append({"rect": rect, "id": card.id})
		super._draw_gacha_showcase_card(rect, card)
		scanning = false
	func _draw_gacha_card_back(rect: Rect2, index: int) -> void:
		backs.append({"rect": rect, "index": index})
		super._draw_gacha_card_back(rect, index)
	func _box(rect: Rect2, fill: Color, line: Color, width: float) -> void:
		if rect.size.x > 600 and rect.position.y >= 180 and rect.position.y <= 260: panel = rect
		super._box(rect, fill, line, width)
	func _draw_text_native(text: String, rect: Rect2, size: int, color: Color, alignment: HorizontalAlignment) -> void:
		if scanning: labels.append({"text": text, "rect": rect, "size": size, "card": current_card})
		super._draw_text_native(text, rect, size, color, alignment)
	func _draw_animal_art_in_rect(card: Dictionary, rect: Rect2, tint: Color = Color.WHITE, clip: Rect2 = Rect2()) -> void:
		if scanning:
			var texture = _card_texture(card)
			var size = rect.size * _animal_art_display_scale(card)
			var target = Rect2(rect.get_center() - size * 0.5, size)
			var visible = _animal_texture_visible_rect(texture)
			art.append({"id": card.id, "card": current_card, "texture": texture.get_size(), "target": target, "visible": Rect2(target.position + visible.position * target.size, visible.size * target.size)})
		super._draw_animal_art_in_rect(card, rect, tint, clip)

var app: TestApp
var viewport: SubViewport
var checks = 0
var failures = 0
var observations: Array = []
var run_name = "candidate"
var gpu = false

func check(ok: bool, label: String, actual: Variant = null) -> void:
	checks += 1
	observations.append({"ok": ok, "label": label, "actual": str(actual)})
	if not ok:
		failures += 1
		push_error("GACHA_SPACED: %s actual=%s" % [label, str(actual)])

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="): run_name = arg.trim_prefix("--receipt=")
	gpu = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GameAudio.set_music_enabled(false)
	GameAudio.set_sfx_enabled(false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = TestApp.new()
	viewport.add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	app.screen = "gacha"
	app.account_center_open = false
	app._layout(viewport.size)
	for card in app.cards:
		app.card_counts[card.id] = 20
		app.card_levels[card.id] = 1
	layout_contract()
	await results_contract()
	await input_contract(1, false, 720)
	await input_contract(10, true, 360)
	var file = FileAccess.open(OUT + run_name + ("-gpu.json" if gpu else "-headless.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "gpu": gpu, "observations": observations}, "\t"))
	file.close()
	print("GACHA_SPACED_RESULT checks=%d failures=%d gpu=%s" % [checks, failures, gpu])
	app.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func layout_contract() -> void:
	for count in range(1, 11):
		var rows: Dictionary = {}
		var bounds = Rect2()
		var rects: Array = []
		for i in range(count):
			var rect = app._gacha_reward_card_rect(i, count)
			check(is_equal_approx(rect.size.x / rect.size.y, 132.0 / 158.0), "original card proportions count=%d index=%d" % [count, i], rect.size)
			check(rect.position.y >= 290 and rect.end.y + 6 <= app._gacha_draw_rect().position.y - 10, "card and shadow clear title and draw controls count=%d index=%d" % [count, i], rect)
			check(rect.position.x >= 52 and rect.end.x <= 668, "card and shadow remain within panel horizontal margin", rect)
			bounds = rect if i == 0 else bounds.merge(rect)
			if not rows.has(rect.position.y): rows[rect.position.y] = []
			rows[rect.position.y].append(rect)
			for prior in rects: check(not rect.grow(3).intersects(prior.grow(3)), "card shadows do not overlap count=%d index=%d" % [count, i])
			rects.append(rect)
		var row_ys = rows.keys()
		row_ys.sort()
		var row_counts: Array = []
		var previous_end = -INF
		for y in row_ys:
			var row: Array = rows[y]
			row_counts.append(row.size())
			row.sort_custom(func(a, b): return a.position.x < b.position.x)
			if previous_end > -INF: check(float(y) - previous_end - 6 >= 22, "vertical shadow-free gap at least22 count=%d" % count, float(y) - previous_end - 6)
			previous_end = row[0].end.y
			for j in range(1, row.size()): check(row[j].position.x - row[j - 1].end.x - 6 >= 32, "horizontal shadow-free gap at least32 count=%d" % count, row[j].position.x - row[j - 1].end.x - 6)
			check(row.size() <= 3, "no more than3 cards per row count=%d" % count, row.size())
		check(absf(bounds.get_center().x - 360) <= 0.1, "whole result group centered count=%d" % count, bounds.get_center().x)
		if count == 10:
			check(row_counts == [2, 3, 3, 2], "ten results use exactly2-3-3-2", row_counts)
			if row_ys.size() == 4:
				check(absf(rows[row_ys[1]][0].position.x - rows[row_ys[2]][0].position.x) >= 16, "middle rows are visibly staggered", [rows[row_ys[1]][0].position.x, rows[row_ys[2]][0].position.x])
	check(app._gacha_draw_rect().end.y + 6 <= 1138 and app._gacha_ten_draw_rect().end.y + 6 <= 1138, "draw buttons and shadows clear navigation")
	check(not app._gacha_draw_rect().grow(3).intersects(app._gacha_ten_draw_rect().grow(3)), "single and ten draw controls remain distinct")

func reset_results() -> void:
	app.gacha_pending_cards.clear()
	app.gacha_card_flip_timers.clear()
	app.gacha_new_card_ids.clear()
	app.gacha_hero_reveal = null
	app.gacha_fx_timer = 0.0
	app.gacha_reveal_timer = 0.0
	app.toast_timer = 0
	app.last_gacha_cards.clear()

func redraw() -> void:
	app.queue_redraw()
	await get_tree().process_frame
	if gpu: await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if not gpu: return
	await redraw()
	var picture = viewport.get_texture().get_image()
	check(picture.save_png(OUT + run_name + "-" + label + ".png") == OK, "saved " + label)

func results_contract() -> void:
	reset_results()
	app.last_gacha_cards = MIX.duplicate()
	for width in [720, 360]:
		viewport.size = Vector2i(width, width * 1280 / 720)
		app._layout(viewport.size)
		await redraw()
		if gpu:
			check(app.faces.size() == 10, "all ten cards actually rendered at" + str(width), app.faces.size())
			check(app.panel.end.y + 6 <= app._gacha_draw_rect().position.y - 8, "result panel and shadow clear controls at" + str(width), app.panel)
			for i in range(app.faces.size()):
				var face = app.faces[i]
				check(app.panel.encloses(face.rect), "actual face inside actual panel " + face.id, face.rect)
				check(face.rect == app._gacha_reward_card_rect(i, 10), "resting card uses same animation slot " + str(i))
			for item in app.labels:
				check(item.size >= 24 and not item.text.contains("…"), "complete readable result name " + item.text, item.size)
				check(app.font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.size).x <= item.rect.size.x + 0.1, "name fits without clipping " + item.text, item.rect)
			for id in MIX: check(app.labels.any(func(item): return item.text == String(app._card_by_id(id).name)), "original full name present " + id)
			for portrait in app.art:
				var card = app._card_by_id(portrait.id)
				var old_slot = Vector2(portrait.card.size.x - 12, portrait.card.size.y - 52)
				var fit_ratio = maxf(portrait.visible.size.x / old_slot.x, portrait.visible.size.y / old_slot.y)
				check(absf(portrait.target.size.x / portrait.target.size.y - portrait.texture.x / portrait.texture.y) < 0.001, "portrait never stretches " + portrait.id)
				check(portrait.card.encloses(portrait.visible), "visible art stays inside card " + portrait.id)
				if app._card_kind(card) == "animal": check(fit_ratio >= 0.72 and fit_ratio <= 0.82, "animal occupancy reduced to72..82 percent " + portrait.id, fit_ratio)
				else: check(is_equal_approx(fit_ratio, 1.0), "tower occupancy unchanged " + portrait.id, fit_ratio)
		await capture("mixture-" + str(width))
	reset_results()
	app.last_gacha_cards = ["frog"]
	await capture("single-360")

func inventory_count() -> int:
	var total = 0
	for value in app.card_counts.values(): total += int(value)
	return total

func tap(position: Vector2, touch: bool) -> void:
	for pressed in [true, false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
			event.index = 0
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = app.canvas_offset + position * app.canvas_scale
		viewport.push_input(event, true)
		await get_tree().process_frame

func input_contract(count: int, touch: bool, width: int) -> void:
	reset_results()
	viewport.size = Vector2i(width, width * 1280 / 720)
	app._layout(viewport.size)
	app.gacha_tickets = 30
	var before = inventory_count()
	seed(23320925 + count)
	await tap((app._gacha_draw_rect() if count == 1 else app._gacha_ten_draw_rect()).get_center(), touch)
	check(inventory_count() == before + count and app.gacha_tickets == 30 - count, "native draw grants and charges exactly" + str(count), [inventory_count() - before, 30 - app.gacha_tickets])
	check(app.gacha_pending_cards.size() + app.last_gacha_cards.size() == count, "all granted cards enter result animation")
	await tap(app._gacha_ten_draw_rect().get_center(), touch)
	check(inventory_count() == before + count and app.gacha_tickets == 30 - count, "animation blocks duplicate grant")
	app._update_gacha_animation(app.GACHA_FX_SECONDS + 0.01)
	await redraw()
	if gpu:
		check(app.faces.size() + app.backs.size() == count, "opening animation keeps all result slots", [app.faces.size(), app.backs.size()])
		for back in app.backs: check(back.rect == app._gacha_reward_card_rect(back.index, count), "card back shares resting slot")
	await capture("opening-" + str(count))
	app.set_process(true)
	var deadline = Time.get_ticks_msec() + 7000
	while app._is_gacha_animating() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	app.set_process(false)
	check(Time.get_ticks_msec() < deadline and app.last_gacha_cards.size() == count, "real engine animation completes every result", app.last_gacha_cards.size())
	check(inventory_count() == before + count and app.gacha_tickets == 30 - count and not app._new_hero_reveal_active(), "owned-card animation preserves grants and skips ceremony")
	await capture("finished-" + str(count))
