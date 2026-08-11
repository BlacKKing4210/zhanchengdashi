## Configurable room validation and team topology.
## This service deliberately knows nothing about ENet, UI, or combat.
extends RefCounted

const LOBBY_STATUS = "lobby"
const RUNNING_STATUS = "running"

static var _config = {
	"min_players_per_side": 1,
	"max_players_per_side": 3,
	"room_code_length": 6,
	"player_name_max_length": 24,
	"sides": {
		"A": [1, 2, 3],
		"B": [4, 5, 6],
	},
	"join_priority": [1, 4, 2, 5, 3, 6],
}


static func configure(overrides: Dictionary) -> Dictionary:
	var candidate = _config.duplicate(true)
	for key in overrides:
		candidate[key] = overrides[key]
	var sides = candidate.get("sides", {})
	if typeof(sides) != TYPE_DICTIONARY:
		return failure("invalid_sides")
	var all_ids = []
	for side in sides:
		var team_ids = sides[side]
		if typeof(team_ids) != TYPE_ARRAY or team_ids.is_empty():
			return failure("invalid_sides")
		for raw_team_id in team_ids:
			if typeof(raw_team_id) != TYPE_INT or int(raw_team_id) <= 0 or all_ids.has(int(raw_team_id)):
				return failure("invalid_team_id")
			all_ids.append(int(raw_team_id))
	var max_size = int(candidate.get("max_players_per_side", 0))
	if max_size <= 0 or max_size > all_ids.size():
		return failure("invalid_room_size")
	_config = candidate
	return success()


static func peer_id_error(peer_id: Variant) -> String:
	if typeof(peer_id) != TYPE_INT:
		return "invalid_peer_id_type"
	return "" if int(peer_id) > 0 else "invalid_peer_id"


static func player_name_error(player_name: Variant) -> String:
	if typeof(player_name) != TYPE_STRING:
		return "invalid_player_name_type"
	var normalized = String(player_name).strip_edges()
	if normalized.is_empty():
		return "invalid_player_name"
	if normalized.length() > int(_config["player_name_max_length"]):
		return "player_name_too_long"
	for index in range(normalized.length()):
		if normalized.unicode_at(index) < 32:
			return "invalid_player_name"
	return ""


static func normalized_player_name(player_name: String) -> String:
	return player_name.strip_edges()


static func players_per_side_error(players_per_side: Variant) -> String:
	if typeof(players_per_side) != TYPE_INT:
		return "invalid_room_size_type"
	var size = int(players_per_side)
	if size < int(_config["min_players_per_side"]) or size > int(_config["max_players_per_side"]):
		return "invalid_room_size"
	return ""


static func bool_error(value: Variant, field_name: String) -> String:
	return "" if typeof(value) == TYPE_BOOL else "invalid_%s_type" % field_name


static func room_code_error(room_code: Variant) -> String:
	if typeof(room_code) != TYPE_STRING:
		return "invalid_room_code_type"
	var code = String(room_code)
	if code.length() != int(_config["room_code_length"]):
		return "invalid_room_code"
	for index in range(code.length()):
		var character = code.unicode_at(index)
		if character < 48 or character > 57:
			return "invalid_room_code"
	return ""


static func team_id_error(team_id: Variant) -> String:
	if typeof(team_id) != TYPE_INT:
		return "invalid_team_id_type"
	return "" if all_team_ids().has(int(team_id)) else "invalid_team_id"


static func active_team_ids(players_per_side: int) -> Array:
	if not players_per_side_error(players_per_side).is_empty():
		return []
	var result = []
	for side in _config["sides"]:
		var team_ids: Array = _config["sides"][side]
		result.append_array(team_ids.slice(0, players_per_side))
	return result


static func join_priority(players_per_side: int) -> Array:
	var active = active_team_ids(players_per_side)
	var result = []
	for team_id in _config["join_priority"]:
		if team_id in active:
			result.append(team_id)
	for team_id in active:
		if not result.has(team_id):
			result.append(team_id)
	return result


static func side_for_team(team_id: int) -> String:
	for side in _config["sides"]:
		if team_id in _config["sides"][side]:
			return String(side)
	return ""


static func side_slot_index(team_id: int) -> int:
	var side = side_for_team(team_id)
	if side.is_empty():
		return 0
	return (_config["sides"][side] as Array).find(team_id) + 1


static func all_team_ids() -> Array:
	var result = []
	for side in _config["sides"]:
		for team_id in _config["sides"][side]:
			result.append(int(team_id))
	return result


static func max_players() -> int:
	return all_team_ids().size()


static func success(extra: Dictionary = {}) -> Dictionary:
	var result = {"ok": true}
	for key in extra:
		result[key] = extra[key]
	return result


static func failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
