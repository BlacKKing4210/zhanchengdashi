extends RefCounted

const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

const PLAYER_TEAM = 1
const ENEMY_TEAM = 4
const NEUTRAL_TEAM = 0
const MIN_SHARED_BORDER_EDGES = 9
const MAX_FRONTIER_DISTANCE_GAP = 2
const COUNT_DIRECTIONS = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
]


static func optimize_match(match_data: Dictionary) -> Dictionary:
	var optimized = match_data.duplicate(true)
	var tiles: Dictionary = optimized.get("tiles", {})
	var base_keys: Dictionary = optimized.get("base_keys", {})
	var before_contact = shared_border_edges(tiles, PLAYER_TEAM, ENEMY_TEAM)
	var result = {
		"ok": false,
		"before_contact_edges": before_contact,
		"after_contact_edges": before_contact,
		"player_frontier_key": MultiplayerRules.INVALID_KEY,
		"enemy_frontier_key": MultiplayerRules.INVALID_KEY,
		"frontier_distance_gap": -1,
		"reason": "no_balanced_frontier_pair",
	}
	if tiles.is_empty() or not base_keys.has(PLAYER_TEAM) or not base_keys.has(ENEMY_TEAM):
		optimized["classic_frontier"] = result
		return optimized

	var neutral_keys = _neutral_seam_keys(tiles)
	if neutral_keys.size() < 3:
		result["reason"] = "insufficient_neutral_seam"
		optimized["classic_frontier"] = result
		return optimized

	var candidates = []
	var player_base: Vector2i = base_keys[PLAYER_TEAM]
	var enemy_base: Vector2i = base_keys[ENEMY_TEAM]
	for first_index in range(neutral_keys.size()):
		for second_index in range(first_index + 1, neutral_keys.size()):
			var first_key: Vector2i = neutral_keys[first_index]
			var second_key: Vector2i = neutral_keys[second_index]
			for reverse_assignment in [false, true]:
				var player_key = second_key if reverse_assignment else first_key
				var enemy_key = first_key if reverse_assignment else second_key
				var player_distance = hex_distance(player_base, player_key)
				var enemy_distance = hex_distance(enemy_base, enemy_key)
				var distance_gap = absi(player_distance - enemy_distance)
				if distance_gap > MAX_FRONTIER_DISTANCE_GAP:
					continue
				var first_original: Dictionary = tiles[first_key].duplicate(true)
				var second_original: Dictionary = tiles[second_key].duplicate(true)
				_apply_balanced_pair(
					tiles,
					player_key,
					enemy_key,
					first_key if posmod(int(optimized.get("layout_seed", 0)), 2) == 0 else second_key
				)
				var contact = shared_border_edges(tiles, PLAYER_TEAM, ENEMY_TEAM)
				var valid = (
					contact >= MIN_SHARED_BORDER_EDGES
					and territory_count(tiles, PLAYER_TEAM) == territory_count(tiles, ENEMY_TEAM)
					and is_team_connected(tiles, PLAYER_TEAM)
					and is_team_connected(tiles, ENEMY_TEAM)
					and neutral_count(tiles) >= 1
				)
				if valid:
					candidates.append({
						"player_key": player_key,
						"enemy_key": enemy_key,
						"template_key": first_key if posmod(int(optimized.get("layout_seed", 0)), 2) == 0 else second_key,
						"contact": contact,
						"distance_gap": distance_gap,
						"distance_total": player_distance + enemy_distance,
					})
				tiles[first_key] = first_original
				tiles[second_key] = second_original

	if candidates.is_empty():
		optimized["classic_frontier"] = result
		return optimized

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["contact"]) != int(b["contact"]):
			return int(a["contact"]) > int(b["contact"])
		if int(a["distance_gap"]) != int(b["distance_gap"]):
			return int(a["distance_gap"]) < int(b["distance_gap"])
		if int(a["distance_total"]) != int(b["distance_total"]):
			return int(a["distance_total"]) < int(b["distance_total"])
		var a_player: Vector2i = a["player_key"]
		var b_player: Vector2i = b["player_key"]
		if a_player.y != b_player.y:
			return a_player.y < b_player.y
		return a_player.x < b_player.x
	)
	var best_contact = int(candidates[0]["contact"])
	var best_gap = int(candidates[0]["distance_gap"])
	var best_total = int(candidates[0]["distance_total"])
	var best_candidates = candidates.filter(func(candidate: Dictionary) -> bool:
		return (
			int(candidate["contact"]) == best_contact
			and int(candidate["distance_gap"]) == best_gap
			and int(candidate["distance_total"]) == best_total
		)
	)
	var chosen: Dictionary = best_candidates[posmod(int(optimized.get("match_seed", 0)), best_candidates.size())]
	_apply_balanced_pair(tiles, chosen["player_key"], chosen["enemy_key"], chosen["template_key"])
	result = {
		"ok": true,
		"before_contact_edges": before_contact,
		"after_contact_edges": shared_border_edges(tiles, PLAYER_TEAM, ENEMY_TEAM),
		"player_frontier_key": chosen["player_key"],
		"enemy_frontier_key": chosen["enemy_key"],
		"frontier_distance_gap": int(chosen["distance_gap"]),
		"reason": "",
	}
	optimized["tiles"] = tiles
	optimized["classic_frontier"] = result
	return optimized


