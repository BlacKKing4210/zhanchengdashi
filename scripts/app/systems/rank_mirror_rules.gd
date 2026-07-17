extends RefCounted

const POLICY_VERSION = 1
const LEGACY_RETAINED_RANKS = {
	"bronze": true,
	"silver": true,
}


static func migrate_legacy_mirrors(value: Variant, stored_policy_version: int) -> Dictionary:
	var mirrors = (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
	if stored_policy_version >= POLICY_VERSION:
		return mirrors
	for raw_rank_key in mirrors.keys():
		var rank_key = String(raw_rank_key).strip_edges().to_lower()
		if not LEGACY_RETAINED_RANKS.has(rank_key):
			mirrors.erase(raw_rank_key)
	return mirrors


static func animal_rarities_from_cards(cards: Dictionary) -> Dictionary:
	var result = {}
	for raw_card_id in cards:
		if typeof(cards[raw_card_id]) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = cards[raw_card_id]
		if not _is_animal_card(card):
			continue
		var card_id = String(card.get("id", raw_card_id)).strip_edges()
		if card_id.is_empty():
			continue
		result[card_id] = String(card.get("rarity", "common")).strip_edges().to_lower()
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


static func _is_animal_card(card: Dictionary) -> bool:
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
