extends RefCounted

## Dedicated-server-owned, privacy-safe analytics projection for completed matches.
##
## This store deliberately accepts only the server-frozen roster and sanitized
## terminal result. It never serializes account records, credentials, device
## identifiers, refresh tokens, or gameplay snapshots.

const DEFAULT_STORAGE_PATH = "user://server/match_analytics.json"
const DEFAULT_DASHBOARD_PATH = "user://server/dashboard_snapshot.json"
const MAX_MATCH_HISTORY = 5000
const MAX_DECK_SIZE = 8
const MAX_CARD_LEVEL = 99
const MAX_USER_ID_LENGTH = 80
const MAX_DISPLAY_NAME_LENGTH = 40
const MAX_ANIMAL_NAME_LENGTH = 48
const MAX_MATCH_ID_LENGTH = 128
const MAX_ROOM_CODE_LENGTH = 24
const MAX_MAP_ID_LENGTH = 64

const RANK_ORDER = {
	"bronze": 0,
	"silver": 1,
	"gold": 2,
	"platinum": 3,
	"diamond": 4,
	"star": 5,
	"king": 6,
}

var storage_path = DEFAULT_STORAGE_PATH
var dashboard_path = DEFAULT_DASHBOARD_PATH
var data: Dictionary = {}


func _init(path_override: String = "", dashboard_path_override: String = "") -> void:
	if not path_override.is_empty():
		storage_path = path_override
	if not dashboard_path_override.is_empty():
		dashboard_path = dashboard_path_override
	_load()
	_ensure_shape()
	_write_dashboard_snapshot()


func begin_match(match_value: Variant, roster_value: Variant, animal_card_ids_value: Variant = []) -> Dictionary:
	if typeof(match_value) != TYPE_DICTIONARY:
		return _failure("invalid_match")
	var source_match: Dictionary = match_value
	var match_id = _safe_identifier(source_match.get("match_id", ""), MAX_MATCH_ID_LENGTH)
	if match_id.is_empty():
		return _failure("invalid_match_id")

	_ensure_shape()
	var animal_catalog = _ensure_animal_catalog(animal_card_ids_value)
	var matches: Dictionary = data["matches"]
	if matches.has(match_id):
		return _success({"match_id": match_id, "created": false, "idempotent": true})

	var now = int(Time.get_unix_time_from_system())
	var roster = _normalize_roster(roster_value, animal_catalog)
	var record = {
		"match_id": match_id,
		"room_code": _safe_identifier(source_match.get("room_code", ""), MAX_ROOM_CODE_LENGTH),
		"map_id": _safe_identifier(source_match.get("map_id", ""), MAX_MAP_ID_LENGTH),
		"started_at_unix": maxi(0, int(source_match.get("started_at_unix", now))),
		"finalized_at_unix": 0,
		"state": "active",
		"result_incomplete": false,
		"players": roster,
		"result": {},
	}
	matches[match_id] = record
	var match_order: Array = data["match_order"]
	match_order.append(match_id)
	data["match_order"] = match_order
	_trim_match_history()
	if not _persist():
		return _failure("storage_error")
	return _success({
		"match_id": match_id,
		"created": true,
		"tracked_player_count": roster.size(),
		"animal_catalog_available": not animal_catalog.is_empty(),
	})


func register_animal_catalog(animal_card_ids_value: Variant) -> Dictionary:
	_ensure_shape()
	var animal_catalog = _ensure_animal_catalog(animal_card_ids_value)
	if not _persist():
		return _failure("storage_error")
	return _success({
		"animal_catalog_available": not animal_catalog.is_empty(),
		"animal_count": animal_catalog.size(),
	})


