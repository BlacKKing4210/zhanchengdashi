extends Node

const Base = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/combat-readability-20260915/"
const CELL = 43.0 * sqrt(3.0)
const RANGED = ["sparrow", "frog", "duck", "parrot", "fox", "swan", "falcon", "crane", "eagle", "golden_eagle"]
var app
var viewport: SubViewport
var checks = 0
var failures = 0
var base_key: Vector2i

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
	app._start_match("1v1_crossroads")
	app._layout(viewport.size)
	base_key = app._battle_base_key(app.PLAYER)
	for card in app.cards:
		app.card_levels[card.id] = 1
	dot_contract()
	head_bar_contract()
	projectile_contract()
	projectile_cleanup_contract()
	tower_legacy_contract()
	snapshot_contract()
	melee_contract()
	await capture_states()
	print("COMBAT_READABILITY checks=%d failures=%d" % [checks, failures])
	app.effects.clear()
	app.animal_skills.shots.clear()
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func reset_units() -> void:
	app.units.clear()
	app.effects.clear()
	app.animal_skills.shots.clear()
	app.unit_index_cache.clear()
	app.game_over = false
	app.result_ack_pending = false
	app.battle_reward_given = false
	app.online_match_id = ""
	app.online_match_authority = false
	app.battle_mode = app.BATTLE_MODE_CLASSIC
	app.multiplayer_free_for_all = false
	app.screen = app.SCREEN_BATTLE

func spawn(id: String, team: int = 1) -> int:
	var index = app.units.size()
	app._spawn_unit(team, base_key, id, true)
	app.units[index].pos = app._hex_center(base_key)
	app.units[index].tile = base_key
	return index

func target(index: int) -> Dictionary:
	return {"kind": "unit", "index": index, "unit_id": app.units[index].id, "pos": app.units[index].pos, "tile": app.units[index].tile}

func victim_at(position: Vector2) -> int:
	var index = spawn("elephant", app.ENEMY)
	app.units[index].pos = position
	app.units[index].tile = app._tile_at_world(position)
	app.units[index].animal_profile = {}
	app.units[index].hp = 1000.0
	app.units[index].max_hp = 1000.0
	app.units[index].base_max_hp = 1000.0
	app.units[index].attack = 0.0
	app.units[index].base_attack = 0.0
	app.units[index].speed = 0.0
	app.units[index].base_speed = 0.0
	return index

func projectiles() -> Array:
	return app.effects.filter(func(effect): return String(effect.get("kind", "")) in ["combat_projectile", "projectile"])

func settle_projectiles() -> void:
	for n in range(140):
		app.animal_skills.update_projectiles(0.05)
		app._update_effects(0.05)

func dot_contract() -> void:
	var card_id = "rabbit"
	app.card_counts[card_id] = 20
	app.card_levels[card_id] = 1
	check(app._card_can_upgrade(card_id), "red-dot fixture really can upgrade")
	for page in [app.SCREEN_LOBBY, app.SCREEN_GACHA, app.SCREEN_ROOM, app.SCREEN_BATTLE, app.SCREEN_DECK]:
		app.screen = page
		check(app._card_upgrade_dot_visible(card_id) == (page == app.SCREEN_DECK), "upgrade notification belongs only to deck: " + page)
	app.card_counts[card_id] = 1
	check(not app._card_upgrade_dot_visible(card_id), "deck does not show unavailable upgrade notification")

