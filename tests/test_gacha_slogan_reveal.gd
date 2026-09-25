extends Node
## Independent frozen probe: config-driven text, native reveal input, measured real draw text.
const Base = preload("res://tests/test_online_rewards_release.gd")
const Reveal = preload("res://scripts/app/ui/gacha_new_hero_reveal.gd")
const OUT = "res://temp/qa/gacha-spaced-20260925/"

class TestApp extends Base.TestApp:
	var labels: Array = []
	var baseline_renderer: Script
	func _init() -> void: home_preview = false
	func _draw() -> void:
		labels.clear()
		var live_renderer = gacha_hero_reveal
		if baseline_renderer != null and live_renderer != null:
			var reference = baseline_renderer.new(self)
			reference.current = live_renderer.current
			reference.stage = live_renderer.stage
			reference.elapsed = live_renderer.elapsed
			gacha_hero_reveal = reference
		super._draw()
		gacha_hero_reveal = live_renderer
	func _draw_text_native(text: String, rect: Rect2, size: int, color: Color, alignment: HorizontalAlignment) -> void:
		labels.append({"text": text, "rect": rect, "size": size})
		super._draw_text_native(text, rect, size, color, alignment)

var app: TestApp
var viewport: SubViewport
var checks = 0
var failures = 0
var observations: Array = []
var run_name = "candidate"
var gpu = false
var catalog: Array = []
var reveal_events = 0