func finalize_match(match_id_value: Variant, result_value: Variant) -> Dictionary:
	var match_id = _safe_identifier(match_id_value, MAX_MATCH_ID_LENGTH)
	if match_id.is_empty():
		return _failure("invalid_match_id")
	_ensure_shape()
	var matches: Dictionary = data["matches"]
	if not matches.has(match_id) or typeof(matches[match_id]) != TYPE_DICTIONARY:
		return _failure("match_not_found")
	var record: Dictionary = (matches[match_id] as Dictionary).duplicate(true)
	if String(record.get("state", "")) == "finalized":
		return _success({"match_id": match_id, "finalized": false, "idempotent": true})

	var normalized_result = _normalize_terminal_result(result_value, record.get("players", []))
	if bool(normalized_result["incomplete"]):
		return _failure("incomplete_result")
	var now = int(Time.get_unix_time_from_system())
	record["state"] = "finalized"
	record["finalized_at_unix"] = now
	record["result_incomplete"] = bool(normalized_result["incomplete"])
	record["result"] = normalized_result["result"]
	matches[match_id] = record

	var team_outcomes: Dictionary = normalized_result["team_outcomes"]
	for player_value in record.get("players", []):
		if typeof(player_value) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = player_value
		var team_id = int(player.get("team_id", 0))
		var outcome = String(team_outcomes.get(team_id, ""))
		if outcome.is_empty():
			continue
		_apply_player_result(player, outcome, now)

	if not _persist():
		return _failure("storage_error")
	return _success({
		"match_id": match_id,
		"finalized": true,
		"idempotent": false,
		"result_incomplete": bool(normalized_result["incomplete"]),
	})


func dashboard_snapshot() -> Dictionary:
	_ensure_shape()
	var generated_at_unix = int(Time.get_unix_time_from_system())
	var active_since_unix = generated_at_unix - 24 * 60 * 60
	var leaderboard = []
	var players: Dictionary = data["players"]
	var active_player_count = 0
	var completed_player_results = 0
	for user_id_value in players:
		if typeof(players[user_id_value]) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = players[user_id_value]
		leaderboard.append(_dashboard_player(player))
		if int(player.get("last_seen_at_unix", 0)) >= active_since_unix:
			active_player_count += 1
		completed_player_results += maxi(0, int(player.get("matches", 0)))
	leaderboard.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _leaderboard_before(a, b)
	)
	for index in range(leaderboard.size()):
		if typeof(leaderboard[index]) != TYPE_DICTIONARY:
			continue
		var ranked_entry: Dictionary = leaderboard[index]
		ranked_entry["rank"] = index + 1
		leaderboard[index] = ranked_entry

	var top_decks = []
	for entry_value in leaderboard:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		top_decks.append({
			"rank": int(entry.get("rank", top_decks.size() + 1)),
			"user_id": String(entry.get("user_id", "")),
			"display_name": String(entry.get("display_name", "")),
			"rank_key": String(entry.get("rank_key", "bronze")),
			"rank_stars": int(entry.get("rank_stars", 1)),
			"elo": maxi(0, int(entry.get("elo", 1000))),
			"deck": (entry.get("deck", []) as Array).duplicate(),
			"card_levels": (entry.get("card_levels", {}) as Dictionary).duplicate(true),
			"matches": int(entry.get("matches", 0)),
			"wins": int(entry.get("wins", 0)),
			"losses": int(entry.get("losses", 0)),
			"draws": int(entry.get("draws", 0)),
			"win_rate": entry.get("win_rate", null),
		})
		if top_decks.size() >= 100:
			break

	var animals = []
	var animal_records: Dictionary = data["animals"]
	for card_id_value in animal_records:
		if typeof(animal_records[card_id_value]) != TYPE_DICTIONARY:
			continue
		var animal: Dictionary = animal_records[card_id_value]
		var appearances = maxi(0, int(animal.get("appearances", 0)))
		animals.append({
			"card_id": String(animal.get("card_id", card_id_value)),
			"name": _safe_animal_name(animal.get("name", ""), String(animal.get("card_id", card_id_value))),
			"games": appearances,
			"appearances": appearances,
			"wins": maxi(0, int(animal.get("wins", 0))),
			"losses": maxi(0, int(animal.get("losses", 0))),
			"draws": maxi(0, int(animal.get("draws", 0))),
			"win_rate": float(animal.get("wins", 0)) / float(appearances) if appearances > 0 else null,
			"pick_rate": float(appearances) / float(completed_player_results) if completed_player_results > 0 else null,
		})
	animals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("appearances", 0)) != int(b.get("appearances", 0)):
			return int(a.get("appearances", 0)) > int(b.get("appearances", 0))
		return String(a.get("card_id", "")) < String(b.get("card_id", ""))
	)

	return {
		"version": 1,
		"generated_at_unix": generated_at_unix,
		"overview": {
			"matches": _completed_match_count(),
			"players": leaderboard.size(),
			"active_24h": active_player_count,
			"season": "",
			"source": "server_recorded_host_authority_full_human_online",
		},
		"leaderboard": leaderboard,
		"top_decks": top_decks,
		"animals": animals,
		"recent_matches": _dashboard_recent_matches(),
	}


