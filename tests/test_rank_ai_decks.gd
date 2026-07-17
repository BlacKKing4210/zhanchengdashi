extends SceneTree

const RankAIDecks = preload("res://scripts/app/systems/rank_ai_decks.gd")

const RANK_KEYS = ["bronze", "silver", "gold", "platinum", "diamond", "star", "king"]
const EXPECTED_RARITY_COUNTS = {
	"bronze": {"common": 6, "rare": 0, "epic": 0, "legendary": 0},
	"silver": {"common": 6, "rare": 0, "epic": 0, "legendary": 0},
	"gold": {"common": 4, "rare": 2, "epic": 0, "legendary": 0},
	"platinum": {"common": 2, "rare": 4, "epic": 0, "legendary": 0},
	"diamond": {"common": 1, "rare": 3, "epic": 2, "legendary": 0},
	"star": {"common": 0, "rare": 2, "epic": 4, "legendary": 0},
	"king": {"common": 0, "rare": 1, "epic": 4, "legendary": 1},
}

var failures = 0
var card_rarities = {}


func _init() -> void:
	card_rarities = _load_card_rarities()
	_expect(not card_rarities.is_empty(), "runtime card rarity table is available")
	for rank_key in RANK_KEYS:
		var mirrors = RankAIDecks.mirrors_for_rank(rank_key)
		_expect(mirrors.size() >= 2, "%s has multiple baseline AI decks" % rank_key)
		var signatures = {}
		for mirror in mirrors:
			var deck: Array = mirror.get("deck", [])
			_expect(deck.size() == 8, "%s AI deck has 8 cards" % rank_key)
			_expect(deck.count("gold_mine_card") == 1, "%s AI deck includes one mandatory mine" % rank_key)
			var defense_count = 0
			var animal_count = 0
			var rarity_counts = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
			for raw_card_id in deck:
				var card_id = String(raw_card_id)
				if card_id == "gold_mine_card":
					continue
				if card_id.begins_with("defense_"):
					defense_count += 1
					continue
				animal_count += 1
				var rarity = String(card_rarities.get(card_id, ""))
				_expect(rarity_counts.has(rarity), "%s animal %s has a known rarity" % [rank_key, card_id])
				if rarity_counts.has(rarity):
					rarity_counts[rarity] = int(rarity_counts[rarity]) + 1
			_expect(defense_count == 1, "%s AI deck includes one defense card" % rank_key)
			_expect(animal_count == 6, "%s AI deck includes six animals" % rank_key)
			_expect(
				rarity_counts == EXPECTED_RARITY_COUNTS[rank_key],
				"%s AI deck follows the approved rarity progression" % rank_key
			)
			signatures[RankAIDecks.deck_signature(deck)] = true
		_expect(signatures.size() == mirrors.size(), "%s baseline decks are distinct" % rank_key)
	_expect(
		RankAIDecks.deck_signature(["a", "b"]) == RankAIDecks.deck_signature(["b", "a"]),
		"deck signature deduplicates reordered decks"
	)
	if failures == 0:
		print("Rank AI deck tests passed.")
	quit(failures)


func _load_card_rarities() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://runtime/config/cards.json"))
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	var result = {}
	for raw_card in parsed:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = raw_card
		var card_id = String(card.get("id", ""))
		if not card_id.is_empty():
			result[card_id] = String(card.get("rarity", ""))
	return result


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error(label)
