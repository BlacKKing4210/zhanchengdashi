extends RefCounted

const MINE = "gold_mine_card"
const TEMPLATE_COUNT = 2
const RANK_KEYS = ["bronze", "silver", "gold", "platinum", "diamond", "star", "king"]
const RARITY_KEYS = ["common", "rare", "epic", "legendary"]

const DEFENSE_BY_RANK = {
	"bronze": "defense_watch_tower",
	"silver": "defense_watch_tower",
	"gold": "defense_watch_tower",
	"platinum": "defense_cannon_tower",
	"diamond": "defense_cannon_tower",
	"star": "defense_repair_beacon",
	"king": "defense_storm_obelisk",
}

const BUILDING_RARITIES = {
	MINE: "epic",
	"defense_watch_tower": "common",
	"defense_cannon_tower": "rare",
	"defense_repair_beacon": "epic",
	"defense_storm_obelisk": "legendary",
}

const ANIMAL_POOLS = {
	"common": ["mouse", "ant", "sparrow", "frog", "rabbit", "chicken", "pigeon", "hamster", "snail", "tadpole"],
	"rare": ["cat", "dog", "duck", "squirrel", "hedgehog", "turtle", "goat", "sheep", "parrot"],
	"epic": ["fox", "monkey", "pig", "deer", "beaver", "otter", "penguin", "peacock", "kangaroo", "seal", "swan", "wolf", "horse", "cow", "zebra", "camel", "dolphin", "falcon", "boar", "crane", "lynx"],
	"legendary": ["bear", "tiger", "lion", "rhino", "hippo", "giraffe", "gorilla", "leopard", "eagle", "crocodile", "elephant", "blue_whale", "orca", "shark", "python", "komodo_dragon", "polar_bear", "silverback", "golden_eagle", "mammoth"],
}

const ANIMAL_RARITY_PLAN = {
	"bronze": {"common": 6, "rare": 0, "epic": 0, "legendary": 0},
	"silver": {"common": 5, "rare": 1, "epic": 0, "legendary": 0},
	"gold": {"common": 4, "rare": 1, "epic": 1, "legendary": 0},
	"platinum": {"common": 3, "rare": 2, "epic": 1, "legendary": 0},
	"diamond": {"common": 2, "rare": 2, "epic": 1, "legendary": 1},
	"star": {"common": 2, "rare": 2, "epic": 1, "legendary": 1},
	"king": {"common": 2, "rare": 2, "epic": 2, "legendary": 0},
}

const DECK_RARITY_PLAN = {
	"bronze": {"common": 7, "rare": 0, "epic": 1, "legendary": 0},
	"silver": {"common": 6, "rare": 1, "epic": 1, "legendary": 0},
	"gold": {"common": 5, "rare": 1, "epic": 2, "legendary": 0},
	"platinum": {"common": 3, "rare": 3, "epic": 2, "legendary": 0},
	"diamond": {"common": 2, "rare": 3, "epic": 2, "legendary": 1},
	"star": {"common": 2, "rare": 2, "epic": 3, "legendary": 1},
	"king": {"common": 2, "rare": 2, "epic": 3, "legendary": 1},
}

const LEVELS = {
	"bronze": 1,
	"silver": 1,
	"gold": 2,
	"platinum": 3,
	"diamond": 4,
	"star": 5,
	"king": 6,
}


static func mirrors_for_rank(rank_key: String) -> Array:
	var resolved_rank_key = rank_key if ANIMAL_RARITY_PLAN.has(rank_key) else "bronze"
	var result = []
	for index in range(TEMPLATE_COUNT):
		var deck = _baseline_deck_for_rank(resolved_rank_key, index)
		if not is_valid_ai_deck(deck):
			continue
		var levels = {}
		for card_id in deck:
			levels[String(card_id)] = int(LEVELS.get(resolved_rank_key, 1))
		result.append({
			"mirror_id": "baseline_ai_%s_%d" % [resolved_rank_key, index + 1],
			"player_id": "baseline_ai",
			"name": "%s电脑%d" % [resolved_rank_key, index + 1],
			"rank_key": resolved_rank_key,
			"stars": 1,
			"deck": deck,
			"card_levels": levels,
			"created_at_unix": 0,
		})
	return result


static func rarity_plan_for_rank(rank_key: String) -> Dictionary:
	var resolved_rank_key = rank_key if ANIMAL_RARITY_PLAN.has(rank_key) else "bronze"
	return (ANIMAL_RARITY_PLAN[resolved_rank_key] as Dictionary).duplicate()


static func deck_rarity_plan_for_rank(rank_key: String) -> Dictionary:
	var resolved_rank_key = rank_key if DECK_RARITY_PLAN.has(rank_key) else "bronze"
	return (DECK_RARITY_PLAN[resolved_rank_key] as Dictionary).duplicate()