func get_match(match_id_value: Variant) -> Dictionary:
	var match_id = _safe_identifier(match_id_value, MAX_MATCH_ID_LENGTH)
	if match_id.is_empty() or not data.get("matches", {}).has(match_id):
		return {}
	var value = data["matches"][match_id]
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _normalize_roster(value: Variant, animal_catalog: Dictionary) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var seen_user_ids = {}
	for raw_player in value:
		if typeof(raw_player) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = raw_player
		var user_id = _safe_identifier(source.get("user_id", ""), MAX_USER_ID_LENGTH)
		var team_id = int(source.get("team_id", 0))
		if user_id.is_empty() or seen_user_ids.has(user_id) or team_id < 1 or team_id > 6:
			continue
		seen_user_ids[user_id] = true
		var deck = _normalize_deck(source.get("deck", []))
		var levels = _normalize_card_levels(source.get("card_levels", {}), deck)
		var animal_deck = []
		if not animal_catalog.is_empty():
			for card_id in deck:
				if animal_catalog.has(card_id):
					animal_deck.append(card_id)
		result.append({
			"user_id": user_id,
			"team_id": team_id,
			"display_name": _safe_display_name(source.get("display_name", ""), user_id),
			"rank_key": _safe_rank_key(source.get("rank_key", "bronze")),
			"rank_stars": maxi(1, int(source.get("rank_stars", source.get("stars", 1)))),
			"elo": maxi(0, int(source.get("elo", 1000))),
			"deck": deck,
			"card_levels": levels,
			"animal_deck": animal_deck,
		})
	return result


func _normalize_terminal_result(value: Variant, players_value: Variant) -> Dictionary:
	var team_outcomes: Dictionary = {}
	var placements: Dictionary = {}
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		var raw_outcomes = source.get("team_outcomes", {})
		if typeof(raw_outcomes) == TYPE_DICTIONARY:
			for raw_team in raw_outcomes:
				var team_id = int(raw_team)
				var outcome = _safe_outcome(raw_outcomes[raw_team])
				if team_id >= 1 and team_id <= 6 and not outcome.is_empty():
					team_outcomes[team_id] = outcome
		var raw_placements = source.get("placements_by_team", {})
		if typeof(raw_placements) == TYPE_DICTIONARY:
			for raw_team in raw_placements:
				var team_id = int(raw_team)
				var placement = int(raw_placements[raw_team])
				if team_id >= 1 and team_id <= 6 and placement > 0:
					placements[team_id] = placement

	var incomplete = team_outcomes.is_empty()
	if typeof(players_value) == TYPE_ARRAY:
		for raw_player in players_value:
			if typeof(raw_player) != TYPE_DICTIONARY:
				continue
			if not team_outcomes.has(int((raw_player as Dictionary).get("team_id", 0))):
				incomplete = true
				break
	return {
		"incomplete": incomplete,
		"team_outcomes": team_outcomes,
		"result": {
			"team_outcomes": team_outcomes.duplicate(true),
			"placements_by_team": placements.duplicate(true),
		},
	}


