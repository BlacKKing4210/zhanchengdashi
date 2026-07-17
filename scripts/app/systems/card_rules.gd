extends RefCounted

const LEVEL_COSTS = [1, 2, 5, 10, 20, 30, 50, 80, 100]
const LEVEL_STAT_STEP = 0.105
const MELEE_ATTACK_RANGE = 40.0

const GACHA_RATES = [
	{"rarity": "common", "label": "绿色", "rate": 80.0},
	{"rarity": "rare", "label": "蓝色", "rate": 16.0},
	{"rarity": "epic", "label": "紫色", "rate": 3.2},
	{"rarity": "legendary", "label": "金色", "rate": 0.8},
]


static func card_from_row(row: Dictionary) -> Dictionary:
	var tier = int(row.get("tier", 1))
	var attack = int(row.get("attack", 5 + tier * 2))
	var skill_id = row.get("skill_id", "")
	var skill_trigger = row.get("skill_trigger", "")
	var skill_effect = row.get("skill_effect", "")
	var skill_power = row.get("skill_power", 0.0)
	var skill_cooldown_sec = row.get("skill_cooldown_sec", 0.0)
	var skill_chance = 1.0
	var raw_skill_chance = row.get("skill_chance", null)
	if raw_skill_chance != null and str(raw_skill_chance).strip_edges() != "":
		skill_chance = clampf(float_from_value(raw_skill_chance), 0.0, 1.0)
	var skill_text = row.get("skill_text", "")
	return {
		"id": string_from_value(row.get("id", "")),
		"name": string_from_value(row.get("name", row.get("id", ""))),
		"rarity": string_from_value(row.get("rarity", rarity_for_tier(tier))),
		"tier": tier,
		"art_path": string_from_value(row.get("art_path", "")),
		"base_attack": attack,
		"base_max_hp": int(row.get("max_hp", 40 + tier * 18)),
		"base_move_speed": float(row.get("move_speed", 58.0 + tier * 2.0)),
		"base_attack_range": float(row.get("attack_range", 42.0)),
		"base_summon_interval_sec": float(row.get("summon_interval_sec", maxf(2.2, 4.2 - tier * 0.18))),
		"skill_id": string_from_value(skill_id),
		"skill_trigger": string_from_value(skill_trigger),
		"skill_effect": string_from_value(skill_effect),
		"skill_power": float_from_value(skill_power),
		"skill_cooldown_sec": float_from_value(skill_cooldown_sec),
		"skill_chance": skill_chance,
		"skill_text": string_from_value(skill_text),
		"tags": tags_from_value(row.get("tags", [])),
	}


static func string_from_value(value) -> String:
	if value == null:
		return ""
	return str(value)


static func float_from_value(value) -> float:
	if value == null:
		return 0.0
	var text = str(value)
	if text == "":
		return 0.0
	return float(value)


