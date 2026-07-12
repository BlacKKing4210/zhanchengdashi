extends SceneTree

const CardRules = preload("res://scripts/app/systems/card_rules.gd")

var failures = 0


func _init() -> void:
	_test_downward_search_order()
	_test_exact_rarity_is_random_within_rarity()
	_test_legendary_falls_back_to_rare()
	_test_epic_falls_back_to_common()
	_test_rare_never_advances_to_epic()
	_test_common_never_advances_to_rare()
	_test_no_configured_defense()
	_test_candidate_outside_roster_is_ignored()
	_test_seed_is_stable()
	_test_animal_fallback_is_unchanged()
	if failures == 0:
		print("Defense rarity fallback tests passed.")
	quit(failures)


func _test_downward_search_order() -> void:
	_expect_array_equal(CardRules.defense_rarity_search_order("common"), ["common"], "common searches only common")
	_expect_array_equal(CardRules.defense_rarity_search_order("rare"), ["rare", "common"], "rare searches downward")
	_expect_array_equal(CardRules.defense_rarity_search_order("epic"), ["epic", "rare", "common"], "epic searches downward")
	_expect_array_equal(
		CardRules.defense_rarity_search_order("legendary"),
		["legendary", "epic", "rare", "common"],
		"legendary searches downward"
	)


func _test_exact_rarity_is_random_within_rarity() -> void:
	var cards = [
		{"id": "defense_common", "rarity": "common"},
		{"id": "defense_rare_a", "rarity": "rare"},
		{"id": "defense_rare_b", "rarity": "rare"},
	]
	var seen = {}
	for seed in range(1, 21):
		var result = CardRules.defense_card_id_for_target_rarity(cards, "rare", seed)
		_expect_true(result in ["defense_rare_a", "defense_rare_b"], "exact rarity stays inside roster rarity")
		seen[result] = true
	_expect_equal(seen.size(), 2, "different seeds can reach both same-rarity defenses")


func _test_legendary_falls_back_to_rare() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity(_defense_cards(["common", "rare"]), "legendary", 13),
		"defense_rare",
		"legendary target uses highest lower roster rarity"
	)


func _test_epic_falls_back_to_common() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity(_defense_cards(["common", "legendary"]), "epic", 17),
		"defense_common",
		"epic target skips higher legendary and falls to common"
	)


func _test_rare_never_advances_to_epic() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity(_defense_cards(["epic", "legendary"]), "rare", 23),
		"",
		"rare target never advances to a higher rarity"
	)


func _test_common_never_advances_to_rare() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity(_defense_cards(["rare", "epic"]), "common", 29),
		"",
		"common target returns empty when common is absent"
	)


func _test_no_configured_defense() -> void:
	_expect_equal(
		CardRules.defense_card_id_for_target_rarity([], "rare", 31),
		"",
		"no roster defense returns empty"
	)


func _test_candidate_outside_roster_is_ignored() -> void:
	var roster = [
		{"id": "defense_common", "rarity": "common"},
		{"id": "defense_rare_in_roster", "rarity": "rare"},
	]
	_expect_equal(
		CardRules.resolve_defense_card_id("defense_rare_outside_roster", roster, "rare", 37),
		"defense_rare_in_roster",
		"config candidate cannot bypass the roster"
	)


func _test_seed_is_stable() -> void:
	var cards = [
		{"id": "defense_epic_a", "rarity": "epic"},
		{"id": "defense_epic_b", "rarity": "epic"},
	]
	var first = CardRules.defense_card_id_for_target_rarity(cards, "epic", 43)
	var second = CardRules.defense_card_id_for_target_rarity(cards, "epic", 43)
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


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_array_equal(actual: Array, expected: Array, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
