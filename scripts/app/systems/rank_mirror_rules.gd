extends RefCounted

const RankAIDecks = preload("res://scripts/app/systems/rank_ai_decks.gd")

const POLICY_VERSION = 4
const RARITY_KEYS = ["common", "rare", "epic", "legendary"]


static func migrate_legacy_mirrors(value: Variant, _stored_policy_version: int) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var result = {}
	var card_rarities = RankAIDecks.card_rarity_map()
	for raw_rank_key in value:
		var rank_key = String(raw_rank_key).strip_edges().to_lower()
		if not RankAIDecks.DECK_RARITY_PLAN.has(rank_key) or typeof(value[raw_rank_key]) != TYPE_ARRAY:
			continue
		var eligible_records = []
		for raw_record in value[raw_rank_key]:
			if typeof(raw_record) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = raw_record
			if not should_record_deck(record.get("deck", []), card_rarities, rank_key):
				continue
			eligible_records.append(record.duplicate(true))
		if not eligible_records.is_empty():
			result[rank_key] = eligible_records
	return result


static func card_rarities_from_cards(cards: Variant) -> Dictionary:
	var result = {}
	if typeof(cards) == TYPE_ARRAY:
		for raw_card in cards:
			_append_card_rarity(result, raw_card, "")
	elif typeof(cards) == TYPE_DICTIONARY:
		for raw_card_id in cards:
			_append_card_rarity(result, cards[raw_card_id], raw_card_id)
	return result


static func animal_rarities_from_cards(cards: Variant) -> Dictionary:
	var result = {}
	if typeof(cards) == TYPE_ARRAY:
		for raw_card in cards:
			_append_animal_rarity(result, raw_card, "")
	elif typeof(cards) == TYPE_DICTIONARY:
		for raw_card_id in cards:
			_append_animal_rarity(result, cards[raw_card_id], raw_card_id)
	return result


static func deck_has_only_common_animals(deck: Variant, animal_rarities: Dictionary) -> bool:
	if typeof(deck) != TYPE_ARRAY:
		return false
	var animal_count = 0
	for raw_card_id in deck:
		var card_id = String(raw_card_id).strip_edges()
		if not animal_rarities.has(card_id):
			continue
		animal_count += 1
		if String(animal_rarities[card_id]).strip_edges().to_lower() != "common":
			return false
	return animal_count > 0


static func should_record_deck(deck: Variant, card_rarities: Dictionary, rank_key: String = "") -> bool:
	return is_valid_ai_candidate_deck(deck, card_rarities, rank_key) and _has_non_common_animal(deck, card_rarities)


static func is_valid_ai_candidate_deck(deck: Variant, card_rarities: Dictionary, rank_key: String = "") -> bool:
	var resolved_rank_key = rank_key.strip_edges().to_lower()
	if typeof(deck) != TYPE_ARRAY or deck.size() != 8 or not RankAIDecks.DECK_RARITY_PLAN.has(resolved_rank_key):
		return false
	if not RankAIDecks.is_valid_ai_deck(deck, card_rarities):
		return false
	return deck_rarity_counts(deck, card_rarities) == RankAIDecks.deck_rarity_plan_for_rank(resolved_rank_key)


static func deck_rarity_counts(deck: Variant, card_rarities: Dictionary) -> Dictionary:
	var result = _empty_rarity_counts()
	if typeof(deck) != TYPE_ARRAY:
		return result
	for raw_card_id in deck:
		var card_id = String(raw_card_id).strip_edges()
		var rarity = String(card_rarities.get(card_id, "")).strip_edges().to_lower()
		if result.has(rarity):
			result[rarity] = int(result[rarity]) + 1
	return result


static func animal_rarity_counts(deck: Variant, animal_rarities: Dictionary) -> Dictionary:
	var result = _empty_rarity_counts()
	if typeof(deck) != TYPE_ARRAY:
		return result
	for raw_card_id in deck:
		var card_id = String(raw_card_id).strip_edges()
		if not animal_rarities.has(card_id):
			continue
		var rarity = String(animal_rarities[card_id]).strip_edges().to_lower()
		if result.has(rarity):
			result[rarity] = int(result[rarity]) + 1
	return result


static func _empty_rarity_counts() -> Dictionary:
	var result = {}
	for rarity in RARITY_KEYS:
		result[rarity] = 0
	return result


static func _has_non_common_animal(deck: Variant, card_rarities: Dictionary) -> bool:
	if typeof(deck) != TYPE_ARRAY:
		return false
	for raw_card_id in deck:
		var card_id = String(raw_card_id).strip_edges()
		if card_id == RankAIDecks.MINE or card_id.begins_with("defense_"):
			continue
		if String(card_rarities.get(card_id, "")).strip_edges().to_lower() != "common":
			return true
	return false


static func _append_card_rarity(result: Dictionary, raw_card: Variant, fallback_id: Variant) -> void:
	if typeof(raw_card) != TYPE_DICTIONARY:
		return
	var card: Dictionary = raw_card
	var card_id = String(card.get("id", fallback_id)).strip_edges()
	var rarity = String(card.get("rarity", "")).strip_edges().to_lower()
	if not card_id.is_empty() and RARITY_KEYS.has(rarity):
		result[card_id] = rarity


static func _append_animal_rarity(result: Dictionary, raw_card: Variant, fallback_id: Variant) -> void:
	if typeof(raw_card) != TYPE_DICTIONARY:
		return
	var card: Dictionary = raw_card
	var card_id = String(card.get("id", fallback_id)).strip_edges()
	if card_id.is_empty() or not _is_animal_card(card, card_id):
		return
	var rarity = String(card.get("rarity", "")).strip_edges().to_lower()
	if RARITY_KEYS.has(rarity):
		result[card_id] = rarity


static func _is_animal_card(card: Dictionary, card_id: String = "") -> bool:
	if not card_id.is_empty():
		return card_id != "gold_mine_card" and not card_id.begins_with("defense_")
	var tags = card.get("tags", [])
	if typeof(tags) == TYPE_ARRAY:
		for raw_tag in tags:
			if String(raw_tag).strip_edges().to_lower() in ["building", "mine", "gold_mine", "defense", "tower"]:
				return false
	else:
		for raw_tag in String(tags).split("|", false):
			if raw_tag.strip_edges().to_lower() in ["building", "mine", "gold_mine", "defense", "tower"]:
				return false
	return true
