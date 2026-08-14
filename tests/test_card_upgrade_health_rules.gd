extends SceneTree

const CardRules = preload("res://scripts/app/systems/card_rules.gd")

var failures = 0


func _init() -> void:
	_test_ranged_animals_gain_health_every_two_levels()
	_test_melee_summon_animals_gain_health_every_level()
	_test_melee_animals_gain_health_every_level()
	_test_non_animal_cards_do_not_receive_the_animal_rule()
	_test_non_health_animal_stats_keep_the_level_multiplier()
	if failures == 0:
		print("Card upgrade health rule tests passed.")
	quit(failures)


func _test_ranged_animals_gain_health_every_two_levels() -> void:
	var card = _card("ranged", 10, 80.0, "", ["ranged"])
	var expected_health = [10, 11, 11, 12, 12, 13, 13, 14]
	_expect_true(CardRules.is_ranged_animal(card), "range above 40 is ranged")
	for level in range(1, 9):
		_expect_equal(CardRules.upgrade_hp_bonus(card, {"ranged": level}), floori(float(level) / 2.0), "ranged level %d uses the half-rate bonus" % level)
		_expect_equal(int(CardRules.card_stats(card, {"ranged": level})["max_hp"]), expected_health[level - 1], "ranged level %d has exact fixed health" % level)


func _test_melee_summon_animals_gain_health_every_level() -> void:
	var card = _card("summoner", 4, 40.0, "summon", ["summon"])
	_expect_false(CardRules.is_ranged_animal(card), "a summon effect does not override melee range classification")
	_expect_false(CardRules.is_ranged_or_summon_animal(card), "compatibility helper also follows strict range classification")
	for level in range(1, 9):
		_expect_equal(CardRules.upgrade_hp_bonus(card, {"summoner": level}), level - 1, "melee summoner level %d gains one health per upgrade" % level)
		_expect_equal(int(CardRules.card_stats(card, {"summoner": level})["max_hp"]), 4 + level - 1, "melee summoner level %d has exact fixed health" % level)


func _test_melee_animals_gain_health_every_level() -> void:
	var melee_card = _card("melee", 10, 40.0, "", ["bruiser"])
	_expect_true(CardRules.is_animal_card(melee_card), "melee card is an animal")
	_expect_false(CardRules.is_ranged_animal(melee_card), "range at 40 remains melee")
	for level in range(1, 9):
		_expect_equal(CardRules.upgrade_hp_bonus(melee_card, {"melee": level}), level - 1, "melee level %d gains one health per upgrade" % level)
		_expect_equal(int(CardRules.card_stats(melee_card, {"melee": level})["max_hp"]), 10 + level - 1, "melee level %d has exact fixed health" % level)


func _test_non_animal_cards_do_not_receive_the_animal_rule() -> void:
	var building_card = _card("tower", 10, 80.0, "", ["building", "defense", "tower"])
	_expect_false(CardRules.is_animal_card(building_card), "building is not an animal")
	_expect_false(CardRules.is_ranged_or_summon_animal(building_card), "ranged building does not receive the animal rule")
	_expect_equal(CardRules.upgrade_hp_bonus(building_card, {"tower": 8}), 0, "building receives no animal health bonus")
	for level in range(1, 9):
		var expected = roundi(10.0 * CardRules.card_multiplier({"tower": level}, "tower"))
		_expect_equal(int(CardRules.card_stats(building_card, {"tower": level})["max_hp"]), expected, "building level %d keeps percentage health scaling" % level)


func _test_non_health_animal_stats_keep_the_level_multiplier() -> void:
	var card = _card("scaled", 10, 40.0, "", ["bruiser"])
	var stats = CardRules.card_stats(card, {"scaled": 3})
	var mult = CardRules.card_multiplier({"scaled": 3}, "scaled")
	_expect_equal(int(stats["attack"]), roundi(10.0 * mult), "animal attack keeps percentage level scaling")
	_expect_close(float(stats["move_speed"]), 40.0 * mult, "animal speed keeps percentage level scaling")
	_expect_close(float(stats["attack_range"]), 40.0 * mult, "animal range keeps percentage level scaling")
	_expect_close(float(stats["summon_interval_sec"]), 5.0 / mult, "animal summon interval keeps percentage level scaling")


func _card(card_id: String, hp: int, attack_range: float, effect: String, tags: Array) -> Dictionary:
	return {
		"id": card_id,
		"base_attack": 10,
		"base_max_hp": hp,
		"base_move_speed": 40.0,
		"base_attack_range": attack_range,
		"base_summon_interval_sec": 5.0,
		"skill_effect": effect,
		"tags": tags,
	}


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error(label)


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)


func _expect_equal(actual, expected, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, expected, actual])


func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= 0.001:
		return
	failures += 1
	push_error("%s: expected %.3f, got %.3f" % [label, expected, actual])
