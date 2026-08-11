## UI-agnostic weighted reward draw service.
## The caller owns ticket persistence, inventory persistence, and reveal effects.
extends RefCounted


static func roll(cards: Array, rarity_rates, random_percent: float, random_index: int = -1) -> Dictionary:
	if cards.is_empty():
		return {}
	var rarity = roll_rarity(rarity_rates, random_percent)
	var pool = []
	for raw_card in cards:
		if typeof(raw_card) == TYPE_DICTIONARY and String(raw_card.get("rarity", "common")) == rarity:
			pool.append(raw_card)
	if pool.is_empty():
		pool = cards
	var index = posmod(random_index, pool.size()) if random_index >= 0 else randi() % pool.size()
	return (pool[index] as Dictionary).duplicate(true)


static func roll_rarity(rarity_rates, random_percent: float) -> String:
	var cursor = 0.0
	if typeof(rarity_rates) == TYPE_DICTIONARY:
		for raw_rarity in rarity_rates:
			var rarity = String(raw_rarity).strip_edges()
			if rarity.is_empty():
				continue
			cursor += maxf(0.0, float(rarity_rates[raw_rarity]))
			if random_percent < cursor:
				return rarity
		for raw_rarity in rarity_rates:
			var fallback_rarity = String(raw_rarity).strip_edges()
			if not fallback_rarity.is_empty():
				return fallback_rarity
	elif typeof(rarity_rates) == TYPE_ARRAY:
		for raw_entry in rarity_rates:
			if typeof(raw_entry) != TYPE_DICTIONARY:
				continue
			var entry = raw_entry as Dictionary
			var rarity = String(entry.get("rarity", "")).strip_edges()
			if rarity.is_empty():
				continue
			cursor += maxf(0.0, float(entry.get("rate", 0.0)))
			if random_percent < cursor:
				return rarity
		for raw_entry in rarity_rates:
			if typeof(raw_entry) != TYPE_DICTIONARY:
				continue
			var fallback_entry = raw_entry as Dictionary
			var fallback_rarity = String(fallback_entry.get("rarity", "")).strip_edges()
			if not fallback_rarity.is_empty():
				return fallback_rarity
	return "common"


static func apply_reward(inventory_counts: Dictionary, inventory_levels: Dictionary, reward: Dictionary) -> Dictionary:
	var card_id = String(reward.get("id", "")).strip_edges()
	if card_id.is_empty():
		return {"counts": inventory_counts.duplicate(true), "levels": inventory_levels.duplicate(true)}
	var counts = inventory_counts.duplicate(true)
	var levels = inventory_levels.duplicate(true)
	counts[card_id] = maxi(0, int(counts.get(card_id, 0))) + 1
	if not levels.has(card_id):
		levels[card_id] = 1
	return {"counts": counts, "levels": levels, "reward_id": card_id}
