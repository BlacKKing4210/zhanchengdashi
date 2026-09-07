extends Node

const Base = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/result-reward-area-20260907/"
var app
var viewport: SubViewport
var checks = 0
var failures = 0
var base_key: Vector2i

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
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
	for card in app.cards: app.card_levels[card.id] = 1
	fox_coverage()
	projectile_contract()
	result_contract()
	await capture_states()
	print("COMBAT_FEEDBACK checks=%d failures=%d" % [checks, failures])
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
	app.battle_mode = app.BATTLE_MODE_CLASSIC
	app.multiplayer_free_for_all = false

func spawn(id: String, team: int = 1, disabled: bool = false) -> int:
	var i = app.units.size()
	app._spawn_unit(team, base_key, id, true, 0, {"skill_triggers_enabled": not disabled})
	app.units[i].pos = Vector2(10000 + i * 20, 10000)
	return i

func fox_coverage() -> void:
	reset_units()
	var before = spawn("rabbit")
	var f1 = spawn("fox")
	var after = spawn("rabbit")
	var disabled = spawn("rabbit", 1, true)
	for i in [before, after, disabled]:
		check(app.units[i].attack == app.units[i].base_attack + 1, "all recipients including late/disabled births have attack aura immediately")
		check(app.units[i].max_hp == app.units[i].base_max_hp + 1, "all recipients have hp aura immediately")
	var f2 = spawn("fox")
	for n in range(20): app._refresh_unit_skill_state(0.01)
	check(app.units[before].attack == 2 and app.units[before].max_hp == 4, "multiple foxes never stack or repeatedly heal")
	app._add_attack_bonus(before, 2, false)
	app._damage_unit(f1, 999, -1, app.ENEMY)
	check(app.units[before].attack == 4, "one fox surviving keeps permanent plus aura")
	app._damage_unit(f2, 999, -1, app.ENEMY)
	check(app.units[before].attack == 3 and app.units[before].max_hp == 3, "last fox removes only aura")
	reset_units()
	# Mixed restored-state ordering must not select the old skill engine for all.
	var legacy = spawn("rabbit")
	app.units[legacy].erase("animal_profile")
	spawn("fox")
	app._refresh_unit_skill_state(0.01)
	check(app.units[legacy].attack == 2, "legacy-first ordering cannot erase fox aura")
	reset_units()
	app.battle_mode = app.BATTLE_MODE_MULTIPLAYER
	spawn("fox", 2)
	for team in [1, 2, 3, 4, 5, 6]:
		var i = spawn("rabbit", team)
		check(app.units[i].attack == (2 if team <= 3 else 1), "3v3 alliance aura team %d" % team)
	spawn("fox", 3)
	app.animal_skills.refresh_auras()
	check(app.units[1].attack == 2, "different allied slots do not stack fox aura")
	app.multiplayer_free_for_all = true
	app.animal_skills.refresh_auras()
	check(app.units[1].attack == 1, "FFA does not share another player's aura")
	for card in app.cards:
		if app._card_kind(card) != app.CARD_KIND_ANIMAL: continue
		reset_units()
		var early = spawn(card.id)
		spawn("fox")
		var late = spawn(card.id, 1, true)
		for i in [early, late]:
			check(app.units[i].attack == maxf(0, app.units[i].base_attack + app.units[i].get("attack_bonus", 0) + 1), card.id + " receives attack aura")
			check(app.units[i].max_hp == app.units[i].base_max_hp + app.units[i].get("max_hp_bonus", 0) + 1, card.id + " receives hp aura")

func target(i: int) -> Dictionary:
	return {"kind": "unit", "index": i, "unit_id": int(app.units[i].id), "pos": app.units[i].pos}

func projectile_contract() -> void:
	for id in ["parrot", "sparrow", "eagle", "golden_eagle"]:
		reset_units()
		var source = spawn(id)
		app.units[source].pos = Vector2.ZERO
		var victim = spawn("elephant", app.ENEMY)
		app.units[victim].pos = Vector2(5, 0)
		var hp = app.units[victim].hp
		app.effects.clear()
		app._unit_attack_target(source, target(victim), 5)
		check(app.units[source].is_ranged, id + " uses ranged attacks")
		check(not app.effects.filter(func(e): return e.kind == "combat_projectile").is_empty(), id + " visible from launch")
		app.animal_skills.update_projectiles(0.05)
		check(app.units[victim].hp < hp, id + " damages on real projectile impact")
		app._update_effects(0.20)
		check(not app.effects.filter(func(e): return e.kind == "combat_projectile").is_empty(), id + " terminal segment survives snapshot interval")
		for n in range(100):
			app.animal_skills.update_projectiles(1.0 / 30)
			app._update_effects(1.0 / 30)
		check(app.effects.filter(func(e): return e.kind == "combat_projectile").is_empty(), id + " no persistent projectile leak")
	check(is_equal_approx(float(app._card_by_id("parrot").base_attack_range), 1.5), "producer-approved parrot range")

func tap(point: Vector2) -> void:
	app._handle_tap(app.canvas_offset + point * app.canvas_scale)