static func card_rarity_map() -> Dictionary:
	var result = BUILDING_RARITIES.duplicate()
	for raw_rarity in RARITY_KEYS:
		var rarity = String(raw_rarity)
		for raw_card_id in ANIMAL_POOLS[rarity]:
			result[String(raw_card_id)] = rarity
	return result


static func has_common_animal(deck: Variant, card_rarities: Dictionary = {}) -> bool:
	if typeof(deck) != TYPE_ARRAY:
		return false
	var resolved_rarities = card_rarities if not card_rarities.is_empty() else card_rarity_map()
	for raw_card_id in deck:
		var card_id = String(raw_card_id).strip_edges()
		if card_id == MINE or card_id.begins_with("defense_"):
			continue
		if String(resolved_rarities.get(card_id, "")).strip_edges().to_lower() == "common":
			return true
	return false


static func is_valid_ai_deck(deck: Variant, card_rarities: Dictionary = {}) -> bool:
	if typeof(deck) != TYPE_ARRAY or deck.size() != 8:
		return false
	var mine_count = 0
	var defense_count = 0
	var animal_count = 0
	for raw_card_id in deck:
		var card_id = String(raw_card_id).strip_edges()
		if card_id == MINE:
			mine_count += 1
		elif card_id.begins_with("defense_"):
			defense_count += 1
		else:
			animal_count += 1
	return mine_count == 1 and defense_count == 1 and animal_count == 6 and has_common_animal(deck, card_rarities)


static func validated_ai_roster(
	raw_deck: Variant,
	raw_levels: Variant,
	rank_key: String,
	selection_seed: int = 0,
	card_rarities: Dictionary = {}
) -> Dictionary:
	var resolved_rank_key = rank_key if RANK_KEYS.has(rank_key) else "bronze"
	if is_valid_ai_deck(raw_deck, card_rarities):
		var deck = (raw_deck as Array).duplicate()
		var source_levels: Dictionary = raw_levels if typeof(raw_levels) == TYPE_DICTIONARY else {}
		var levels = {}
		for raw_card_id in deck:
			var card_id = String(raw_card_id)
			levels[card_id] = maxi(1, int(source_levels.get(card_id, LEVELS[resolved_rank_key])))
		return {"rank_key": resolved_rank_key, "deck": deck, "card_levels": levels, "replaced": false}
	var mirrors = mirrors_for_rank(resolved_rank_key)
	if mirrors.is_empty():
		return {"rank_key": resolved_rank_key, "deck": [], "card_levels": {}, "replaced": true}
	var mirror: Dictionary = mirrors[posmod(selection_seed, mirrors.size())]
	return {
		"rank_key": resolved_rank_key,
		"deck": (mirror.get("deck", []) as Array).duplicate(),
		"card_levels": (mirror.get("card_levels", {}) as Dictionary).duplicate(true),
		"replaced": true,
	}


static func _baseline_deck_for_rank(rank_key: String, template_index: int) -> Array:
	var animals = _animal_cards_for_rank(rank_key, template_index)
	var common_pool: Array = ANIMAL_POOLS["common"]
	var common_offset = posmod(RANK_KEYS.find(rank_key) * 2 + template_index * 3, common_pool.size())
	while animals.size() > 6:
		animals.pop_back()
	while animals.size() < 6:
		animals.append(common_pool[(common_offset + animals.size()) % common_pool.size()])
	var deck = [MINE, String(DEFENSE_BY_RANK[rank_key])]
	deck.append_array(animals)
	if has_common_animal(deck):
		return deck
	deck[deck.size() - 1] = common_pool[common_offset]
	return deck


static func _animal_cards_for_rank(rank_key: String, template_index: int) -> Array:
	var result = []
	var plan = rarity_plan_for_rank(rank_key)
	var rank_offset = maxi(0, RANK_KEYS.find(rank_key)) * 2
	for rarity_index in range(RARITY_KEYS.size()):
		var rarity = String(RARITY_KEYS[rarity_index])
		var pool: Array = ANIMAL_POOLS[rarity]
		var count = int(plan.get(rarity, 0))
		var offset = (rank_offset + template_index * 3 + rarity_index) % pool.size()
		for card_index in range(count):
			result.append(pool[(offset + card_index) % pool.size()])
	return result


static func deck_signature(deck: Variant) -> String:
	if typeof(deck) != TYPE_ARRAY:
		return ""
	var ids = []
	for card_id in deck:
		var id = String(card_id)
		if not id.is_empty():
			ids.append(id)
	ids.sort()
	return "|".join(ids)