static func shared_border_edges(tiles: Dictionary, first_team: int, second_team: int) -> int:
	var count = 0
	for key in tiles:
		var team = int(tiles[key].get("territory_team", NEUTRAL_TEAM))
		if team != first_team and team != second_team:
			continue
		for direction in COUNT_DIRECTIONS:
			var neighbor: Vector2i = key + direction
			if not tiles.has(neighbor):
				continue
			var neighbor_team = int(tiles[neighbor].get("territory_team", NEUTRAL_TEAM))
			if (team == first_team and neighbor_team == second_team) or (team == second_team and neighbor_team == first_team):
				count += 1
	return count


static func territory_count(tiles: Dictionary, team: int) -> int:
	var count = 0
	for tile in tiles.values():
		if int(tile.get("territory_team", NEUTRAL_TEAM)) == team:
			count += 1
	return count


static func neutral_count(tiles: Dictionary) -> int:
	return territory_count(tiles, NEUTRAL_TEAM)


static func is_team_connected(tiles: Dictionary, team: int) -> bool:
	var owned = []
	for key in tiles:
		if int(tiles[key].get("territory_team", NEUTRAL_TEAM)) == team:
			owned.append(key)
	if owned.is_empty():
		return false
	var seen = {owned[0]: true}
	var pending = [owned[0]]
	while not pending.is_empty():
		var key: Vector2i = pending.pop_back()
		for neighbor in MultiplayerRules.neighbors(tiles, key):
			if seen.has(neighbor) or int(tiles[neighbor].get("territory_team", NEUTRAL_TEAM)) != team:
				continue
			seen[neighbor] = true
			pending.append(neighbor)
	return seen.size() == owned.size()


static func hex_distance(first: Vector2i, second: Vector2i) -> int:
	var delta = first - second
	return maxi(maxi(absi(delta.x), absi(delta.y)), absi(delta.x + delta.y))


static func _neutral_seam_keys(tiles: Dictionary) -> Array:
	var result = []
	for key in tiles:
		if (
			int(tiles[key].get("territory_team", NEUTRAL_TEAM)) == NEUTRAL_TEAM
			and MultiplayerRules.mirror_key(key) == key
		):
			result.append(key)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return result


static func _apply_balanced_pair(
	tiles: Dictionary,
	player_key: Vector2i,
	enemy_key: Vector2i,
	template_key: Vector2i
) -> void:
	var template: Dictionary = tiles[template_key].duplicate(true)
	var player_tile = template.duplicate(true)
	var enemy_tile = template.duplicate(true)
	player_tile["territory_team"] = PLAYER_TEAM
	enemy_tile["territory_team"] = ENEMY_TEAM
	tiles[player_key] = player_tile
	tiles[enemy_key] = enemy_tile
