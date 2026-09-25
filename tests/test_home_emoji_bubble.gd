extends Node
## Frozen before the home renderer repair; all profile writes are isolated.
const Base = preload("res://tests/test_home_runtime.gd")
const Home = preload("res://scripts/app/ui/home_view.gd")
const OUT = "res://temp/qa/home-emoji-20260925/"
const MOODS = ["happy", "love", "excited", "tired"]
const POINTS = [Vector2(190, 440), Vector2(490, 440), Vector2(190, 760), Vector2(490, 760)]

class TraceHome extends Home:
	var draws: Array = []
	func _draw_residents() -> void:
		draws.clear()
		super()
	func _draw_mood(center: Vector2, mood: String) -> void:
		draws.append({"center": center, "mood": mood})
		super(center, mood)

class TestApp extends Base.TestApp:
	var isolated_moods: Array = []
	var isolated = false
	func _ensure_home():
		if home_view == null:
			home_view = TraceHome.new(self)
			home_view.preview = true
		return home_view
	func _draw() -> void:
		if not isolated:
			super()
			return
		_set_tracked_draw_transform(canvas_offset, 0, Vector2.ONE * canvas_scale)
		draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color.WHITE)
		for i in range(isolated_moods.size()):
			home_view._draw_mood(POINTS[i], isolated_moods[i])

var app: TestApp
var viewport: SubViewport
var stage = "baseline"
var checks: Array = []
var failures = 0
var resolution = ""

