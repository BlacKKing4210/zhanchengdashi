extends RefCounted

const Rules = preload("res://scripts/app/systems/animal_skill_rules.gd")
const CELL = 43.0 * sqrt(3.0)
var host: WeakRef
var shots: Array = []
var a:
	get:
		return host.get_ref()

func _init(app) -> void:
	host = weakref(app)

func profile(u: Dictionary) -> Dictionary:
	return u.get("animal_profile", {}) if bool(u.get("skill_triggers_enabled", true)) else {}

func alive(i: int) -> bool:
	return i >= 0 and i < a.units.size() and float(a.units[i].get("hp", 0)) > 0

func candidates(team: int, allied: bool, exclude: int = -1) -> Array:
	var result = []
	for i in range(a.units.size()):
		if i != exclude and alive(i) and a._are_allies(team, int(a.units[i].team)) == allied:
			result.append(i)
	return result

func buff(i: int, attack: float, hp: float) -> void:
	if not alive(i):
		return
	if attack != 0:
		a._add_attack_bonus(i, attack, false)
	if hp != 0:
		a._add_max_hp_bonus(i, hp, true, false)

func on_spawn(i: int) -> void:
	var u = a.units[i]
	var p = profile(u)
	u["age"] = 0.0
	u["next_skill_age"] = 8.0
	u["charge_wait"] = 4.0
	var allies = candidates(int(u.team), true, i)
	for j in allies:
		buff(j, float(profile(a.units[j]).get("ally_spawn_attack", 0)), 0)
	match String(p.get("spawn", "")):
		"ally_hp":
			allies.shuffle()
			for j in allies.slice(0, 2):
				buff(j, 0, 3)
		"building_hp", "building_attack":
			var buildings = []
			for key in a.tiles:
				var t = a.tiles[key]
				if a._are_allies(int(u.team), int(t.get("team", -1))) and String(t.get("building", "")) != "" and float(t.get("hp", 0)) > 0:
					buildings.append(key)
			buildings.shuffle()
			var hp_mode = String(p.spawn) == "building_hp"
			for key in buildings.slice(0, 1 if hp_mode else 2):
				var t = a.tiles[key]
				if hp_mode:
					t["max_hp"] = float(t.max_hp) + 5
					t["hp"] = float(t.hp) + 5
				else:
					t["animal_attack_bonus"] = float(t.get("animal_attack_bonus", 0)) + 1
				a._pulse(a._hex_center(key), Color("81d9a2"))
		"strongest_damage":
			var enemies = candidates(int(u.team), false)
			enemies.sort_custom(func(x, y): return float(a.units[x].attack) > float(a.units[y].attack))
			if not enemies.is_empty():
				skill_damage(enemies[0], 6, i, int(u.team))
	refresh_auras()

func refresh_auras() -> void:
	var sources = {}
	for u in a.units:
		var aura = String(profile(u).get("aura", ""))
		if float(u.get("hp", 0)) > 0 and aura != "":
			# Different allied slots still share one aura from the same species.
			sources["%d:%s" % [int(u.team), String(u.get("card", ""))]] = {"team": int(u.team), "aura": aura}
	for u in a.units:
		if float(u.get("hp", 0)) <= 0:
			continue
		var active = {}
		for source in sources.values():
			if a._are_allies(int(u.team), int(source.team)):
				active[source.aura] = true
		var hp_aura = 1.0 if active.has("stats") else 0.0
		var hp_delta = hp_aura - float(u.get("aura_hp", 0))
		u["aura_hp"] = hp_aura
		u["aura_critical"] = active.has("critical")
		u["aura_jump"] = active.has("jump")
		u["attack"] = maxf(0, float(u.get("base_attack", u.get("attack", 0))) + float(u.get("attack_bonus", 0)) + hp_aura)
		u["max_hp"] = maxf(1, float(u.get("base_max_hp", u.get("max_hp", 1))) + float(u.get("max_hp_bonus", 0)) + hp_aura)
		u["hp"] = minf(float(u.hp) + maxf(0, hp_delta), float(u.max_hp))
		u["speed"] = (float(u.get("base_speed", u.get("speed", 0))) + float(u.get("speed_bonus", 0))) * a._unit_speed_status_multiplier(u)

