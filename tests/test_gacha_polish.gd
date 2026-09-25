extends Node
## Frozen before/after probe: real main roll/grant and viewport input; never user saves.
const Base = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/home-polish-20260925/"
class TestApp extends Base.TestApp:
	var collection_draws = 0
	var detail_draws = 0
	func _init() -> void: home_preview = false
	func _draw_upgrade_progress(rect: Rect2, card_id: String, show_label: bool) -> void:
		collection_draws += 1
		super._draw_upgrade_progress(rect, card_id, show_label)
	func _draw_card_level_badge(rect: Rect2, card_id: String) -> void:
		collection_draws += 1
		super._draw_card_level_badge(rect, card_id)
	func _draw_card_detail(rect: Rect2, detail_card_id: String = "") -> void:
		detail_draws += 1
		super._draw_card_detail(rect, detail_card_id)

var app: TestApp
var viewport: SubViewport
var catalog: Array = []
var checks = 0
var failures = 0
var results: Array = []
var captures: Array = []
var gpu = false

func _ready() -> void:
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
	check(app.screen == "gacha", "normal navigation enters gacha")
	for rarity in ["common", "rare", "epic", "legendary"]:
		await first_then_duplicate(rarity)
	await ten_draws()
	await all_owned()
	await collection_unchanged()
	var result = {"checks": checks, "failures": failures, "gpu": gpu, "results": results, "captures": captures, "input": "native SubViewport.push_input", "grants": "real main._roll_gacha and GachaService.apply_reward; no overrides", "isolation": "no login or persistence; bounded test pools only"}
	print("GACHA_POLISH_RESULT ", JSON.stringify(result))
	var file = FileAccess.open(OUT + ("gacha-polish-gpu.json" if gpu else "gacha-polish-headless.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	app.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	results.append({"ok": ok, "label": label})
	if not ok:
		failures += 1
		push_error("GACHA_POLISH: " + label)

func choose(rarity: String, offset: int = 0) -> Dictionary:
	for card in catalog:
		if app._card_kind(card) == "animal" and String(card.rarity) == rarity:
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
	GameAudio.clear_event_cooldowns()
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)

func first_then_duplicate(rarity: String) -> void:
	var card = choose(rarity)
	reset([card])
	var opened = GameAudio.get_sfx_play_count("gacha_open")
	var revealed = GameAudio.get_sfx_play_count("gacha_reveal")
	var surprised = GameAudio.get_sfx_play_count("gacha_new_hero")
	await tap(app._gacha_draw_rect().get_center())
	check(app.gacha_tickets == 19 and app._card_total_count(card.id) == 1, rarity + " first draw spends/grants once")
	await wait_for_reveal()
	check(app._new_hero_reveal_active() and app.gacha_hero_reveal.stage == "rarity", rarity + " first ownership enters quality")
	await capture(rarity + "-rarity")
	if rarity in ["common", "epic"]:
		await advance(1.8)
		check(app.gacha_hero_reveal.stage == "rarity", rarity + " remains before two seconds")
		await advance(0.25)
	else:
		await tap(app._gacha_ten_draw_rect().get_center())
	await advance(0.60)
	check(app.gacha_hero_reveal.stage == "hero", rarity + " quality becomes hero by time or tap")
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == surprised + 1, rarity + " warm surprise plays exactly once at hero")
	check(GameAudio.get_sfx_play_count("gacha_open") == opened + 1 and GameAudio.get_sfx_play_count("gacha_reveal") == revealed + 1, rarity + " single open and card sound")
	check(app.gacha_tickets == 19 and app._card_total_count(card.id) == 1, rarity + " overlay tap cannot draw or regrant")
	await capture(rarity + "-hero")
	await advance(0.3)
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == surprised + 1, rarity + " frames do not retrigger surprise")
	await tap(app._nav_rect(0).get_center())
	check(app.screen == "gacha" and not app._new_hero_reveal_active(), rarity + " hero dismissal cannot enter home")
	await advance(0.5)
	await check_result_drawing(rarity + "-single-result")
	viewport.size = Vector2i(360, 640)
	await tap(app._gacha_draw_rect().get_center())
	await advance(1.3)
	check(not app._new_hero_reveal_active() and app.gacha_new_card_ids.is_empty(), rarity + " duplicate has no new hero")
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == surprised + 1, rarity + " duplicate has no surprise sound")
	check(app.gacha_tickets == 18 and app._card_total_count(card.id) == 2 and app.wallet_gold == 333, rarity + " duplicate economy unchanged")

