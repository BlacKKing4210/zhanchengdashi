extends Node

const Base = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/combat-natural-20260925/evaluator"
const RANGED = ["sparrow", "frog", "duck", "parrot", "fox", "swan", "falcon", "crane", "eagle", "golden_eagle"]
const TOWERS = ["defense_watch_tower", "defense_longshot_tower", "defense_cannon_tower", "defense_plunder_tower", "defense_rapid_tower", "defense_repair_beacon", "defense_twinshot_tower", "defense_bounty_tower", "defense_territory_tower"]

class ProbeApp extends Base.TestApp:
	var destroy_during_attack = false
	var probe_mode = ""
	var probe_effect: Dictionary = {}
	var probe_tile: Dictionary = {}
	func _tower_attack(key: Vector2i, team: int) -> void:
		if destroy_during_attack:
			_damage_tile(key, ENEMY if team == PLAYER else PLAYER, 9999.0)
		else:
			super._tower_attack(key, team)
	func _draw() -> void:
		if probe_mode == "":
			super._draw()
			return
		draw_set_transform(canvas_offset, 0, Vector2.ONE * canvas_scale)
		draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color.WHITE)
		if probe_mode == "projectile": _draw_projectile_visual(probe_effect)
		elif probe_mode == "health": _draw_building_health_bar(Vector2(360, 500), probe_tile)

var app: ProbeApp
var viewport: SubViewport
var base_key: Vector2i
var checks = 0
var failures = 0
var results: Array = []

func check(value: bool, label: String, observed: Variant = null) -> void:
	checks += 1
	results.append({"label": label, "pass": value, "observed": observed})
	if not value:
		failures += 1
		push_error("%s observed=%s" % [label, str(observed)])

