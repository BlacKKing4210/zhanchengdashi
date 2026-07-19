extends SceneTree

const RankAIDecks = preload("res://scripts/app/systems/rank_ai_decks.gd")

const RANK_KEYS = ["bronze", "silver", "gold", "platinum", "diamond", "star", "king"]
const EXPECTED_DECK_RARITY_COUNTS = {
	"bronze": {"common": 7, "rare": 0, "epic": 1, "legendary": 0},
	"silver": {"common": 6, "rare": 1, "epic": 1, "legendary": 0},
	"gold": {"common": 5, "rare": 1, "epic": 2, "legendary": 0},
	"platinum": {"common": 3, "rare": 3, "epic": 2, "legendary": 0},
	"diamond": {"common": 2, "rare": 3, "epic": 2, "legendary": 1},
	"star": {"common": 2, "rare": 2, "epic": 3, "legendary": 1},
	"king": {"common": 2, "rare": 2, "epic": 3, "legendary": 1},
}
const EXPECTED_ANIMAL_RARITY_COUNTS = {
	"bronze": {"common": 6, "rare": 0, "epic": 0, "legendary": 0},
	"silver": {"common": 5, "rare": 1, "epic": 0, "legendary": 0},
	"gold": {"common": 4, "rare": 1, "epic": 1, "legendary": 0},
	"platinum": {"common": 3, "rare": 2, "epic": 1, "legendary": 0},
	"diamond": {"common": 2, "rare": 2, "epic": 1, "legendary": 1},
	"star": {"common": 2, "rare": 2, "epic": 1, "legendary": 1},
	"king": {"common": 2, "rare": 2, "epic": 2, "legendary": 0},
}

var failures = 0
var card_rarities = {}


func _init() -> void:
	card_rarities = _load_card_rarities()
	_expect(not card_rarities.is_empty(), "runtime card rarity table is available")
	_expect(String(card_rarities.get("gold_mine_card", "")) == "epic", "mandatory mine is configured as an epic economy card")
	for rank_key in RANK_KEYS:
		_expect_equal(
			RankAIDecks.rarity_plan_for_rank(rank_key),
			EXPECTED_ANIMAL_RARITY_COUNTS[rank_key],
			"%s animal slots follow the approved progressive plan" % rank_key
		)
		_expect_equal(
			RankAIDecks.deck_rarity_plan_for_rank(rank_key),
			EXPECTED_DECK_RARITY_COUNTS[rank_key],
			"%s full deck follows the approved all-quality plan" % rank_key
		)
		var mirrors = RankAIDecks.mirrors_for_rank(rank_key)
		_expect(mirrors.size() >= 2, "%s has multiple baseline AI decks" % rank_key)
		var signatures = {}
		for mirror in mirrors:
			var deck: Array = mirror.get("deck", [])
			_expect(deck.size() == 8, "%s AI deck has 8 cards" % rank_key)
			_expect(RankAIDecks.has_common_animal(deck, card_rarities), "%s AI deck has a green animal" % rank_key)
			_expect(RankAIDecks.is_valid_ai_deck(deck, card_rarities), "%s AI deck is build-ready" % rank_key)
			_expect(deck.count("gold_mine_card") == 1, "%s AI deck includes one mandatory mine" % rank_key)
			var defense_count = 0
			var animal_count = 0
			for raw_card_id in deck:
				var card_id = String(raw_card_id)
				if card_id.begins_with("defense_"):
					defense_count += 1
				elif card_id != "gold_mine_card":
					animal_count += 1
			_expect(defense_count == 1, "%s AI deck includes one defense card" % rank_key)
			_expect(animal_count == 6, "%s AI deck includes six animals" % rank_key)
			_expect_equal(
				_rarity_counts(deck),
				EXPECTED_DECK_RARITY_COUNTS[rank_key],
				"%s AI deck counts every card quality, including the mine and defense" % rank_key
			)
			signatures[RankAIDecks.deck_signature(deck)] = true
		_expect(signatures.size() == mirrors.size(), "%s baseline decks are distinct" % rank_key)
		var replacement = RankAIDecks.validated_ai_roster(
			_no_common_deck_for_rank(String(rank_key)),
			{},
			String(rank_key),
			17,
			card_rarities
		)
		_expect(bool(replacement.get("replaced", false)), "%s rejects an AI deck without a green animal" % rank_key)
		_expect_equal(String(replacement.get("rank_key", "")), String(rank_key), "%s replacement keeps its rank" % rank_key)
		_expect(
			RankAIDecks.is_valid_ai_deck(replacement.get("deck", []), card_rarities),
			"%s replacement AI deck is build-ready" % rank_key
		)
	_expect_equal(
		RankAIDecks.deck_signature(["a", "b"]), RankAIDecks.deck_signature(["b", "a"]),
		"deck signature deduplicates reordered decks"
	)
	if failures == 0:
		print("Rank AI deck tests passed.")
	quit(failures)


func _rarity_counts(deck: Array) -> Dictionary:
	var result = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for raw_card_id in deck:
		var rarity = String(card_rarities.get(String(raw_card_id), ""))
		_expect(result.has(rarity), "card %s has a known rarity" % String(raw_card_id))
		if result.has(rarity):
			result[rarity] = int(result[rarity]) + 1
	return result


func _no_common_deck_for_rank(rank_key: String) -> Array:
	return [
		"gold_mine_card",
		String(RankAIDecks.DEFENSE_BY_RANK[rank_key]),
		"fox",
		"monkey",
		"pig",
		"deer",
		"beaver",
		"otter",
	]


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


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_expect(actual == expected, "%s: expected %s, got %s" % [label, str(expected), str(actual)])
