extends Node

const MainApp = preload("res://scripts/app/main.gd")
const Rules = preload("res://scripts/app/systems/animal_skill_rules.gd")
const CardRules = preload("res://scripts/app/systems/card_rules.gd")
const CELL = sqrt(3.0) * 43

class IsolatedApp extends MainApp:
	func _auto_login_saved_account_on_startup() -> void: pass
	func _setup_online_room() -> void: online_room_service = OnlineRoom

var app: IsolatedApp
var checks = 0
var failures = 0
var base_key: Vector2i

func _ready() -> void:
	seed(8421)
	GameAudio.sfx_enabled = false
	app = IsolatedApp.new()
	add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	app.battle_mode = "classic"
	app.screen = "battle"
	app.card_levels.clear()
	app.enemy_card_levels.clear()
	app._reset_battle()
	base_key = app._battle_base_key(app.PLAYER)
	data_contract()
	event_contract()
	remaining_events_contract()
	aura_contract()
	attack_contract()
	projectile_contract()
	movement_contract()
	benchmark()
	print("Animal table V3 checks=", checks, " failures=", failures)
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func eq(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.0001, "%s actual=%s expected=%s" % [label, actual, expected])

func reset() -> void:
	app.units.clear()
	app.effects.clear()
	app.unit_index_cache.clear()
	app.animal_skills.shots.clear()
	app.game_over = false
	app.gold = 100
	app.enemy_gold = 100

func spawn(id: String, team: int = 0, pos: Vector2 = Vector2(10000, 10000)) -> int:
	var index = app.units.size()
	app._spawn_unit(app.PLAYER if team == 0 else app.ENEMY, base_key, id, true)
	app.units[index].pos = pos
	return index

func dummy(team: int, pos: Vector2, hp: float = 100) -> int:
	var i = spawn("rabbit", team, pos)
	app.units[i].animal_profile = {}
	app.units[i].hp = hp
	app.units[i].max_hp = hp
	app.units[i].base_max_hp = hp
	return i

func target(i: int) -> Dictionary:
	return {"kind": "unit", "index": i, "pos": Vector2(app.units[i].pos), "unit_id": int(app.units[i].id)}

func data_contract() -> void:
	var animals = 0
	for card in app.cards:
		var id = String(card.id)
		if CardRules.is_animal_card(card):
			animals += 1
			check(not Rules.compile_text(String(card.skill_text)).has("unsupported"), "recognized " + id)
			check(String(card.skill_id) == "" and String(card.skill_effect) == "", "obsolete machine effect removed " + id)
		for level in range(1, 11):
			var stats = CardRules.card_stats(card, {id: level})
			eq(stats.attack, floorf(float(card.base_attack) + (level - 1) * float(card.attack_lv) + 0.000001), id + " attack growth")
			eq(stats.max_hp, floorf(float(card.base_max_hp) + (level - 1) * float(card.max_hp_lv) + 0.000001), id + " health growth")
			eq(stats.move_speed, card.base_move_speed, id + " final speed")
			eq(stats.attack_range, card.base_attack_range, id + " final range")
			eq(stats.summon_interval_sec, card.base_summon_interval_sec, id + " unchanged interval")
	check(animals == 60, "all 60 animals classified, including beaver")
	for id in ["horse", "turtle", "swan", "falcon", "crocodile", "defense_watch_tower"]:
		var card = app._card_by_id(id)
		var stats = app._card_stats_with_levels(card, {})
		eq(stats.attack, card.base_attack, "no static attack doubled " + id)
		eq(stats.move_speed, float(card.base_move_speed) * CELL * 0.5, "half-cell/sec baseline " + id)
		if float(card.base_attack_range) > 0: eq(stats.attack_range, float(card.base_attack_range) * CELL, "range cell conversion " + id)
	var m = app._card_by_id("mouse")
	eq(CardRules.card_stats(m, {"mouse": 5}).attack, 1, ".8 growth not rounded up")
	eq(CardRules.card_stats(m, {"mouse": 6}).attack, 2, "five .2 increments accumulate")
	var goat = app._card_by_id("goat")
	eq(CardRules.card_stats(goat, {"goat": 3}).max_hp_exact, 8.5, "fraction retained")

