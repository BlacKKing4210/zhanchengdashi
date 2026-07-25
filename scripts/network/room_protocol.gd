## Compatibility facade for existing server callers.
## New projects may use res://scripts/foundation/room/room_rules.gd directly.
extends RefCounted

const RoomRules = preload("res://scripts/foundation/room/room_rules.gd")
const MIN_PLAYERS_PER_SIDE = 1
const MAX_PLAYERS_PER_SIDE = 3
const MAX_PLAYERS = 6
const ROOM_CODE_LENGTH = 6
const PLAYER_NAME_MAX_LENGTH = 24
const SIDE_A_TEAM_IDS = [1, 2, 3]
const SIDE_B_TEAM_IDS = [4, 5, 6]
const JOIN_PRIORITY = [1, 4, 2, 5, 3, 6]
const LOBBY_STATUS = RoomRules.LOBBY_STATUS
const RUNNING_STATUS = RoomRules.RUNNING_STATUS

static func configure(overrides: Dictionary) -> Dictionary:
	return RoomRules.configure(overrides)

static func peer_id_error(value: Variant) -> String:
	return RoomRules.peer_id_error(value)

static func player_name_error(value: Variant) -> String:
	return RoomRules.player_name_error(value)

static func normalized_player_name(value: String) -> String:
	return RoomRules.normalized_player_name(value)

static func players_per_side_error(value: Variant) -> String:
	return RoomRules.players_per_side_error(value)

static func bool_error(value: Variant, field_name: String) -> String:
	return RoomRules.bool_error(value, field_name)

static func room_code_error(value: Variant) -> String:
	return RoomRules.room_code_error(value)

static func team_id_error(value: Variant) -> String:
	return RoomRules.team_id_error(value)

static func active_team_ids(value: int) -> Array:
	return RoomRules.active_team_ids(value)

static func join_priority(value: int) -> Array:
	return RoomRules.join_priority(value)

static func side_for_team(value: int) -> String:
	return RoomRules.side_for_team(value)

static func side_slot_index(value: int) -> int:
	return RoomRules.side_slot_index(value)

static func all_team_ids() -> Array:
	return RoomRules.all_team_ids()

static func max_players() -> int:
	return RoomRules.max_players()

static func success(extra: Dictionary = {}) -> Dictionary:
	return RoomRules.success(extra)

static func failure(error: String) -> Dictionary:
	return RoomRules.failure(error)