func head_bar_contract() -> void:
	var foot = Vector2(300, 600)
	var alpha_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	alpha_image.fill(Color.TRANSPARENT)
	alpha_image.fill_rect(Rect2i(20, 12, 28, 40), Color.WHITE)
	var alpha_texture = ImageTexture.create_from_image(alpha_image)
	var visible = app._animal_texture_visible_rect(alpha_texture)
	check(visible.is_equal_approx(Rect2(20.0 / 64.0, 12.0 / 64.0, 28.0 / 64.0, 40.0 / 64.0)), "alpha fixture ignores transparent outer padding")
	check(app._animal_texture_visible_rect(alpha_texture) == visible, "visible alpha bounds are stable when cached")
	var region_visible = app._animal_texture_visible_rect(alpha_texture, Rect2(16, 8, 48, 48))
	check(region_visible.is_equal_approx(Rect2(4.0 / 48.0, 4.0 / 48.0, 28.0 / 48.0, 40.0 / 48.0)), "sequence source region has its own normalized alpha bounds")
	var alpha_pose = {"offset": Vector2(8, -12), "scale": Vector2(-1.1, 0.9), "rotation": 0.2}
	var visible_bounds = app._animal_texture_canvas_bounds(foot, Vector2(44, 44), alpha_pose, 1.3, 0.0, visible)
	var full_bounds = app._animal_texture_canvas_bounds(foot, Vector2(44, 44), alpha_pose, 1.3, 0.0)
	check(visible_bounds.size.y < full_bounds.size.y, "visible-bound head anchoring is tighter than padded texture")
	check(app._animal_head_health_rect(visible_bounds, 1.3).end.y <= visible_bounds.position.y - 7.9, "head bar still clears actual alpha by eight pixels")
	for card in app.cards:
		if app._card_kind(card) != app.CARD_KIND_ANIMAL:
			continue
		for zoom in [0.65, 1.0, 1.3, 1.75]:
			for angle in [-0.45, 0.0, 0.45]:
				for mirror in [-1.0, 1.0]:
					var pose = {"offset": Vector2(12, -26), "scale": Vector2(mirror * 1.13, 0.86), "rotation": angle}
					var scale = app._animal_art_visual_scale(card) * zoom
					var padding = app._animal_art_bottom_padding_ratio(card)
					var bounds = app._animal_texture_canvas_bounds(foot, Vector2(44, 44), pose, scale, padding)
					var bar = app._animal_head_health_rect(bounds, zoom)
					check(bar.end.y <= bounds.position.y - 7.9, card.id + " head bar clears transformed artwork")
					check(is_equal_approx(bar.get_center().x, bounds.get_center().x), card.id + " head bar tracks artwork center")
					check(bar.size.x >= 36 and bar.size.y >= 6, card.id + " head bar remains legible at zoom")
					var local = Rect2(Vector2(-22, -44 + padding * 44), Vector2(44, 44))
					for corner in [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
						var point = foot + Vector2(pose.offset) + (Vector2(corner) * Vector2(pose.scale) * scale).rotated(angle)
						check(bounds.grow(0.01).has_point(point), card.id + " transformed corner is inside conservative bounds")

func projectile_contract() -> void:
	var configured = app.cards.filter(func(card): return app._card_kind(card) == app.CARD_KIND_ANIMAL and app.CardRules.is_ranged_animal(card))
	check(configured.size() == RANGED.size(), "all ten configured ranged animals are explicitly covered")
	for id in RANGED:
		reset_units()
		var source = spawn(id)
		var origin = Vector2(app.units[source].pos)
		var victim = victim_at(origin + Vector2(CELL * 1.1, 0))
		app.units[source].attack = 5.0
		app.units[source].base_attack = 5.0
		app.effects.clear()
		app._unit_attack_target(source, target(victim), CELL * 1.1)
		check(app.units[source].is_ranged and app.animal_skills.shots.size() > 0, id + " launches a real projectile")
		check(projectiles().size() > 0, id + " has a visual at launch")
		if projectiles().is_empty():
			continue
		var visual = projectiles()[0]
		check(visual.has("visual_id") and visual.has("flight_duration"), id + " stable visual metadata")
		check(Vector2(visual.get("from", Vector2.ZERO)).is_equal_approx(origin), id + " visual starts at launcher")
		app._update_effects(float(visual.time) + 0.1)
		check(app.animal_skills.shots.size() > 0, id + " logical projectile survives visual-only long frame")
		app.animal_skills.update_projectiles(0.01)
		check(projectiles().size() > 0, id + " missing effect reattaches after long frame")
		var hp = float(app.units[victim].hp)
		settle_projectiles()
		check(app.units[victim].hp < hp, id + " real projectile hits enemy")
		check(app.animal_skills.shots.is_empty() and projectiles().is_empty(), id + " projectile and residue finish cleanly")

func projectile_cleanup_contract() -> void:
	for id in ["parrot", "crane", "eagle", "golden_eagle"]:
		reset_units()
		var source = spawn(id)
		var victim = victim_at(Vector2(app.units[source].pos) + Vector2(CELL, 0))
		app._unit_attack_target(source, target(victim), CELL)
		app.units[victim].hp = 0
		settle_projectiles()
		check(app.animal_skills.shots.is_empty() and projectiles().is_empty(), id + " target-death cleanup")
	reset_units()
	var source = spawn("eagle")
	var origin = Vector2(app.units[source].pos)
	var first = victim_at(origin + Vector2(CELL * 0.6, 0))
	var second = victim_at(origin + Vector2(CELL * 0.7, CELL * 0.2))
	var third = victim_at(origin + Vector2(CELL * 0.8, -CELL * 0.2))
	app._unit_attack_target(source, target(first), CELL * 0.6)
	var initial_id = str(projectiles()[0].visual_id)
	app.animal_skills.update_projectiles(0.1)
	check(projectiles().any(func(effect): return str(effect.visual_id) != initial_id), "eagle bounce starts a distinct visual segment")
	settle_projectiles()
	check(app.units[first].hp < 1000 and app.units[second].hp < 1000 and app.units[third].hp < 1000, "eagle keeps both bounce hits")
	check(app.animal_skills.shots.is_empty() and projectiles().is_empty(), "bounce chain residue fully clears")
	reset_units()
	source = spawn("golden_eagle")
	origin = Vector2(app.units[source].pos)
	first = victim_at(origin + Vector2(CELL * 0.6, 0))
	second = victim_at(origin + Vector2(CELL * 1.2, 0))
	app._unit_attack_target(source, target(first), CELL * 0.6)
	settle_projectiles()
	check(app.units[first].hp < 1000 and app.units[second].hp < 1000, "pierce still damages both collinear targets")
	check(app.animal_skills.shots.is_empty() and projectiles().is_empty(), "piercing reaches maximum range then clears")
	reset_units()
	source = spawn("sparrow")
	first = victim_at(Vector2(app.units[source].pos) + Vector2(CELL, 0))
	app._unit_attack_target(source, target(first), CELL)
	app._unit_attack_target(source, target(first), CELL)
	check(projectiles().size() == 2, "identical simultaneous trajectories retain two effects")
	check(str(projectiles()[0].visual_id) != str(projectiles()[1].visual_id), "simultaneous projectiles have distinct IDs")
	settle_projectiles()
	reset_units()
	source = spawn("sparrow")
	first = victim_at(Vector2(app.units[source].pos) + Vector2(CELL, 0))
	app._unit_attack_target(source, target(first), CELL)
	app.game_over = true
	app._update_effects(20.0)
	check(projectiles().is_empty(), "settlement cannot retain immortal projectile residue")

func snapshot_contract() -> void:
	reset_units()
	var visual = app._new_projectile_visual(Vector2(20, 40), Vector2(100, 40), app.PLAYER)
	visual.visual_id = "qa-repeatable-flight"
	visual.visual_elapsed = 0.0
	app.effects.clear()
	app._merge_online_snapshot_effects([visual.duplicate(true)])
	check(projectiles().size() == 1, "remote new projectile arrives")
	app._update_effects(0.05)
	var elapsed = float(projectiles()[0].visual_elapsed)
	check(elapsed > 0, "remote projectile has advancing local visual clock")
	app._merge_online_snapshot_effects([visual.duplicate(true)])
	check(projectiles().size() == 1 and float(projectiles()[0].visual_elapsed) >= elapsed, "repeated snapshot does not restart known flight")
	app._update_effects(20.0)
	app._merge_online_snapshot_effects([visual.duplicate(true)])
	check(projectiles().is_empty(), "stale repeated snapshot cannot replay expired flight")
	app.online_match_id = "qa-new-match"
	app._merge_online_snapshot_effects([])
	check(app.online_projectile_visual_seen.is_empty(), "new match clears prior replay bookkeeping")
	app._merge_online_snapshot_effects([visual.duplicate(true)])
	check(projectiles().size() == 1, "same visual ID can play in a different match")
	app.online_match_id = "qa-native-numbered-match"
	var native_effects: Array = []
	for n in range(100):
		native_effects.append(app._new_projectile_visual(Vector2(20, 40), Vector2(100, 40), app.PLAYER).duplicate(true))
	app.effects.clear()
	app._merge_online_snapshot_effects(native_effects)
	check(projectiles().size() == 100, "monotonic native IDs keep every distinct projectile")
	check(app.online_projectile_visual_seen.is_empty(), "native ID deduplication uses bounded watermark, not per-shot history")
	app._update_effects(20.0)
	app._merge_online_snapshot_effects(native_effects)
	check(projectiles().is_empty(), "expired native flights never replay even beyond 20 seconds")
	app.online_match_id = "qa-unordered-packet"
	var unordered: Array = []
	for id in [10, 12, 11]:
		var packet_visual = visual.duplicate(true)
		packet_visual.visual_id = id
		unordered.append(packet_visual)
	app._merge_online_snapshot_effects(unordered)
	check(projectiles().size() == 3, "numeric watermark accepts all IDs in an unordered snapshot")
	app._merge_online_snapshot_effects(unordered)
	check(projectiles().size() == 3, "repeated numeric packet adds no duplicate")
	var following = visual.duplicate(true)
	following.visual_id = 13
	app._merge_online_snapshot_effects([following])
	check(projectiles().size() == 4, "next higher numeric ID is accepted")
	app.online_match_id = "qa-lower-id-new-match"
	app._merge_online_snapshot_effects([unordered[0]])
	check(projectiles().size() == 1 and int(projectiles()[0].visual_id) == 10, "new match accepts lower numeric ID")
	app.online_match_id = "qa-authority-migration"
	app._apply_online_battle_snapshot({"match_id": app.online_match_id, "projectile_visual_serial": 9000, "effects": [], "game_over": false})
	var migrated = app._new_projectile_visual(Vector2(20, 40), Vector2(100, 40), app.PLAYER).duplicate(true)
	check(int(migrated.visual_id) > 9000, "new authority inherits serial even from empty-effect snapshot")
	app.effects.clear()
	app.online_projectile_visual_highest = 9000
	app._merge_online_snapshot_effects([migrated])
	check(projectiles().size() == 1, "observer watermark accepts new authority's first projectile")
	app.online_last_received_sequence = 777
	app.online_match_authority = false
	app._on_online_authority_changed({"match_id": app.online_match_id, "is_authority": false})
	app._on_online_authority_snapshot({"match_id": app.online_match_id, "sequence": 1, "snapshot": {"match_id": app.online_match_id, "battle_timer": 123.0, "effects": [], "game_over": false}})
	check(app.online_last_received_sequence == 1 and is_equal_approx(app.battle_timer, 123.0), "observer accepts restarted sequence after migration")
	app.online_snapshot_sequence = 777
	app._on_online_authority_changed({"match_id": app.online_match_id, "is_authority": true})
	check(app.online_snapshot_sequence == 0, "new authority starts a fresh snapshot sequence without network call")

func tower_legacy_contract() -> void:
	reset_units()
	app._projectile(Vector2(100, 100), Vector2(180, 100), app.PLAYER)
	check(projectiles().size() == 1 and projectiles()[0].has("visual_id"), "tower projectile uses common identifiable visual")
	if projectiles().is_empty():
		return
	check(projectiles()[0].has("from") and projectiles()[0].has("to"), "tower projectile retains interpolation endpoints")
	var before = float(projectiles()[0].visual_elapsed)
	app._update_effects(0.05)
	check(float(projectiles()[0].visual_elapsed) > before, "tower visual advances on the common clock")
	app._update_effects(3.0)
	check(projectiles().is_empty(), "tower visual clears")
	for retained_flag in [false, true]:
		reset_units()
		var source = spawn("sparrow")
		var victim = victim_at(Vector2(app.units[source].pos) + Vector2(5, 0))
		app.units[source].erase("animal_profile")
		if not retained_flag:
			app.units[source].erase("is_ranged")
		app._unit_attack_target(source, target(victim), 5.0)
		check(projectiles().size() > 0, "legacy close ranged attack shows bullet; retained flag=%s" % retained_flag)
		check(app.units[victim].hp < 1000, "legacy attack damage remains immediate")

func melee_contract() -> void:
	for card in app.cards:
		if app._card_kind(card) != app.CARD_KIND_ANIMAL or app.CardRules.is_ranged_animal(card):
			continue
		var jump = app.AnimalSkillRules.compile_text(String(card.skill_text)).has("jump")
		var stats = app._card_stats(card)
		check(is_equal_approx(float(stats.attack_range), CELL * (1.01 if jump else 0.65)), card.id + " approved close-contact range")
	reset_units()
	var source = spawn("rabbit")
	var origin = Vector2(app.units[source].pos)
	var victim = victim_at(origin + Vector2(CELL * 0.8, 0))
	check(app._nearest_attack_target_in_range(app.units[source]).is_empty(), "ordinary melee does not swing at 0.8 cells")
	app.units[victim].pos = origin + Vector2(CELL * 0.60, 0)
	check(not app._nearest_attack_target_in_range(app.units[source]).is_empty(), "ordinary melee can swing within 0.65 cells")
	var jump_cards = app.cards.filter(func(card): return app._card_kind(card) == app.CARD_KIND_ANIMAL and app.AnimalSkillRules.compile_text(String(card.skill_text)).has("jump"))
	check(jump_cards.size() == 4, "all four formal jumping animals are covered")
	for card in jump_cards:
		var id = String(card.id)
		reset_units()
		source = spawn(id)
		var profile = app.animal_skills.profile(app.units[source])
		if not profile.has("jump"):
			continue
		origin = Vector2(app.units[source].pos)
		victim = victim_at(origin + Vector2(CELL, 0))
		app._unit_attack_target(source, target(victim), CELL)
		check(app.units[victim].hp < 1000, id + " adjacent enemy remains attackable without jump oscillation")
		check(not app.units[source].has("motion_trip"), id + " adjacent contact does not start another jump")
		app.units[source].pos = origin
		app.units[source].tile = base_key
		var began = app.animal_skills.begin_jump(source, origin + Vector2(CELL * 5, 0))
		check(began and app.units[source].has("motion_trip"), id + " still begins genuine fixed-length jump")
		if not app.units[source].has("motion_trip"):
			continue
		var trip = app.units[source].motion_trip.duplicate(true)
		check(is_equal_approx(Vector2(trip.start).distance_to(trip.finish), CELL * int(profile.jump)), id + " jump distance unchanged")
		app.animal_skills.tick_motion(source, float(trip.duration))
		check(Vector2(app.units[source].pos).is_equal_approx(Vector2(trip.finish)), id + " jump lands at planned center")
		check(Vector2(app.units[source].pos).distance_to(app._hex_center(app.units[source].tile)) < 0.01, id + " landing remains exactly on grid center")
	actual_contact_contract(jump_cards)

func actual_contact_contract(jump_cards: Array) -> void:
	var directions = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
	var inner_key = app.MultiplayerRules.INVALID_KEY
	for key in app.tiles:
		if directions.all(func(direction): return app.tiles.has(key + direction)):
			inner_key = key
			break
	check(inner_key != app.MultiplayerRules.INVALID_KEY, "real map has an interior contact fixture")
	if inner_key == app.MultiplayerRules.INVALID_KEY:
		return
	base_key = inner_key
	for key in app.tiles:
		app.tiles[key].building = ""
		app.tiles[key].hp = 0
	for direction in directions:
		reset_units()
		var source = spawn("rabbit")
		var destination = app._hex_center(inner_key + direction)
		var victim = victim_at(destination)
		app.units[victim].stun_timer = 100.0
		app.units[source].cooldown = 0.0
		app.units[source] = app._lock_unit_attack_target(app.units[source], target(victim), true)
		var hit = false
		for n in range(100):
			app._update_units(0.02)
			var distance = Vector2(app.units[source].pos).distance_to(destination)
			if app.units[victim].hp < 1000:
				check(distance <= CELL * 0.65 + 0.01, "actual walking melee hits only after closing: " + str(direction))
				hit = true
				break
		check(hit, "actual walking melee reaches target from direction " + str(direction))
	for card in jump_cards:
		for building_target in [false, true]:
			reset_units()
			var source = spawn(String(card.id))
			var destination_key = inner_key + directions[0]
			var destination = app._hex_center(destination_key)
			var victim = -1
			if building_target:
				app.tiles[destination_key].building = "barracks"
				app.tiles[destination_key].team = app.ENEMY
				app.tiles[destination_key].hp = 1000.0
				app.tiles[destination_key].max_hp = 1000.0
			else:
				victim = victim_at(destination)
				app.units[victim].stun_timer = 100.0
			app.units[source].cooldown = 0.0
			var origin = Vector2(app.units[source].pos)
			app._update_units(0.02)
			var hp = float(app.tiles[destination_key].hp) if building_target else float(app.units[victim].hp)
			check(hp < 1000, String(card.id) + " real update attacks adjacent " + ("building" if building_target else "animal"))
			check(not app.units[source].has("motion_trip"), String(card.id) + " real adjacent combat does not loop jumping")
			check(Vector2(app.units[source].pos).is_equal_approx(origin), String(card.id) + " contact lunge never changes ground position")
			app.UnitMotionFeedback.begin_frame(app.units[source], 0.06)
			var lunge = app._jump_contact_visual_offset(app.units[source], 1.3)
			check(lunge.length() > 0.1, String(card.id) + " contact attack has visible forward lunge")
			for n in range(10):
				app._update_units(0.02)
			check(not app.units[source].has("motion_trip"), String(card.id) + " adjacent combat remains stable during cooldown")
			app.tiles[destination_key].building = ""
			app.tiles[destination_key].hp = 0

func save_capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUT + name + ".png") == OK, "saved " + name)

