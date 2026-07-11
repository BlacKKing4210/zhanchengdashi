extends SceneTree

const CardRules = preload("res://scripts/app/systems/card_rules.gd")

var failures = 0


func _init() -> void:
	_test_exact_rarity()
	_test_common_advances_to_rare()
	_test_next_higher_rarity()
	_test_multiple_missing_rarities()
	_test_highest_rarity_safety_fallback()
	_test_no_configured_defense()
	_test_animal_candidate_is_rejected()
	_test_mismatched_defense_candidate_is_rejected()
	_test_seed_is_stable()
	_test_animal_fallback_is_unchanged()
	if failures == 0:
		print("Defense rarity fallback tests passed.")
	quit(failures)


func _test_exact_rarity() -> void:
	_expect_equal(
		CardRules.resolve_defense_card_id(
			"defense_rare",
			_defense_cards(["common", "rare", "epic"]),
			"rare",
			11
		),
		"defense_rare",
		"exact defense rarity"
	)


func _test_common_advances_to_rare() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity(
			_defense_cards(["rare", "epic"]),
			"common",
			13
		),
		"defense_rare",
		"missing common advances to rare"
	)


func _test_next_higher_rarity() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity(
			_defense_cards(["common", "epic", "legendary"]),
			"rare",
			17
		),
		"defense_epic",
		"missing rare advances to epic"
	)


func _test_multiple_missing_rarities() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity(
			_defense_cards(["common", "legendary"]),
			"rare",
			23
		),
		"defense_legendary",
		"missing rare and epic advances to legendary"
	)


func _test_highest_rarity_safety_fallback() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity(
			_defense_cards(["common", "epic"]),
			"legendary",
			29
		),
		"defense_epic",
		"missing legendary falls back to nearest lower rarity"
	)


func _test_no_configured_defense() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity([], "rare", 31),
		"",
		"no configured defense returns empty"
	)


func _test_animal_candidate_is_rejected() -> void:
	_expect_equal(
		CardRules.resolve_defense_card_id(
			"animal_rare",
			_defense_cards(["common", "epic"]),
			"rare",
			37
		),
		"defense_epic",
		"animal candidate is replaced by next defense rarity"
	)


func _test_mismatched_defense_candidate_is_rejected() -> void:
	_expect_equal(
		CardRules.resolve_defense_card_id(
			"defense_common",
			_defense_cards(["common", "epic"]),
			"rare",
			41
		),
		"defense_epic",
		"mismatched defense candidate uses target rarity fallback"
	)


func _test_seed_is_stable() -> void:
	var cards = [
		{"id": "defense_epic_a", "rarity": "epic"},
		{"id": "defense_epic_b", "rarity": "epic"},
	]
	var first = CardRules.defense_card_id_for_target_rarity(cards, "rare", 43)
	var second = CardRules.defense_card_id_for_target_rarity(cards, "rare", 43)
	_expect_equal(first, second, "same seed keeps defense selection stable")


func _test_animal_fallback_is_unchanged() -> void:
	_expect_array_equal(
		CardRules.rarity_search_order("epic"),
		["epic", "rare", "common"],
		"animal rarity still falls downward"
	)


func _defense_cards(rarities: Array) -> Array:
	var result = []
	for rarity in rarities:
		result.append({"id": "defense_%s" % String(rarity), "rarity": String(rarity)})
	return result


func _expect_equal(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, expected, actual])


func _expect_array_equal(actual: Array, expected: Array, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
