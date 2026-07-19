extends Node

const MainApp = preload("res://scripts/app/main.gd")
const PlayerAccountStore = preload("res://scripts/server/player_account_store.gd")
const RankAIDecks = preload("res://scripts/app/systems/rank_ai_decks.gd")
const RankMirrorRules = preload("res://scripts/app/systems/rank_mirror_rules.gd")
const RankingRules = preload("res://scripts/app/systems/ranking_rules.gd")

var failures = 0


func _ready() -> void:
	_test_color_eligibility()
	_test_rank_quality_gate()
	_test_policy_migration()
	_test_main_recording_gate()
	_test_invalid_match_mirror_is_replaced()
	_test_server_profile_migration()
	if failures == 0:
		print("Rank mirror policy tests passed.")
	get_tree().quit(failures)


func _test_color_eligibility() -> void:
	var animal_rarities = RankMirrorRules.animal_rarities_from_cards(_card_catalog_array())
	_expect_true(
		RankMirrorRules.deck_has_only_common_animals(["rabbit", "gold_mine_card", "rabbit"], animal_rarities),
		"building cards do not prevent detecting an all-green animal deck"
	)
	_expect_false(
		RankMirrorRules.deck_has_only_common_animals(["rabbit", "wolf", "gold_mine_card"], animal_rarities),
		"one blue animal prevents an all-green animal classification"
	)
	_expect_false(
		RankMirrorRules.deck_has_only_common_animals(["rabbit", "beaver", "gold_mine_card"], animal_rarities),
		"a high-quality animal is counted even when its tags include a building role"
	)


