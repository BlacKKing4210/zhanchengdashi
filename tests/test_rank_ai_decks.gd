extends SceneTree

const RankAIDecks = preload("res://scripts/app/systems/rank_ai_decks.gd")

const COMMON_ANIMALS = ["mouse", "ant", "sparrow", "frog", "rabbit", "chicken", "pigeon", "hamster", "snail", "tadpole"]

var failures = 0


func _init() -> void:
	for rank_key in ["bronze", "silver", "gold", "platinum", "diamond", "star", "king"]:
		var mirrors = RankAIDecks.mirrors_for_rank(rank_key)
		_expect(mirrors.size() >= 2, "%s has multiple baseline AI decks" % rank_key)
		for mirror in mirrors:
			var deck: Array = mirror.get("deck", [])
			_expect(deck.size() == 8, "%s AI deck has 8 cards" % rank_key)
			_expect(deck.has("gold_mine_card"), "%s AI deck includes mandatory mine" % rank_key)
			if rank_key in ["bronze", "silver"]:
				for card_id in deck:
					if card_id not in ["gold_mine_card", "defense_watch_tower"]:
						_expect(COMMON_ANIMALS.has(card_id), "%s animal %s is common" % [rank_key, card_id])
	_expect(
		RankAIDecks.deck_signature(["a", "b"]) == RankAIDecks.deck_signature(["b", "a"]),
		"deck signature deduplicates reordered decks"
	)
	if failures == 0:
		print("Rank AI deck tests passed.")
	quit(failures)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error(label)