func tick(delta: float) -> void:
	refresh_auras()
	for i in range(a.units.size()):
		if not alive(i):
			continue
		var u = a.units[i]
		for key in ["stun_timer", "slow_timer", "haste_timer", "dodge_time"]:
			u[key] = maxf(0, float(u.get(key, 0)) - delta)
		u["age"] = float(u.get("age", 0)) + delta
		var p = profile(u)
		if not p.has("interval"):
			continue
		while alive(i) and float(u.age) + 0.000001 >= float(u.get("next_skill_age", 8)):
			u["next_skill_age"] = INF if bool(p.get("once", false)) else float(u.get("next_skill_age", 8)) + 8
			on_interval(i, String(p.interval))
			if String(p.interval) == "transform":
				break
	update_projectiles(delta)

func on_interval(i: int, event: String) -> void:
	var u = a.units[i]
	match event:
		"gold": a._add_gold(int(u.team), randi_range(1, 5), a._unit_gold_feedback_position(u))
		"grow": buff(i, 1, 2)
		"strongest_hp":
			var friends = candidates(int(u.team), true)
			friends.sort_custom(func(x, y): return float(a.units[x].attack) > float(a.units[y].attack))
			if not friends.is_empty(): buff(friends[0], 0, 10)
		"lowest_damage":
			var enemies = candidates(int(u.team), false)
			enemies.sort_custom(func(x, y): return float(a.units[x].hp) < float(a.units[y].hp))
			if not enemies.is_empty(): skill_damage(enemies[0], 10, i, int(u.team))
		"transform":
			var card = a._card_by_id("frog")
			var stats = a._card_stats_for_team(card, int(u.team))
			u["card"] = "frog"
			u["animal_profile"] = Rules.compile_text(String(card.skill_text))
			u["base_attack"] = stats.attack
			u["attack_bonus"] = 1.0
			u["base_max_hp"] = stats.max_hp
			u["max_hp_bonus"] = 0.0
			u["hp"] = stats.max_hp
			u["base_speed"] = stats.move_speed
			u["range"] = stats.attack_range
			u["base_range"] = stats.attack_range
			u["base_card_range"] = card.base_attack_range
			u["is_ranged"] = true
			refresh_auras()
			a._pulse(Vector2(u.pos), Color("91eeaa"))

func on_capture(i: int) -> void:
	if not alive(i): return
	var u = a.units[i]
	var p = profile(u)
	buff(i, 0, float(p.get("capture_hp", 0)))
	if p.has("capture_gold"):
		a._add_gold(int(u.team), randi_range(1, int(p.capture_gold)), a._unit_gold_feedback_position(u))

func on_death(i: int, killer: int, source_team: int) -> void:
	var u = a.units[i]
	var p = profile(u)
	if p.has("death_gold"):
		a._add_gold(int(u.team), randi_range(1, int(p.death_gold)), a._unit_gold_feedback_position(u))
	if p.has("feed_killer") and alive(killer): buff(killer, 1, 1)
	if p.has("death_ranged"):
		var targets = candidates(int(u.team), false).filter(func(j): return bool(a.units[j].get("is_ranged", false)))
		if not targets.is_empty(): skill_damage(targets.pick_random(), float(p.death_ranged), i, int(u.team))
	if alive(killer) and not a._are_allies(int(u.team), source_team):
		on_kill(killer, u)
	refresh_auras()

func on_kill(i: int, dead: Dictionary) -> void:
	var u = a.units[i]
	var p = profile(u)
	buff(i, float(p.get("kill_attack", 0)), float(p.get("kill_hp", 0)))
	if p.has("absorb_hp"): buff(i, 0, float(dead.max_hp))
	if p.has("plunder"):
		var amount = mini(5, maxi(0, a._gold_for_team(int(dead.team))))
		a._spend_team_gold(int(dead.team), amount)
		a._add_gold(int(u.team), amount, a._unit_gold_feedback_position(u))
	if p.has("kill_chain"):
		var targets = candidates(int(u.team), false)
		targets.shuffle()
		for j in targets.slice(0, 3): skill_damage(j, 5, i, int(u.team))

func skill_damage(i: int, damage: float, source: int, team: int, reactive: bool = true) -> void:
	if alive(i): a._damage_unit(i, damage, source, team, reactive)

func incoming(i: int, damage: float, source: int, source_key: Vector2i) -> float:
	var u = a.units[i]
	var p = profile(u)
	var source_hp = 0.0
	if source >= 0 and source < a.units.size(): source_hp = float(a.units[source].hp)
	elif a.tiles.has(source_key): source_hp = float(a.tiles[source_key].get("hp", 0))
	if p.has("higher_hp_guard") and float(u.hp) > source_hp and source_hp > 0: damage *= 0.5
	return maxf(0, damage - float(p.get("reduction", 0)))

