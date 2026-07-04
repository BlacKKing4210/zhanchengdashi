extends RefCounted

const DB_VERSION = 1
const INITIAL_ELO = 1000
const MIN_ELO = 1000
const ELO_K_FACTOR = 32
const KING_STAR_ELO = 40

const RANKS = [
	{"key": "bronze", "name": "青铜", "min_elo": 1000, "max_elo": 1199, "max_stars": 3},
	{"key": "silver", "name": "白银", "min_elo": 1200, "max_elo": 1399, "max_stars": 3},
	{"key": "gold", "name": "黄金", "min_elo": 1400, "max_elo": 1599, "max_stars": 4},
	{"key": "diamond", "name": "钻石", "min_elo": 1600, "max_elo": 1799, "max_stars": 5},
	{"key": "king", "name": "王者", "min_elo": 1800, "max_elo": -1, "max_stars": -1},
]


static func default_profile() -> Dictionary:
	return {
		"player_id": "local_player",
		"name": "玩家",
		"elo": INITIAL_ELO,
		"matches": 0,
		"wins": 0,
		"losses": 0,
	}


static func rank_for_elo(elo: int) -> Dictionary:
	var selected = RANKS[0]
	for rank in RANKS:
		if elo >= int(rank["min_elo"]):
			selected = rank
	return selected.duplicate(true)


static func rank_for_key(rank_key: String) -> Dictionary:
	for rank in RANKS:
		if String(rank["key"]) == rank_key:
			return rank.duplicate(true)
	return RANKS[0].duplicate(true)


static func rank_key_for_elo(elo: int) -> String:
	return String(rank_for_elo(elo)["key"])


static func stars_for_elo(elo: int) -> int:
	var rank = rank_for_elo(elo)
	var min_elo = int(rank["min_elo"])
	var max_elo = int(rank["max_elo"])
	var max_stars = int(rank["max_stars"])
	if max_elo < 0:
		return max(1, floori(float(max(0, elo - min_elo)) / float(KING_STAR_ELO)) + 1)
	var span = max(1, max_elo - min_elo + 1)
	var star_step = max(1.0, float(span) / float(max_stars))
	return clampi(floori(float(max(0, elo - min_elo)) / star_step) + 1, 1, max_stars)


static func rank_state_for_elo(elo: int) -> Dictionary:
	var rank = rank_for_elo(elo)
	var stars = stars_for_elo(elo)
	return {
		"key": String(rank["key"]),
		"name": String(rank["name"]),
		"elo": elo,
		"stars": stars,
		"max_stars": int(rank["max_stars"]),
		"display": display_for_elo(elo),
	}


static func display_for_elo(elo: int) -> String:
	var rank = rank_for_elo(elo)
	return "%s %d星" % [String(rank["name"]), stars_for_elo(elo)]


static func elo_result(player_elo: int, opponent_elo: int, won: bool) -> Dictionary:
	var expected = 1.0 / (1.0 + pow(10.0, float(opponent_elo - player_elo) / 400.0))
	var score = 1.0 if won else 0.0
	var raw_delta = roundi(float(ELO_K_FACTOR) * (score - expected))
	if won:
		raw_delta = max(1, raw_delta)
	else:
		raw_delta = min(-1, raw_delta)
	var new_elo = max(MIN_ELO, player_elo + raw_delta)
	var delta = new_elo - player_elo
	return {
		"old_elo": player_elo,
		"new_elo": new_elo,
		"delta": delta,
		"old_rank": rank_state_for_elo(player_elo),
		"new_rank": rank_state_for_elo(new_elo),
		"opponent_elo": opponent_elo,
	}
