extends Node
## Runs the real main draw/grant/reveal path with isolated accounts and bounded
## draw pools. Native viewport input starts and advances every player action.
const Base = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/home-20260924/"
class TestApp extends Base.TestApp:
	func _init() -> void: home_preview = false

var app: TestApp
var viewport: SubViewport
var catalog: Array = []
var checks = 0
var failures = 0
var captures: Array = []
var gpu = false


func _ready() -> void:
	GameAudio.set_music_enabled(false)
	GameAudio.set_sfx_enabled(false)
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
	check(app.screen == "gacha", "real nav input enters gacha")
	await test_single_and_duplicate()
	await test_ten_draw_queue()
	await test_four_quality_captures()
	print("GACHA_REVEAL_INTEGRATION_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "gpu": gpu, "captures": captures, "input": "SubViewport.push_input mouse press/release", "timers": "real engine process frames; no grant/roll override", "ten_draw_seed": 92625017}))
	app.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GACHA_INTEGRATION: " + label)


func choose(rarity: String, offset: int = 0) -> Dictionary:
	for card in catalog:
		if app._card_kind(card) == "animal" and String(card.rarity) == rarity:
			if offset == 0: return card.duplicate(true)
			offset -= 1
	return {}


func reset_draw(pool: Array, owned: Dictionary = {}) -> void:
	app.set_process(false)
	app.cards = pool.duplicate(true)
	app.card_counts = owned.duplicate(true)
	app.card_levels = {}
	app.deck.clear()
	app.gacha_tickets = 20
	app.wallet_gold = 333
	app.screen = "gacha"
	app.gacha_fx_timer = 0.0
	app.gacha_reveal_timer = 0.0
	app.gacha_card_flip_timers.clear()
	app.gacha_pending_cards.clear()
	app.last_gacha_cards.clear()
	app.gacha_new_card_ids.clear()
	app.gacha_hero_reveal = null
	app.gacha_detail_card_id = ""
	app.toast_timer = 0
	app.account_center_open = false
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)


func test_single_and_duplicate() -> void:
	var card = choose("common")
	reset_draw([card])
	await tap(app._gacha_draw_rect().get_center())
	check(app.gacha_tickets == 19 and app._card_total_count(card.id) == 1, "real single draw grants once and spends exactly one ticket")
	await tap(app._nav_rect(0).get_center())
	check(app.screen == "gacha", "opening animation blocks leaving before hero reveal")
	await wait_for_reveal()
	check(app._new_hero_reveal_active() and app.gacha_hero_reveal.stage == "rarity", "first ownership enters quality page after opening FX")
	check(app._is_gacha_animating(), "active reveal blocks draw actions")
	var gm_key = InputEventKey.new()
	gm_key.keycode = KEY_F2
	gm_key.pressed = true
	viewport.push_input(gm_key, true)
	await get_tree().process_frame
	check(not app._is_gm_panel_open() and app.gacha_hero_reveal.stage == "rarity", "quality overlay blocks GM keyboard opening")
	await capture_pair("common-rarity")
	await advance(1.80)
	check(app.gacha_hero_reveal.stage == "rarity", "quality remains before two seconds of engine time")
	await advance(0.25)
	check(app.gacha_hero_reveal.stage == "hero", "quality auto-reveals after two seconds via main process")
	await capture_pair("common-hero")
	await advance(0.25)
	check(app._card_total_count(card.id) == 1 and app.gacha_tickets == 19, "automatic presentation does not re-grant")
	await tap(app._nav_rect(2).get_center())
	check(app.screen == "gacha" and not app._new_hero_reveal_active(), "hero dismiss tap cannot activate underlying battle tab")
	await advance(0.45)
	check(not app._is_gacha_animating(), "completed hero releases normal gacha animation")
	viewport.size = Vector2i(360, 640)
	app._layout(viewport.size)
	await tap(app._gacha_draw_rect().get_center())
	check(app._card_total_count(card.id) == 2 and app.gacha_tickets == 18, "360px viewport native input duplicate draw still gives one card")
	await advance(1.3)
	check(not app._new_hero_reveal_active() and app.gacha_new_card_ids.is_empty(), "duplicate card never opens first-ownership scene")
	check(app.wallet_gold == 333, "draw presenter never mutates wallet")
	app.gacha_tickets = 0
	await tap(app._gacha_draw_rect().get_center())
	check(app._card_total_count(card.id) == 2 and not app._new_hero_reveal_active(), "insufficient tickets cannot create reward or reveal")


