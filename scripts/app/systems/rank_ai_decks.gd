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

const ANIMAL_POOLS = {
	"common": ["mouse", "ant", "sparrow", "frog", "rabbit", "chicken", "pigeon", "hamster", "snail", "tadpole"],
	"rare": ["cat", "dog", "duck", "squirrel", "hedgehog", "turtle", "goat", "sheep", "parrot"],
	"epic": ["fox", "monkey", "pig", "deer", "beaver", "otter", "penguin", "peacock", "kangaroo", "seal", "swan", "wolf", "horse", "cow", "zebra", "camel", "dolphin", "falcon", "boar", "crane", "lynx"],
	"legendary": ["bear", "tiger", "lion", "rhino", "hippo", "giraffe", "gorilla", "leopard", "eagle", "crocodile", "elephant", "blue_whale", "orca", "shark", "python", "komodo_dragon", "polar_bear", "silverback", "golden_eagle", "mammoth"],
}

const ANIMAL_RARITY_PLAN = {
	"bronze": {"common": 6, "rare": 0, "epic": 0, "legendary": 0},
	"silver": {"common": 6, "rare": 0, "epic": 0, "legendary": 0},
	"gold": {"common": 4, "rare": 2, "epic": 0, "legendary": 0},
	"platinum": {"common": 2, "rare": 4, "epic": 0, "legendary": 0},
	"diamond": {"common": 1, "rare": 3, "epic": 2, "legendary": 0},
	"star": {"common": 0, "rare": 2, "epic": 4, "legendary": 0},
	"king": {"common": 0, "rare": 1, "epic": 4, "legendary": 1},
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
		var deck = [MINE, String(DEFENSE_BY_RANK[resolved_rank_key])]
		deck.append_array(_animal_cards_for_rank(resolved_rank_key, index))
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