func event_contract() -> void:
	for id in ["mouse", "ant", "duck", "wolf"]:
		reset()
		app._spawn_unit(app.PLAYER, base_key, id)
		check(app.units.size() == 2, "one extra birth " + id)
	reset()
	var dog = spawn("dog")
	var before = float(app.units[dog].attack)
	spawn("rabbit")
	eq(app.units[dog].attack, before, "ordinary allied birth does not buff dog")
	app._spawn_unit(app.PLAYER, base_key, "mouse")
	eq(app.units[dog].attack, before + 1, "dog observes successful extra birth only once")
	spawn("rabbit", 1)
	eq(app.units[dog].attack, before + 1, "enemy birth excluded")
	reset()
	for n in range(3): dummy(0, Vector2(n * 100, 0))
	spawn("sheep")
	var buffed = 0
	for i in range(3):
		if float(app.units[i].max_hp) == 103: buffed += 1
	check(buffed == 2, "sheep buffs two distinct friends")
	reset()
	var enemy = dummy(1, Vector2.ZERO)
	app.units[enemy].attack = 20
	app.units[enemy].base_attack = 20
	spawn("dolphin")
	eq(app.units[enemy].hp, 94, "dolphin strongest enemy damage")
	for id in ["rabbit", "pigeon", "penguin"]:
		reset()
		var i = spawn(id)
		var hp = float(app.units[i].hp)
		app._apply_unit_capture_skill(i, base_key)
		if id == "rabbit": eq(app.units[i].hp, hp + 1, "rabbit capture")
		elif id == "pigeon": check(app.gold >= 101 and app.gold <= 102, "pigeon gold 1-2")
		else:
			check(app.gold >= 101 and app.gold <= 105, "penguin gold 1-5")
			eq(app.units[i].hp, hp + 3, "penguin capture hp")
	reset()
	var squirrel = spawn("squirrel")
	app.animal_skills.tick(7.99)
	eq(app.gold, 100, "no early payout")
	app.animal_skills.tick(0.01)
	check(app.gold >= 101 and app.gold <= 105, "8 second payout")
	var earned = app.gold
	app.animal_skills.tick(24)
	eq(app.gold, earned, "squirrel one-time payout")
	reset()
	var camel = spawn("camel")
	app.animal_skills.tick(24)
	eq(app.units[camel].attack, 6, "camel 3 periodic attack gains")
	eq(app.units[camel].max_hp, 11, "camel 3 periodic hp gains")
	reset()
	var tadpole = spawn("tadpole")
	var stable_id = app.units[tadpole].id
	var stable_pos = app.units[tadpole].pos
	app.animal_skills.tick(8)
	check(app.units[tadpole].card == "frog", "tadpole becomes frog")
	eq(app.units[tadpole].attack, 2, "frog has extra attack")
	check(app.units[tadpole].id == stable_id and app.units[tadpole].pos == stable_pos and app.units[tadpole].is_ranged, "transform preserves identity/position and gains ranged")
	reset()
	var cat = spawn("cat")
	var chicken = spawn("chicken", 1)
	app._damage_unit(chicken, 100, cat, app.PLAYER)
	eq(app.units[cat].max_hp, 8, "cat kill event")
	check(app.enemy_gold >= 101 and app.enemy_gold <= 102, "chicken death pays owner")
	reset()
	var killer = spawn("tiger")
	var hamster = spawn("hamster", 1)
	app._damage_unit(hamster, 100, killer, app.PLAYER)
	eq(app.units[killer].attack, 6, "hamster and tiger gain attack once")
	eq(app.units[killer].max_hp, 30, "hamster and tiger gain hp once")
	app._damage_unit(hamster, 100, killer, app.PLAYER)
	eq(app.units[killer].max_hp, 30, "dead target cannot re-award")
	reset()
	var lynx = spawn("lynx")
	var prey = spawn("rabbit", 1)
	app.enemy_gold = 3
	app._damage_unit(prey, 100, lynx, app.PLAYER)
	eq(app.gold, 103, "plunder capped at victim money")
	eq(app.enemy_gold, 0, "plunder removes enemy gold")
	reset()
	var python = spawn("python")
	prey = dummy(1, Vector2.ZERO, 17)
	app._damage_unit(prey, 100, python, app.PLAYER)
	eq(app.units[python].max_hp, 41, "python exact target max hp")