func on_damage(i: int, source: int, source_key: Vector2i) -> void:
	var u = a.units[i]
	if not profile(u).has("thorns"): return
	if alive(source): skill_damage(source, 1, i, int(u.team), false)
	elif a.tiles.has(source_key): a._damage_tile(source_key, int(u.team), 1)

func attack(i: int, target: Dictionary) -> void:
	if not alive(i): return
	var u = a.units[i]
	var p = profile(u)
	var targets = [stable_target(target)]
	var others = candidates(int(u.team), false, int(target.get("index", -1)))
	others.sort_custom(func(x, y): return Vector2(a.units[x].pos).distance_squared_to(u.pos) < Vector2(a.units[y].pos).distance_squared_to(u.pos))
	for j in others:
		if targets.size() > int(p.get("extra_targets", 0)): break
		if Vector2(a.units[j].pos).distance_to(u.pos) <= float(u.range): targets.append(unit_target(j))
	a._trigger_unit_motion(i, "attack", Vector2(target.pos) - Vector2(u.pos))
	a._play_world_sfx("ranged_attack" if bool(u.get("is_ranged", false)) else "unit_attack", Vector2(u.pos), int(u.team), -4)
	for t in targets:
		var shot = {"source_id": int(u.id), "team": int(u.team), "damage": float(u.attack), "profile": p.duplicate(), "critical_aura": bool(u.get("aura_critical", false)), "pos": Vector2(u.pos), "origin": Vector2(u.pos), "target": t, "remaining": int(p.get("bounce", 0)), "hit": [], "traveled": 0.0, "range": float(u.range), "life": 10.0}
		shot["direction"] = Vector2(u.pos).direction_to(Vector2(t.pos))
		shot["critical_chance"] = crit_chance(u, p)
		if bool(u.get("is_ranged", false)):
			shots.append(shot)
		else:
			impact(shot, t)
	buff(i, 0, float(p.get("attack_hp", 0)))
	if p.has("attack_decay"):
		# Clamp the effective total; aura refresh must not resurrect decayed attack.
		a._add_attack_bonus(i, -minf(float(u.attack), 3.0), false)
	u["attack_target_chase"] = false

func crit_chance(u: Dictionary, p: Dictionary) -> float:
	var chance = 0.2 if bool(u.get("aura_critical", false)) else 0.0
	var key = a._tile_at_world(Vector2(u.pos))
	if a.tiles.has(key):
		var owner = int(a.tiles[key].get("team", -1))
		if a._are_allies(owner, int(u.team)): chance += float(p.get("home_crit", 0))
		elif owner != a.NEUTRAL: chance += float(p.get("enemy_crit", 0))
	return minf(1, chance)

func stable_target(target: Dictionary) -> Dictionary:
	if String(target.get("kind", "")) == "unit": return unit_target(int(target.get("index", -1)))
	return target.duplicate()

func unit_target(i: int) -> Dictionary:
	if i < 0 or i >= a.units.size(): return {}
	return {"kind": "unit", "unit_id": int(a.units[i].id), "pos": Vector2(a.units[i].pos)}

func target_token(t: Dictionary) -> String:
	return "u%d" % int(t.get("unit_id", -1)) if String(t.get("kind", "")) == "unit" else "b%s" % str(t.get("key", Vector2i.ZERO))

func resolve(t: Dictionary, team: int) -> Dictionary:
	if String(t.get("kind", "")) == "unit":
		var j = a._unit_index_by_id(int(t.get("unit_id", -1)))
		if not alive(j) or a._are_allies(int(a.units[j].team), team): return {}
		return {"kind": "unit", "index": j, "unit_id": int(a.units[j].id), "pos": Vector2(a.units[j].pos)}
	var key = t.get("key", a.MultiplayerRules.INVALID_KEY)
	if not a._is_enemy_building_target_valid(key, team): return {}
	return {"kind": "building", "key": key, "pos": a._hex_center(key)}