func test_ten_draw_queue() -> void:
	var first = choose("common", 0)
	var second = choose("common", 1)
	reset_draw([first, second])
	seed(92625017)
	await tap(app._gacha_ten_draw_rect().get_center())
	check(app.gacha_tickets == 10 and app._card_total_count(first.id) + app._card_total_count(second.id) == 10, "ten-draw grants exactly ten cards and spends ten tickets")
	check(app._card_total_count(first.id) > 0 and app._card_total_count(second.id) > 0, "fixed-seed ten draw contains two newly owned species")
	var inventory: Dictionary = app.card_counts.duplicate(true)
	var shown: Array = []
	var guard = 0
	while app._is_gacha_animating() and guard < 30:
		guard += 1
		await wait_for_reveal()
		if not app._new_hero_reveal_active():
			break
		var id = String(app.gacha_hero_reveal.current.id)
		shown.append(id)
		var remaining = app.gacha_pending_cards.size()
		await tap(app._gacha_ten_draw_rect().get_center())
		check(app.gacha_hero_reveal.stage == "hero", "quality pointer advances to hero")
		check(app.gacha_tickets == 10 and app.card_counts == inventory, "quality tap cannot trigger underlying ten-draw button")
		await advance(0.15)
		check(app.gacha_pending_cards.size() == remaining, "next rewards stay paused behind current hero")
		await tap(app._nav_rect(0).get_center())
		check(app.screen == "gacha", "hero tap cannot enter underlying home")
	check(guard < 30, "ten-draw reveal queue terminates")
	check(shown.size() == 2 and shown.has(first.id) and shown.has(second.id), "exactly one new-hero scene per first-owned species in ten draw")
	check(app.last_gacha_cards.size() == 10 and app.gacha_pending_cards.is_empty(), "ten-draw displays every actual result")
	check(app.card_counts == inventory and app.gacha_tickets == 10, "reveal queue never repeats any grant or spend")


func test_four_quality_captures() -> void:
	for rarity in ["rare", "epic", "legendary"]:
		var card = choose(rarity)
		reset_draw([card])
		await tap(app._gacha_draw_rect().get_center())
		await wait_for_reveal()
		check(app._new_hero_reveal_active() and app.gacha_hero_reveal.current.rarity == rarity, "real draw selects fixture quality " + rarity)
		await capture_pair(rarity + "-rarity")
		await tap(Vector2(360, 961))
		check(app.gacha_hero_reveal.stage == "hero", "tap reveals " + rarity)
		await advance(0.45)
		await capture_pair(rarity + "-hero")
		await tap(Vector2(360, 1145))
		check(not app._new_hero_reveal_active() and app._card_total_count(card.id) == 1, "one grant after full showcase " + rarity)


func wait_for_reveal() -> void:
	app.set_process(true)
	var deadline = Time.get_ticks_msec() + 5000
	while not app._new_hero_reveal_active() and app._is_gacha_animating() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	app.set_process(false)
	check(Time.get_ticks_msec() < deadline, "real reveal timer bounded")


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


func capture_pair(label: String) -> void:
	if not gpu:
		return
	for width in [720, 360]:
		viewport.size = Vector2i(width, int(width * 1280 / 720))
		app._layout(viewport.size)
		app.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var picture = viewport.get_texture().get_image()
		var file_name = "gacha-%s-%d.png" % [label, width]
		check(picture.get_size() == viewport.size and picture.save_png(OUT + file_name) == OK, "GPU capture " + file_name)
		captures.append(file_name)
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)