func aura_contract() -> void:
	reset()
	var ally = spawn("rabbit")
	var fox = spawn("fox")
	var fox2 = spawn("fox")
	eq(app.units[ally].attack, 2, "fox map-wide aura")
	eq(app.units[ally].max_hp, 4, "fox hp nonstacking")
	app._damage_unit(fox, 100, -1, app.ENEMY)
	eq(app.units[ally].attack, 2, "one duplicate source survives")
	app._damage_unit(fox2, 100, -1, app.ENEMY)
	eq(app.units[ally].attack, 1, "last source removal")
	eq(app.units[ally].max_hp, 3, "aura maximum removed")
	app.units[ally].hp = 0.5
	app.animal_skills.tick(0.1)
	eq(app.units[ally].hp, 0.5, "refresh must not heal fractional damage")
	spawn("monkey")
	spawn("monkey")
	eq(app.animal_skills.crit_chance(app.units[ally], {}), 0.2, "monkey duplicates not .4")
	spawn("deer")
	app.animal_skills.on_jump_start(ally)
	eq(app.units[ally].max_hp, 5, "first jump deer bonus")
	app.animal_skills.on_jump_start(ally)
	eq(app.units[ally].max_hp, 5, "deer only first jump")

func remaining_events_contract() -> void:
	reset()
	var keys = []
	for key in app.tiles:
		if app._are_allies(int(app.tiles[key].get("team", 0)), app.PLAYER) and String(app.tiles[key].get("building", "")) != "": keys.append(key)
	check(not keys.is_empty(), "real buildings for spawn buffs")
	var totals_before = 0.0
	for key in keys: totals_before += float(app.tiles[key].max_hp)
	spawn("beaver")
	var totals_after = 0.0
	for key in keys: totals_after += float(app.tiles[key].max_hp)
	eq(totals_after, totals_before + 5, "beaver buffs one building max hp by five")
	# Create a second owned building, then verify otter chooses distinct buildings.
	for key in app.tiles:
		if not keys.has(key):
			app.tiles[key].building = "tower"
			app.tiles[key].team = app.PLAYER
			app.tiles[key].hp = 20
			app.tiles[key].max_hp = 20
			keys.append(key)
			break
	var bonus_before = 0.0
	for key in keys: bonus_before += float(app.tiles[key].get("animal_attack_bonus", 0))
	spawn("otter")
	var bonus_after = 0.0
	for key in keys: bonus_after += float(app.tiles[key].get("animal_attack_bonus", 0))
	eq(bonus_after, bonus_before + 2, "otter adds total two building attack")
	reset()
	var strong = spawn("lion")
	var weak = spawn("rabbit")
	spawn("giraffe")
	app.animal_skills.tick(8)
	eq(app.units[strong].max_hp, 28, "giraffe highest attack ally +10 hp")
	eq(app.units[weak].max_hp, 3, "giraffe leaves weaker ally unchanged")
	reset()
	spawn("blue_whale")
	var low = dummy(1, Vector2.ZERO, 12)
	var high = dummy(1, Vector2.ZERO, 20)
	app.animal_skills.tick(8)
	eq(app.units[low].hp, 2, "whale lowest current hp enemy -10")
	eq(app.units[high].hp, 20, "whale only one target")
	reset()
	var seal = spawn("seal")
	var ranged = spawn("eagle", 1)
	var melee = spawn("lion", 1)
	app._damage_unit(seal, 100, melee, app.ENEMY)
	eq(app.units[ranged].hp, 2, "seal death targets enemy ranged -10")
	eq(app.units[melee].hp, 18, "seal excludes melee")
	reset()
	var orca = spawn("orca")
	var first = dummy(1, Vector2.ZERO, 1)
	for n in range(4): dummy(1, Vector2.ZERO)
	app._damage_unit(first, 100, orca, app.PLAYER)
	var hit_count = 0
	for j in range(2, 6):
		if float(app.units[j].hp) == 95: hit_count += 1
	check(hit_count == 3, "orca kill hits exactly three distinct random enemies")
	reset()
	var komodo = spawn("komodo_dragon")
	var victim = dummy(1, Vector2(10010, 10000))
	app._unit_attack_target(komodo, target(victim), 10)
	eq(app.units[victim].hp, 48.5, "komodo halves remaining health after direct hit")
	reset()
	var lion = spawn("lion")
	victim = dummy(1, Vector2(10010, 10000))
	app._unit_attack_target(lion, target(victim), 10)
	eq(app.units[lion].max_hp, 20, "lion per-attack health gain")
	reset()
	var gorilla = spawn("gorilla", 0, app._hex_center(base_key))
	eq(app.animal_skills.crit_chance(app.units[gorilla], app.units[gorilla].animal_profile), 0.5, "gorilla home territory critical")
	var silverback = spawn("silverback", 1, app._hex_center(base_key))
	eq(app.animal_skills.crit_chance(app.units[silverback], app.units[silverback].animal_profile), 0.8, "silverback enemy territory critical")
	# Force a guaranteed roll only in the fixture, check the post-critical event.
	app.units[gorilla].animal_profile.home_crit = 1.0
	victim = dummy(1, Vector2(app.units[gorilla].pos) + Vector2(10, 0))
	var attack_before = float(app.units[gorilla].attack)
	app._unit_attack_target(gorilla, target(victim), 10)
	eq(app.units[gorilla].attack, attack_before + 1, "gorilla critical raises attack once")

