extends Node
const OldHomeTest = preload("res://tests/test_home_runtime.gd")
const Rules = preload("res://scripts/shared/home_rules.gd")
const OUT = "res://temp/qa/home-polish-20260925/"
var app
var viewport: SubViewport
var checks = 0
var failures = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _ready() -> void:
	GameAudio.set_music_enabled(false)
	GameAudio.set_sfx_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = OldHomeTest.TestApp.new()
	viewport.add_child(app)
	await get_tree().process_frame
	app.set_process(false)
	app.screen = "home"
	app.home_view.modal = ""
	app.home_view.selected = "0,0"
	app.home_view.simulation.clock = 55
	app.home_view.state.last_claim_day = Rules.day_key()
	app.home_view.accept_snapshot(Rules.daily_snapshot(app.home_view.state, Rules.day_key()), false)
	await capture("home-locked")
	var initial_gold = app.wallet_gold
	var initial_tickets = app.gacha_tickets
	await tap(app.home_view.plot_point("1,0"))
	check(app.home_view.state.owned.has("1,0"), "one tap on affordable locked plot unlocks directly")
	check(app.wallet_gold == initial_gold - int(Rules.plot("1,0").cost) and app.gacha_tickets == initial_tickets + 1, "direct unlock spends once and grants one ticket")
	var selected = app.home_view.selected
	app.wallet_gold = 0
	await tap(app.home_view.plot_point("-1,0"))
	check(not app.home_view.state.owned.has("-1,0"), "poor player cannot unlock")
	check(app.home_view.selected == selected, "locked tile cannot open details or change owned selection")
	check(app.toast_text.contains("金币不足"), "insufficient funds produces an explicit toast")
	await capture("home-poor", true)
	app.home_view.selected = "0,0"
	app.home_view.zoom = 1.0
	var initial_pan = app.home_view.pan
	await tap(Vector2(124, 904))
	check(app.home_view.zoom == 1.0 and app.home_view.pan == initial_pan, "removed plus camera control has no stale hit target")
	app.wallet_gold = 1000
	app.home_view.zoom = 0.84
	var before_hidden_price = app.wallet_gold
	await tap(app.home_view.plot_point("-1,0"))
	check(not app.home_view.state.owned.has("-1,0") and app.wallet_gold == before_hidden_price, "hidden price cannot spend gold")
	check(app.home_view.zoom >= 1.0, "hidden price tap focuses the readable building price")
	await tap(app.home_view.plot_point("-1,0"))
	check(app.home_view.state.owned.has("-1,0"), "focused affordable building unlocks on the next direct tap")
	app.home_view.pan = Vector2(0, -140)
	var before_edge = app.wallet_gold
	await tap(app.home_view.plot_point("0,-1"))
	check(not app.home_view.state.owned.has("0,-1") and app.wallet_gold == before_edge, "clipped price at map edge cannot spend gold")
	app.home_view.pan = Vector2.ZERO
	app.home_view.status = "家园服务待更新，稍后重试"
	app.home_view.available = false
	await capture("home-unavailable")
	app.home_view.available = true
	app.wallet_gold = 99999999
	for p in Rules.all_plots():
		if p.ring == 1 and not app.home_view.state.owned.has(p.id): app._home_request("unlock", p.id)
	app.home_view.selected = "0,0"
	await capture("home-developed")
	viewport.size = Vector2i(360, 640)
	await capture("home-developed-360")
	print("HOME_POLISH checks=%d failures=%d" % [checks, failures])
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func tap(position: Vector2) -> void:
	app._layout(viewport.size)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = app.canvas_offset + position * app.canvas_scale
		viewport.push_input(event, true)
		await get_tree().process_frame

func capture(label: String, keep_toast: bool = false) -> void:
	if not keep_toast: app.toast_timer = 0
	app.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT + label + ".png")