func check(ok: bool, label: String, actual: Variant = null) -> void:
	checks += 1
	observations.append({"ok": ok, "label": label, "actual": str(actual)})
	if not ok:
		failures += 1
		push_error("GACHA_SLOGAN: %s actual=%s" % [label, str(actual)])

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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-renderer="): app.baseline_renderer = load(arg.trim_prefix("--baseline-renderer="))
	viewport.add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	catalog = app.cards.duplicate(true)
	await real_reveal("我跑得慢，笑点却很快。", false, 720)
	await real_reveal("换个说法，也还是本蛙。", true, 360)
	await missing_contract()
	await catalog_contract()
	var file = FileAccess.open(OUT + run_name + ("-slogan-gpu.json" if gpu else "-slogan-headless.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "gpu": gpu, "observations": observations}, "\t"))
	file.close()
	print("GACHA_SLOGAN_RESULT checks=%d failures=%d gpu=%s" % [checks, failures, gpu])
	app.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func fixture(slogan: Variant, include_field: bool = true) -> Dictionary:
	var card = catalog.filter(func(c): return c.id == "frog")[0].duplicate(true)
	if include_field: card.slogan = slogan
	else: card.erase("slogan")
	return card

func reset(card: Dictionary, width: int = 720) -> void:
	app.cards = [card]
	app.card_counts = {}
	app.card_levels = {}
	app.deck.clear()
	app.gacha_tickets = 20
	app.wallet_gold = 333
	app.screen = "gacha"
	app.account_center_open = false
	app.gacha_fx_timer = 0
	app.gacha_reveal_timer = 0
	app.gacha_card_flip_timers.clear()
	app.gacha_pending_cards.clear()
	app.last_gacha_cards.clear()
	app.gacha_new_card_ids.clear()
	app.gacha_hero_reveal = null
	app.toast_timer = 0
	viewport.size = Vector2i(width, width * 1280 / 720)
	app._layout(viewport.size)
	reveal_events = 0

func redraw() -> void:
	app.queue_redraw()
	await get_tree().process_frame
	if gpu: await RenderingServer.frame_post_draw

func slogan_lines() -> Array:
	# The full opaque hero layer hides the underlying gacha controls. Only text
	# entirely within its dialogue panel is visible slogan text, regardless of
	# where controls on that hidden page move in a separate layout change.
	return app.labels.filter(func(item): return Rect2(64, 936, 592, 128).encloses(item.rect) and item.text != "继续")

func inspect(expected: String, label: String) -> void:
	if not gpu: return
	var lines = slogan_lines()
	var combined = ""
	for line in lines:
		combined += String(line.text).strip_edges()
		check(line.size >= 30 and not String(line.text).contains("…"), label + " slogan never shrinks or truncates", line.size)
		check(app.font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line.size).x <= line.rect.size.x + 0.1, label + " complete line fits", line.text)
		check(line.rect.position.y >= 920 and line.rect.end.y <= 1088, label + " line stays between name and continue", line.rect)
	check(lines.size() >= 1 and lines.size() <= 2 and combined == expected, label + " exact configurable slogan visible in at most2 lines", combined)

func tap(point: Vector2, touch: bool) -> void:
	for pressed in [true, false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
			event.index = 0
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.position = app.canvas_offset + point * app.canvas_scale
		event.pressed = pressed
		viewport.push_input(event, true)
		await get_tree().process_frame

func real_reveal(slogan: String, touch: bool, width: int) -> void:
	reset(fixture(slogan), width)
	await tap(app._gacha_draw_rect().get_center(), touch)
	check(app.gacha_tickets == 19 and app._card_total_count("frog") == 1, "real draw grants first ownership once")
	app._update_gacha_animation(app.GACHA_FX_SECONDS + 0.01)
	check(app._new_hero_reveal_active() and app.gacha_hero_reveal.stage == "rarity", "real first ownership enters rarity stage")
	app.gacha_hero_reveal.hero_revealed.connect(func(_card): reveal_events += 1)
	await redraw()
	if gpu: check(slogan_lines().is_empty(), "rarity stage hides slogan")
	await tap(Vector2(360, 525), touch)
	check(app.gacha_hero_reveal.stage == "flip", "native input begins normal flip")
	await redraw()
	if gpu: check(slogan_lines().is_empty(), "flip stage hides slogan")
	await tap(Vector2(360, 525), touch)
	check(app.gacha_hero_reveal.stage == "flip" and reveal_events == 0, "flip consumes repeat input without callback")
	app.set_process(true)
	var deadline = Time.get_ticks_msec() + 2500
	while app.gacha_hero_reveal.stage != "hero" and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	app.set_process(false)
	check(Time.get_ticks_msec() < deadline and reveal_events == 1, "real engine flip invokes exactly one hero callback", reveal_events)
	await redraw()
	inspect(slogan, "synthetic same-card slogan" + str(width))
	if gpu:
		check(viewport.get_texture().get_image().save_png(OUT + run_name + "-slogan-hero-" + str(width) + ".png") == OK, "hero screenshot" + str(width))
	await tap(Vector2(360, 1150), touch)
	check(not app._new_hero_reveal_active() and app.screen == "gacha", "continue dismisses without navigation clickthrough")
	check(app.gacha_tickets == 19 and app._card_total_count("frog") == 1 and app.wallet_gold == 333 and reveal_events == 1, "slogan changes no grants currency or reveal count")

func missing_contract() -> void:
	for missing in [true, false]:
		reset(fixture(null, not missing))
		app.gacha_hero_reveal = Reveal.new(app)
		app.gacha_hero_reveal.enqueue(app.cards[0])
		app.gacha_hero_reveal.stage = "hero"
		await redraw()
		if gpu: check(slogan_lines().is_empty(), "missing/null legacy slogan hides safely " + str(missing), slogan_lines())

func catalog_contract() -> void:
	var animals = catalog.filter(func(card): return app._card_kind(card) == "animal")
	check(animals.size() == 60, "formal catalog includes60 animals", animals.size())
	var unique: Dictionary = {}
	for card in animals:
		var value: Variant = card.get("slogan", null)
		var slogan = value.strip_edges() if value is String else ""
		check(not slogan.is_empty(), "formal configurable slogan exists " + card.id, slogan)
		if slogan.is_empty(): continue
		unique[slogan] = true
		reset(card)
		app.gacha_hero_reveal = Reveal.new(app)
		app.gacha_hero_reveal.enqueue(card)
		app.gacha_hero_reveal.stage = "hero"
		await redraw()
		inspect(slogan, card.id)
	check(unique.size() == 60, "each animal has its own distinct configured line", unique.size())