func attack_contract() -> void:
	reset()
	var shark = spawn("shark", 0, Vector2.ZERO)
	var victim = dummy(1, Vector2(20, 0))
	app.units[victim].hp = 99
	app._unit_attack_target(shark, target(victim), 20)
	eq(app.units[victim].hp, 87, "wounded guaranteed double critical")
	check(app.effects.any(func(e): return e.get("kind") == "combat_text" and bool(e.get("critical", false))), "red critical feedback event")
	spawn("monkey")
	app._unit_attack_target(shark, target(victim), 20)
	eq(app.units[victim].hp, 69, "monkey triple critical")
	reset()
	var bear = spawn("bear", 0, Vector2.ZERO)
	victim = dummy(1, Vector2(10, 0))
	var close = dummy(1, Vector2(CELL + 9, 0))
	var far = dummy(1, Vector2(CELL + 11, 0))
	var friend = dummy(0, Vector2(10, 0))
	app._unit_attack_target(bear, target(victim), 10)
	eq(app.units[victim].hp, 97, "splash primary damage")
	eq(app.units[close].hp, 97, "splash equal nearby damage")
	eq(app.units[far].hp, 100, "splash radius boundary")
	eq(app.units[friend].hp, 100, "splash never hits friend")
	for id in ["parrot", "peacock"]:
		reset()
		var attacker = spawn(id, 0, Vector2.ZERO)
		for n in range(4): dummy(1, Vector2(10 + n * 5, 0))
		app._unit_attack_target(attacker, target(1), 10)
		if bool(app.units[attacker].is_ranged):
			app.animal_skills.update_projectiles(0.1)
		var hits = 0
		for j in range(1, 5):
			if float(app.units[j].hp) < 100: hits += 1
		check(hits == (2 if id == "parrot" else 3), "distinct extra targets " + id)
	reset()
	var crocodile = spawn("crocodile")
	victim = dummy(1, Vector2(10010, 10000))
	for n in range(3): app._unit_attack_target(crocodile, target(victim), 10)
	eq(app.units[victim].hp, 91, "crocodile starts final six, then three, zero")
	app.animal_skills.refresh_auras()
	eq(app.units[crocodile].attack, 0, "decay cannot go below zero")
	reset()
	var hedgehog = spawn("hedgehog")
	var ranged = spawn("eagle", 1)
	app._damage_unit(hedgehog, 1, ranged, app.ENEMY)
	eq(app.units[ranged].hp, 11, "thorns also reflects ranged damage")
	reset()
	var guard = spawn("pig", 0, Vector2.ZERO)
	var protected = dummy(0, Vector2(CELL - 1, 0))
	app._damage_unit(protected, 3, -1, app.ENEMY)
	eq(app.units[guard].hp, 15, "pig receives guarded damage")
	eq(app.units[protected].hp, 100, "protected ally unchanged")
	app.units[protected].pos = Vector2(CELL + 1, 0)
	app._damage_unit(protected, 3, -1, app.ENEMY)
	eq(app.units[protected].hp, 97, "guard one-cell boundary")
	reset()
	var hippo = spawn("hippo")
	victim = spawn("rabbit", 1)
	app._damage_unit(hippo, 3, victim, app.ENEMY)
	eq(app.units[hippo].hp, 32.5, "hippo damage halved based on source hp")
	reset()
	var leopard = spawn("leopard")
	# deterministic 100% roll hook proves the attack/skill damage boundary.
	app.units[leopard].animal_profile.dodge = 1.0
	app._damage_unit(leopard, 3, -1, app.ENEMY, true, Vector2i(-99, -99), true, null, false, true)
	eq(app.units[leopard].hp, 18, "tower attack can be dodged")
	app._damage_unit(leopard, 3, -1, app.ENEMY)
	eq(app.units[leopard].hp, 15, "skill damage not dodged")
	check(float(app.units[leopard].dodge_time) > 0, "dodge motion feedback")

