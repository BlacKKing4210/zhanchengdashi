extends RefCounted

const DB_VERSION = 3
const INITIAL_ELO = 1000
const INITIAL_RANK_KEY = "bronze"
const INITIAL_STARS = 1
const KING_STAR_ELO = 40

const RANKS = [
	{"key": "bronze", "name": "青铜", "min_elo": 1000, "max_elo": 1359, "max_stars": 9},
	{"key": "silver", "name": "白银", "min_elo": 1360, "max_elo": 1719, "max_stars": 9},
	{"key": "gold", "name": "黄金", "min_elo": 1720, "max_elo": 2359, "max_stars": 16},
	{"key": "platinum", "name": "铂金", "min_elo": 2360, "max_elo": 2999, "max_stars": 16},
	{"key": "diamond", "name": "钻石", "min_elo": 3000, "max_elo": 3999, "max_stars": 25},
	{"key": "star", "name": "星耀", "min_elo": 4000, "max_elo": 4999, "max_stars": 25},
	{"key": "king", "name": "王者", "min_elo": 5000, "max_elo": -1, "max_stars": -1},
]

const RANK_VISUALS = {
	"bronze": {"castle_key": "bronze", "panel_color": "#513b33", "accent_color": "#c98733", "text_color": "#fff1d0"},
	"silver": {"castle_key": "silver", "panel_color": "#384a5f", "accent_color": "#79a9e3", "text_color": "#eef5ff"},
	"gold": {"castle_key": "gold", "panel_color": "#6b3a22", "accent_color": "#e6b83c", "text_color": "#fff0b0"},
	"platinum": {"castle_key": "platinum", "panel_color": "#244d55", "accent_color": "#50b7b0", "text_color": "#dff8ef"},
	"diamond": {"castle_key": "diamond", "panel_color": "#164b70", "accent_color": "#52c7f2", "text_color": "#e9fbff"},
	"star": {"castle_key": "star", "panel_color": "#2d265d", "accent_color": "#a477f2", "text_color": "#ffd56b"},
	"king": {"castle_key": "king", "panel_color": "#671f24", "accent_color": "#e3a52e", "text_color": "#fff1c2"},
}


static func default_profile() -> Dictionary:
	return {
		"player_id": "local_player",
		"name": "玩家",
		"elo": INITIAL_ELO,
		"rank_key": INITIAL_RANK_KEY,
		"stars": INITIAL_STARS,
		"matches": 0,
		"wins": 0,
		"losses": 0,
	}


static func normalize_profile(profile: Variant) -> Dictionary:
	var normalized = default_profile()
	var has_rank_state = false
	if typeof(profile) == TYPE_DICTIONARY:
		has_rank_state = profile.has("rank_key") and profile.has("stars")
		for key in profile.keys():
			normalized[key] = profile[key]
	if not has_rank_state:
		var legacy_state = rank_state_for_elo(int(normalized.get("elo", INITIAL_ELO)))
		normalized["rank_key"] = String(legacy_state["key"])
		normalized["stars"] = int(legacy_state["stars"])
	var rank_key = String(normalized.get("rank_key", INITIAL_RANK_KEY))
	if rank_index_for_key(rank_key) < 0:
		rank_key = INITIAL_RANK_KEY
	normalized["rank_key"] = rank_key
	normalized["stars"] = clamp_stars_for_rank(rank_key, int(normalized.get("stars", INITIAL_STARS)))
	normalized["matches"] = int(normalized.get("matches", 0))
	normalized["wins"] = int(normalized.get("wins", 0))
	normalized["losses"] = int(normalized.get("losses", 0))
	return normalized


static func rank_for_elo(elo: int) -> Dictionary:
	var selected = RANKS[0]
	for rank in RANKS:
		if elo >= int(rank["min_elo"]):
			selected = rank
	return selected.duplicate(true)


static func rank_for_key(rank_key: String) -> Dictionary:
	var index = rank_index_for_key(rank_key)
	if index >= 0:
		return RANKS[index].duplicate(true)
	return RANKS[0].duplicate(true)


static func visual_for_key(rank_key: String) -> Dictionary:
	var resolved_key = rank_key if RANK_VISUALS.has(rank_key) else INITIAL_RANK_KEY
	return (RANK_VISUALS[resolved_key] as Dictionary).duplicate(true)


static func rank_index_for_key(rank_key: String) -> int:
	for i in range(RANKS.size()):
		if String(RANKS[i]["key"]) == rank_key:
			return i
	return -1


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


static func clamp_stars_for_rank(rank_key: String, stars: int) -> int:
	var rank = rank_for_key(rank_key)
	var max_stars = int(rank["max_stars"])
	if max_stars <= 0:
		return max(1, stars)
	return clampi(stars, 1, max_stars)


static func rank_state_for_elo(elo: int) -> Dictionary:
	var rank_key = rank_key_for_elo(elo)
	return rank_state_for_key_and_stars(rank_key, stars_for_elo(elo))


static func rank_state_for_profile(profile: Variant) -> Dictionary:
	var normalized = normalize_profile(profile)
	return rank_state_for_key_and_stars(String(normalized["rank_key"]), int(normalized["stars"]))


static func rank_state_for_key_and_stars(rank_key: String, stars: int) -> Dictionary:
	var rank = rank_for_key(rank_key)
	var clamped_stars = clamp_stars_for_rank(String(rank["key"]), stars)
	return {
		"key": String(rank["key"]),
		"name": String(rank["name"]),
		"elo": int(rank["min_elo"]),
		"stars": clamped_stars,
		"max_stars": int(rank["max_stars"]),
		"display": display_for_key_and_stars(String(rank["key"]), clamped_stars),
	}


static func display_for_elo(elo: int) -> String:
	var state = rank_state_for_elo(elo)
	return String(state["display"])


static func display_for_profile(profile: Variant) -> String:
	var state = rank_state_for_profile(profile)
	return String(state["display"])


static func display_for_key_and_stars(rank_key: String, stars: int) -> String:
	var rank = rank_for_key(rank_key)
	var clamped_stars = clamp_stars_for_rank(String(rank["key"]), stars)
	return "%s %d星" % [String(rank["name"]), clamped_stars]


static func star_result(rank_key: String, stars: int, won: bool) -> Dictionary:
	return star_result_for_delta(rank_key, stars, 1 if won else -1)


static func star_result_for_delta(rank_key: String, stars: int, star_delta: int) -> Dictionary:
	var old_state = rank_state_for_key_and_stars(rank_key, stars)
	var rank_index = rank_index_for_key(String(old_state["key"]))
	var new_stars = int(old_state["stars"])
	for _step in range(absi(star_delta)):
		if star_delta > 0:
			var max_stars = int(RANKS[rank_index]["max_stars"])
			if max_stars <= 0 or new_stars < max_stars:
				new_stars += 1
			elif rank_index < RANKS.size() - 1:
				rank_index += 1
				new_stars = 1
		elif new_stars > 1:
			new_stars -= 1
		elif rank_index > 0:
			rank_index -= 1
			new_stars = max(1, int(RANKS[rank_index]["max_stars"]))
	var new_state = rank_state_for_key_and_stars(String(RANKS[rank_index]["key"]), new_stars)
	return {
		"old_rank": old_state,
		"new_rank": new_state,
		"star_delta": star_delta,
		"won": star_delta > 0,
	}