func _ready() -> void:
	seed(9252026)
	GameAudio.sfx_enabled = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = ProbeApp.new()
	viewport.add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	app._start_match("1v1_crossroads")
	app._layout(viewport.size)
	base_key = app._battle_base_key(app.PLAYER)
	app.card_levels.clear()
	app.enemy_card_levels.clear()
	building_contract()
	thorns_contract()
	projectile_contract()
	snapshot_contract()
	if DisplayServer.get_name() != "headless":
		await rendered_contract()
		await battle_captures()
	var mode = "headless" if DisplayServer.get_name() == "headless" else "gpu"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var file = FileAccess.open(OUT + "-" + mode + "-observations.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_video_adapter_name(), "seed": 9252026, "results": results}, "\t"))
	print("COMBAT_NATURAL_PROJECTILES checks=%d failures=%d" % [checks, failures])
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func reset() -> void:
	app.units.clear()
	app.effects.clear()
	app.animal_skills.shots.clear()
	app.unit_index_cache.clear()
	app.tower_target_locks.clear()
	app.game_over = false
	app.result_ack_pending = false
	app.battle_reward_given = false
	app.online_match_id = ""
	app.online_match_authority = false
	app.battle_mode = app.BATTLE_MODE_CLASSIC
	app.multiplayer_free_for_all = false
	app.screen = app.SCREEN_BATTLE
	app.destroy_during_attack = false
	for key in app.tiles:
		app.tiles[key].building = ""
		app.tiles[key].hp = 0
		app.tiles[key].max_hp = 0

func tower(id: String = "defense_watch_tower", hp: float = 10.0) -> void:
	var tile = app.tiles[base_key]
	tile.building = "tower"
	tile.site_card = id
	tile.team = app.PLAYER
	tile.occupier = app.PLAYER
	tile.territory_team = app.PLAYER
	tile.hp = hp
	tile.max_hp = maxf(100, hp)
	tile.spawn_timer = 0.0

func spawn(id: String, team: int, hp: float = 100.0) -> int:
	var index = app.units.size()
	app._spawn_unit(team, base_key, id, true)
	app.units[index].pos = app._hex_center(base_key) + Vector2(20, 0)
	app.units[index].tile = base_key
	app.units[index].hp = hp
	app.units[index].max_hp = hp
	app.units[index].base_max_hp = hp
	app.units[index].shield = 0.0
	return index

func target(index: int) -> Dictionary:
	return {"kind": "unit", "index": index, "unit_id": app.units[index].id, "pos": app.units[index].pos, "tile": app.units[index].tile}

func projectiles() -> Array:
	return app.effects.filter(func(effect): return String(effect.get("kind", "")) in ["combat_projectile", "projectile"])

func building_contract() -> void:
	reset()
	tower("defense_watch_tower", 0.5)
	var victim = spawn("hedgehog", app.ENEMY)
	app._update_buildings(0.02)
	check(float(app.units[victim].hp) < 100.0, "true building tick fired at hedgehog", app.units[victim].hp)
	check(is_equal_approx(float(app.tiles[base_key].hp), 0.5), "hedgehog thorns do not damage firing building", app.tiles[base_key].hp)
	check(String(app.tiles[base_key].building) == "tower" and float(app.tiles[base_key].hp) > 0.0, "firing building cannot be present with empty health", {"building": app.tiles[base_key].building, "hp": app.tiles[base_key].hp})
	reset()
	tower("defense_watch_tower", 0.5)
	app.destroy_during_attack = true
	app._update_buildings(0.02)
	check(String(app.tiles[base_key].building) == "", "building tick preserves callback destruction instead of resurrecting stale tile", app.tiles[base_key])
	check(int(app.tiles[base_key].team) == app.ENEMY, "callback capture owner survives building tick", app.tiles[base_key].team)
	reset()
	tower("defense_watch_tower", 0.5)
	app.tiles[base_key].building = "base"
	app.destroy_during_attack = true
	app._update_buildings(0.02)
	check(int(app.tiles[base_key].team) == app.ENEMY and float(app.tiles[base_key].hp) > 0, "base capture during attack retains captured owner and restored health", app.tiles[base_key])
	check(app.game_over, "base destruction still finishes classic battle")
	reset()
	tower("defense_watch_tower", 20)
	victim = spawn("hedgehog", app.ENEMY)
	var damage = float(app.units[victim].attack)
	app._unit_attack_target(victim, {"kind": "building", "key": base_key, "pos": app._hex_center(base_key), "tile": base_key}, 20.0)
	check(damage > 0 and is_equal_approx(float(app.tiles[base_key].hp), 20.0 - damage), "hedgehog ordinary attack still damages building", app.tiles[base_key].hp)

func thorns_contract() -> void:
	for source_card in ["rabbit", "eagle", "hedgehog"]:
		for lethal in [false, true]:
			reset()
			var victim = spawn("hedgehog", app.PLAYER, 0.5 if lethal else 100.0)
			var source = spawn(source_card, app.ENEMY)
			app._damage_unit(victim, 1.0, source, app.ENEMY)
			check(is_equal_approx(float(app.units[source].hp), 99.0), "one-point animal retaliation retained: %s lethal=%s" % [source_card, lethal], app.units[source].hp)
			check(is_equal_approx(float(app.units[victim].hp), -0.5 if lethal else 99.0), "retaliation cannot recurse: %s lethal=%s" % [source_card, lethal], app.units[victim].hp)
	reset()
	var victim = spawn("hedgehog", app.PLAYER)
	var source = spawn("rabbit", app.ENEMY)
	app.units[victim].shield = 5.0
	app._damage_unit(victim, 1.0, source, app.ENEMY)
	check(is_equal_approx(float(app.units[source].hp), 100.0), "fully absorbed attack still triggers no thorns", app.units[source].hp)

func projectile_contract() -> void:
	for id in RANGED:
		reset()
		var source = spawn(id, app.PLAYER)
		var victim = spawn("elephant", app.ENEMY, 1000.0)
		app.units[victim].pos += Vector2(100, 0)
		app.units[victim].animal_profile = {}
		app._unit_attack_target(source, target(victim), 100.0)
		check(not projectiles().is_empty(), id + " really launches a visible projectile")
		for effect in projectiles(): check(String(effect.get("source_card", "")) == id, id + " launch visual retains animal identity", effect.get("source_card"))
		for n in range(140):
			app.animal_skills.update_projectiles(0.05)
			app._update_effects(0.05)
		check(float(app.units[victim].hp) < 1000, id + " physical projectile still deals damage", app.units[victim].hp)
		check(app.animal_skills.shots.is_empty() and projectiles().is_empty(), id + " clears physical and visual projectile")
	for id in TOWERS:
		reset()
		tower(id)
		spawn("elephant", app.ENEMY, 1000)
		spawn("elephant", app.ENEMY, 1000)
		app._update_buildings(0.02)
		check(not projectiles().is_empty(), id + " fires via building update")
		for effect in projectiles(): check(String(effect.get("source_card", "")) == id, id + " tower visual retains source identity", effect.get("source_card"))
	reset()
	var source = spawn("eagle", app.PLAYER)
	for n in range(3):
		var victim = spawn("elephant", app.ENEMY, 1000)
		app.units[victim].animal_profile = {}
		app.units[victim].pos += Vector2(30 + n * 20, n * 10)
	app._unit_attack_target(source, target(1), 30)
	var initial_id = str(projectiles()[0].visual_id)
	app.animal_skills.update_projectiles(0.1)
	check(projectiles().any(func(effect): return str(effect.visual_id) != initial_id), "bounce actually creates another segment")
	for effect in projectiles(): check(String(effect.get("source_card", "")) == "eagle", "bounce keeps original animal identity", effect.get("source_card"))

func snapshot_contract() -> void:
	reset()
	var source = spawn("sparrow", app.PLAYER)
	var victim = spawn("elephant", app.ENEMY, 1000)
	app.units[victim].pos += Vector2(100, 0)
	app._unit_attack_target(source, target(victim), 100)
	var packet = app._online_battle_snapshot()
	check(packet.effects.any(func(effect): return String(effect.get("source_card", "")) == "sparrow"), "authority snapshot carries projectile identity")
	app.effects.clear()
	app._apply_online_battle_snapshot(packet)
	check(projectiles().any(func(effect): return String(effect.get("source_card", "")) == "sparrow"), "snapshot receiver preserves projectile identity")
	app._update_effects(0.05)
	var elapsed = float(projectiles()[0].visual_elapsed)
	app._apply_online_battle_snapshot(packet)
	check(float(projectiles()[0].visual_elapsed) >= elapsed, "repeated snapshot keeps visual clock")

func capture(path: String) -> Image:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var result = viewport.get_texture().get_image()
	check(result.save_png(OUT + path + ".png") == OK, "saved " + path)
	return result

func ink_bounds(img: Image, rect: Rect2i) -> Rect2i:
	var low = rect.end
	var high = rect.position - Vector2i.ONE
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var pixel = img.get_pixel(x, y)
			if minf(pixel.r, minf(pixel.g, pixel.b)) < 0.90:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	return Rect2i(low, high - low + Vector2i.ONE) if high.x >= low.x else Rect2i()

func rendered_contract() -> void:
	reset()
	var appearance_hashes: Dictionary = {}
	for id in ["sparrow", "frog", "parrot", "fox", "defense_watch_tower", "defense_cannon_tower", "defense_plunder_tower"]:
		app.probe_mode = "projectile"
		var from = app._canvas_to_world(Vector2(260, 500))
		var to = app._canvas_to_world(Vector2(460, 500))
		app.probe_effect = app._new_projectile_visual(from, to, app.PLAYER)
		app.probe_effect.source_card = id
		app.probe_effect.visual_elapsed = float(app.probe_effect.flight_duration) * 0.5
		var img = await capture("-isolated-" + id)
		var bounds = ink_bounds(img, Rect2i(260, 400, 200, 160))
		check(bounds.size.x > 0 and bounds.size.x <= 22 and bounds.size.y <= 22, id + " compact rendered bullet without long trail", str(bounds))
		appearance_hashes[hash(img.get_region(Rect2i(260, 400, 200, 160)).get_data())] = true
	check(appearance_hashes.size() >= 5, "at least five visually distinct bullet types", appearance_hashes.size())
	app.probe_mode = "health"
	app.probe_tile = {"hp": 0.001, "max_hp": 100, "team": app.PLAYER, "building": "tower"}
	var image = await capture("-near-zero-building-health-720")
	var color = app._team_health_color(app.PLAYER)
	var visible = 0
	for y in range(528, 532):
		for x in range(338, 345):
			var pixel = image.get_pixel(x, y)
			if absf(pixel.r - color.r) + absf(pixel.g - color.g) + absf(pixel.b - color.b) < 0.16: visible += 1
	check(visible >= 6, "living near-zero building retains visible health pixels", visible)
	app.probe_mode = ""

func battle_captures() -> void:
	reset()
	app.board_pan += Vector2(360, 470) - app._world_to_canvas(app._hex_center(base_key))
	tower("defense_watch_tower", 0.001)
	for n in range(6):
		var id = ["sparrow", "frog", "parrot", "fox", "eagle", "hedgehog"][n]
		var index = spawn(id, app.PLAYER if n % 2 == 0 else app.ENEMY, 10)
		app.units[index].pos = app._canvas_to_world(Vector2(220 + (n % 2) * 260, 590 + (n / 2) * 160))
		app.units[index].tile = app._tile_at_world(app.units[index].pos)
		if n < 5:
			var visual = app._new_projectile_visual(app.units[index].pos, app._canvas_to_world(Vector2(480 if n % 2 == 0 else 220, 590 + (n / 2) * 160)), int(app.units[index].team))
			visual.source_card = id
			visual.visual_elapsed = float(visual.flight_duration) * 0.5
	app.toast_timer = 0
	var pause_pos = app.canvas_offset + app._pause_button_rect().get_center() * app.canvas_scale
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pause_pos
	press.pressed = true
	viewport.push_input(press, true)
	var release = press.duplicate()
	release.pressed = false
	viewport.push_input(release, true)
	check(app.pause_open, "native mouse event pauses battle through viewport input")
	var resume = press.duplicate()
	resume.position = app.canvas_offset + app._pause_continue_rect().get_center() * app.canvas_scale
	viewport.push_input(resume, true)
	var resume_release = resume.duplicate()
	resume_release.pressed = false
	viewport.push_input(resume_release, true)
	check(not app.pause_open, "native mouse event resumes battle through viewport input")
	await capture("-battle-720")
	viewport.size = Vector2i(360, 640)
	app._layout(viewport.size)
	await capture("-battle-360")
