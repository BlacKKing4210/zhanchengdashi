extends Node

const Base = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/all-animals-audit-20260906/"
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
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = Base.TestApp.new()
	viewport.add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for mode in ["classic", "3v3", "ffa"]:
		if mode == "classic": app._start_match("1v1_crossroads")
		else: app._start_multiplayer_match("3v3_plateau" if mode == "3v3" else "", 3, mode == "ffa")
		app._layout(viewport.size)
		if app._should_draw_3v3_team_scoreboard():
			for side in range(2):
				check(not app._pause_button_rect().intersects(app._multiplayer_team_scoreboard_rect(side)), "pause does not obscure team counts")
		var original_tiles = app.tiles.duplicate(true)
		for key in app.tiles:
			var world = app._hex_center(key)
			var canvas = app._world_to_canvas(world)
			check(app._canvas_to_world(canvas).distance_to(world) < 0.001, mode + " reversible projection")
			check(app._tile_at_canvas(canvas) == key, mode + " projected tile click")
			for neighbor in app._neighbors(key):
				var distance = canvas.distance_to(app._world_to_canvas(app._hex_center(neighbor)))
				check(absf(distance - sqrt(3.0) * app.HEX_SIZE * app._battle_camera_zoom()) < 0.002, mode + " six equal center distances")
		var points = app._terrain_hex_points(Vector2.ZERO)
		var top_y = INF
		for point in points: top_y = minf(top_y, point.y)
		var top_count = 0
		for point in points:
			if absf(point.y - top_y) < 0.001: top_count += 1
		check(top_count == 2, "flat top is a horizontal edge, not a vertex")
		for i in range(6):
			var apothem = Geometry2D.get_closest_point_to_segment(Vector2.ZERO, points[i], points[(i + 1) % 6]).length()
			var gap = sqrt(3.0) * app.HEX_SIZE * app._battle_camera_zoom() - 2 * apothem
			check(absf(gap - sqrt(3.0) * app.HEX_SIZE * app._battle_camera_zoom() * 0.04) < 0.001, "equal four-percent seam on every side")
		app.board_pan += Vector2(20, -16)
		app._clamp_board_pan()
		check(app.tiles == original_tiles, "camera does not mutate gameplay state")
		# Real unlock click, centered safely outside HUD and unit priority targets.
		app.gold = 999
		app.multiplayer_gold[app._local_control_team()] = 999
		for key in app.tiles:
			if not app._can_unlock(key, app._local_control_team()): continue
			app.board_pan = Vector2(360, 650) - app._battle_view_rect().get_center() - app._battle_view_vector(app._hex_center(key)) * app._battle_camera_zoom()
			var canvas = app._world_to_canvas(app._hex_center(key))
			app._handle_tap(app.canvas_offset + canvas * app.canvas_scale)
			check(app.tiles[key].team == app._local_control_team(), mode + " real rotated build click")
			break
		app._reset_multiplayer_board_pan()
		app.gold = 72
		app.multiplayer_gold[app._local_control_team()] = 72
		app.toast_timer = 0.0
		app._clear_building_card_preview(true)
		await capture("hex-" + mode + "-720.png")
		if mode == "classic":
			viewport.size = Vector2i(360, 640)
			await capture("hex-classic-360.png")
			viewport.size = Vector2i(720, 1280)
	print("FLAT_HEX_VIEW checks=", checks, " failures=", failures)
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	app.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUT + filename) == OK, "GPU capture " + filename)
