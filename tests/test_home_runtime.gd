extends Node
const Base = preload("res://tests/test_online_rewards_release.gd")
const Rules = preload("res://scripts/shared/home_rules.gd")
const Sim = preload("res://scripts/app/systems/home_simulation.gd")
const OUT = "res://temp/qa/home-polish-20260925/regression/"
class TestApp extends Base.TestApp:
	var saved_preview: Dictionary = {}
	var reject_save = false
	func _init() -> void: home_preview = true
	func _home_load_preview() -> void:
		var view = _ensure_home()
		view.state = HomeRules.initial_state(HomeRules.day_key())
		wallet_gold = 600
		gacha_tickets = 10
		view.accept_snapshot(HomeRules.daily_snapshot(view.state, HomeRules.day_key()), false)
	func _home_save_preview(candidate: Dictionary) -> bool:
		if reject_save: return false
		saved_preview = candidate.duplicate(true)
		return true
class DiskPreviewApp extends Base.TestApp:
	func _init() -> void: home_preview = true
var app
var viewport: SubViewport
var checks = 0
var failures = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _ready() -> void:
	GameAudio.sfx_enabled = false
	GameAudio.set_music_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = TestApp.new()
	viewport.add_child(app)
	await get_tree().process_frame
	app.set_process(false)
	app.screen = "lobby"
	app.home_view.modal = ""
	await tap(app._nav_rect(0).get_center())
	check(app.screen == "home", "real nav input opens home")
	check(app.home_view.modal == "claim", "first home entry opens reward list")
	await capture("home-first-reward")
	await tap(app.home_view.exchange_button().get_center())
	check(app.wallet_gold == 700 and app.gacha_tickets == 11, "castle reward applies once")
	check(app.home_view.modal == "result", "claim opens receipt")
	await capture("home-reward-result")
	await tap(app.home_view.exchange_button().get_center())
	var state_before = app.home_view.state.duplicate(true)
	await tap(app._nav_rect(2).get_center())
	await tap(app._nav_rect(0).get_center())
	check(app.home_view.modal == "", "same day re-entry no second claim")
	check(not app.home_view.has_dot(), "claimed rewards clear home dot even with affordable adjacent land")
	await capture("home-initial-map")
	var first = ""
	for p in app.home_view.visible:
		if p.id != "0,0": first = p.id; break
	var cost = int(Rules.plot(first).cost)
	var gold_before = app.wallet_gold
	var tickets_before = app.gacha_tickets
	await tap(app.home_view.plot_point(first))
	check(app.home_view.state.owned.has(first), "single pointer release unlocks affordable land")
	await tap(app.home_view.plot_point(first))
	check(app.home_view.selected == first, "owned land tap opens its details")
	await capture("home-owned-detail")
	check(app.wallet_gold == gold_before - cost and app.gacha_tickets == tickets_before + 1, "unlock charges and awards exactly one ticket")
	app._home_request("unlock", first)
	check(app.wallet_gold == gold_before - cost and app.gacha_tickets == tickets_before + 1, "repeated unlock no double charge or ticket")
	check(app.home_view.snapshot.items.is_empty(), "new plot produces tomorrow")
	var candidate = ""
	for p in app.home_view.visible:
		if bool(Rules.can_unlock(app.home_view.state, p.id, 10000).ok): candidate = p.id; break
	app.wallet_gold = 0
	await tap(app.home_view.plot_point(candidate))
	check(not app.home_view.state.owned.has(candidate), "insufficient gold has no unlock")
	check(app.home_view.selected == first, "insufficient land tap retains owned details")
	await capture("home-insufficient")
	app.wallet_gold = 10000
	app.reject_save = true
	var count = app.home_view.state.owned.size()
	app._home_request("unlock", candidate)
	check(app.home_view.state.owned.size() == count and app.wallet_gold == 10000, "failed preview save rolls back balances and land")
	app.reject_save = false
	# Build all first-ring types through the actual transaction adapter.
	for p in Rules.all_plots():
		if p.ring == 1 and not app.home_view.state.owned.has(p.id): app._home_request("unlock", p.id)
	app.home_view.selected = "0,0"
	app.home_view.status = ""
	for card in app.cards:
		if app._card_kind(card) == "animal": app.card_counts[card.id] = 1
	app.home_view.refresh()
	check(app.home_view.simulation.residents.size() == 60, "residents are owned animals only, no defense or mine cards")
	test_simulation()
	await test_pan()
	await test_touch()
	app.home_view.pan = Vector2.ZERO
	app.home_view.zoom = 0.88
	app.home_view.simulation.clock = 55
	for i in range(90): app.home_view.simulation.update(0.2)
	await capture("home-developed-day")
	app.home_view.simulation.clock = 139.0
	for i in range(125): app.home_view.simulation.update(0.2)
	await capture("home-developed-night")
	var old = Rules.day_key() - 5
	app.home_view.state.started_day = old
	app.home_view.state.last_claim_day = old - 1
	for id in app.home_view.state.owned: app.home_view.state.owned[id] = old
	app.home_view.pending_pop = true
	app.home_view.accept_snapshot(Rules.daily_snapshot(app.home_view.state, Rules.day_key()))
	check(app.home_view.snapshot.days.size() == 3, "three-day UI lists capped yield")
	var quantity = 0
	for group in app.home_view._reward_groups(): quantity += int(group.count)
	check(quantity == 18, "reward grouped quantities retain every building-day")
	await capture("home-three-day-reward")
	viewport.size = Vector2i(360, 640)
	await capture("home-three-day-reward-360")
	app.home_view.modal = ""
	await capture("home-map-360")
	test_disk_preview()
	print("HOME_RUNTIME checks=%d failures=%d" % [checks, failures])
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func test_disk_preview() -> void:
	# Exercise the production save/replace/reopen path without touching user://.
	var path = OUT + "preview-persistence-" + str(Time.get_ticks_usec()) + ".json"
	var first = DiskPreviewApp.new()
	first.home_preview_save_path = path
	first._home_load_preview()
	first._home_preview_action("claim", "")
	check(FileAccess.file_exists(path), "preview claim writes real isolated save")
	check(first.wallet_gold == 700 and first.gacha_tickets == 11, "real save commits castle payout")
	var id = "1,0"
	first._home_preview_action("unlock", id)
	check(first.home_view.state.owned.has(id), "atomic replacement stores unlocked land")
	var reopened = DiskPreviewApp.new()
	reopened.home_preview_save_path = path
	reopened._home_load_preview()
	check(reopened.home_view.state.owned.has(id) and reopened.wallet_gold == first.wallet_gold and reopened.gacha_tickets == 12, "reopen restores home and both currencies")
	reopened._home_preview_action("claim", "")
	check(reopened.gacha_tickets == 12 and reopened.wallet_gold == first.wallet_gold, "reopen cannot claim the same day twice")
	check(not FileAccess.file_exists(path + ".tmp"), "successful replacement leaves no temporary save")
	first.free()
	reopened.free()
	check(DirAccess.remove_absolute(path) == OK, "isolated preview save cleaned")

