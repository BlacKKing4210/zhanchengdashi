extends RefCounted

const POLICY_VERSION = 2


static func migrate_legacy_mirrors(value: Variant, stored_policy_version: int) -> Dictionary:
	if stored_policy_version < POLICY_VERSION:
		return {}
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


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


static func should_record_deck(deck: Variant, animal_rarities: Dictionary) -> bool:
	return not deck_has_only_common_animals(deck, animal_rarities)


static func _append_animal_rarity(result: Dictionary, raw_card: Variant, fallback_id: Variant) -> void:
	if typeof(raw_card) != TYPE_DICTIONARY:
		return
	var card: Dictionary = raw_card
	var card_id = String(card.get("id", fallback_id)).strip_edges()
	if card_id.is_empty() or not _is_animal_card(card, card_id):
		return
	result[card_id] = String(card.get("rarity", "common")).strip_edges().to_lower()


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
