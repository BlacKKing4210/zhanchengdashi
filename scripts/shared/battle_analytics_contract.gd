extends RefCounted

const CLASSIC_RANKED_AI = "classic_ranked_ai"
const MULTIPLAYER_1V1 = "multiplayer_1v1"
const MULTIPLAYER_2V2 = "multiplayer_2v2"
const MULTIPLAYER_3V3 = "multiplayer_3v3"
const FREE_FOR_ALL_6 = "free_for_all_6"
const LEGACY_UNKNOWN = "legacy_unknown"

const SERVER_AUTHORITATIVE = "server_authoritative"
const AUTHENTICATED_CLIENT_REPORTED = "authenticated_client_reported"
const LEGACY_SERVER_RECORDED = "legacy_server_recorded"

const BATTLE_TYPES = [
	CLASSIC_RANKED_AI,
	MULTIPLAYER_1V1,
	MULTIPLAYER_2V2,
	MULTIPLAYER_3V3,
	FREE_FOR_ALL_6,
	LEGACY_UNKNOWN,
]


static func normalize_battle_type(value: Variant) -> String:
	var candidate = String(value).strip_edges().to_lower()
	return candidate if candidate in BATTLE_TYPES else LEGACY_UNKNOWN


static func multiplayer_type(players_per_side: int) -> String:
	match clampi(players_per_side, 1, 3):
		1:
			return MULTIPLAYER_1V1
		2:
			return MULTIPLAYER_2V2
		_:
			return MULTIPLAYER_3V3


static func is_client_reportable(value: Variant) -> bool:
	return normalize_battle_type(value) in [
		CLASSIC_RANKED_AI,
		MULTIPLAYER_1V1,
		MULTIPLAYER_2V2,
		MULTIPLAYER_3V3,
		FREE_FOR_ALL_6,
	]


static func normalize_authority(value: Variant) -> String:
	var candidate = String(value).strip_edges().to_lower()
	if candidate in [SERVER_AUTHORITATIVE, AUTHENTICATED_CLIENT_REPORTED, LEGACY_SERVER_RECORDED]:
		return candidate
	return LEGACY_SERVER_RECORDED


static func local_terminal_result(battle_type_value: Variant, outcome_value: Variant, placement_value: Variant = 0) -> Dictionary:
	var battle_type = normalize_battle_type(battle_type_value)
	if not is_client_reportable(battle_type):
		return {"ok": false, "error": "invalid_battle_type"}
	var outcome = String(outcome_value).strip_edges().to_lower()
	if outcome not in ["win", "loss", "draw"]:
		return {"ok": false, "error": "invalid_outcome"}
	if battle_type == FREE_FOR_ALL_6:
		var placement = int(placement_value)
		if placement < 1 or placement > 6:
			return {"ok": false, "error": "invalid_placement"}
		var placements = {1: placement}
		var remaining = []
		for rank in range(1, 7):
			if rank != placement:
				remaining.append(rank)
		for team_id in range(2, 7):
			placements[team_id] = remaining[team_id - 2]
		var outcomes = {}
		for team_id in range(1, 7):
			outcomes[team_id] = "win" if int(placements[team_id]) == 1 else "loss"
		return {"ok": true, "team_outcomes": outcomes, "placements_by_team": placements}
	var opposing_outcome = "draw" if outcome == "draw" else ("loss" if outcome == "win" else "win")
	var placements = {}
	if outcome != "draw":
		placements = {1: 1 if outcome == "win" else 2, 2: 2 if outcome == "win" else 1}
	return {
		"ok": true,
		"team_outcomes": {1: outcome, 2: opposing_outcome},
		"placements_by_team": placements,
	}
