extends Node
## Frozen before/after evaluator: observes rendered labels/art, real grants and native pointer input.
const Base = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/home-readability-20260925/gacha/"
const FORBIDDEN = ["绿色", "蓝色", "紫色", "金色", "普通", "稀有", "史诗", "传说", "品质", "发现新的", "点击揭晓", "即将加入", "攻击", "生命", "移速", "射程", "专属能力", "格/秒"]

class TestApp extends Base.TestApp:
	var labels: Array = []
	var art: Array = []
	var collection_draws = 0
	var scanning_result = false
	func _init() -> void: home_preview = false
	func _draw() -> void:
		labels.clear()
		art.clear()
		collection_draws = 0
		super._draw()
	func _draw_gacha_showcase_card(rect: Rect2, card: Dictionary) -> void:
		scanning_result = true
		super._draw_gacha_showcase_card(rect, card)
		scanning_result = false
	func _draw_text_native(text: String, rect: Rect2, size: int, color: Color, alignment: HorizontalAlignment) -> void:
		labels.append({"text": text, "rect": rect, "size": size, "result": scanning_result})
		super._draw_text_native(text, rect, size, color, alignment)
	func _draw_animal_art_in_rect(card: Dictionary, rect: Rect2, tint: Color = Color.WHITE, clip: Rect2 = Rect2()) -> void:
		if scanning_result:
			var texture = _card_texture(card)
			var scaled = rect.size * _animal_art_display_scale(card)
			var target = Rect2(rect.get_center() - scaled * 0.5, scaled)
			var visible = _animal_texture_visible_rect(texture)
			art.append({"id": card.id, "texture_size": texture.get_size(), "target": target, "visible": Rect2(target.position + visible.position * target.size, visible.size * target.size)})
		super._draw_animal_art_in_rect(card, rect, tint, clip)
	func _draw_upgrade_progress(rect: Rect2, card_id: String, show_label: bool) -> void:
		collection_draws += 1
		super._draw_upgrade_progress(rect, card_id, show_label)
	func _draw_card_level_badge(rect: Rect2, card_id: String) -> void:
		collection_draws += 1
		super._draw_card_level_badge(rect, card_id)

var app: TestApp
var viewport: SubViewport
var catalog: Array = []
var checks = 0
var failures = 0
var observations: Array = []
var captures: Array = []
var gpu = false
var run_name = "candidate"

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt="): run_name = argument.trim_prefix("--receipt=")
	GameAudio.set_music_enabled(false)
	GameAudio.set_sfx_enabled(true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("UI"), true)
	gpu = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = TestApp.new()
	viewport.add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	catalog = app.cards.duplicate(true)
	app.screen = "lobby"
	app.account_center_open = false
	await tap(app._nav_rect(3).get_center())
	check(app.screen == "gacha", "native navigation enters gacha")
	for rarity in ["common", "rare", "epic", "legendary"]:
		await ceremony(rarity, rarity in ["common", "epic"])
	await all_result_cards()
	await ten_draws()
	await collection_unchanged()
	var report = {"checks": checks, "failures": failures, "gpu": gpu, "observations": observations, "captures": captures, "input": "native SubViewport mouse and touch", "grants": "real main gacha path; isolated bounded pools; no login/persistence"}
	var file = FileAccess.open(OUT + run_name + ("-gpu.json" if gpu else "-headless.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GACHA_READABILITY_RESULT checks=", checks, " failures=", failures, " gpu=", gpu)
	app.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	observations.append({"ok": ok, "label": label})
	if not ok:
		failures += 1
		push_error("GACHA_READABILITY: " + label)

func choose(rarity: String, offset: int = 0) -> Dictionary:
	for card in catalog:
		if app._card_kind(card) == "animal" and card.rarity == rarity:
			if offset == 0: return card.duplicate(true)
			offset -= 1
	return {}

func reset(pool: Array, owned: Dictionary = {}) -> void:
	app.set_process(false)
	app.cards = pool.duplicate(true)
	app.card_counts = owned.duplicate(true)
	app.card_levels = {}
	app.deck.clear()
	app.gacha_tickets = 20
	app.wallet_gold = 333
	app.screen = "gacha"
	app.gacha_fx_timer = 0
	app.gacha_reveal_timer = 0
	app.gacha_card_flip_timers.clear()
	app.gacha_pending_cards.clear()
	app.last_gacha_cards.clear()
	app.gacha_new_card_ids.clear()
	app.gacha_hero_reveal = null
	app.gacha_detail_card_id = ""
	app.account_center_open = false
	app.toast_timer = 0
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)
	GameAudio.clear_event_cooldowns()