func projectile_contract() -> void:
	reset()
	var eagle = spawn("eagle", 0, Vector2(10000, 10000))
	for n in range(4): dummy(1, Vector2(10030 + n * 90, 10000))
	app._unit_attack_target(eagle, target(1), 30)
	eq(app.units[1].hp, 100, "projectile is not instant damage")
	for n in range(200): app.animal_skills.update_projectiles(0.016)
	for j in range(1, 4): eq(app.units[j].hp, 95, "two bounces hit three distinct enemies")
	eq(app.units[4].hp, 100, "bounce count exhausted")
	reset()
	var piercer = spawn("golden_eagle", 0, Vector2(10000, 10000))
	var positions = [Vector2(10030, 10000), Vector2(10090, 10000), Vector2(10180, 10000), Vector2(10090, 10050)]
	for pos in positions: dummy(1, pos)
	app._unit_attack_target(piercer, target(1), 30)
	for n in range(60): app.animal_skills.update_projectiles(0.016)
	eq(app.units[1].hp, 94, "pierce first target")
	eq(app.units[2].hp, 94, "pierce original direction second target")
	eq(app.units[3].hp, 100, "pierce ends at original attack range")
	eq(app.units[4].hp, 100, "pierce does not steer sideways")
	reset()
	eagle = spawn("eagle", 0, Vector2(10000, 10000))
	var irrelevant = dummy(1, Vector2(11000, 10000))
	var intended = dummy(1, Vector2(10050, 10000))
	app._unit_attack_target(eagle, target(intended), 50)
	app.units.remove_at(irrelevant)
	for n in range(30): app.animal_skills.update_projectiles(0.016)
	eq(app.units[1].hp, 95, "stable projectile target survives index compaction")