func impact(shot: Dictionary, raw: Dictionary) -> void:
	var t = resolve(raw, int(shot.team))
	if t.is_empty(): return
	var token = target_token(t)
	if shot.hit.has(token): return
	shot.hit.append(token)
	var source = a._unit_index_by_id(int(shot.source_id))
	var p = shot.profile
	var critical = randf() < float(shot.get("critical_chance", 0))
	if String(t.kind) == "unit":
		var victim = a.units[int(t.index)]
		if p.has("wounded_crit") and float(victim.hp) < float(victim.max_hp): critical = true
		if randf() < float(profile(victim).get("dodge", 0)):
			victim["dodge_time"] = 0.3
			feedback(Vector2(t.pos), "miss", false)
			return
	var damage = float(shot.damage) * (3.0 if bool(shot.get("critical_aura", false)) else 2.0) if critical else float(shot.damage)
	if String(t.kind) == "unit":
		skill_damage(int(t.index), damage, source, int(shot.team))
		if p.has("halve_hp") and alive(int(t.index)):
			# This is an additional skill loss, not another attack/critical/dodge roll.
			a._lose_unit_hp(int(t.index), float(a.units[int(t.index)].hp) * 0.5, source, int(shot.team))
	else:
		a._damage_tile(t.key, int(shot.team), damage)
	if critical:
		feedback(Vector2(t.pos), str(damage).trim_suffix(".0"), true)
		if alive(source): buff(source, float(p.get("crit_attack", 0)), 0)
	if p.has("splash"):
		for j in candidates(int(shot.team), false, int(t.get("index", -1))):
			if Vector2(a.units[j].pos).distance_to(Vector2(t.pos)) <= CELL:
				skill_damage(j, damage, source, int(shot.team))
		a.effects.append({"kind": "skill_splash", "pos": Vector2(t.pos), "time": 0.4, "duration": 0.4})

func feedback(pos: Vector2, label: String, critical: bool) -> void:
	a.effects.append({"kind": "combat_text", "pos": pos, "text": label, "critical": critical, "time": 0.8, "duration": 0.8})

func update_projectiles(delta: float) -> void:
	var kept = []
	for shot in shots:
		shot.life = float(shot.life) - delta
		if float(shot.life) <= 0: continue
		var start = Vector2(shot.pos)
		var step = minf(CELL * 8 * delta, maxf(0, float(shot.range) - float(shot.traveled))) if shot.profile.has("pierce") else CELL * 8 * delta
		if shot.profile.has("pierce"):
			var finish = start + Vector2(shot.direction) * step
			for t in segment_targets(start, finish, int(shot.team)):
				impact(shot, t)
			shot.pos = finish
			shot.traveled = float(shot.traveled) + step
			if float(shot.traveled) >= float(shot.range): continue
		else:
			var target = resolve(shot.target, int(shot.team))
			if target.is_empty(): continue
			shot.pos = start.move_toward(Vector2(target.pos), step)
			if Vector2(shot.pos).distance_to(Vector2(target.pos)) < 0.01:
				impact(shot, target)
				if int(shot.remaining) <= 0: continue
				var next = bounce_target(shot)
				if next.is_empty(): continue
				shot.remaining = int(shot.remaining) - 1
				shot.target = next
		# One visual per live projectile, retained across the 0.20s online snapshot
		# cadence. Do not accumulate a new effect every simulation frame.
		if not shot.has("visual"):
			shot["visual"] = {"kind": "combat_projectile", "pos": Vector2(shot.pos), "from": start, "time": 0.26, "duration": 0.26}
			a.effects.append(shot.visual)
		shot.visual.pos = Vector2(shot.pos)
		shot.visual.from = start
		shot.visual.time = 0.26
		kept.append(shot)
	shots = kept

func bounce_target(shot: Dictionary) -> Dictionary:
	var choices = []
	for j in candidates(int(shot.team), false): choices.append(unit_target(j))
	for key in a.tiles:
		if a._is_enemy_building_target_valid(key, int(shot.team)):
			choices.append({"kind": "building", "key": key, "pos": a._hex_center(key)})
	var best = {}
	var distance = CELL * 3 + 0.00001
	for t in choices:
		var d = Vector2(t.pos).distance_to(Vector2(shot.pos))
		if not shot.hit.has(target_token(t)) and d < distance:
			best = t
			distance = d
	return best

func segment_targets(start: Vector2, finish: Vector2, team: int) -> Array:
	var result = []
	for j in candidates(team, false):
		var t = unit_target(j)
		if Geometry2D.get_closest_point_to_segment(Vector2(t.pos), start, finish).distance_to(Vector2(t.pos)) <= CELL * 0.24: result.append(t)
	for key in a.tiles:
		if a._is_enemy_building_target_valid(key, team):
			var pos = a._hex_center(key)
			if Geometry2D.get_closest_point_to_segment(pos, start, finish).distance_to(pos) <= CELL * 0.3:
				result.append({"kind": "building", "key": key, "pos": pos})
	result.sort_custom(func(x, y): return start.distance_squared_to(Vector2(x.pos)) < start.distance_squared_to(Vector2(y.pos)))
	return result