func check(ok: bool, label: String, actual: Variant = null) -> void:
	checks.append({"id": label, "pass": ok, "actual": str(actual), "resolution": resolution})
	if not ok:
		failures += 1
		print("HOME_EMOJI_FAIL ", label, " actual=", actual)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-stage="): stage = arg.trim_prefix("--evidence-stage=")
	GameAudio.sfx_enabled = false
	GameAudio.set_music_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + stage))
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for size in [Vector2i(720, 1280), Vector2i(360, 640)]:
		viewport.size = size
		resolution = "%dx%d" % [size.x, size.y]
		app = TestApp.new()
		viewport.add_child(app)
		await get_tree().process_frame
		app.set_process(false)
		app._layout(size)
		app.screen = "lobby"
		await tap(app._nav_rect(0).get_center())
		check(app.screen == "home", "native_navigation_opens_home")
		app.home_view.modal = ""
		app.home_view.pending_pop = false
		app.toast_timer = 0
		await resident_contract()
		if DisplayServer.get_name() != "headless": await rendered_contract()
		app.queue_free()
		await get_tree().process_frame
	var file = FileAccess.open(OUT + stage + "/report-" + DisplayServer.get_name() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "stage": stage, "engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "probe_hash": FileAccess.get_sha256("res://tests/test_home_emoji_bubble.gd"), "home_hash": FileAccess.get_sha256("res://scripts/app/ui/home_view.gd"), "simulation_hash": FileAccess.get_sha256("res://scripts/app/systems/home_simulation.gd"), "boundary": "Windows native viewport, isolated preview profile, no device export or server acceptance"}, "\t"))
	file.close()
	print("HOME_EMOJI checks=%d failures=%d" % [checks.size(), failures])
	get_tree().quit(1 if failures else 0)

func fixture() -> void:
	var h = app.home_view
	h.pan = Vector2.ZERO
	h.zoom = 1.0
	h.simulation.clock = 0.0
	var template: Dictionary = h.simulation.residents[0].duplicate(true)
	h.simulation.residents.clear()
	for i in range(4):
		var animal = template.duplicate(true)
		animal.id = ["rabbit", "fox", "parrot", "hedgehog"][i]
		animal.pos = POINTS[i] - Vector2(360, 564)
		animal.inside = false
		animal.route = []
		animal.target = ""
		animal.wait = 20.0
		animal.mood = MOODS[i]
		animal.mood_time = 3.0
		animal.facing = -1.0 if i % 2 else 1.0
		h.simulation.residents.append(animal)

func resident_contract() -> void:
	fixture()
	var h = app.home_view
	await frame()
	check(h.draws.size() == 4, "four_active_moods_render_once", h.draws.size())
	for i in range(mini(4, h.draws.size())):
		var foot: Vector2 = h.map_point(h.simulation.residents[i].pos)
		var pointer_bottom = float(h.draws[i].center.y) + 28.0
		check(pointer_bottom <= foot.y - 64.0 * h.zoom - 5.0, "bubble_clears_actor_head_" + MOODS[i], foot.y - 64.0 * h.zoom - pointer_bottom)
	await capture("four-moods")
	var first_before: Vector2 = h.draws[0].center
	await pointer(Vector2(350, 800), true)
	var drag = InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = app.canvas_offset + Vector2(390, 824) * app.canvas_scale
	drag.relative = Vector2(40, 24) * app.canvas_scale
	viewport.push_input(drag, true)
	await pointer(Vector2(390, 824), false)
	await frame()
	check(h.pan.is_equal_approx(Vector2(40, 24)), "native_drag_preserves_map_behavior", h.pan)
	check(Vector2(h.draws[0].center).is_equal_approx(first_before + Vector2(40, 24)), "bubble_follows_pan_without_drift", h.draws[0].center)
	for n in range(4):
		var wheel = InputEventMouseButton.new()
		wheel.pressed = true
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.position = app.canvas_offset + Vector2(350, 800) * app.canvas_scale
		viewport.push_input(wheel, true)
	await frame()
	check(h.zoom > 1.3, "native_zoom_remains_enabled", h.zoom)
	for row in h.draws:
		var index = MOODS.find(row.mood)
		var foot: Vector2 = h.map_point(h.simulation.residents[index].pos)
		check(float(row.center.y) + 28 <= foot.y - 64 * h.zoom - 5, "zoomed_bubble_clears_actor_" + row.mood)
	await capture("zoom-and-drag")
	fixture()
	h.simulation.residents[0].inside = true
	h.simulation.residents[1].mood_time = 0.0
	h.simulation.residents[2].mood = ""
	h.simulation.residents[3].mood_time = 0.05
	h.simulation.update(0.1)
	await frame()
	check(h.draws.is_empty(), "inside_expired_and_empty_moods_emit_no_bubble", h.draws)
	fixture()
	var resident: Dictionary = h.simulation.residents[0]
	resident.target = "0,0"
	resident.action = "sport"
	resident.wait = 0.0
	resident.mood = ""
	resident.mood_time = 0.0
	var completed: int = h.simulation.completed_behaviors
	h.simulation.rng.seed = 250925
	h.simulation.update(0.01)
	check(h.simulation.completed_behaviors == completed + 1 and MOODS.has(resident.mood), "real_activity_finish_sets_supported_mood", resident.mood)
	check(is_equal_approx(float(resident.mood_time), 3.0), "original_three_second_mood_duration_preserved", resident.mood_time)
	h.simulation.update(3.01)
	check(is_zero_approx(float(resident.mood_time)), "simulation_expires_mood_without_ui_mutation", resident.mood_time)

func rendered_contract() -> void:
	app.isolated = true
	app.isolated_moods = MOODS.duplicate()
	await frame()
	var image = viewport.get_texture().get_image()
	var appearances: Dictionary = {}
	for i in range(4):
		var center: Vector2 = app.canvas_offset + POINTS[i] * app.canvas_scale
		var rect = Rect2i(Vector2i(center - Vector2(16, 16) * app.canvas_scale), Vector2i(Vector2(32, 32) * app.canvas_scale))
		var yellow = 0
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c = image.get_pixel(x, y)
				if c.r > 0.8 and c.g > 0.5 and c.b < 0.45: yellow += 1
		check(yellow > 100.0 * app.canvas_scale * app.canvas_scale, "real_colored_emoji_pixels_" + MOODS[i], yellow)
		appearances[hash(image.get_region(rect).get_data())] = true
	check(appearances.size() == 4, "four_moods_have_four_distinct_emoji_faces", appearances.size())
	await capture("isolated-emoji")
	app.isolated_moods = ["", "unknown"]
	await frame()
	image = viewport.get_texture().get_image()
	for i in range(2):
		var nonwhite = 0
		var center: Vector2 = app.canvas_offset + POINTS[i] * app.canvas_scale
		var rect = Rect2i(Vector2i(center - Vector2(30, 30) * app.canvas_scale), Vector2i(Vector2(60, 65) * app.canvas_scale))
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c = image.get_pixel(x, y)
				if minf(c.r, minf(c.g, c.b)) < 0.98: nonwhite += 1
		check(nonwhite == 0, "unsupported_mood_draws_nothing_" + str(i), nonwhite)
	app.isolated = false

func frame() -> void:
	app._layout(viewport.size)
	app.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func pointer(position: Vector2, down: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = app.canvas_offset + position * app.canvas_scale
	viewport.push_input(event, true)
	await get_tree().process_frame

func tap(position: Vector2) -> void:
	await pointer(position, true)
	await pointer(position, false)
	await frame()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frame()
	check(viewport.get_texture().get_image().save_png(OUT + stage + "/" + resolution + "-" + label + ".png") == OK, "capture_" + label)