func _apply_player_result(player: Dictionary, outcome: String, timestamp: int) -> void:
	var user_id = String(player.get("user_id", ""))
	if user_id.is_empty():
		return
	_upsert_player_snapshot(player, timestamp)
	var players: Dictionary = data["players"]
	var record: Dictionary = (players.get(user_id, {}) as Dictionary).duplicate(true)
	record["matches"] = maxi(0, int(record.get("matches", 0))) + 1
	match outcome:
		"win":
			record["wins"] = maxi(0, int(record.get("wins", 0))) + 1
		"loss":
			record["losses"] = maxi(0, int(record.get("losses", 0))) + 1
		"draw":
			record["draws"] = maxi(0, int(record.get("draws", 0))) + 1
	record["last_match_at_unix"] = timestamp
	players[user_id] = record

	for card_id_value in player.get("animal_deck", []):
		var card_id = String(card_id_value)
		if not card_id.is_empty():
			_apply_animal_result(card_id, outcome)


func _apply_animal_result(card_id: String, outcome: String) -> void:
	var animals: Dictionary = data["animals"]
	var record: Dictionary = (animals.get(card_id, _empty_animal_record(card_id)) as Dictionary).duplicate(true)
	record["appearances"] = maxi(0, int(record.get("appearances", 0))) + 1
	match outcome:
		"win":
			record["wins"] = maxi(0, int(record.get("wins", 0))) + 1
		"loss":
			record["losses"] = maxi(0, int(record.get("losses", 0))) + 1
		"draw":
			record["draws"] = maxi(0, int(record.get("draws", 0))) + 1
	animals[card_id] = record


func _upsert_player_snapshot(player: Dictionary, timestamp: int) -> void:
	var user_id = String(player.get("user_id", ""))
	if user_id.is_empty():
		return
	var players: Dictionary = data["players"]
	var existing = players.get(user_id, {})
	var record: Dictionary = (existing as Dictionary).duplicate(true) if typeof(existing) == TYPE_DICTIONARY else _empty_player_record(user_id)
	record["user_id"] = user_id
	record["display_name"] = _safe_display_name(player.get("display_name", record.get("display_name", "")), user_id)
	record["rank_key"] = _safe_rank_key(player.get("rank_key", record.get("rank_key", "bronze")))
	record["rank_stars"] = maxi(1, int(player.get("rank_stars", record.get("rank_stars", 1))))
	record["elo"] = maxi(0, int(player.get("elo", record.get("elo", 1000))))
	record["deck"] = _normalize_deck(player.get("deck", record.get("deck", [])))
	record["card_levels"] = _normalize_card_levels(player.get("card_levels", record.get("card_levels", {})), record["deck"])
	record["last_seen_at_unix"] = timestamp
	players[user_id] = record


func _ensure_animal_catalog(value: Variant) -> Dictionary:
	var catalog = {}
	if typeof(value) == TYPE_ARRAY:
		for raw_id in value:
			var card_id = _safe_identifier(raw_id, 80)
			if not card_id.is_empty():
				catalog[card_id] = card_id
	elif typeof(value) == TYPE_DICTIONARY:
		for raw_id in value:
			var card_id = _safe_identifier(raw_id, 80)
			if not card_id.is_empty():
				catalog[card_id] = _safe_animal_name(value[raw_id], card_id)
	var animals: Dictionary = data["animals"]
	for card_id in catalog:
		var normalized_id = String(card_id)
		var animal_name = _safe_animal_name(catalog[card_id], normalized_id)
		var record: Dictionary = (animals.get(normalized_id, _empty_animal_record(normalized_id, animal_name)) as Dictionary).duplicate(true)
		record["card_id"] = normalized_id
		record["name"] = animal_name
		animals[normalized_id] = record
	return catalog


func _trim_match_history() -> void:
	var match_order: Array = data["match_order"]
	var matches: Dictionary = data["matches"]
	while match_order.size() > MAX_MATCH_HISTORY:
		var oldest_id = String(match_order.pop_front())
		matches.erase(oldest_id)
	data["match_order"] = match_order


func _completed_match_count() -> int:
	var completed_matches = 0
	var matches: Dictionary = data["matches"]
	for match_id_value in matches:
		if typeof(matches[match_id_value]) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = matches[match_id_value]
		if String(record.get("state", "")) == "finalized" and not bool(record.get("result_incomplete", false)):
			completed_matches += 1
	return completed_matches


