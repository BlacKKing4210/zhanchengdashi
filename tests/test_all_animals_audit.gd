extends Node

# Offline screening only. Uses real spawn, movement, targeting, skill and damage
# paths; no fake duel damage formula, account writes or online service calls.
const Base = preload("res://tests/test_online_rewards_release.gd")
const CardRules = preload("res://scripts/app/systems/card_rules.gd")
const OUT = "res://temp/qa/all-animals-audit-20260906/"
const DT = 1.0 / 30.0
var app
var checks = 0
var failures = 0
var roster: Array = []
var rows: Array = []
var template: Dictionary = {}
var base_keys: Array = [Vector2i(-5, 0), Vector2i(5, 0)]

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	GameAudio.sfx_enabled = false
	app = Base.TestApp.new()
	add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	app._start_match("1v1_crossroads")
	for card in app.cards:
		if CardRules.is_animal_card(card): roster.append(card)
	check(roster.size() == 60, "all sixty animals present")
	var empty = app.tiles.values()[0].duplicate(true)
	for q in range(-6, 7):
		for r in range(-3, 4):
			var t = empty.duplicate(true)
			t.merge({"building": "", "site": "", "site_card": "", "team": app.PLAYER if q < 0 else app.ENEMY, "territory_team": app.PLAYER if q < 0 else app.ENEMY, "occupier": app.NEUTRAL, "hp": 0.0, "max_hp": 0.0, "locked": false}, true)
			t.erase("soft_owner")
			template[Vector2i(q, r)] = t
	for k in range(2):
		var t = template[base_keys[k]]
		t.merge({"building": "base", "hp": 100000.0, "max_hp": 100000.0}, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for card in roster:
		for level in [1, 5, 10]:
			reset_arena(card.id, card.id, level, 991)
			app._spawn_unit(app.PLAYER, Vector2i(-2, 0), card.id)
			var u = app.units[0]
			check(is_equal_approx(u.base_attack, floorf(card.base_attack + (level - 1) * card.attack_lv + 0.000001)), card.id + " attack Lv" + str(level))
			check(is_equal_approx(u.base_max_hp, floorf(card.base_max_hp + (level - 1) * card.max_hp_lv + 0.000001)), card.id + " HP Lv" + str(level))
			check(is_equal_approx(u.base_speed, card.base_move_speed * sqrt(3.0) * app.HEX_SIZE * 0.5), card.id + " final speed")
			check(not u.animal_profile.has("unsupported"), card.id + " implemented")
	squad_contract()
	var quick = "--audit-quick" in OS.get_cmdline_user_args()
	for level in ([1] if quick else [1, 5]):
		for scenario_seed in ([211] if quick else [211, 733]):
			for i in range(roster.size()):
				for j in range(i + 1, roster.size()):
					if roster[i].rarity != roster[j].rarity: continue
					for mirror in range(2):
						rows.append(duel(roster[i].id, roster[j].id, level, scenario_seed, mirror))
				if i % 5 == 0:
					print("AUDIT_PROGRESS level=", level, " seed=", scenario_seed, " animal=", i + 1, "/60 duels=", rows.size())
					await get_tree().process_frame
	var file = FileAccess.open(OUT + ("duels-quick.json" if quick else "duels.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "dt": DT, "limit_sec": 40, "config_sha256": FileAccess.get_sha256("res://runtime/config/cards.json"), "rows": rows}, "\t"))
	file.close()
	print("ALL_ANIMALS_AUDIT animals=", roster.size(), " duels=", rows.size(), " checks=", checks, " failures=", failures)
	app.units.clear()
	app.effects.clear()
	app.animal_skills.shots.clear()
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func reset_arena(left: String, right: String, level: int, scenario_seed: int) -> void:
	seed(scenario_seed)
	app.units.clear()
	app.unit_index_cache.clear()
	app.animal_skills.shots.clear()
	app.effects.clear()
	app.tiles = template.duplicate(true)
	app._rebuild_ground_navigation()
	app.classic_base_keys = {app.PLAYER: base_keys[0], app.ENEMY: base_keys[1]}
	app.card_levels = {left: level, right: level}
	app.enemy_card_levels = app.card_levels.duplicate()
	app.next_unit_id = 1
	app.game_over = false
	app.gold = 100
	app.enemy_gold = 100
	app._refresh_combat_building_keys()

func squad_contract() -> void:
	# Every animal runs in a mixed party too: birth extras, guards and global
	# supports cannot be judged solely from duels. No numeric winner claim here.
	for card in roster:
		reset_arena(card.id, "rabbit", 1, 447)
		for id in ["mouse", "goat", "frog", "dog"]:
			app._spawn_unit(app.PLAYER, Vector2i(-2, 0), id)
		app._spawn_unit(app.PLAYER, Vector2i(-2, 0), card.id)
		for id in ["ant", "frog", "rabbit", "cat", "hamster"]:
			app._spawn_unit(app.ENEMY, Vector2i(2, 0), id)
		for frame in range(900):
			app._update_units(DT)
			app._update_effects(DT)
		check(app.units.all(func(u): return is_finite(float(u.attack)) and is_finite(float(u.hp)) and u.attack >= 0 and u.hp <= u.max_hp + 0.00001), card.id + " 30-second mixed squad stable")
	print("ALL_ANIMALS_MIXED_SQUADS 60 scenarios completed")

func duel(a_id: String, b_id: String, level: int, scenario_seed: int, mirror: int) -> Dictionary:
	reset_arena(a_id, b_id, level, scenario_seed)
	var a_team = app.PLAYER if mirror == 0 else app.ENEMY
	var b_team = app.ENEMY if mirror == 0 else app.PLAYER
	var left_key = Vector2i(-2, 0)
	var right_key = Vector2i(2, 0)
	# Mirroring swaps both side and spawn/evaluation order.
	app._spawn_unit(app.PLAYER, left_key, a_id if mirror == 0 else b_id)
	app._spawn_unit(app.ENEMY, right_key, b_id if mirror == 0 else a_id)
	var elapsed = 0.0
	while elapsed < 40.0 and app._multiplayer_alive_unit_count(a_team) > 0 and app._multiplayer_alive_unit_count(b_team) > 0:
		app._update_units(DT)
		app._update_effects(DT)
		elapsed += DT
	var a_count = app._multiplayer_alive_unit_count(a_team)
	var b_count = app._multiplayer_alive_unit_count(b_team)
	var valid = true
	var health = {a_team: 0.0, b_team: 0.0}
	for u in app.units:
		valid = valid and is_finite(float(u.attack)) and is_finite(float(u.hp)) and float(u.attack) >= 0 and float(u.hp) <= float(u.max_hp) + 0.00001
		health[int(u.team)] += float(u.hp)
	check(valid, "%s/%s Lv%d seed%d mirror%d valid runtime stats" % [a_id, b_id, level, scenario_seed, mirror])
	return {"a": a_id, "b": b_id, "level": level, "seed": scenario_seed, "mirror": mirror, "winner": a_id if a_count > 0 and b_count == 0 else (b_id if b_count > 0 and a_count == 0 else "draw"), "seconds": snappedf(elapsed, 0.01), "a_alive": a_count, "b_alive": b_count, "a_hp": health[a_team], "b_hp": health[b_team], "a_gold": app._gold_for_team(a_team) - 100, "b_gold": app._gold_for_team(b_team) - 100}