func result_contract() -> void:
	reset_units()
	app.screen = app.SCREEN_BATTLE
	app.wallet_gold = 120
	app._finish_battle("胜利", false)
	var wallet = app.wallet_gold
	check(app.result_ack_pending, "result awaits explicit close")
	var reward_area = app._result_reward_rect()
	check(app._result_other_players_rect().end.y + 16 <= reward_area.position.y, "reward area is separate and below player list")
	check(reward_area.end.y + 16 <= app._result_return_rect().position.y, "reward area is separate and above close")
	app.result_ack_delay = 0
	tap(reward_area.get_center())
	check(app.result_ack_pending and app.wallet_gold == wallet, "reward area tap neither closes nor grants again")
	app.result_ack_delay = 0.35
	tap(app._result_return_rect().get_center())
	check(app.screen == app.SCREEN_BATTLE, "finishing tap cannot accidentally dismiss reward")
	for n in range(600): app._update_effects(0.1)
	check(app.result_ack_pending and app.screen == app.SCREEN_BATTLE, "reward persists after 60 seconds")
	app.online_match_id = "terminal-test"
	app.battle_mode = app.BATTLE_MODE_MULTIPLAYER
	app._apply_online_battle_snapshot({"match_id": "terminal-test", "game_over": false})
	check(app.game_over and app.result_ack_pending, "late active snapshot cannot erase terminal reward")
	app._on_online_server_disconnected()
	check(app.screen == app.SCREEN_BATTLE and app.result_ack_pending, "disconnect keeps reward visible")
	app._on_online_room_left()
	check(app.screen == app.SCREEN_BATTLE and app.result_ack_pending, "room-left keeps reward visible")
	tap(Vector2(10, 10))
	check(app.result_ack_pending, "outside tap does not close")
	app.result_ack_delay = 0
	tap(app._result_return_rect().get_center())
	check(not app.result_ack_pending and app.screen != app.SCREEN_BATTLE, "explicit close returns normally")
	check(app.wallet_gold == wallet, "dismissal does not grant twice")

func save_capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT + name + ".png")

func capture_states() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	app._start_match("1v1_crossroads")
	app._layout(viewport.size)
	app.units.clear()
	app.effects.clear()
	var tower_cards = app.cards.filter(func(c): return app._card_kind(c) == app.CARD_KIND_DEFENSE)
	var keys = app.tiles.keys()
	keys.sort_custom(func(a, b): return app._world_to_canvas(app._hex_center(a)).y < app._world_to_canvas(app._hex_center(b)).y)
	var visible = keys.filter(func(k): return Rect2(90, 180, 540, 750).has_point(app._world_to_canvas(app._hex_center(k))))
	for key in keys:
		app.tiles[key].building = ""
		app.tiles[key].hp = 0
	for i in range(mini(tower_cards.size(), visible.size())):
		var tile = app.tiles[visible[i]]
		tile.building = "tower"
		tile.site_card = tower_cards[i].id
		tile.team = app.PLAYER
		tile.hp = 10
		tile.max_hp = 10
	var prior = 0.0
	for rarity in ["common", "rare", "epic", "legendary"]:
		var rect = app._tower_art_rect(Vector2.ZERO, rarity)
		check(rect.size.x > prior, "tower rarity grows monotonically")
		prior = rect.size.x
	check(app._tower_art_rect(Vector2.ZERO, "rare").size.x < 84, "blue tower smaller than old fixed sprite")
	await save_capture("tower-sizes-720")
	app._start_match("1v1_crossroads")
	base_key = app._battle_base_key(app.PLAYER)
	reset_units()
	var s = spawn("parrot")
	var e = spawn("elephant", app.ENEMY)
	app.units[s].pos = app._canvas_to_world(Vector2(260, 620))
	app.units[e].pos = app._canvas_to_world(Vector2(360, 620))
	app._unit_attack_target(s, target(e), 100)
	app.animal_skills.update_projectiles(0.08)
	app.toast_timer = 0
	await save_capture("projectile-720")
	app._finish_battle("胜利", false)
	app.result_ack_delay = 0
	await save_capture("victory-720")
	viewport.size = Vector2i(360, 640)
	app._layout(viewport.size)
	await save_capture("victory-360")
	viewport.size = Vector2i(720, 1280)
	app._layout(viewport.size)
	# Six-player state uses the real settlement builder and scroll path.
	app._start_multiplayer_match("3v3_crossroads", 3)
	app._finish_multiplayer_battle("loss", false)
	app.result_ack_delay = 0
	app.result_players_scroll = 0
	await save_capture("team-loss-top-720")
	var reward_before = app._result_reward_rect()
	var drag = InputEventScreenDrag.new()
	drag.position = app.canvas_offset + reward_before.get_center() * app.canvas_scale
	drag.relative = Vector2(0, -100) * app.canvas_scale
	check(not app._handle_result_scroll_input(drag), "reward drag is outside scroll hitbox")
	check(app.result_players_scroll == 0 and app.result_ack_pending, "reward drag neither scrolls list nor closes result")
	drag.position = app.canvas_offset + app._result_other_players_rect().get_center() * app.canvas_scale
	check(app._handle_result_scroll_input(drag) and app.result_players_scroll > 0, "touch drag still scrolls player list")
	app._scroll_result_players(99999)
	check(app.result_players_scroll == app._result_players_max_scroll(), "six-player list scroll reaches final player")
	var last_bottom = app._result_other_players_rect().position.y + 4 * (app.RESULT_PLAYER_ROW_HEIGHT + app.RESULT_PLAYER_ROW_GAP) - app.result_players_scroll + app.RESULT_PLAYER_ROW_HEIGHT
	check(is_equal_approx(last_bottom, app._result_other_players_rect().end.y), "last player row is fully in list at bottom")
	check(app._result_reward_rect() == reward_before, "reward panel stays fixed while player list scrolls")
	await save_capture("team-loss-bottom-720")
	app._start_multiplayer_match("3v3_crossroads", 3, true)
	app._finish_multiplayer_free_for_all(1, false)
	app.result_ack_delay = 0
	await save_capture("ffa-720")
	app._start_match("1v1_crossroads")
	app._finish_battle("胜利", false)
	app.result_ack_delay = 0
	app.last_battle_reward_gold = 99999
	app.last_battle_reward_tickets = 9999
	await save_capture("reward-large-values-720")