func _dashboard_player(player: Dictionary) -> Dictionary:
	var matches = maxi(0, int(player.get("matches", 0)))
	var wins = maxi(0, int(player.get("wins", 0)))
	return {
		"user_id": String(player.get("user_id", "")),
		"display_name": _safe_display_name(player.get("display_name", ""), String(player.get("user_id", ""))),
		"rank_key": _safe_rank_key(player.get("rank_key", "bronze")),
		"rank_stars": maxi(1, int(player.get("rank_stars", 1))),
		"elo": maxi(0, int(player.get("elo", 1000))),
		"deck": _normalize_deck(player.get("deck", [])),
		"card_levels": _normalize_card_levels(player.get("card_levels", {}), player.get("deck", [])),
		"matches": matches,
		"wins": wins,
		"losses": maxi(0, int(player.get("losses", 0))),
		"draws": maxi(0, int(player.get("draws", 0))),
		"win_rate": float(wins) / float(matches) if matches > 0 else null,
		"last_match_at_unix": maxi(0, int(player.get("last_match_at_unix", 0))),
	}


func _dashboard_recent_matches() -> Array:
	var result = []
	var match_order: Array = data["match_order"]
	var matches: Dictionary = data["matches"]
	for index in range(match_order.size() - 1, -1, -1):
		var match_id = String(match_order[index])
		if not matches.has(match_id) or typeof(matches[match_id]) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = matches[match_id]
		if String(record.get("state", "")) != "finalized" or bool(record.get("result_incomplete", false)):
			continue
		var players = []
		var team_outcomes = {}
		var raw_result = record.get("result", {})
		if typeof(raw_result) == TYPE_DICTIONARY:
			var raw_outcomes = (raw_result as Dictionary).get("team_outcomes", {})
			if typeof(raw_outcomes) == TYPE_DICTIONARY:
				for raw_team_id in raw_outcomes:
					var team_id = int(raw_team_id)
					var outcome = _safe_outcome(raw_outcomes[raw_team_id])
					if team_id >= 1 and team_id <= 6 and not outcome.is_empty():
						team_outcomes[team_id] = outcome
		for raw_player in record.get("players", []):
			if typeof(raw_player) != TYPE_DICTIONARY:
				continue
			var player: Dictionary = raw_player
			players.append({
				"user_id": String(player.get("user_id", "")),
				"display_name": _safe_display_name(player.get("display_name", ""), String(player.get("user_id", ""))),
				"team_id": int(player.get("team_id", 0)),
				"rank_key": _safe_rank_key(player.get("rank_key", "bronze")),
				"rank_stars": maxi(1, int(player.get("rank_stars", 1))),
			})
		result.append({
			"match_id": String(record.get("match_id", match_id)),
			"room_code": String(record.get("room_code", "")),
			"map_id": String(record.get("map_id", "")),
			"started_at_unix": maxi(0, int(record.get("started_at_unix", 0))),
			"finalized_at_unix": maxi(0, int(record.get("finalized_at_unix", 0))),
			"state": String(record.get("state", "active")),
			"result_incomplete": bool(record.get("result_incomplete", false)),
			"team_outcomes": team_outcomes,
			"players": players,
		})
		if result.size() >= 100:
			break
	return result


func _leaderboard_before(a: Dictionary, b: Dictionary) -> bool:
	var a_rank = int(RANK_ORDER.get(String(a.get("rank_key", "bronze")), -1))
	var b_rank = int(RANK_ORDER.get(String(b.get("rank_key", "bronze")), -1))
	if a_rank != b_rank:
		return a_rank > b_rank
	if int(a.get("rank_stars", 1)) != int(b.get("rank_stars", 1)):
		return int(a.get("rank_stars", 1)) > int(b.get("rank_stars", 1))
	if int(a.get("wins", 0)) != int(b.get("wins", 0)):
		return int(a.get("wins", 0)) > int(b.get("wins", 0))
	return String(a.get("user_id", "")) < String(b.get("user_id", ""))


func _normalize_deck(value: Variant) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_card_id in value:
		var card_id = _safe_identifier(raw_card_id, 80)
		if not card_id.is_empty() and not result.has(card_id):
			result.append(card_id)
		if result.size() >= MAX_DECK_SIZE:
			break
	return result


