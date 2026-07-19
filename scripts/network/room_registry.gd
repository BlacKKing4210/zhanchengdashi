extends RefCounted

const RoomProtocol = preload("res://scripts/network/room_protocol.gd")
const RankAIDecks = preload("res://scripts/app/systems/rank_ai_decks.gd")

const ROOM_CODE_SPACE = 1000000
const RANDOM_CODE_ATTEMPTS = 64
const RANK_ORDER = ["bronze", "silver", "gold", "platinum", "diamond", "star", "king"]

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
	fill_with_ai_value: Variant = false,
	player_rank_value: Variant = {}
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
		1,
		player_rank_value
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
	player_name_value: Variant,
	player_rank_value: Variant = {}
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
		join_order,
		player_rank_value
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
	var departing_participant = (slots.get(team_id, {}) as Dictionary).duplicate(true)
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

	var running_takeover = String(room["status"]) == RoomProtocol.RUNNING_STATUS
	var takeover_participant = {}
	if running_takeover:
		takeover_participant = _takeover_ai_participant(departing_participant)
		slots[team_id] = takeover_participant
	if int(room["host_peer_id"]) == peer_id:
		room["host_peer_id"] = _oldest_human_peer_id(room)
	if String(room["status"]) == RoomProtocol.LOBBY_STATUS:
		_reset_human_ready(room)
		_reconcile_ai_slots(room)
	_touch_room(room)
	room_changed.emit(room_code)
	return RoomProtocol.success({
		"action": "ai_takeover" if running_takeover else "left",
		"room_code": room_code,
		"team_id": team_id,
		"ai_id": int(takeover_participant.get("ai_id", 0)),
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
			"rank_key": "bronze",
			"rank_stars": 1,
			"deck": [],
			"card_levels": {},
			"takeover": false,
		}
		if slots.has(team_id):
			var participant: Dictionary = slots[team_id]
			var kind = String(participant["kind"])
			slot["kind"] = kind
			slot["display_name"] = String(participant["display_name"])
			slot["ready"] = bool(participant["ready"])
			slot["rank_key"] = String(participant.get("rank_key", "bronze"))
			slot["rank_stars"] = maxi(1, int(participant.get("rank_stars", 1)))
			slot["deck"] = (participant.get("deck", []) as Array).duplicate() if typeof(participant.get("deck", [])) == TYPE_ARRAY else []
			slot["card_levels"] = (participant.get("card_levels", {}) as Dictionary).duplicate(true) if typeof(participant.get("card_levels", {})) == TYPE_DICTIONARY else {}
			if kind == "human":
				var participant_peer_id = int(participant["peer_id"])
				slot["peer_id"] = participant_peer_id
				slot["is_local"] = participant_peer_id == peer_id
				slot["is_host"] = participant_peer_id == int(room["host_peer_id"])
				human_count += 1
			else:
				slot["ai_id"] = int(participant["ai_id"])
				slot["takeover"] = bool(participant.get("takeover", false))
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


## Server-only roster snapshot used to freeze match analytics at match start.
## User IDs intentionally do not appear in ordinary client room snapshots.
func match_roster(room_code_value: Variant) -> Array:
	var room_code = String(room_code_value)
	if room_code.is_empty() or not _rooms.has(room_code):
		return []
	var room: Dictionary = _rooms[room_code]
	var slots: Dictionary = room["slots"]
	var roster = []
	for team_id_value in RoomProtocol.active_team_ids(int(room.get("players_per_side", 1))):
		var team_id = int(team_id_value)
		if not slots.has(team_id) or typeof(slots[team_id]) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = slots[team_id]
		if String(participant.get("kind", "")) != "human":
			continue
		var user_id = String(participant.get("user_id", "")).strip_edges()
		if user_id.is_empty():
			continue
		roster.append({
			"user_id": user_id,
			"team_id": team_id,
			"display_name": String(participant.get("display_name", "")),
			"rank_key": String(participant.get("rank_key", "bronze")),
			"rank_stars": maxi(1, int(participant.get("rank_stars", 1))),
			"elo": maxi(0, int(participant.get("elo", 1000))),
			"deck": (participant.get("deck", []) as Array).duplicate() if typeof(participant.get("deck", [])) == TYPE_ARRAY else [],
			"card_levels": (participant.get("card_levels", {}) as Dictionary).duplicate(true) if typeof(participant.get("card_levels", {})) == TYPE_DICTIONARY else {},
		})
	return roster


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


func _human_participant(peer_id: int, display_name: String, join_order: int, player_rank_value: Variant = {}) -> Dictionary:
	var player_rank = player_rank_value if typeof(player_rank_value) == TYPE_DICTIONARY else {}
	return {
		"kind": "human",
		"peer_id": peer_id,
		"user_id": String(player_rank.get("user_id", "")).strip_edges().left(80),
		"display_name": display_name,
		"ready": false,
		"join_order": join_order,
		"rank_key": String(player_rank.get("rank_key", "bronze")),
		"rank_stars": maxi(1, int(player_rank.get("rank_stars", player_rank.get("stars", 1)))),
		"elo": maxi(0, int(player_rank.get("elo", 1000))),
		"deck": (player_rank.get("deck", []) as Array).duplicate() if typeof(player_rank.get("deck", [])) == TYPE_ARRAY else [],
		"card_levels": (player_rank.get("card_levels", {}) as Dictionary).duplicate(true) if typeof(player_rank.get("card_levels", {})) == TYPE_DICTIONARY else {},
	}


func _ai_participant(rank_key: String = "bronze") -> Dictionary:
	var ai_id = _next_ai_id
	_next_ai_id += 1
	var roster = _ai_roster_for_rank(rank_key, ai_id)
	return {
		"kind": "ai",
		"ai_id": ai_id,
		"display_name": "AI %d" % ai_id,
		"ready": true,
		"rank_key": String(roster.get("rank_key", "bronze")),
		"rank_stars": 1,
		"deck": (roster.get("deck", []) as Array).duplicate(),
		"card_levels": (roster.get("card_levels", {}) as Dictionary).duplicate(true),
		"takeover": false,
	}


func _ai_roster_for_rank(rank_key: String, ai_id: int) -> Dictionary:
	var resolved_rank_key = rank_key if RANK_ORDER.has(rank_key) else "bronze"
	var mirrors = RankAIDecks.mirrors_for_rank(resolved_rank_key)
	if mirrors.is_empty():
		return RankAIDecks.validated_ai_roster([], {}, resolved_rank_key, ai_id)
	var mirror: Dictionary = mirrors[posmod(ai_id - 1, mirrors.size())]
	return RankAIDecks.validated_ai_roster(
		mirror.get("deck", []),
		mirror.get("card_levels", {}),
		resolved_rank_key,
		ai_id
	)


func _ai_rank_key_for_room(room: Dictionary) -> String:
	var best_rank_key = "bronze"
	var best_rank_index = 0
	var slots: Dictionary = room.get("slots", {})
	for participant_value in slots.values():
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		if String(participant.get("kind", "")) != "human":
			continue
		var candidate_rank_key = String(participant.get("rank_key", "bronze"))
		var candidate_index = RANK_ORDER.find(candidate_rank_key)
		if candidate_index > best_rank_index:
			best_rank_key = candidate_rank_key
			best_rank_index = candidate_index
	return best_rank_key


func _takeover_ai_participant(human: Dictionary) -> Dictionary:
	var rank_key = String(human.get("rank_key", "bronze"))
	var participant = _ai_participant(rank_key)
	var original_name = String(human.get("display_name", "玩家")).strip_edges()
	participant["display_name"] = "%s（AI）" % (original_name if not original_name.is_empty() else "玩家")
	participant["rank_key"] = rank_key
	participant["rank_stars"] = maxi(1, int(human.get("rank_stars", 1)))
	participant["elo"] = maxi(0, int(human.get("elo", 1000)))
	var roster = RankAIDecks.validated_ai_roster(
		human.get("deck", []),
		human.get("card_levels", {}),
		rank_key,
		int(participant.get("ai_id", 0))
	)
	participant["deck"] = (roster.get("deck", []) as Array).duplicate()
	participant["card_levels"] = (roster.get("card_levels", {}) as Dictionary).duplicate(true)
	participant["takeover"] = true
	return participant


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
	var ai_rank_key = _ai_rank_key_for_room(room)
	for participant_value in slots.values():
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		if String(participant.get("kind", "")) != "ai" or bool(participant.get("takeover", false)):
			continue
		var roster = _ai_roster_for_rank(ai_rank_key, int(participant.get("ai_id", 0)))
		participant["rank_key"] = String(roster.get("rank_key", "bronze"))
		participant["rank_stars"] = 1
		participant["deck"] = (roster.get("deck", []) as Array).duplicate()
		participant["card_levels"] = (roster.get("card_levels", {}) as Dictionary).duplicate(true)
	for team_id in active:
		if not slots.has(team_id):
			slots[team_id] = _ai_participant(ai_rank_key)


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