func ten_draws() -> void:
	var first = choose("common", 0)
	var second = choose("common", 1)
	reset([first, second])
	var surprised = GameAudio.get_sfx_play_count("gacha_new_hero")
	var opened = GameAudio.get_sfx_play_count("gacha_open")
	var revealed = GameAudio.get_sfx_play_count("gacha_reveal")
	seed(92625017)
	await tap(app._gacha_ten_draw_rect().get_center())
	check(app.gacha_tickets == 10 and app._card_total_count(first.id) + app._card_total_count(second.id) == 10, "ten draw grants ten and charges ten once")
	var inventory = app.card_counts.duplicate(true)
	var shown: Array = []
	var guard = 0
	while app._is_gacha_animating() and guard < 30:
		guard += 1
		await wait_for_reveal()
		if not app._new_hero_reveal_active(): break
		shown.append(app.gacha_hero_reveal.current.id)
		await tap(app._gacha_ten_draw_rect().get_center())
		var pending = app.gacha_pending_cards.size()
		await advance(0.65)
		check(app.gacha_pending_cards.size() == pending and app.card_counts == inventory, "ten reveal pauses pending cards without granting")
		await tap(app._nav_rect(2).get_center())
		check(app.screen == "gacha", "ten reveal tap cannot enter battle")
	check(guard < 30 and shown.size() == 2 and shown.has(first.id) and shown.has(second.id), "ten draw shows one ceremony for each new species")
	check(app.card_counts == inventory and app.gacha_tickets == 10 and app.last_gacha_cards.size() == 10, "ten queue finishes with exactly original grants")
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == surprised + 2, "ten draw exactly two new hero sounds")
	check(GameAudio.get_sfx_play_count("gacha_open") == opened + 1 and GameAudio.get_sfx_play_count("gacha_reveal") == revealed + 10, "ten draw one opening and ten card cues")
	await check_result_drawing("ten-result")

func all_owned() -> void:
	var owned: Dictionary = {}
	for card in catalog:
		if app._card_kind(card) == "animal": owned[card.id] = 1
	reset(catalog, owned)
	var surprised = GameAudio.get_sfx_play_count("gacha_new_hero")
	check(owned.size() == 60, "all sixty animals fixture matches full collection")
	await tap(app._gacha_ten_draw_rect().get_center())
	await advance(4)
	check(not app._new_hero_reveal_active() and app.gacha_new_card_ids.is_empty(), "full collection ten draw correctly never flags an existing animal as new")
	check(GameAudio.get_sfx_play_count("gacha_new_hero") == surprised and app.last_gacha_cards.size() == 10, "full collection no false ceremony or sound; ten rewards shown")

func collection_unchanged() -> void:
	app.screen = "deck"
	app.collection_draws = 0
	app.selected_card_id = choose("common").id
	app.queue_redraw()
	await get_tree().process_frame
	check(app.collection_draws > 0, "deck retains level and material progress")

func check_result_drawing(label: String) -> void:
	app.collection_draws = 0
	app.detail_draws = 0
	app.queue_redraw()
	await get_tree().process_frame
	check(app.collection_draws == 0, label + " draws no levels or upgrade progress")
	await tap(app._gacha_reward_card_rect(0, app.last_gacha_cards.size()).get_center())
	app.queue_redraw()
	await get_tree().process_frame
	check(app.detail_draws == 0 and app.collection_draws == 0, label + " card tap cannot expose upgrade details")
	await capture(label)

func wait_for_reveal() -> void:
	app.set_process(true)
	var deadline = Time.get_ticks_msec() + 5000
	while not app._new_hero_reveal_active() and app._is_gacha_animating() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	app.set_process(false)
	check(Time.get_ticks_msec() < deadline, "real animation timer bounded")

func advance(seconds: float) -> void:
	app.set_process(true)
	await get_tree().create_timer(seconds).timeout
	app.set_process(false)

func tap(position: Vector2) -> void:
	app._layout(viewport.size)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = app.canvas_offset + position * app.canvas_scale
		viewport.push_input(event, true)
		await get_tree().process_frame

func capture(label: String) -> void:
	if not gpu: return
	for width in [720, 360]:
		viewport.size = Vector2i(width, width * 1280 / 720)
		app._layout(viewport.size)
		app.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var filename = "gacha-%s-%d.png" % [label, width]
		check(viewport.get_texture().get_image().save_png(OUT + filename) == OK, "GPU capture " + filename)
		captures.append(filename)
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)