func _test_rank_quality_gate() -> void:
	var card_rarities = RankMirrorRules.card_rarities_from_cards(_card_catalog_array())
	var animal_rarities = RankMirrorRules.animal_rarities_from_cards(_card_catalog_array())
	for rank_key in RankAIDecks.RANK_KEYS:
		var baseline_deck = _deck_for_rank(String(rank_key))
		_expect_true(
			RankMirrorRules.is_valid_ai_candidate_deck(baseline_deck, card_rarities, String(rank_key)),
			"%s baseline deck is valid for AI control" % String(rank_key)
		)
		var is_pure_green = RankMirrorRules.deck_has_only_common_animals(baseline_deck, animal_rarities)
		_expect_equal(
			RankMirrorRules.should_record_deck(baseline_deck, card_rarities, String(rank_key)),
			not is_pure_green,
			"%s winner storage keeps the pure-green exclusion separate from AI validity" % String(rank_key)
		)
	_expect_false(
		RankMirrorRules.is_valid_ai_candidate_deck(_old_unbalanced_king_deck(), card_rarities, "king"),
		"an AI candidate without a green animal is invalid"
	)
	_expect_false(
		RankMirrorRules.should_record_deck(_old_unbalanced_king_deck(), card_rarities, "king"),
		"the old 0-green / 1-blue / 4-purple / 1-orange King animal mix is rejected"
	)
	_expect_false(
		RankMirrorRules.should_record_deck(["gold_mine_card", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit"], card_rarities, "bronze"),
		"a stored AI deck must preserve its mandatory defense slot"
	)


func _test_policy_migration() -> void:
	var valid_king = _deck_for_rank("king")
	var history = {
		"king": [
			{"mirror_id": "legacy-unbalanced", "deck": _old_unbalanced_king_deck()},
			{"mirror_id": "current-valid", "deck": valid_king},
		],
	}
	for policy_version in [0, 2, RankMirrorRules.POLICY_VERSION]:
		var migrated = RankMirrorRules.migrate_legacy_mirrors(history, int(policy_version))
		var retained: Array = migrated.get("king", [])
		_expect_equal(retained.size(), 1, "policy %d revalidates stored mirrors with the current AI gate" % int(policy_version))
		if retained.size() == 1:
			_expect_equal(
				String((retained[0] as Dictionary).get("mirror_id", "")), "current-valid",
				"policy %d removes the no-green mirror and keeps the valid replacement" % int(policy_version)
			)


func _test_main_recording_gate() -> void:
	var app = MainApp.new()
	app.set("cards", _card_catalog_array())
	app.set("card_levels", _levels_for(_deck_for_rank("king"), 1))
	app.set("rank_db", {
		"version": RankingRules.DB_VERSION,
		"mirror_policy_version": RankMirrorRules.POLICY_VERSION,
		"player": RankingRules.default_profile(),
		"mirrors": {},
	})
	var invalid_bronze = ["gold_mine_card", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit"]
	app.set("deck", invalid_bronze.duplicate())
	app.call("_record_victory_mirror", "bronze", 1)
	_expect_equal(_mirror_count(app, "bronze"), 0, "a victory deck without the required defense is not stored")
	_expect_equal(app.get("deck"), invalid_bronze, "record rejection does not rewrite the player's equipped deck")
	var bronze_deck = _deck_for_rank("bronze")
	app.set("deck", bronze_deck.duplicate())
	app.set("card_levels", _levels_for(bronze_deck, 1))
	app.call("_record_victory_mirror", "bronze", 1)
	_expect_equal(_mirror_count(app, "bronze"), 0, "a pure-green Bronze winner is valid for AI but is not stored as a winner mirror")
	var silver_deck = _deck_for_rank("silver")
	app.set("deck", silver_deck.duplicate())
	app.set("card_levels", _levels_for(silver_deck, 2))
	app.call("_record_victory_mirror", "silver", 1)
	_expect_equal(_mirror_count(app, "silver"), 1, "a valid mixed-quality Silver winner is stored")
	app.set("deck", _old_unbalanced_king_deck())
	app.call("_record_victory_mirror", "king", 1)
	_expect_equal(_mirror_count(app, "king"), 0, "the old unbalanced King deck is not stored")
	var king_deck = _deck_for_rank("king")
	app.set("deck", king_deck.duplicate())
	app.set("card_levels", _levels_for(king_deck, 6))
	app.call("_record_victory_mirror", "king", 1)
	_expect_equal(_mirror_count(app, "king"), 1, "the 2-green / 2-blue / 3-purple / 1-orange King deck is stored")
	app.free()


func _test_invalid_match_mirror_is_replaced() -> void:
	var app = MainApp.new()
	app.set("cards", _card_catalog_array())
	app.set("active_match_rank_key", "king")
	var invalid_deck = _old_unbalanced_king_deck()
	app.call("_apply_match_mirror", {
		"rank_key": "king",
		"deck": invalid_deck,
		"card_levels": _levels_for(invalid_deck, 6),
	})
	var enemy_deck: Array = app.get("enemy_deck")
	var card_rarities = RankMirrorRules.card_rarities_from_cards(_card_catalog_array())
	_expect_true(RankAIDecks.is_valid_ai_deck(enemy_deck, card_rarities), "a no-green match mirror is replaced by a valid AI deck")
	_expect_true(RankAIDecks.has_common_animal(enemy_deck, card_rarities), "the replacement match mirror contains a green animal")
	var camp_card = String(app.call("_enemy_card_for_cost", 50, 17))
	_expect_false(camp_card.is_empty(), "the replacement AI can resolve a common camp animal for building")
	if not camp_card.is_empty():
		_expect_equal(String(card_rarities.get(camp_card, "")), "common", "AI building selects a green animal from the replacement deck")
	app.free()


func _test_server_profile_migration() -> void:
	var store = PlayerAccountStore.new("user://tests/rank_mirror_policy_test.json")
	var normalized: Dictionary = store.call("_normalize_profile", {
		"rank_mirrors": {
			"king": [{"mirror_id": "king-old", "deck": _old_unbalanced_king_deck()}],
		},
	})
	var mirrors: Dictionary = normalized.get("rank_mirrors", {})
	_expect_equal(mirrors.size(), 0, "server migration clears historical unbalanced mirrors")
	_expect_equal(
		int(normalized.get("rank_mirror_policy_version", 0)),
		RankMirrorRules.POLICY_VERSION,
		"server stamps the current mirror policy version"
	)
	var current: Dictionary = store.call("_normalize_profile", {
		"rank_mirror_policy_version": RankMirrorRules.POLICY_VERSION,
		"rank_mirrors": {
			"platinum": [{"mirror_id": "platinum-balanced", "deck": _deck_for_rank("platinum")}],
		},
	})
	_expect_equal(
		(current.get("rank_mirrors", {}) as Dictionary).get("platinum", []).size(), 1,
		"server retains a current-policy balanced mirror"
	)


func _deck_for_rank(rank_key: String) -> Array:
	var mirrors = RankAIDecks.mirrors_for_rank(rank_key)
	if mirrors.is_empty():
		return []
	return (mirrors[0].get("deck", []) as Array).duplicate()


func _old_unbalanced_king_deck() -> Array:
	return [
		"gold_mine_card",
		"defense_storm_obelisk",
		"wolf",
		"beaver",
		"fox",
		"monkey",
		"pig",
		"lion",
	]


func _levels_for(deck: Array, level: int) -> Dictionary:
	var result = {}
	for raw_card_id in deck:
		result[String(raw_card_id)] = level
	return result


func _card_catalog() -> Dictionary:
	var result = {}
	for raw_card_id in RankAIDecks.card_rarity_map():
		var card_id = String(raw_card_id)
		var tags = []
		if card_id == "gold_mine_card":
			tags = ["mine"]
		elif card_id.begins_with("defense_"):
			tags = ["defense"]
		elif card_id == "beaver":
			tags = ["building"]
		result[card_id] = {"id": card_id, "rarity": String(RankAIDecks.card_rarity_map()[card_id]), "tags": tags}
	return result


func _card_catalog_array() -> Array:
	return _card_catalog().values()


func _mirror_count(app: Node, rank_key: String) -> int:
	var database: Dictionary = app.get("rank_db")
	var mirrors: Dictionary = database.get("mirrors", {})
	return (mirrors.get(rank_key, []) as Array).size()


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
