extends RefCounted
## Shared deterministic home catalog and pure transitions. Online callers never
## supply a clock, price, reward, or ownership state to the authoritative store.

const DIRECTIONS = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const CASTLE_ID = "0,0"
const VERSION = 1
const TERRAIN_INDICES = {"castle": 7, "residence": 1, "dining": 5, "entertainment": 2, "sport": 4}
static var _economy: Dictionary = {}
static var _buildings: Array = []
static var _plots: Array = []
static var _plot_lookup: Dictionary = {}


static func economy() -> Dictionary:
	if _economy.is_empty():
		var rows = _load_rows("res://runtime/config/home_economy.json")
		if not rows.is_empty():
			_economy = rows[0]
	return _economy.duplicate(true)


static func buildings() -> Array:
	if _buildings.is_empty():
		_buildings = _load_rows("res://runtime/config/home_buildings.json")
	return _buildings.duplicate(true)


static func _load_rows(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid home configuration: " + path)
		return []
	return parsed


static func day_key(unix_seconds: int = -1) -> int:
	var timestamp = int(Time.get_unix_time_from_system()) if unix_seconds < 0 else unix_seconds
	return int(floor(float(timestamp + int(economy().timezone_hours) * 3600) / 86400.0))


static func plot_id(coords: Vector2i) -> String:
	return "%d,%d" % [coords.x, coords.y]


static func ring_of(coords: Vector2i) -> int:
	return maxi(absi(coords.x), maxi(absi(coords.y), absi(coords.x + coords.y)))


static func _stable_number(id: String, salt: String) -> int:
	return (id + ":home-v1:" + salt).sha256_text().left(8).hex_to_int()


static func daily_value(cost: int) -> int:
	var config = economy()
	var value = float(cost) / float(config.linear_divisor)
	if cost > int(config.linear_limit):
		value = float(config.log_base_value) + float(config.log_growth) * log(float(cost) / float(config.linear_limit))
	return clampi(int(round(value)), 1, int(config.max_daily_value))


static func all_plots() -> Array:
	if not _plots.is_empty():
		return _plots.duplicate(true)
	var config = economy()
	var types = buildings()
	if config.is_empty() or types.is_empty():
		return []
	var castle = {"id": CASTLE_ID, "q": 0, "r": 0, "ring": 0, "type": "castle", "name": "主城堡", "cost": 0, "capacity": 0, "value": 0, "item_id": "", "item_name": "", "terrain_index": 7, "color": "dfcf9e", "activity": "休息", "active_period": "night"}
	_plots.append(castle)
	_plot_lookup[CASTLE_ID] = castle
	for ring in range(1, int(config.max_rings) + 1):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var coords = Vector2i(q, r)
				if ring_of(coords) != ring:
					continue
				var id = plot_id(coords)
				var type_index = _stable_number(id, "type") % types.size()
				if ring == 1:
					type_index = DIRECTIONS.find(coords) % types.size()
				var definition: Dictionary = types[type_index]
				var base = int(config.first_ring_base) * int(pow(float(config.ring_multiplier), ring - 1))
				var low = int(round(base * float(config.price_min_pct)))
				var high = int(round(base * float(config.price_max_pct)))
				var cost = low + _stable_number(id, "cost") % (high - low + 1)
				var capacity = 0
				if int(definition.capacity_max) > 0:
					capacity = int(definition.capacity_min) + _stable_number(id, "capacity") % (int(definition.capacity_max) - int(definition.capacity_min) + 1)
				var entry = {"id": id, "q": q, "r": r, "ring": ring, "type": definition.id, "name": definition.name, "cost": cost, "capacity": capacity, "value": daily_value(cost), "item_id": definition.item_id, "item_name": definition.item_name, "terrain_index": TERRAIN_INDICES.get(definition.id, 7), "color": definition.color, "activity": definition.activity, "active_period": definition.active_period}
				_plots.append(entry)
				_plot_lookup[id] = entry
	return _plots.duplicate(true)


static func plot(id: String) -> Dictionary:
	if _plot_lookup.is_empty():
		all_plots()
	return (_plot_lookup.get(id, {}) as Dictionary).duplicate(true)


static func initial_state(day: int) -> Dictionary:
	return {"version": VERSION, "started_day": day, "owned": {CASTLE_ID: day}, "last_claim_day": day - 1, "last_reward": {}}


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or int(value.get("started_day", -1)) < 0:
		return {}
	var source: Dictionary = value
	var start = maxi(0, int(source.started_day))
	var result = initial_state(start)
	var raw_owned: Variant = source.get("owned", {})
	if typeof(raw_owned) == TYPE_DICTIONARY:
		for id in raw_owned:
			if typeof(id) == TYPE_STRING and not plot(id).is_empty():
				result.owned[id] = maxi(start, int(raw_owned[id]))
	result.last_claim_day = maxi(start - 1, int(source.get("last_claim_day", start - 1)))
	if typeof(source.get("last_reward")) == TYPE_DICTIONARY:
		result.last_reward = _normalize_reward(source.last_reward)
	return result


static func _normalize_reward(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var result = {"day": int(source.get("day", -1)), "days": [], "items": [], "gold": maxi(0, int(source.get("gold", 0))), "tickets": maxi(0, int(source.get("tickets", 0)))}
	var days: Variant = source.get("days", [])
	if typeof(days) == TYPE_ARRAY:
		for day in days:
			result.days.append(int(day))
	var items: Variant = source.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw_item.duplicate(true)
			for field in ["quantity", "gold", "tickets"]:
				item[field] = maxi(0, int(item.get(field, 0)))
			result.items.append(item)
	return result


static func visible_plots(home: Dictionary) -> Array:
	var owned: Dictionary = home.get("owned", {CASTLE_ID: 0})
	var outer = 0
	for id in owned:
		outer = maxi(outer, int(plot(String(id)).get("ring", 0)))
	var result: Array = []
	for entry in all_plots():
		if int(entry.ring) <= outer + 1:
			result.append(entry)
	return result


static func can_unlock(home: Dictionary, id: String, gold: int) -> Dictionary:
	var entry = plot(id)
	if entry.is_empty():
		return {"ok": false, "error": "invalid_plot"}
	var owned: Dictionary = home.get("owned", {})
	if owned.has(id):
		return {"ok": false, "error": "already_unlocked"}
	var adjacent = false
	var coords = Vector2i(int(entry.q), int(entry.r))
	for offset in DIRECTIONS:
		if owned.has(plot_id(coords + offset)):
			adjacent = true
			break
	if not adjacent:
		return {"ok": false, "error": "plot_not_adjacent"}
	if gold < int(entry.cost):
		return {"ok": false, "error": "insufficient_gold"}
	return {"ok": true, "cost": int(entry.cost)}


static func unlock(home: Dictionary, id: String, gold: int, tickets: int, day: int) -> Dictionary:
	var state = normalize_state(home)
	var checked = can_unlock(state, id, gold)
	if not bool(checked.ok):
		return checked
	state.owned[id] = day
	var bonus = int(economy().unlock_tickets)
	return {"ok": true, "home": state, "wallet_gold": gold - int(checked.cost), "gacha_tickets": tickets + bonus, "cost": int(checked.cost), "reward": {"gold": 0, "tickets": bonus}}


static func daily_snapshot(home: Dictionary, day: int) -> Dictionary:
	var state = normalize_state(home)
	var result = {"day": day, "days": [], "items": [], "castle_gold": 0, "castle_tickets": 0, "can_claim": false}
	if state.is_empty():
		return result
	var config = economy()
	var first = maxi(int(state.started_day), maxi(int(state.last_claim_day) + 1, day - int(config.catchup_days) + 1))
	for eligible_day in range(first, day + 1):
		result.days.append(eligible_day)
	if result.days.is_empty():
		return result
	result.can_claim = true
	result.castle_gold = int(config.castle_gold) * result.days.size()
	result.castle_tickets = int(config.castle_tickets) * result.days.size()
	for entry in all_plots():
		if entry.id == CASTLE_ID or not state.owned.has(entry.id):
			continue
		var count = 0
		for eligible_day in result.days:
			if int(eligible_day) > int(state.owned[entry.id]):
				count += 1
		if count > 0:
			result.items.append({"plot_id": entry.id, "item_id": entry.item_id, "item_name": entry.item_name, "type": entry.type, "quantity": count})
	return result


static func settle_daily(home: Dictionary, day: int, rng: RandomNumberGenerator) -> Dictionary:
	var state = normalize_state(home)
	var snapshot = daily_snapshot(state, day)
	if not bool(snapshot.can_claim):
		return {"ok": false, "error": "already_claimed"}
	var config = economy()
	var reward = {"day": day, "days": snapshot.days.duplicate(), "items": [], "gold": snapshot.castle_gold, "tickets": snapshot.castle_tickets}
	for raw_item in snapshot.items:
		var item: Dictionary = raw_item.duplicate(true)
		var value = int(plot(String(item.plot_id)).value)
		item["gold"] = 0
		item["tickets"] = 0
		for _index in range(int(item.quantity)):
			item.gold += rng.randi_range(int(ceil(value * float(config.coin_min_pct))), int(floor(value * float(config.coin_max_pct))))
			if rng.randf() < float(value) * float(config.ticket_value_share) / float(config.ticket_value):
				item.tickets += 1
		reward.gold += item.gold
		reward.tickets += item.tickets
		reward.items.append(item)
	state.last_claim_day = day
	state.last_reward = reward.duplicate(true)
	return {"ok": true, "home": state, "reward": reward}