func inspect_labels(label: String, result_only: bool = false) -> void:
	for item in app.labels:
		if result_only and not item.result: continue
		# Underlying gacha is covered by the opaque ceremony; examine visible ceremony text.
		if not result_only and item.result: continue
		for word in FORBIDDEN:
			check(not String(item.text).contains(word), label + " excludes " + word + ": " + item.text)
		check(not String(item.text).contains("…"), label + " has complete text: " + item.text)
		check(app.font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.size).x <= item.rect.size.x + 0.1, label + " text fits: " + item.text)

func ceremony(rarity: String, automatic: bool) -> void:
	var card = choose(rarity)
	reset([card])
	var cue_before = GameAudio.get_sfx_play_count("gacha_new_hero")
	await tap(app._gacha_draw_rect().get_center(), rarity == "rare")
	await wait_reveal()
	check(app.gacha_tickets == 19 and app._card_total_count(card.id) == 1, rarity + " charged/granted once")
	check(app.gacha_hero_reveal.stage == "rarity", rarity + " first ownership begins with card back")
	await redraw()
	inspect_labels(rarity + " back")
	await capture(rarity + "-back")
	if automatic:
		await advance(1.82)
		check(app.gacha_hero_reveal.stage == "rarity", rarity + " no premature automatic flip")
		await advance(0.20)
	else:
		await tap(app._gacha_ten_draw_rect().get_center(), rarity == "rare")
	check(app.gacha_hero_reveal.stage == "flip", rarity + " tap/timeout enters actual flip stage")
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == cue_before, rarity + " hero cue waits until face opens")
	await advance(0.10)
	await capture(rarity + "-flip-back")
	await tap(app._nav_rect(2).get_center(), true)
	check(app.gacha_hero_reveal.stage == "flip" and app.screen == "gacha", rarity + " flip consumes touch without skipping or clickthrough")
	await advance(0.21)
	await capture(rarity + "-flip-front")
	await advance(0.60)
	check(app.gacha_hero_reveal.stage == "hero", rarity + " completed flip opens large animal")
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == cue_before + 1, rarity + " hero cue exactly once")
	await redraw()
	inspect_labels(rarity + " hero")
	check(app.labels.any(func(item): return item.text == card.name), rarity + " hero full name remains")
	check(app.gacha_tickets == 19 and app._card_total_count(card.id) == 1, rarity + " all flip inputs leave grants unchanged")
	await capture(rarity + "-hero")
	await tap(app._nav_rect(0).get_center())
	check(app.screen == "gacha" and not app._new_hero_reveal_active(), rarity + " dismiss cannot enter underlying home")
	await advance(0.6)
	await capture(rarity + "-single")
	await tap(app._gacha_draw_rect().get_center())
	await advance(1.4)
	check(not app._new_hero_reveal_active() and app._card_total_count(card.id) == 2 and app.gacha_tickets == 18, rarity + " duplicate skips ceremony with unchanged economy")
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == cue_before + 1, rarity + " duplicate never repeats warm cue")

