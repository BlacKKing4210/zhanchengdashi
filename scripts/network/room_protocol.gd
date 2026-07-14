extends RefCounted

const MIN_PLAYERS_PER_SIDE = 1
const MAX_PLAYERS_PER_SIDE = 3
const MAX_PLAYERS = 6
const ROOM_CODE_LENGTH = 6
const PLAYER_NAME_MAX_LENGTH = 24
const SIDE_A_TEAM_IDS = [1, 2, 3]
const SIDE_B_TEAM_IDS = [4, 5, 6]
const JOIN_PRIORITY = [1, 4, 2, 5, 3, 6]
const LOBBY_STATUS = "lobby"
const RUNNING_STATUS = "running"


static func peer_id_error(peer_id: Variant) -> String:
	if typeof(peer_id) != TYPE_INT:
		return "invalid_peer_id_type"
	if int(peer_id) <= 0:
		return "invalid_peer_id"
	return ""


static func player_name_error(player_name: Variant) -> String:
	if typeof(player_name) != TYPE_STRING:
		return "invalid_player_name_type"
	var normalized = String(player_name).strip_edges()
	if normalized.is_empty():
		return "invalid_player_name"
	if normalized.length() > PLAYER_NAME_MAX_LENGTH:
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
	if size < MIN_PLAYERS_PER_SIDE or size > MAX_PLAYERS_PER_SIDE:
		return "invalid_room_size"
	return ""


static func bool_error(value: Variant, field_name: String) -> String:
	if typeof(value) != TYPE_BOOL:
		return "invalid_%s_type" % field_name
	return ""


static func room_code_error(room_code: Variant) -> String:
	if typeof(room_code) != TYPE_STRING:
		return "invalid_room_code_type"
	var code = String(room_code)
	if code.length() != ROOM_CODE_LENGTH:
		return "invalid_room_code"
	for index in range(code.length()):
		var character = code.unicode_at(index)
		if character < 48 or character > 57:
			return "invalid_room_code"
	return ""


static func team_id_error(team_id: Variant) -> String:
	if typeof(team_id) != TYPE_INT:
		return "invalid_team_id_type"
	var value = int(team_id)
	if value < 1 or value > MAX_PLAYERS:
		return "invalid_team_id"
	return ""


static func active_team_ids(players_per_side: int) -> Array:
	if not players_per_side_error(players_per_side).is_empty():
		return []
	var result = SIDE_A_TEAM_IDS.slice(0, players_per_side)
	result.append_array(SIDE_B_TEAM_IDS.slice(0, players_per_side))
	return result


static func join_priority(players_per_side: int) -> Array:
	var active = active_team_ids(players_per_side)
	var result = []
	for team_id in JOIN_PRIORITY:
		if team_id in active:
			result.append(team_id)
	return result


static func side_for_team(team_id: int) -> String:
	if team_id in SIDE_A_TEAM_IDS:
		return "A"
	if team_id in SIDE_B_TEAM_IDS:
		return "B"
	return ""


static func side_slot_index(team_id: int) -> int:
	if team_id in SIDE_A_TEAM_IDS:
		return team_id
	if team_id in SIDE_B_TEAM_IDS:
		return team_id - 3
	return 0


static func success(extra: Dictionary = {}) -> Dictionary:
	var result = {"ok": true}
	for key in extra:
		result[key] = extra[key]
	return result


static func failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