func test_simulation() -> void:
	var sim = app.home_view.simulation
	var capacities: Dictionary = {}
	for a in sim.residents: capacities[a.home] = int(capacities.get(a.home, 0)) + 1
	for id in capacities:
		if id != "0,0": check(capacities[id] <= Rules.plot(id).capacity, "house capacity respected")
	check(capacities.get("0,0", 0) > 0, "castle holds overflow")
	var nodes = sim.vertices.keys()
	for start in nodes:
		for finish in nodes:
			var route = sim.route_between(start, finish)
			check(start == finish or not route.is_empty(), "owned graph is connected")
			var previous = start
			for next in route:
				check(sim.links[previous].has(next), "every path segment follows an actual hex edge")
				check(absf(sim.vertices[previous].distance_to(sim.vertices[next]) - Sim.RADIUS) < 0.02, "edge step has one hex side length")
				previous = next
	var saw_outside = false
	var saw_meal = false
	var saw_sport = false
	var saw_mood = false
	for _frame in range(1400):
		sim.update(0.1)
		for a in sim.residents:
			saw_outside = saw_outside or not a.inside
			saw_meal = saw_meal or (a.action == "dining" and a.inside)
			saw_sport = saw_sport or (a.action == "sport" and not a.inside)
			saw_mood = saw_mood or a.mood_time > 0
	check(saw_outside and saw_meal and saw_sport and saw_mood, "time stepping shows castle exit, indoor meals, sport and completion bubbles")
	var saw_fun = false
	sim.clock = 130.0
	for _frame in range(1600):
		sim.update(0.1)
		for a in sim.residents: saw_fun = saw_fun or a.action == "entertainment"
	check(saw_fun, "night entertainment occurs")

func test_pan() -> void:
	var start = Vector2(350, 800)
	await pointer(start, true)
	var event = InputEventMouseMotion.new()
	event.position = start + Vector2(82, 0)
	event.relative = Vector2(82, 0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(event, true)
	await pointer(event.position, false)
	check(app.home_view.pan.x >= 80, "drag moves map")

func test_touch() -> void:
	app.home_view.pan = Vector2.ZERO
	app.home_view.selected = "0,1"
	for down in [true, false]:
		var event = InputEventScreenTouch.new()
		event.index = 0
		event.pressed = down
		event.position = app.home_view.plot_point("0,0")
		viewport.push_input(event, true)
		await get_tree().process_frame
	check(app.home_view.selected == "0,0" and app.home_view.touch_id == -1, "touch release selects castle and releases pointer")
	app.home_view.selected = "0,1"
	var start = app.home_view.plot_point("0,0")
	for index in [0, 1]:
		var down = InputEventScreenTouch.new()
		down.index = index
		down.pressed = true
		down.position = start if index == 0 else start + Vector2(150, 70)
		viewport.push_input(down, true)
	var secondary_drag = InputEventScreenDrag.new()
	secondary_drag.index = 1
	secondary_drag.position = start + Vector2(200, 90)
	secondary_drag.relative = Vector2(50, 20)
	viewport.push_input(secondary_drag, true)
	check(app.home_view.pan == Vector2.ZERO and not app.home_view.dragged, "secondary finger cannot move primary pointer map")
	for index in [0, 1]:
		var up = InputEventScreenTouch.new()
		up.index = index
		up.pressed = false
		up.position = start if index == 0 else secondary_drag.position
		viewport.push_input(up, true)
	check(app.home_view.selected == "0,0" and app.home_view.touch_id == -1, "primary touch still selects after secondary finger interference")

func pointer(position: Vector2, down: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = app.canvas_offset + position * app.canvas_scale
	viewport.push_input(event, true)
	await get_tree().process_frame

func tap(position: Vector2) -> void:
	app._layout(viewport.size)
	await pointer(position, true)
	await pointer(position, false)

func capture(label: String) -> void:
	app.toast_timer = 0.0
	app.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUT + label + ".png") == OK, "capture " + label)
