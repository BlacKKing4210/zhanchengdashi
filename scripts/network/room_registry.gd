extends RefCounted

const RoomProtocol = preload("res://scripts/network/room_protocol.gd")

const ROOM_CODE_SPACE = 1000000
const RANDOM_CODE_ATTEMPTS = 64

signal room_changed(room_code: String)
signal room_closed(room_code: String)

var _rooms: Dictionary = {}
var _peer_rooms: Dictionary = {}
var _peer_teams: Dictionary = {}
var _rng = RandomNumberGenerator.new()
var _next_code_cursor = 0
var _next_ai_id = 1


func _init(seed: int = 0) -> void:
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed
	_next_code_cursor = posmod(seed, ROOM_CODE_SPACE)


func create_room(
	peer_id_value: Variant,
	player_name_value: Variant,
	players_per_side_value: Variant = 1,
	fill_with_ai_value: Variant = false
) -> Dictionary:
	var error = RoomProtocol.peer_id_error(peer_id_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	error = RoomProtocol.player_name_error(player_name_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	error = RoomProtocol.players_per_side_error(players_per_side_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	error = RoomProtocol.bool_error(fill_with_ai_value, "fill_with_ai")
	if not error.is_empty():
		return RoomProtocol.failure(error)

	var peer_id = int(peer_id_value)
	if _peer_rooms.has(peer_id):
		return RoomProtocol.failure("peer_already_in_room")
	var room_code = _allocate_room_code()
	if room_code.is_empty():
		return RoomProtocol.failure("room_code_space_exhausted")
	var players_per_side = int(players_per_side_value)
	var room = {
		"room_code": room_code,
		"status": RoomProtocol.LOBBY_STATUS,
		"players_per_side": players_per_side,
		"fill_with_ai": bool(fill_with_ai_value),
		"host_peer_id": peer_id,
		"slots": {},
		"revision": 1,
		"next_join_order": 2,
	}
	room["slots"][1] = _human_participant(
		peer_id,
		RoomProtocol.normalized_player_name(String(player_name_value)),
		1
	)
	_rooms[room_code] = room
	_peer_rooms[peer_id] = room_code
	_peer_teams[peer_id] = 1
	_reconcile_ai_slots(room)
	room_changed.emit(room_code)
	return RoomProtocol.success({
		"action": "created",
		"room_code": room_code,
		"team_id": 1,
		"affected_peer_ids": _human_peer_ids(room),
	})


func join_room(
	peer_id_value: Variant,
	room_code_value: Variant,
	player_name_value: Variant
) -> Dictionary:
	var error = RoomProtocol.peer_id_error(peer_id_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	error = RoomProtocol.room_code_error(room_code_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	error = RoomProtocol.player_name_error(player_name_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)

	var peer_id = int(peer_id_value)
	if _peer_rooms.has(peer_id):
		return RoomProtocol.failure("peer_already_in_room")
	var room_code = String(room_code_value)
	if not _rooms.has(room_code):
		return RoomProtocol.failure("room_not_found")
	var room: Dictionary = _rooms[room_code]
	if String(room["status"]) != RoomProtocol.LOBBY_STATUS:
		return RoomProtocol.failure("room_running")
	var team_id = _available_join_team(room)
	if team_id == 0:
		return RoomProtocol.failure("room_full")

	var slots: Dictionary = room["slots"]
	var join_order = int(room["next_join_order"])
	room["next_join_order"] = join_order + 1
	slots[team_id] = _human_participant(
		peer_id,
		RoomProtocol.normalized_player_name(String(player_name_value)),
		join_order
	)
	_peer_rooms[peer_id] = room_code
	_peer_teams[peer_id] = team_id
	_reset_human_ready(room)
	_reconcile_ai_slots(room)
	_touch_room(room)
	room_changed.emit(room_code)
	return RoomProtocol.success({
		"action": "joined",
		"room_code": room_code,
		"team_id": team_id,
		"affected_peer_ids": _human_peer_ids(room),
	})


func leave_room(peer_id_value: Variant) -> Dictionary:
	var error = RoomProtocol.peer_id_error(peer_id_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	var peer_id = int(peer_id_value)
	if not _peer_rooms.has(peer_id):
		return RoomProtocol.failure("peer_not_in_room")

	var room_code = String(_peer_rooms[peer_id])
	var room: Dictionary = _rooms[room_code]
	var team_id = int(_peer_teams[peer_id])
	var slots: Dictionary = room["slots"]
	slots.erase(team_id)
	_peer_rooms.erase(peer_id)
	_peer_teams.erase(peer_id)

	var remaining_peers = _human_peer_ids(room)
	if remaining_peers.is_empty():
		_rooms.erase(room_code)
		room_closed.emit(room_code)
		return RoomProtocol.success({
			"action": "room_closed",
			"room_code": room_code,
			"team_id": team_id,
			"affected_peer_ids": [],
		})

	if int(room["host_peer_id"]) == peer_id:
		room["host_peer_id"] = _oldest_human_peer_id(room)
	if String(room["status"]) == RoomProtocol.LOBBY_STATUS:
		_reset_human_ready(room)
		_reconcile_ai_slots(room)
	_touch_room(room)
	room_changed.emit(room_code)
	return RoomProtocol.success({
		"action": "left",
		"room_code": room_code,
		"team_id": team_id,
		"new_host_peer_id": int(room["host_peer_id"]),
		"affected_peer_ids": _human_peer_ids(room),
	})


func peer_disconnected(peer_id_value: Variant) -> Dictionary:
	return leave_room(peer_id_value)


func update_room_settings(
	peer_id_value: Variant,
	players_per_side_value: Variant,
	fill_with_ai_value: Variant
) -> Dictionary:
	var context = _mutable_lobby_for_host(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	var error = RoomProtocol.players_per_side_error(players_per_side_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	error = RoomProtocol.bool_error(fill_with_ai_value, "fill_with_ai")
	if not error.is_empty():
		return RoomProtocol.failure(error)

	var room: Dictionary = context["room"]
	var new_size = int(players_per_side_value)
	var active = RoomProtocol.active_team_ids(new_size)
	var slots: Dictionary = room["slots"]
	for team_id in slots.keys():
		var participant: Dictionary = slots[team_id]
		if not team_id in active and String(participant["kind"]) == "human":
			return RoomProtocol.failure("room_size_conflict")

	var changed = (
		int(room["players_per_side"]) != new_size
		or bool(room["fill_with_ai"]) != bool(fill_with_ai_value)
	)
	room["players_per_side"] = new_size
	room["fill_with_ai"] = bool(fill_with_ai_value)
	_reconcile_ai_slots(room)
	if changed:
		_reset_human_ready(room)
		_touch_room(room)
		room_changed.emit(String(room["room_code"]))
	return RoomProtocol.success({
		"action": "settings_updated",
		"room_code": String(room["room_code"]),
		"players_per_side": new_size,
		"fill_with_ai": bool(fill_with_ai_value),
		"affected_peer_ids": _human_peer_ids(room),
	})


func set_room_size(peer_id_value: Variant, players_per_side_value: Variant) -> Dictionary:
	var context = _room_context_for_peer(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	var room: Dictionary = context["room"]
	return update_room_settings(
		peer_id_value,
		players_per_side_value,
		bool(room["fill_with_ai"])
	)


func set_ai_fill(peer_id_value: Variant, fill_with_ai_value: Variant) -> Dictionary:
	var context = _room_context_for_peer(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	var room: Dictionary = context["room"]
	return update_room_settings(
		peer_id_value,
		int(room["players_per_side"]),
		fill_with_ai_value
	)


func move_to_slot(peer_id_value: Variant, team_id_value: Variant) -> Dictionary:
	var context = _mutable_lobby_for_peer(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	var error = RoomProtocol.team_id_error(team_id_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	var peer_id = int(peer_id_value)
	var team_id = int(team_id_value)
	var room: Dictionary = context["room"]
	if not team_id in RoomProtocol.active_team_ids(int(room["players_per_side"])):
		return RoomProtocol.failure("inactive_team_slot")
	var current_team = int(_peer_teams[peer_id])
	if current_team == team_id:
		return RoomProtocol.success({
			"action": "slot_unchanged",
			"room_code": String(room["room_code"]),
			"team_id": team_id,
			"affected_peer_ids": _human_peer_ids(room),
		})

	var slots: Dictionary = room["slots"]
	if slots.has(team_id):
		var occupant: Dictionary = slots[team_id]
		if String(occupant["kind"]) == "human":
			return RoomProtocol.failure("slot_occupied")
	var participant: Dictionary = slots[current_team]
	slots.erase(current_team)
	slots[team_id] = participant
	_peer_teams[peer_id] = team_id
	_reset_human_ready(room)
	_reconcile_ai_slots(room)
	_touch_room(room)
	room_changed.emit(String(room["room_code"]))
	return RoomProtocol.success({
		"action": "slot_changed",
		"room_code": String(room["room_code"]),
		"previous_team_id": current_team,
		"team_id": team_id,
		"affected_peer_ids": _human_peer_ids(room),
	})


func set_ready(peer_id_value: Variant, ready_value: Variant) -> Dictionary:
	var context = _mutable_lobby_for_peer(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	var error = RoomProtocol.bool_error(ready_value, "ready")
	if not error.is_empty():
		return RoomProtocol.failure(error)
	var peer_id = int(peer_id_value)
	var room: Dictionary = context["room"]
	var team_id = int(_peer_teams[peer_id])
	var participant: Dictionary = room["slots"][team_id]
	participant["ready"] = bool(ready_value)
	_touch_room(room)
	room_changed.emit(String(room["room_code"]))
	return RoomProtocol.success({
		"action": "ready_changed",
		"room_code": String(room["room_code"]),
		"team_id": team_id,
		"ready": bool(ready_value),
		"affected_peer_ids": _human_peer_ids(room),
	})


func start_room(peer_id_value: Variant) -> Dictionary:
	var context = _mutable_lobby_for_host(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	var room: Dictionary = context["room"]
	var slots: Dictionary = room["slots"]
	for team_id in RoomProtocol.active_team_ids(int(room["players_per_side"])):
		if not slots.has(team_id):
			return RoomProtocol.failure("room_not_full")
		var participant: Dictionary = slots[team_id]
		if String(participant["kind"]) == "human" and not bool(participant["ready"]):
			return RoomProtocol.failure("players_not_ready")
	_randomize_active_slots(room)
	room["status"] = RoomProtocol.RUNNING_STATUS
	_touch_room(room)
	room_changed.emit(String(room["room_code"]))
	return RoomProtocol.success({
		"action": "started",
		"room_code": String(room["room_code"]),
		"revision": int(room["revision"]),
		"authority_peer_id": int(room["host_peer_id"]),
		"assignments": _human_assignments(room),
		"affected_peer_ids": _human_peer_ids(room),
	})


func _randomize_active_slots(room: Dictionary) -> void:
	var active = RoomProtocol.active_team_ids(int(room["players_per_side"]))
	var slots: Dictionary = room["slots"]
	var participants = []
	for team_id in active:
		participants.append((slots[team_id] as Dictionary).duplicate(true))
	for index in range(participants.size() - 1, 0, -1):
		var swap_index = _rng.randi_range(0, index)
		var temporary = participants[index]
		participants[index] = participants[swap_index]
		participants[swap_index] = temporary
	for index in range(active.size()):
		var team_id = int(active[index])
		var participant: Dictionary = participants[index]
		slots[team_id] = participant
		if String(participant.get("kind", "")) == "human":
			_peer_teams[int(participant["peer_id"])] = team_id


func assignment_for_peer(peer_id_value: Variant) -> Dictionary:
	var error = RoomProtocol.peer_id_error(peer_id_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	var peer_id = int(peer_id_value)
	if not _peer_rooms.has(peer_id):
		return RoomProtocol.failure("peer_not_in_room")
	return RoomProtocol.success({
		"room_code": String(_peer_rooms[peer_id]),
		"team_id": int(_peer_teams[peer_id]),
	})


func room_code_for_peer(peer_id_value: Variant) -> String:
	if not RoomProtocol.peer_id_error(peer_id_value).is_empty():
		return ""
	return String(_peer_rooms.get(int(peer_id_value), ""))


func team_for_peer(peer_id_value: Variant) -> int:
	if not RoomProtocol.peer_id_error(peer_id_value).is_empty():
		return 0
	return int(_peer_teams.get(int(peer_id_value), 0))


func peer_ids_in_same_room(peer_id_value: Variant) -> Array:
	var context = _room_context_for_peer(peer_id_value)
	if not bool(context.get("ok", false)):
		return []
	return _human_peer_ids(context["room"])


func snapshot_for_peer(peer_id_value: Variant) -> Dictionary:
	var context = _room_context_for_peer(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	var peer_id = int(peer_id_value)
	var room: Dictionary = context["room"]
	var slots: Dictionary = room["slots"]
	var slot_snapshots = []
	var human_count = 0
	var ai_count = 0
	var active = RoomProtocol.active_team_ids(int(room["players_per_side"]))
	for team_id in range(1, RoomProtocol.MAX_PLAYERS + 1):
		var slot = {
			"team_id": team_id,
			"side": RoomProtocol.side_for_team(team_id),
			"side_slot_index": RoomProtocol.side_slot_index(team_id),
			"active": team_id in active,
			"occupied": slots.has(team_id),
			"kind": "empty",
			"display_name": "",
			"peer_id": 0,
			"ready": false,
			"is_local": false,
			"is_host": false,
		}
		if slots.has(team_id):
			var participant: Dictionary = slots[team_id]
			var kind = String(participant["kind"])
			slot["kind"] = kind
			slot["display_name"] = String(participant["display_name"])
			slot["ready"] = bool(participant["ready"])
			if kind == "human":
				var participant_peer_id = int(participant["peer_id"])
				slot["peer_id"] = participant_peer_id
				slot["is_local"] = participant_peer_id == peer_id
				slot["is_host"] = participant_peer_id == int(room["host_peer_id"])
				human_count += 1
			else:
				slot["ai_id"] = int(participant["ai_id"])
				ai_count += 1
		slot_snapshots.append(slot)

	var full_and_ready = _is_full_and_ready(room)
	return RoomProtocol.success({
		"room_code": String(room["room_code"]),
		"status": String(room["status"]),
		"players_per_side": int(room["players_per_side"]),
		"capacity": int(room["players_per_side"]) * 2,
		"fill_with_ai": bool(room["fill_with_ai"]),
		"host_peer_id": int(room["host_peer_id"]),
		"authority_peer_id": int(room["host_peer_id"]),
		"is_host": int(room["host_peer_id"]) == peer_id,
		"local_team_id": int(_peer_teams[peer_id]),
		"human_count": human_count,
		"ai_count": ai_count,
		"all_ready": full_and_ready,
		"can_start": (
			String(room["status"]) == RoomProtocol.LOBBY_STATUS
			and int(room["host_peer_id"]) == peer_id
			and full_and_ready
		),
		"revision": int(room["revision"]),
		"slots": slot_snapshots,
	})


func room_count() -> int:
	return _rooms.size()


func _room_context_for_peer(peer_id_value: Variant) -> Dictionary:
	var error = RoomProtocol.peer_id_error(peer_id_value)
	if not error.is_empty():
		return RoomProtocol.failure(error)
	var peer_id = int(peer_id_value)
	if not _peer_rooms.has(peer_id):
		return RoomProtocol.failure("peer_not_in_room")
	var room_code = String(_peer_rooms[peer_id])
	if not _rooms.has(room_code):
		return RoomProtocol.failure("room_not_found")
	return RoomProtocol.success({"room": _rooms[room_code]})


func _mutable_lobby_for_peer(peer_id_value: Variant) -> Dictionary:
	var context = _room_context_for_peer(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	if String(context["room"]["status"]) != RoomProtocol.LOBBY_STATUS:
		return RoomProtocol.failure("room_running")
	return context


func _mutable_lobby_for_host(peer_id_value: Variant) -> Dictionary:
	var context = _mutable_lobby_for_peer(peer_id_value)
	if not bool(context.get("ok", false)):
		return context
	if int(context["room"]["host_peer_id"]) != int(peer_id_value):
		return RoomProtocol.failure("host_only")
	return context


func _allocate_room_code() -> String:
	if _rooms.size() >= ROOM_CODE_SPACE:
		return ""
	for _attempt in range(RANDOM_CODE_ATTEMPTS):
		var candidate = "%06d" % _rng.randi_range(0, ROOM_CODE_SPACE - 1)
		if not _rooms.has(candidate):
			return candidate
	for offset in range(ROOM_CODE_SPACE):
		var value = posmod(_next_code_cursor + offset, ROOM_CODE_SPACE)
		var candidate = "%06d" % value
		if not _rooms.has(candidate):
			_next_code_cursor = posmod(value + 1, ROOM_CODE_SPACE)
			return candidate
	return ""


func _human_participant(peer_id: int, display_name: String, join_order: int) -> Dictionary:
	return {
		"kind": "human",
		"peer_id": peer_id,
		"display_name": display_name,
		"ready": false,
		"join_order": join_order,
	}


func _ai_participant() -> Dictionary:
	var ai_id = _next_ai_id
	_next_ai_id += 1
	return {
		"kind": "ai",
		"ai_id": ai_id,
		"display_name": "AI %d" % ai_id,
		"ready": true,
	}


func _available_join_team(room: Dictionary) -> int:
	var slots: Dictionary = room["slots"]
	var priority = RoomProtocol.join_priority(int(room["players_per_side"]))
	for team_id in priority:
		if not slots.has(team_id):
			return team_id
	for team_id in priority:
		if String(slots[team_id]["kind"]) == "ai":
			return team_id
	return 0


func _reconcile_ai_slots(room: Dictionary) -> void:
	var slots: Dictionary = room["slots"]
	var active = RoomProtocol.active_team_ids(int(room["players_per_side"]))
	for team_id in slots.keys():
		var participant: Dictionary = slots[team_id]
		if not team_id in active and String(participant["kind"]) == "ai":
			slots.erase(team_id)
		elif not bool(room["fill_with_ai"]) and String(participant["kind"]) == "ai":
			slots.erase(team_id)
	if not bool(room["fill_with_ai"]):
		return
	for team_id in active:
		if not slots.has(team_id):
			slots[team_id] = _ai_participant()


func _reset_human_ready(room: Dictionary) -> void:
	for participant in room["slots"].values():
		if String(participant["kind"]) == "human":
			participant["ready"] = false


func _human_peer_ids(room: Dictionary) -> Array:
	var result = []
	for team_id in range(1, RoomProtocol.MAX_PLAYERS + 1):
		if not room["slots"].has(team_id):
			continue
		var participant: Dictionary = room["slots"][team_id]
		if String(participant["kind"]) == "human":
			result.append(int(participant["peer_id"]))
	return result


func _human_assignments(room: Dictionary) -> Array:
	var result = []
	for team_id in range(1, RoomProtocol.MAX_PLAYERS + 1):
		if not room["slots"].has(team_id):
			continue
		var participant: Dictionary = room["slots"][team_id]
		if String(participant["kind"]) != "human":
			continue
		result.append({
			"peer_id": int(participant["peer_id"]),
			"team_id": team_id,
		})
	return result


func _oldest_human_peer_id(room: Dictionary) -> int:
	var oldest_peer_id = 0
	var oldest_order = 2147483647
	for participant in room["slots"].values():
		if String(participant["kind"]) != "human":
			continue
		var join_order = int(participant["join_order"])
		if join_order < oldest_order:
			oldest_order = join_order
			oldest_peer_id = int(participant["peer_id"])
	return oldest_peer_id


func _is_full_and_ready(room: Dictionary) -> bool:
	var slots: Dictionary = room["slots"]
	for team_id in RoomProtocol.active_team_ids(int(room["players_per_side"])):
		if not slots.has(team_id):
			return false
		var participant: Dictionary = slots[team_id]
		if String(participant["kind"]) == "human" and not bool(participant["ready"]):
			return false
	return true


func _touch_room(room: Dictionary) -> void:
	room["revision"] = int(room["revision"]) + 1