func all_result_cards() -> void:
	reset(catalog)
	var animals = 0
	for card in catalog:
		if app._card_kind(card) == "animal": animals += 1
		app.last_gacha_cards = [card.id]
		await redraw()
		inspect_labels(card.id + " single", true)
		check(app.collection_draws == 0, card.id + " no level/progress in result")
		check(app.labels.filter(func(item): return item.result).size() == 1, card.id + " result draws name only")
		for count in [1, 10]:
			app.last_gacha_cards.clear()
			for i in range(count): app.last_gacha_cards.append(card.id)
			await redraw()
			var card_rect = app._gacha_reward_card_rect(0, count)
			check(is_equal_approx(card_rect.size.x / card_rect.size.y, 132.0 / 158.0), card.id + " original collection card ratio " + str(count))
			for portrait in app.art:
				check(absf(portrait.target.size.x / portrait.target.size.y - portrait.texture_size.x / portrait.texture_size.y) < 0.001, card.id + " artwork not stretched " + str(count))
				var requested_scale = 0.78 if app._card_kind(card) == "animal" else 1.0
				check(card_rect.size.x > 0 and portrait.visible.size.y >= card_rect.size.y * 0.36 * requested_scale, card.id + " visible artwork remains readable at requested scale " + str(count))
				break
	check(animals == 60, "all sixty animal artworks covered")
	for count in range(1, 11):
		var rectangles: Array = []
		for i in range(count):
			var rect = app._gacha_reward_card_rect(i, count)
			check(Rect2(46, 298, 628, 732).encloses(rect), "result inside panel " + str(count))
			for other in rectangles: check(not rect.intersects(other), "result cards never overlap " + str(count))
			rectangles.append(rect)

func ten_draws() -> void:
	var first = choose("common", 0)
	var second = choose("common", 1)
	reset([first, second])
	seed(92625017)
	var cues = GameAudio.get_sfx_play_count("gacha_new_hero")
	await tap(app._gacha_ten_draw_rect().get_center())
	var inventory = app.card_counts.duplicate(true)
	check(app.gacha_tickets == 10 and app._card_total_count(first.id) + app._card_total_count(second.id) == 10, "ten grant count unchanged")
	var shown: Array = []
	var guard = 0
	while app._is_gacha_animating() and guard < 30:
		guard += 1
		await wait_reveal()
		if not app._new_hero_reveal_active(): break
		shown.append(app.gacha_hero_reveal.current.id)
		await tap(Vector2(360, 490))
		await advance(0.65)
		await tap(Vector2(360, 1140))
	check(guard < 30 and shown.size() == 2 and shown.has(first.id) and shown.has(second.id), "ten draw one ceremony per species")
	check(app.card_counts == inventory and app.gacha_tickets == 10 and app.last_gacha_cards.size() == 10, "ten flip queue never repeats grants")
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == cues + 2, "ten draw one warm cue per new species")
	await capture("ten-results")

func collection_unchanged() -> void:
	app.cards = catalog.duplicate(true)
	app.screen = "deck"
	await redraw()
	check(app.collection_draws > 0, "normal collection retains level/progress")

func wait_reveal() -> void:
	app.set_process(true)
	var deadline = Time.get_ticks_msec() + 5000
	while not app._new_hero_reveal_active() and app._is_gacha_animating() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	app.set_process(false)
	check(Time.get_ticks_msec() < deadline, "bounded real animation timer")

func advance(seconds: float) -> void:
	app.set_process(true)
	await get_tree().create_timer(seconds).timeout
	app.set_process(false)

func redraw() -> void:
	app.queue_redraw()
	await get_tree().process_frame

func tap(position: Vector2, touch: bool = false) -> void:
	app._layout(viewport.size)
	for pressed in [true, false]:
		var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
		if touch: event.index = 0
		else: event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = app.canvas_offset + position * app.canvas_scale
		viewport.push_input(event, true)
		await get_tree().process_frame

func capture(label: String) -> void:
	if not gpu: return
	for width in [720, 360]:
		viewport.size = Vector2i(width, width * 1280 / 720)
		app._layout(viewport.size)
		await redraw()
		await RenderingServer.frame_post_draw
		var filename = "%s-%s-%d.png" % [run_name, label, width]
		check(viewport.get_texture().get_image().save_png(OUT + filename) == OK, "capture " + filename)
		captures.append(filename)
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)