static func tags_from_value(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate()
	if value == null:
		return []
	var result = []
	for tag in str(value).split("|", false):
		var clean = str(tag).strip_edges()
		if clean != "":
			result.append(clean)
	return result


static func rarity_for_tier(tier: int) -> String:
	if tier >= 6:
		return "legendary"
	if tier >= 5:
		return "epic"
	if tier >= 3:
		return "rare"
	return "common"


static func card_level(card_levels: Dictionary, card_id: String) -> int:
	return int(card_levels.get(card_id, 1))


static func card_total_count(card_counts: Dictionary, card_id: String) -> int:
	return int(card_counts.get(card_id, 0))


static func card_spare_count(card_counts: Dictionary, card_id: String) -> int:
	return max(0, card_total_count(card_counts, card_id) - 1)


static func next_upgrade_cost(card_levels: Dictionary, card_id: String) -> int:
	var level = card_level(card_levels, card_id)
	if level > LEVEL_COSTS.size():
		return -1
	return int(LEVEL_COSTS[level - 1])


static func card_multiplier(card_levels: Dictionary, card_id: String) -> float:
	return 1.0 + float(card_level(card_levels, card_id) - 1) * LEVEL_STAT_STEP


static func is_ranged_or_summon_animal(card: Dictionary) -> bool:
	var tags = card.get("tags", [])
	if typeof(tags) == TYPE_ARRAY:
		for tag in tags:
			if String(tag) in ["building", "mine", "gold_mine", "defense", "tower"]:
				return false
	var is_ranged = float(card.get("base_attack_range", 0.0)) > MELEE_ATTACK_RANGE
	var is_summon_type = String(card.get("skill_effect", "")) == "summon"
	return is_ranged or is_summon_type


static func guaranteed_upgrade_hp_bonus(card: Dictionary, card_levels: Dictionary) -> int:
	if not is_ranged_or_summon_animal(card):
		return 0
	var level = max(1, card_level(card_levels, String(card.get("id", ""))))
	return floori(float(level) / 2.0)


static func card_stats(card: Dictionary, card_levels: Dictionary) -> Dictionary:
	var id = String(card.get("id", ""))
	var mult = card_multiplier(card_levels, id)
	var guaranteed_hp_bonus = guaranteed_upgrade_hp_bonus(card, card_levels)
	return {
		"attack": maxi(0, roundi(float(card.get("base_attack", 1)) * mult)),
		"max_hp": maxi(1, roundi(float(card.get("base_max_hp", 1)) * mult)) + guaranteed_hp_bonus,
		"move_speed": float(card.get("base_move_speed", 60.0)) * mult,
		"attack_range": float(card.get("base_attack_range", 42.0)) * mult,
		"summon_interval_sec": maxf(1.0, float(card.get("base_summon_interval_sec", 3.5)) / mult),
		"upgrade_hp_bonus": guaranteed_hp_bonus,
	}


static func attack_range_label(value: float, hex_size: float) -> String:
	if value <= hex_size * 1.5:
		return "近战"
	if value <= hex_size * 2.6:
		return "远程"
	return "超远程"


static func rarity_sort_rank(rarity: String) -> int:
	match rarity:
		"legendary":
			return 4
		"epic":
			return 3
		"rare":
			return 2
		_:
			return 1


static func rarity_for_rank(rank: int) -> String:
	match rank:
		4:
			return "legendary"
		3:
			return "epic"
		2:
			return "rare"
		_:
			return "common"


static func rarity_search_order(target_rarity: String, search_higher: bool = false) -> Array:
	var target_rank = rarity_sort_rank(target_rarity)
	var rank_end = 5 if search_higher else 0
	var rank_step = 1 if search_higher else -1
	var result = []
	for rank in range(target_rank, rank_end, rank_step):
		result.append(rarity_for_rank(rank))
	return result


static func defense_rarity_search_order(target_rarity: String) -> Array:
	return rarity_search_order(target_rarity)


static func defense_card_id_for_target_rarity(defense_cards: Array, target_rarity: String, site_seed: int) -> String:
	for rarity in defense_rarity_search_order(target_rarity):
		var options = []
		for card in defense_cards:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var card_id = String(card.get("id", ""))
			if card_id != "" and String(card.get("rarity", "common")) == rarity:
				options.append(card_id)
		if not options.is_empty():
			var rank = rarity_sort_rank(String(rarity))
			var pick_seed = absi(site_seed + rank * 97 + defense_cards.size() * 13)
			return String(options[pick_seed % options.size()])
	return ""


static func resolve_defense_card_id(_candidate_card_id: String, defense_cards: Array, target_rarity: String, site_seed: int) -> String:
	return defense_card_id_for_target_rarity(defense_cards, target_rarity, site_seed)


static func rarity_label(rarity: String) -> String:
	match rarity:
		"legendary":
			return "金色"
		"epic":
			return "紫色"
		"rare":
			return "蓝色"
		_:
			return "绿色"


static func roll_rarity(roll: float) -> String:
	var acc = 0.0
	for entry in GACHA_RATES:
		acc += float(entry["rate"])
		if roll < acc:
			return String(entry["rarity"])
	return "legendary"