# Movement owns the world trajectory; art height is separate from hit/capture
# coordinates. No skipped cell is captured by a jump.
func tick_motion(i: int, delta: float) -> bool:
	var u = a.units[i]
	var p = profile(u)
	if u.has("motion_trip"):
		var trip = u.motion_trip
		trip.elapsed = minf(float(trip.duration), float(trip.elapsed) + delta)
		var progress = float(trip.elapsed) / float(trip.duration)
		var previous = Vector2(u.pos)
		u.pos = Vector2(trip.start).lerp(Vector2(trip.finish), progress)
		u["jump_height"] = sin(progress * PI) * 26 if String(trip.kind) == "jump" else 0.0
		if String(trip.kind) == "charge":
			for t in segment_targets(previous, Vector2(u.pos), int(u.team)):
				var token = target_token(t)
				if trip.hit.has(token): continue
				trip.hit.append(token)
				var target = resolve(t, int(u.team))
				if String(target.get("kind", "")) == "unit": skill_damage(int(target.index), float(u.attack), i, int(u.team))
				elif not target.is_empty(): a._damage_tile(target.key, int(u.team), float(u.attack))
			a.effects.append({"kind": "combat_projectile", "pos": previous, "from": Vector2(u.pos), "time": 0.12, "duration": 0.12})
		if progress >= 1:
			u.erase("motion_trip")
			u["jump_height"] = 0.0
			u.tile = a._tile_at_world(Vector2(u.pos))
			if String(trip.kind) == "jump": on_landing(i)
			a._try_paint_crossed_tile(u.tile, int(u.team), i)
		return true
	if not p.has("charge"): return false
	if u.has("charge_windup"):
		u.charge_windup = float(u.charge_windup) - delta
		if float(u.charge_windup) <= 0:
			u.erase("charge_windup")
			var finish = Vector2(u.charge_finish)
			u["motion_trip"] = {"kind": "charge", "start": Vector2(u.pos), "finish": finish, "duration": 0.35, "elapsed": 0.0, "hit": []}
			u["charge_wait"] = 4.0
		return true
	u["charge_wait"] = float(u.get("charge_wait", 4)) - delta
	if float(u.charge_wait) > 0: return false
	var target = a._locked_unit_attack_target(u)
	if target.is_empty(): target = a._unit_navigation_target(u)
	if target.is_empty(): return false
	var direction = Vector2(u.pos).direction_to(Vector2(target.pos))
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var end = Vector2(u.pos)
	# Stop at map boundaries instead of crossing missing ground cells.
	for n in range(1, 33):
		var candidate = Vector2(u.pos) + direction * CELL * 4 * n / 32.0
		if not a.tiles.has(a._tile_at_world(candidate)): break
		end = candidate
	if end.distance_to(Vector2(u.pos)) > 1:
		u["charge_finish"] = end
		u["charge_windup"] = 2.0
		return true
	return false

func begin_jump(i: int, target_pos: Vector2) -> bool:
	var u = a.units[i]
	var p = profile(u)
	if not p.has("jump"): return false
	var origin = a._tile_at_world(Vector2(u.pos))
	var length = int(p.jump)
	var best = Vector2.ZERO
	var score = INF
	for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]:
		var end = origin + direction * length
		var valid = true
		for n in range(1, length + 1):
			if not a.tiles.has(origin + direction * n): valid = false
		if not valid: continue
		var pos = a._hex_center(end)
		var value = pos.distance_squared_to(target_pos)
		if end == u.get("previous_jump_tile", a.MultiplayerRules.INVALID_KEY): value += CELL * CELL * 9
		if value < score:
			score = value
			best = pos
	if score == INF: return true
	u["previous_jump_tile"] = origin
	u["motion_trip"] = {"kind": "jump", "start": Vector2(u.pos), "finish": best, "duration": maxf(0.2, Vector2(u.pos).distance_to(best) / maxf(1, float(u.speed))), "elapsed": 0.0}
	on_jump_start(i)
	return true

func on_jump_start(i: int) -> void:
	if not alive(i): return
	var u = a.units[i]
	if not bool(u.get("has_jumped", false)) and bool(u.get("aura_jump", false)):
		buff(i, 0, 2)
	u["has_jumped"] = true

func on_landing(i: int) -> void:
	if not alive(i): return
	var u = a.units[i]
	var p = profile(u)
	buff(i, 0, float(p.get("landing_hp", 0)))
	if p.has("landing_damage"):
		for j in candidates(int(u.team), false):
			if a._tile_at_world(Vector2(a.units[j].pos)) == u.tile: skill_damage(j, 1, i, int(u.team))
		a.effects.append({"kind": "skill_splash", "pos": Vector2(u.pos), "time": 0.4, "duration": 0.4})
