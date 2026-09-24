extends RefCounted
## Presentation-only residents. All outdoor routes follow the hex edge graph.
const RADIUS = 108.0
const CYCLE_SECONDS = 240.0
const WALK_SPEED = 42.0
var residents: Array = []
var clock = 55.0
var vertices: Dictionary = {}
var links: Dictionary = {}
var doors: Dictionary = {}
var plots: Dictionary = {}
var homes: Dictionary = {}
var rng = RandomNumberGenerator.new()
var signature = ""
var completed_behaviors = 0

func _init() -> void:
	rng.randomize()

static func center(q: int, r: int) -> Vector2:
	return Vector2(1.5 * RADIUS * q, sqrt(3.0) * RADIUS * (r + q * 0.5))

static func corners(c: Vector2, radius: float = RADIUS) -> PackedVector2Array:
	var result = PackedVector2Array()
	for i in range(6):
		result.append(c + Vector2.from_angle(float(i) * TAU / 6.0) * radius)
	return result

static func vertex_key(p: Vector2) -> String:
	return "%d:%d" % [roundi(p.x * 100), roundi(p.y * 100)]

func is_night() -> bool:
	return fmod(clock, CYCLE_SECONDS) >= CYCLE_SECONDS * 0.58

func hour() -> int:
	return int(fmod(clock / CYCLE_SECONDS * 24.0 + 6.0, 24.0))

func configure(owned: Dictionary, definitions: Array, animal_ids: Array) -> void:
	var next_signature = JSON.stringify([owned.keys(), animal_ids])
	if next_signature == signature:
		return
	signature = next_signature
	vertices.clear()
	links.clear()
	doors.clear()
	plots.clear()
	homes.clear()
	for p in definitions:
		if not owned.has(p.id):
			continue
		plots[p.id] = p
		var c = center(int(p.q), int(p.r))
		var points = corners(c)
		for i in range(6):
			var a = vertex_key(points[i])
			var b = vertex_key(points[(i + 1) % 6])
			vertices[a] = points[i]
			vertices[b] = points[(i + 1) % 6]
			if not links.has(a): links[a] = []
			if not links.has(b): links[b] = []
			if not links[a].has(b): links[a].append(b)
			if not links[b].has(a): links[b].append(a)
		# Lower-right corner is the road entrance; disappear at the door.
		doors[p.id] = vertex_key(points[1])
		if p.type == "residence": homes[p.id] = int(p.capacity)
	var previous: Dictionary = {}
	for resident in residents: previous[resident.id] = resident
	residents.clear()
	var used: Dictionary = {}
	for animal_id in animal_ids:
		var home_id = "0,0"
		for id in homes:
			if int(used.get(id, 0)) < int(homes[id]):
				home_id = id
				used[id] = int(used.get(id, 0)) + 1
				break
		var a: Dictionary = previous.get(animal_id, {})
		if a.is_empty():
			a = {"id": animal_id, "pos": vertices.get(doors.get("0,0", ""), Vector2.ZERO), "node": doors.get("0,0", ""), "inside": true, "building": "0,0", "target": "", "action": "rest", "route": [], "wait": rng.randf_range(0.5, 30.0), "mood": "", "mood_time": 0.0, "facing": 1.0, "night_trip": false}
		a.home = home_id
		residents.append(a)

func route_between(from_key: String, to_key: String) -> Array:
	if not vertices.has(from_key) or not vertices.has(to_key): return []
	var queue: Array = [from_key]
	var previous: Dictionary = {from_key: ""}
	var cursor = 0
	while cursor < queue.size():
		var key: String = queue[cursor]
		cursor += 1
		if key == to_key: break
		for next in links.get(key, []):
			if not previous.has(next):
				previous[next] = key
				queue.append(next)
	if not previous.has(to_key): return []
	var result: Array = []
	var step = to_key
	while step != from_key:
		result.push_front(step)
		step = previous[step]
	return result

func update(delta: float) -> void:
	var was_night = is_night()
	clock += delta
	if plots.is_empty(): return
	for a in residents:
		a.mood_time = maxf(0.0, float(a.mood_time) - delta)
		if was_night != is_night():
			a.night_trip = false
			if a.inside: a.wait = rng.randf_range(0.4, 8.0)
		if not a.route.is_empty():
			_step_route(a, delta)
			continue
		a.wait = float(a.wait) - delta
		if a.wait > 0.0: continue
		if not a.inside and a.target != "":
			# Activity ends outside; show a face before entering or moving again.
			_finish(a)
			continue
		_choose_trip(a)

func _step_route(a: Dictionary, delta: float) -> void:
	var remaining = WALK_SPEED * delta
	while remaining > 0.0 and not a.route.is_empty():
		var key: String = a.route[0]
		var end: Vector2 = vertices[key]
		var position: Vector2 = a.pos
		var distance = position.distance_to(end)
		if absf(end.x - position.x) > 1.0: a.facing = signf(end.x - position.x)
		if remaining >= distance:
			a.pos = end
			a.node = key
			a.route.pop_front()
			remaining -= distance
		else:
			a.pos = position.move_toward(end, remaining)
			remaining = 0.0
	if a.route.is_empty():
		if a.action == "wander":
			a.target = ""
			a.wait = rng.randf_range(1.0, 3.0)
		elif a.action == "rest":
			a.inside = true
			a.building = a.target
			a.target = ""
			a.wait = 8.0 if not is_night() else CYCLE_SECONDS
		else:
			# Meals and entertainment happen indoors; sport stays on the road.
			a.inside = a.action in ["dining", "entertainment"]
			a.building = a.target
			a.wait = rng.randf_range(4.0, 9.0)

func _finish(a: Dictionary) -> void:
	completed_behaviors += 1
	a.mood = ["happy", "love", "excited"][rng.randi_range(0, 2)] if rng.randf() < 0.85 else "tired"
	a.mood_time = 3.0
	a.target = ""
	a.inside = false
	a.wait = 3.2

func _choose_trip(a: Dictionary) -> void:
	if a.inside and a.action in ["dining", "entertainment"] and a.target != "":
		_finish(a)
		return
	if a.inside:
		var outside = 0
		for other in residents:
			if not other.inside: outside += 1
		if outside >= mini(18, maxi(4, plots.size() * 2)):
			a.wait = rng.randf_range(3.0, 8.0)
			return
	var candidates: Array = []
	var desired = ""
	if is_night():
		if not bool(a.night_trip) and rng.randf() < 0.75:
			desired = "entertainment"
			a.night_trip = true
		else:
			desired = "rest"
	else:
		desired = "dining" if rng.randf() < 0.55 else "sport"
	for id in plots:
		if plots[id].type == desired: candidates.append(id)
	if desired == "rest": candidates = [a.home]
	if candidates.is_empty():
		if is_night():
			candidates = [a.home]
			desired = "rest"
		else:
			a.inside = false
			a.action = "wander"
			a.target = ""
			var all_nodes = vertices.keys()
			a.route = route_between(a.node, all_nodes[rng.randi_range(0, all_nodes.size() - 1)])
			a.wait = rng.randf_range(3.0, 6.0)
			return
	var target: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	if desired == "rest" and a.inside and a.building == target:
		a.wait = CYCLE_SECONDS
		return
	a.inside = false
	a.action = desired
	a.target = target
	a.route = route_between(a.node, doors[target])
	a.wait = rng.randf_range(4.0, 9.0)
	if a.route.is_empty():
		a.inside = desired != "sport"
		a.building = target
		if desired == "rest":
			a.target = ""
			a.wait = CYCLE_SECONDS