func _normalize_card_levels(value: Variant, deck_value: Variant) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var deck = _normalize_deck(deck_value)
	var result = {}
	for card_id in deck:
		result[card_id] = clampi(int(source.get(card_id, 1)), 1, MAX_CARD_LEVEL)
	return result


func _safe_identifier(value: Variant, max_length: int) -> String:
	var result = String(value).strip_edges().replace("\n", "").replace("\r", "").replace("\t", "")
	return result.left(max_length)


func _safe_display_name(value: Variant, fallback_user_id: String) -> String:
	var result = _safe_identifier(value, MAX_DISPLAY_NAME_LENGTH)
	if not result.is_empty():
		return result
	return "玩家 " + fallback_user_id.right(8) if not fallback_user_id.is_empty() else "玩家"


func _safe_animal_name(value: Variant, fallback_card_id: String) -> String:
	var result = _safe_identifier(value, MAX_ANIMAL_NAME_LENGTH)
	return result if not result.is_empty() else fallback_card_id


func _safe_rank_key(value: Variant) -> String:
	var rank_key = _safe_identifier(value, 24).to_lower()
	return rank_key if RANK_ORDER.has(rank_key) else "bronze"


func _safe_outcome(value: Variant) -> String:
	var outcome = String(value).strip_edges().to_lower()
	return outcome if outcome in ["win", "loss", "draw"] else ""


func _empty_player_record(user_id: String) -> Dictionary:
	return {
		"user_id": user_id,
		"display_name": _safe_display_name("", user_id),
		"rank_key": "bronze",
		"rank_stars": 1,
		"elo": 1000,
		"deck": [],
		"card_levels": {},
		"matches": 0,
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"last_seen_at_unix": 0,
		"last_match_at_unix": 0,
	}


func _empty_animal_record(card_id: String, name: String = "") -> Dictionary:
	return {
		"card_id": card_id,
		"name": _safe_animal_name(name, card_id),
		"appearances": 0,
		"wins": 0,
		"losses": 0,
		"draws": 0,
	}


func _ensure_shape() -> void:
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	data["version"] = 1
	if not data.has("matches") or typeof(data["matches"]) != TYPE_DICTIONARY:
		data["matches"] = {}
	if not data.has("match_order") or typeof(data["match_order"]) != TYPE_ARRAY:
		data["match_order"] = []
	if not data.has("players") or typeof(data["players"]) != TYPE_DICTIONARY:
		data["players"] = {}
	if not data.has("animals") or typeof(data["animals"]) != TYPE_DICTIONARY:
		data["animals"] = {}


func _load() -> void:
	data = {}
	if not FileAccess.file_exists(storage_path):
		return
	var file = FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		data = (parsed as Dictionary).duplicate(true)


func _persist() -> bool:
	if not _atomic_write_json(storage_path, data):
		return false
	return _write_dashboard_snapshot()


func _write_dashboard_snapshot() -> bool:
	return _atomic_write_json(dashboard_path, dashboard_snapshot())


func _atomic_write_json(path: String, payload: Dictionary) -> bool:
	var directory = path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var temporary_path = path + ".tmp"
	var file = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	var absolute_path = ProjectSettings.globalize_path(path)
	var absolute_temporary_path = ProjectSettings.globalize_path(temporary_path)
	if DirAccess.rename_absolute(absolute_temporary_path, absolute_path) == OK:
		return true
	if not FileAccess.file_exists(path):
		return false

	var backup_path = path + ".previous"
	var absolute_backup_path = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	if DirAccess.rename_absolute(absolute_path, absolute_backup_path) != OK:
		return false
	if DirAccess.rename_absolute(absolute_temporary_path, absolute_path) == OK:
		DirAccess.remove_absolute(absolute_backup_path)
		return true
	DirAccess.rename_absolute(absolute_backup_path, absolute_path)
	return false


func _success(extra: Dictionary = {}) -> Dictionary:
	var result = {"ok": true}
	result.merge(extra, true)
	return result


func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