func movement_contract() -> void:
	reset()
	var key = base_key
	for candidate in app.tiles:
		if app.tiles.has(candidate + Vector2i(4, 0)) and app.tiles.has(candidate + Vector2i(0, 3)):
			key = candidate
			break
	var walker = spawn("rabbit", 0, app._hex_center(key))
	app.units[walker].tile = key
	var origin = Vector2(app.units[walker].pos)
	var next_key = key + Vector2i(1, 0)
	var destination = app._hex_center(next_key)
	var moved = app._move_unit_toward_target(app.units[walker].duplicate(true), {"tile": next_key}, destination, 1.0)
	eq(origin.distance_to(moved.pos), CELL * 0.5, "configured speed one walks half a cell in one second")
	moved = app._move_unit_toward_target(moved, {"tile": next_key}, destination, 1.0)
	eq(Vector2(moved.pos).distance_to(destination), 0, "configured speed one walks one cell in two seconds")
	var flying = app.units[walker].duplicate(true)
	flying.flying = true
	moved = app._move_unit_toward_target(flying, {"tile": next_key}, destination, 1.0)
	eq(origin.distance_to(moved.pos), CELL * 0.5, "flying uses the same half-cell baseline")
	reset()
	var i = spawn("kangaroo", 0, app._hex_center(key))
	app.units[i].tile = key
	check(app.animal_skills.begin_jump(i, app._hex_center(key + Vector2i(4, 0))), "jump starts")
	check(app.units[i].has("motion_trip"), "jump owns world trajectory")
	if app.units[i].has("motion_trip"):
		var trip = app.units[i].motion_trip.duplicate()
		eq(Vector2(trip.start).distance_to(trip.finish), CELL * 2, "jump skips exactly one cell")
		eq(float(trip.duration), 4.0, "two-cell jump at configured speed one uses four seconds")
		app.animal_skills.tick_motion(i, float(trip.duration) * 0.5)
		check(float(app.units[i].jump_height) > 20, "visible jump arc at midpoint")
		app.animal_skills.tick_motion(i, float(trip.duration) * 0.5)
		eq(Vector2(app.units[i].pos).distance_to(trip.finish), 0, "jump lands at exact center")
		eq(app.units[i].max_hp, 5, "kangaroo landing gains hp")
	reset()
	i = spawn("rhino", 0, app._hex_center(key))
	app.units[i].tile = key
	var foe = dummy(1, Vector2(app.units[i].pos) + Vector2(CELL, 0))
	app.units[i].range = CELL * 2
	app.units[i] = app._lock_unit_attack_target(app.units[i], target(foe))
	app.animal_skills.tick_motion(i, 3.99)
	check(not app.units[i].has("charge_windup"), "charge waits four seconds")
	app.animal_skills.tick_motion(i, 0.02)
	check(app.units[i].has("charge_windup"), "charge starts two-second windup")
	app.animal_skills.tick_motion(i, 2.0)
	check(app.units[i].has("motion_trip"), "charge trajectory starts after windup")
	if app.units[i].has("motion_trip"):
		var trip = app.units[i].motion_trip
		eq(Vector2(trip.start).distance_to(trip.finish), CELL * 4, "explicit charge distance remains four cells")
		eq(float(trip.duration), 0.35, "explicit charge travel time unchanged by movement baseline")
		for n in range(35): app.animal_skills.tick_motion(i, 0.01)
		eq(app.units[foe].hp, 95, "swept dash hits once, not each frame")

func benchmark() -> void:
	reset()
	var roster = ["fox", "monkey", "deer", "camel", "giraffe", "blue_whale", "eagle", "rhino", "tiger", "goat", "polar_bear", "mammoth"]
	for n in range(72):
		var key = app.tiles.keys()[n % app.tiles.size()]
		var i = spawn(roster[n % roster.size()], n % 2, app._hex_center(key))
		app.units[i].hp = 10000
		app.units[i].max_hp = 10000
		app.units[i].base_max_hp = 10000
	var samples = []
	for n in range(240):
		var start = Time.get_ticks_usec()
		app._update_units(1.0 / 60)
		app._update_effects(1.0 / 60)
		if n >= 60: samples.append(Time.get_ticks_usec() - start)
	samples.sort()
	var p95 = samples[int(samples.size() * 0.95)]
	print("V3 72-unit mixed-skill CPU p95_us=", p95)
	check(p95 < 8000, "mixed-skill CPU P95 budget 8ms")
