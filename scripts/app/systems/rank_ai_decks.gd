extends RefCounted

const MINE = "gold_mine_card"

const TEMPLATES = {
	"bronze": [
		["defense_watch_tower", "mouse", "ant", "sparrow", "frog", "rabbit", "chicken"],
		["defense_watch_tower", "pigeon", "hamster", "snail", "tadpole", "mouse", "rabbit"],
	],
	"silver": [
		["defense_watch_tower", "ant", "frog", "rabbit", "chicken", "pigeon", "hamster"],
		["defense_watch_tower", "mouse", "sparrow", "frog", "snail", "tadpole", "chicken"],
	],
	"gold": [
		["defense_watch_tower", "cat", "dog", "duck", "squirrel", "rabbit", "frog"],
		["defense_watch_tower", "hedgehog", "turtle", "goat", "sheep", "ant", "hamster"],
	],
	"platinum": [
		["defense_cannon_tower", "dog", "duck", "goat", "fox", "monkey", "deer"],
		["defense_cannon_tower", "squirrel", "turtle", "sheep", "beaver", "penguin", "kangaroo"],
	],
	"diamond": [
		["defense_cannon_tower", "monkey", "deer", "beaver", "wolf", "horse", "bear"],
		["defense_cannon_tower", "penguin", "kangaroo", "camel", "falcon", "tiger", "rhino"],
	],
	"star": [
		["defense_repair_beacon", "wolf", "camel", "bear", "tiger", "eagle", "elephant"],
		["defense_repair_beacon", "falcon", "crane", "rhino", "gorilla", "blue_whale", "python"],
	],
	"king": [
		["defense_storm_obelisk", "bear", "tiger", "eagle", "elephant", "orca", "mammoth"],
		["defense_storm_obelisk", "lion", "rhino", "gorilla", "blue_whale", "silverback", "golden_eagle"],
	],
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
	var templates: Array = TEMPLATES.get(rank_key, TEMPLATES["bronze"])
	var result = []
	for index in range(templates.size()):
		var deck = [MINE]
		deck.append_array((templates[index] as Array).duplicate())
		var levels = {}
		for card_id in deck:
			levels[String(card_id)] = int(LEVELS.get(rank_key, 1))
		result.append({
			"mirror_id": "baseline_ai_%s_%d" % [rank_key, index + 1],
			"player_id": "baseline_ai",
			"name": "%s电脑%d" % [rank_key, index + 1],
			"rank_key": rank_key,
			"stars": 1,
			"deck": deck,
			"card_levels": levels,
			"created_at_unix": 0,
		})
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