func capture_states() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	app._start_match("1v1_crossroads")
	base_key = app._battle_base_key(app.PLAYER)
	reset_units()
	for key in app.tiles:
		app.tiles[key].building = ""
		app.tiles[key].hp = 0
	var examples = ["rabbit", "parrot", "fox", "elephant", "frog", "golden_eagle", "zebra", "eagle"]
	for n in range(examples.size()):
		var index = spawn(examples[n], app.PLAYER if n % 2 == 0 else app.ENEMY)
		app.units[index].pos = app._canvas_to_world(Vector2(190 + (n % 2) * 230, 340 + (n / 2) * 190))
		app.units[index].tile = app._tile_at_world(app.units[index].pos)
		app.units[index].hp = maxf(1, float(app.units[index].max_hp) * 0.60)
	app._unit_attack_target(1, target(0), Vector2(app.units[1].pos).distance_to(app.units[0].pos))
	app._unit_attack_target(2, target(3), Vector2(app.units[2].pos).distance_to(app.units[3].pos))
	app._unit_attack_target(4, target(5), Vector2(app.units[4].pos).distance_to(app.units[5].pos))
	app._update_effects(0.10)
	app.toast_timer = 0
	await save_capture("battle-head-bars-projectiles-720")
	app._update_effects(0.06)
	await save_capture("battle-head-bars-projectiles-frame2-720")
	app._update_effects(0.06)
	await save_capture("battle-head-bars-projectiles-frame3-720")
	viewport.size = Vector2i(360, 640)
	app._layout(viewport.size)
	await save_capture("battle-head-bars-projectiles-360")
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)
	for card in app.cards:
		app.card_counts[card.id] = 20
		app.card_levels[card.id] = 1
	app.last_gacha_cards = ["sheep", "chicken", "rabbit", "ant", "sheep", "snail", "pigeon", "mouse", "snail", "chicken"]
	app.gacha_pending_cards.clear()
	app.gacha_detail_card_id = ""
	app.gacha_fx_timer = 0
	app.screen = app.SCREEN_GACHA
	await save_capture("gacha-no-upgrade-dots-720")
	viewport.size = Vector2i(360, 640)
	app._layout(viewport.size)
	await save_capture("gacha-no-upgrade-dots-360")
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)
	app.deck = ["rabbit", "parrot", "fox", "elephant", "frog", "golden_eagle", "zebra", "eagle"]
	app.selected_card_id = "rabbit"
	app.screen = app.SCREEN_DECK
	app.deck_scroll = 0
	await save_capture("deck-upgrade-dots-720")
	viewport.size = Vector2i(360, 640)
	app._layout(viewport.size)
	await save_capture("deck-upgrade-dots-360")
